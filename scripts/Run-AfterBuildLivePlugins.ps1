<#
.SYNOPSIS
  Finds wordpress_plugins/scripts/after-build-live-plugins.ps1 from a plugin repo and runs it.

.DESCRIPTION
  Walks upward from -PluginProjectRoot until scripts/after-build-live-plugins.ps1 exists, then invokes it.
  Use at the end of every plugin build script after the zip is built.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$PluginProjectRoot
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath $PluginProjectRoot).Path
$c = $repo
while ($true) {
  # Only the wordpress_plugins monorepo root has publish-live-plugins + after-build here.
  # Plugin repos also ship scripts/after-build-live-plugins.ps1 (thin wrapper); do not invoke that or we recurse.
  $publish = Join-Path $c '.tools\scripts\publish-live-plugins.ps1'
  $abf = Join-Path $c 'scripts\after-build-live-plugins.ps1'
  if ((Test-Path -LiteralPath $publish) -and (Test-Path -LiteralPath $abf)) {
    & $abf -RepoRoot $repo
    exit $LASTEXITCODE
  }
  $p = Split-Path -Parent $c
  if (-not $p -or $p -eq $c) {
    Write-Host "Run-AfterBuildLivePlugins: wordpress_plugins root (publish + after-build) not found above $repo ; skipped."
    exit 0
  }
  $c = $p
}
