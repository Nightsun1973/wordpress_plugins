<#
.SYNOPSIS
  Standard plugin zip build wrapper for Chameleon plugin repos.
.DESCRIPTION
  Dot-source from plugin build scripts. Outputs dist/<slug>/<slug>-<version>.zip.
#>
function Get-ChameleonWordpressPluginsRoot {
    param([string]$Start)
    $cur = (Resolve-Path -LiteralPath $Start).Path
    while ($true) {
        if ((Split-Path -Leaf $cur) -eq 'wordpress_plugins') { return $cur }
        $parent = Split-Path -Parent $cur
        if (-not $parent -or $parent -eq $cur) { return $null }
        $cur = $parent
    }
}

function Invoke-ChameleonPluginZipBuild {
    param(
        [Parameter(Mandatory = $true)][string]$Slug,
        [Parameter(Mandatory = $true)][string]$SourceRelative,
        [Parameter(Mandatory = $true)][string]$VersionRelative
    )
    $projectRoot = (Get-Location).Path
    $wpRoot = Get-ChameleonWordpressPluginsRoot -Start $projectRoot
    if (-not $wpRoot) { throw "Could not locate wordpress_plugins root" }

    . (Join-Path $wpRoot '.tools\scripts\Invoke-StandardPluginZipBuild.ps1')

    $sourceDir = Join-Path $projectRoot $SourceRelative
    $versionFile = Join-Path $projectRoot $VersionRelative
    Invoke-StandardPluginZipBuild -ProjectRoot $projectRoot -Slug $Slug -SourceDir $sourceDir -VersionFile $versionFile
}
