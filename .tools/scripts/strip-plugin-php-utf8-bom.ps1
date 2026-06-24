# Strip UTF-8 BOM from PHP files under a directory tree.
# Usage: .\.tools\scripts\strip-plugin-php-utf8-bom.ps1 -RootDir plugins-dev

param(
    [Parameter(Mandatory = $true)]
    [string] $RootDir,
    [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $RootDir)) {
    Write-Error "RootDir not found: $RootDir"
}

$root = (Resolve-Path -LiteralPath $RootDir).Path
$stripped = @()

Get-ChildItem -LiteralPath $root -Recurse -Filter '*.php' -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch '\\(vendor|node_modules|_zip_build|archive)\\'
    } |
    ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $rel = $_.FullName.Substring($root.Length).TrimStart('\')
            if ($WhatIf) {
                Write-Host "Would strip BOM: $rel"
            } else {
                [System.IO.File]::WriteAllBytes($_.FullName, $bytes[3..($bytes.Length - 1)])
                Write-Host "Stripped BOM: $rel"
            }
            $stripped += $_.FullName
        }
    }

Write-Host "Done. Files with BOM: $($stripped.Count)"
exit 0
