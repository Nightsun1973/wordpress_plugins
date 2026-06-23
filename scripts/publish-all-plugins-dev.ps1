<#
.SYNOPSIS
  Publish newest dist zips from every plugins-dev repo into plugins-live, regenerate index.json, optional SFTP.
.EXAMPLE
  .\scripts\publish-all-plugins-dev.ps1
#>
$ErrorActionPreference = 'Stop'

$wpRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pluginsDev = Join-Path $wpRoot 'plugins-dev'
$liveDir = Join-Path $wpRoot 'plugins-live'
$publish = Join-Path $wpRoot '.tools\scripts\publish-live-plugins.ps1'

if (-not (Test-Path -LiteralPath $pluginsDev)) {
  throw "Missing plugins-dev: $pluginsDev"
}

function Parse-SlugVersionFromZipName {
  param([string]$ZipFileName)
  $m = [regex]::Match($ZipFileName, '^(?<slug>.+)-(?<ver>\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\.zip$')
  if (-not $m.Success) { return $null }
  return [pscustomobject]@{ Slug = $m.Groups['slug'].Value; Version = $m.Groups['ver'].Value }
}

New-Item -ItemType Directory -Force -Path $liveDir | Out-Null

$zips = @()
foreach ($distName in @('dist', 'plugins\dist')) {
  Get-ChildItem -LiteralPath $pluginsDev -Recurse -Directory -Filter $distName -ErrorAction SilentlyContinue |
    ForEach-Object {
      $zips += Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Filter '*.zip' -ErrorAction SilentlyContinue
    }
}

if (-not $zips -or $zips.Count -eq 0) {
  Write-Host 'No zips found under plugins-dev/**/dist or plugins-dev/**/plugins/dist'
  exit 0
}

$bySlug = @{}
foreach ($z in $zips) {
  $parsed = Parse-SlugVersionFromZipName -ZipFileName $z.Name
  if (-not $parsed) { continue }
  $slug = $parsed.Slug
  if (-not $bySlug.ContainsKey($slug)) { $bySlug[$slug] = @() }
  $bySlug[$slug] += [pscustomobject]@{
    File = $z
    Slug = $slug
    Version = $parsed.Version
    LastWriteTimeUtc = $z.LastWriteTimeUtc
  }
}

foreach ($slug in ($bySlug.Keys | Sort-Object)) {
  $latest = $bySlug[$slug] | Sort-Object @{
    Expression = {
      $parts = $_.Version -split '\.'
      [version]"$($parts[0]).$($parts[1]).$($parts[2])"
    }
  } -Descending | Select-Object -First 1
  $destName = "$($latest.Slug)-$($latest.Version).zip"
  $dest = Join-Path $liveDir $destName
  Get-ChildItem -LiteralPath $liveDir -File -Filter "$slug-*.zip" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $dest } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
  Copy-Item -LiteralPath $latest.File.FullName -Destination $dest -Force
  Write-Host "PUBLISHED $slug => $destName"
}

$manifestScript = Join-Path $wpRoot '.tools\scripts\generate-live-plugins-manifest.ps1'
if (Test-Path -LiteralPath $manifestScript) {
  & $manifestScript -LivePluginsDir $liveDir
}

& (Join-Path $wpRoot 'scripts\push-plugins-live-to-server.ps1')
