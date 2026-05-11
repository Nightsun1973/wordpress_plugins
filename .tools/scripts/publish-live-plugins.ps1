param(
  [Parameter(Mandatory = $false)]
  [string]$RepoRoot = '.',

  [Parameter(Mandatory = $false)]
  [string]$LivePluginsDir = $null
)

$ErrorActionPreference = 'Stop'

function Get-WordpressPluginsRoot {
  param([string]$StartPath)
  $p = Resolve-Path -LiteralPath $StartPath
  $cur = $p.Path
  while ($true) {
    $name = Split-Path -Leaf $cur
    if ($name -eq 'wordpress_plugins') { return $cur }
    $parent = Split-Path -Parent $cur
    if (-not $parent -or $parent -eq $cur) { return $null }
    $cur = $parent
  }
}

function Get-ZipCandidates {
  param([string]$Root)
  $paths = @(
    (Join-Path $Root 'dist'),
    (Join-Path $Root 'plugins\dist')
  )
  $zips = @()
  foreach ($p in $paths) {
    if (Test-Path -LiteralPath $p) {
      $zips += Get-ChildItem -LiteralPath $p -Recurse -File -Filter *.zip -ErrorAction SilentlyContinue
    }
  }
  return $zips
}

function Parse-SlugVersionFromZipName {
  param([string]$ZipFileName)
  # expected: <slug>-<version>.zip where <version> resembles semver
  $m = [regex]::Match($ZipFileName, '^(?<slug>.+)-(?<ver>\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\.zip$')
  if (-not $m.Success) { return $null }
  return [pscustomobject]@{ Slug = $m.Groups['slug'].Value; Version = $m.Groups['ver'].Value }
}

$repoRootPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$wpRoot = Get-WordpressPluginsRoot -StartPath $repoRootPath
if (-not $wpRoot) { throw "Could not locate wordpress_plugins root from: $repoRootPath" }

if (-not $LivePluginsDir) {
  $LivePluginsDir = Join-Path $wpRoot 'plugins-live'
}

New-Item -ItemType Directory -Force -Path $LivePluginsDir | Out-Null

$candidates = Get-ZipCandidates -Root $repoRootPath
if (-not $candidates -or $candidates.Count -eq 0) {
  Write-Host "No zip files found under dist/ or plugins/dist/ for: $repoRootPath"
  exit 0
}

# Choose the newest zip per slug, by LastWriteTimeUtc
$bySlug = @{}
foreach ($z in $candidates) {
  $parsed = Parse-SlugVersionFromZipName -ZipFileName $z.Name
  if (-not $parsed) { continue }

  $slug = $parsed.Slug
  if (-not $bySlug.ContainsKey($slug)) {
    $bySlug[$slug] = @()
  }
  $bySlug[$slug] += [pscustomobject]@{
    File = $z
    Slug = $slug
    Version = $parsed.Version
    LastWriteTimeUtc = $z.LastWriteTimeUtc
  }
}

if ($bySlug.Keys.Count -eq 0) {
  Write-Host "Zip files were found, but none matched the expected <slug>-<version>.zip pattern."
  Write-Host "Found:"
  $candidates | Select-Object -ExpandProperty FullName | ForEach-Object { Write-Host " - $_" }
  exit 0
}

foreach ($slug in ($bySlug.Keys | Sort-Object)) {
  $latest = $bySlug[$slug] | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
  $src = $latest.File.FullName
  $destName = "$($latest.Slug)-$($latest.Version).zip"
  $dest = Join-Path $LivePluginsDir $destName

  # Remove any previous versions in plugins-live for this slug
  Get-ChildItem -LiteralPath $LivePluginsDir -File -Filter "$slug-*.zip" -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.FullName -ne $dest) {
      Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
    }
  }

  Copy-Item -LiteralPath $src -Destination $dest -Force
  Write-Host "PUBLISHED $slug => $destName"
}

# Update manifest (best effort; never fail publish if manifest generation fails)
try {
  $wpRoot = Get-WordpressPluginsRoot -StartPath $repoRootPath
  if ($wpRoot) {
    $manifestScript = Join-Path (Join-Path $wpRoot '.tools\scripts') 'generate-live-plugins-manifest.ps1'
    if (Test-Path -LiteralPath $manifestScript) {
      powershell -NoProfile -ExecutionPolicy Bypass -File $manifestScript -LivePluginsDir $LivePluginsDir | Out-Null
    }
  }
} catch {
  Write-Host "WARN: plugins-live manifest not updated: $($_.Exception.Message)"
}

# Load SFTP credentials when scripts/live-plugins-ftp.env exists so uploads run after build without manually dot-sourcing load-live-plugins-ftp-env.ps1 in the same session.
$ftpEnvFile = Join-Path $wpRoot 'scripts\live-plugins-ftp.env'
$ftpEnvLoader = Join-Path $wpRoot 'scripts\load-live-plugins-ftp-env.ps1'
if ((Test-Path -LiteralPath $ftpEnvFile) -and (Test-Path -LiteralPath $ftpEnvLoader)) {
  try {
    . $ftpEnvLoader
  } catch {
    Write-Host "WARN: Could not load scripts/live-plugins-ftp.env: $($_.Exception.Message)"
  }
}

# Optional: mirror to public repo over SFTP (env CHAMELEON_LIVE_PLUGINS_SFTP_HOST or CHAMELEON_LIVE_PLUGINS_FTP_HOST) — scripts/sync-live-plugins-repo-ftp.ps1
if (($env:CHAMELEON_LIVE_PLUGINS_SFTP_HOST -and $env:CHAMELEON_LIVE_PLUGINS_SFTP_HOST.Trim()) -or ($env:CHAMELEON_LIVE_PLUGINS_FTP_HOST -and $env:CHAMELEON_LIVE_PLUGINS_FTP_HOST.Trim())) {
  $syncScript = Join-Path $wpRoot 'scripts\sync-live-plugins-repo-ftp.ps1'
  if (Test-Path -LiteralPath $syncScript) {
    & $syncScript -LivePluginsDir $LivePluginsDir
  } else {
    Write-Host "WARN: FTP sync skipped; script not found: $syncScript"
  }
}

