<#
.SYNOPSIS
  Publish the plugin repo's latest dist zip(s) to plugins-live and run SFTP sync when env is set.

.DESCRIPTION
  Lives under wordpress_plugins/scripts/. Invoked with -RepoRoot pointing at a plugin project root
  (folder containing README.md and dist/). Calls .tools/scripts/publish-live-plugins.ps1.
#>
param(
  [Parameter(Mandatory = $false)]
  [string]$RepoRoot = '.'
)

$ErrorActionPreference = 'Stop'
$wpRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$publish = Join-Path $wpRoot '.tools\scripts\publish-live-plugins.ps1'
if (-not (Test-Path -LiteralPath $publish)) {
  throw "Missing publish script: $publish"
}
$repoResolved = (Resolve-Path -LiteralPath $RepoRoot).Path
& $publish -RepoRoot $repoResolved
