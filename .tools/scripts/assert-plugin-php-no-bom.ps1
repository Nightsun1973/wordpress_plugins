# Assert plugin PHP sources or an install zip contain no UTF-8 BOM.
# Usage:
#   .\.tools\scripts\assert-plugin-php-no-bom.ps1 -SourceDir plugins-dev\chameleon\other\kore-sim-manager\plugin
#   .\.tools\scripts\assert-plugin-php-no-bom.ps1 -ZipPath plugins-live\kore-sim-manager-1.1.44.zip

param(
    [string] $SourceDir,
    [string] $ZipPath
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$wpRoot    = Split-Path -Parent (Split-Path -Parent $scriptDir)
$helper    = Join-Path $wpRoot '.tools\scripts\build-plugin-install-zip.ps1'

if (-not (Test-Path -LiteralPath $helper)) {
    Write-Error "Shared helper not found: $helper"
}

. $helper

if ($SourceDir -and $ZipPath) {
    Write-Error 'Specify -SourceDir or -ZipPath, not both.'
}
if (-not $SourceDir -and -not $ZipPath) {
    Write-Error 'Specify -SourceDir <plugin-folder> or -ZipPath <install.zip>.'
}

if ($SourceDir) {
    if (-not (Test-Path -LiteralPath $SourceDir)) {
        Write-Error "SourceDir not found: $SourceDir"
    }
    Assert-PluginPhpNoUtf8Bom -SourceDir (Resolve-Path -LiteralPath $SourceDir).Path
    Write-Host "OK: no UTF-8 BOM in PHP under $SourceDir"
    exit 0
}

if (-not (Test-Path -LiteralPath $ZipPath)) {
    Write-Error "ZipPath not found: $ZipPath"
}
Assert-PluginInstallZipNoUtf8Bom -ZipPath (Resolve-Path -LiteralPath $ZipPath).Path
Write-Host "OK: no UTF-8 BOM in PHP entries in $ZipPath"
exit 0
