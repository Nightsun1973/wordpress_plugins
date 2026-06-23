# Shared plugin zip build: dist/<slug>/<slug>-<version>.zip with POSIX paths.
# Dot-source from plugin scripts after locating wordpress_plugins root.

function Find-WordpressPluginsRootFromPath {
    param([string]$Start)
    $cur = (Resolve-Path -LiteralPath $Start).Path
    while ($true) {
        if ((Split-Path -Leaf $cur) -eq 'wordpress_plugins') { return $cur }
        $parent = Split-Path -Parent $cur
        if (-not $parent -or $parent -eq $cur) { return $null }
        $cur = $parent
    }
}

function Invoke-StandardPluginZipBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$Slug,
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$VersionFile
    )

    $wpRoot = Find-WordpressPluginsRootFromPath -Start $ProjectRoot
    if (-not $wpRoot) { throw "Could not locate wordpress_plugins root from: $ProjectRoot" }

    $lib = Join-Path $wpRoot '.tools\scripts\build-plugin-install-zip.ps1'
    if (-not (Test-Path -LiteralPath $lib)) { throw "Missing shared zip helper: $lib" }
    . $lib

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "SourceDir not found: $SourceDir"
    }
    if (-not (Test-Path -LiteralPath $VersionFile)) {
        throw "VERSION file not found: $VersionFile"
    }

    $version = (Get-Content -LiteralPath $VersionFile -Raw).Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+') {
        throw "Invalid VERSION: $version"
    }

    $distDir = Join-Path (Join-Path $ProjectRoot 'dist') $Slug
    if (-not (Test-Path -LiteralPath $distDir)) {
        New-Item -ItemType Directory -Path $distDir -Force | Out-Null
    }

    $zipPath = Join-Path $distDir "$Slug-$version.zip"
    Build-PluginInstallZip -SourceDir $SourceDir -Slug $Slug -Version $version -OutZip $zipPath
    Assert-PluginInstallZipPosixPaths -ZipPath $zipPath -ExpectedSlug $Slug

    $cleanup = Join-Path $ProjectRoot 'scripts\cleanup-plugin-zips.ps1'
    if (Test-Path -LiteralPath $cleanup) {
        & $cleanup
    } else {
        $masterCleanup = Join-Path $wpRoot '.tools\scripts\cleanup-plugin-zips.ps1'
        if (Test-Path -LiteralPath $masterCleanup) { & $masterCleanup }
    }

    $afterBuild = Join-Path $ProjectRoot 'scripts\after-build-live-plugins.ps1'
    if ((Test-Path -LiteralPath $afterBuild) -and $env:CHAMELEON_SKIP_LIVE_PUBLISH -ne '1') {
        & $afterBuild
    }

    return $zipPath
}
