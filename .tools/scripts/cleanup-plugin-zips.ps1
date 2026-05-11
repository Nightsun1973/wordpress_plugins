$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
  Keeps only the last 5 zips plus any x.0.0 release zips per plugin folder.
.DESCRIPTION
  This is the **master** copy for the shared workspace.

  Run from a plugin repo root. By default it operates on:
  - dist/<slug>/<slug>-<version>.zip

  Each plugin repo can keep its own specialized wrapper script if needed.
.EXAMPLE
  .\.tools\scripts\cleanup-plugin-zips.ps1
#>

$projectRoot = (Get-Location).Path
$readmePath = Join-Path $projectRoot 'README.md'

if (-not (Test-Path $readmePath)) {
  Write-Error "Run this script from the project root (folder containing README.md). Current: $projectRoot"
}

$keepLast = 5

function Invoke-PluginZipRetention {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ZipDir,
    [Parameter(Mandatory = $true)]
    [string]$Prefix
  )

  if (-not (Test-Path $ZipDir)) {
    return
  }

  $pattern = Join-Path $ZipDir "$Prefix-*.zip"
  $zips = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
  if (-not $zips -or $zips.Count -eq 0) {
    return
  }

  $withVersion = $zips | ForEach-Object {
    $ver = ($_.Name -replace "^$([regex]::Escape($Prefix))-|\.zip$", '')
    [PSCustomObject]@{ Path = $_.FullName; Name = $_.Name; Version = $ver }
  } | Where-Object {
    $_.Version -match '^\d+\.\d+\.\d+$'
  }

  if (-not $withVersion) {
    return
  }

  $sorted = $withVersion | Sort-Object { [version]$_.Version } -Descending
  $majorReleases = $sorted | Where-Object { $_.Version -match '^\d+\.0\.0$' }
  $topN = $sorted | Select-Object -First $keepLast
  $keepPaths = @($majorReleases.Path) + @($topN.Path) | Select-Object -Unique

  $toDelete = $sorted | Where-Object { $_.Path -notin $keepPaths }
  foreach ($item in $toDelete) {
    Remove-Item -LiteralPath $item.Path -Force
    Write-Host "Deleted (zip retention): $($item.Name)"
  }
}

# Default convention: dist/<slug>/<slug>-<version>.zip
$distRoot = Join-Path $projectRoot 'dist'
if (-not (Test-Path $distRoot)) {
  exit 0
}

$pluginDirs = Get-ChildItem -LiteralPath $distRoot -Directory -ErrorAction SilentlyContinue
foreach ($d in $pluginDirs) {
  $prefix = $d.Name
  Invoke-PluginZipRetention -ZipDir $d.FullName -Prefix $prefix
}

