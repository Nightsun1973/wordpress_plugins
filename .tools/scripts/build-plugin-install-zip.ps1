# Shared helper for building WordPress plugin installation zips.
#
# Why this exists:
#   PowerShell's Compress-Archive can write backslash ('\') path separators in the
#   zip's central directory. Linux/PHP (Cloudways, WP's unzip_file()) does NOT
#   treat '\' as a directory separator, so the archive looks like a flat list of
#   filenames containing backslashes. WordPress can't find a single top-level
#   folder, falls back to naming the install folder after the zip filename
#   (e.g. plugins/<slug>-<version>/), and the plugin won't activate
#   ("Plugin file does not exist.").
#
# This helper:
#   - Uses System.IO.Compression.ZipArchive directly.
#   - Writes every entry path with forward slashes ('/').
#   - Forces a single top-level folder named exactly $Slug/.
#
# Usage:
#   . "$WpRoot\.tools\scripts\build-plugin-install-zip.ps1"
#   Build-PluginInstallZip -SourceDir "$ProjectRoot\plugin" `
#                          -Slug      'my-plugin' `
#                          -Version   '1.2.3' `
#                          -OutZip    "$ProjectRoot\dist\my-plugin\my-plugin-1.2.3.zip"

function Strip-PluginPhpUtf8Bom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $SourceDir
    )

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Strip-PluginPhpUtf8Bom: SourceDir not found: $SourceDir"
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    Get-ChildItem -LiteralPath $SourceDir -Recurse -Filter '*.php' -File | ForEach-Object {
        $path = $_.FullName
        $bytes = [System.IO.File]::ReadAllBytes($path)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $trimmed = New-Object byte[] ($bytes.Length - 3)
            [Array]::Copy($bytes, 3, $trimmed, 0, $trimmed.Length)
            [System.IO.File]::WriteAllBytes($path, $trimmed)
            Write-Warning "Stripped UTF-8 BOM before zip: $path"
        }
    }
}

function Build-PluginInstallZip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $SourceDir,
        [Parameter(Mandatory = $true)] [string] $Slug,
        [Parameter(Mandatory = $true)] [string] $Version,
        [Parameter(Mandatory = $true)] [string] $OutZip
    )

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Build-PluginInstallZip: SourceDir not found: $SourceDir"
    }

    Strip-PluginPhpUtf8Bom -SourceDir $SourceDir

    Add-Type -AssemblyName System.IO.Compression       | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

    $sourceFull = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\','/')

    $outDir = Split-Path -Parent $OutZip
    if (-not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $OutZip) { Remove-Item -LiteralPath $OutZip -Force }

    $compression = [System.IO.Compression.CompressionLevel]::Optimal
    $rootPrefix = "$Slug/"

    $zipStream = [System.IO.File]::Open($OutZip, [System.IO.FileMode]::CreateNew)
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            Get-ChildItem -LiteralPath $sourceFull -Recurse -File | ForEach-Object {
                $rel = $_.FullName.Substring($sourceFull.Length).TrimStart('\','/')
                $entryName = $rootPrefix + ($rel -replace '\\', '/')

                $entry = $zip.CreateEntry($entryName, $compression)
                $entryStream = $entry.Open()
                try {
                    $fileStream = [System.IO.File]::OpenRead($_.FullName)
                    try {
                        $fileStream.CopyTo($entryStream)
                    } finally {
                        $fileStream.Dispose()
                    }
                } finally {
                    $entryStream.Dispose()
                }
            }
        } finally {
            $zip.Dispose()
        }
    } finally {
        $zipStream.Dispose()
    }

    Write-Host "Built: $OutZip (slug=$Slug version=$Version)"
}

function Assert-PluginInstallZipPosixPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $ZipPath,
        [Parameter(Mandatory = $true)] [string] $ExpectedSlug
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $bad = @()
        $roots = New-Object System.Collections.Generic.HashSet[string]
        foreach ($e in $zip.Entries) {
            if ($e.FullName -match '\\') { $bad += $e.FullName; continue }
            $first = ($e.FullName -split '/')[0]
            if ($first) { [void]$roots.Add($first) }
        }
        if ($bad.Count -gt 0) {
            throw ("Zip contains $($bad.Count) entries with backslash separators (Linux/PHP-unsafe): " + ($bad -join ', '))
        }
        if ($roots.Count -ne 1 -or -not $roots.Contains($ExpectedSlug)) {
            throw ("Zip top-level folders = [$($roots -join ', ')]; expected exactly [$ExpectedSlug]")
        }
    } finally {
        $zip.Dispose()
    }
}
