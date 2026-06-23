<#
.SYNOPSIS
  Migrate legacy chameleon-* install slugs to functional slugs (keeps chameleon-admin).
.EXAMPLE
  .\scripts\migrate-chameleon-slugs.ps1
#>
$ErrorActionPreference = 'Stop'

$wpRoot = $PSScriptRoot | Split-Path -Parent
$scanRoot = Join-Path $wpRoot 'plugins-dev'

$slugMap = [ordered]@{
  'chameleon-mailer'                  = 'woo-mailer'
  'chameleon-regional-stock-control'  = 'woo-region-stock-levels'
  'chameleon-cron-monitor'            = 'cron-monitor'
  'chameleon-booking'                 = 'simple-booking'
  'chameleon-demo-gate'               = 'demo-gate'
  'cc-complete-address'               = 'complete-address'
  'cc-media-cleanup'                  = 'media-cleanup'
  'cc-custom-online-diary'            = 'custom-online-diary'
}

function Replace-InTree {
  param(
    [string]$Root,
    [hashtable]$Map
  )
  if (-not (Test-Path -LiteralPath $Root)) { return }
  $ext = @('.php', '.ps1', '.md', '.mdc', '.json', '.txt', '.js', '.css', '.html')
  Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
    Where-Object {
      $_.FullName -notmatch '\\\.git\\' -and
      $_.FullName -notmatch '\\dist\\' -and
      $ext -contains $_.Extension.ToLower()
    } |
    ForEach-Object {
      if ([string]::IsNullOrEmpty($_.Extension)) { return }
      $raw = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
      if ($null -eq $raw) { return }
      $new = $raw
      foreach ($k in $Map.Keys) {
        $new = $new.Replace($k, $Map[$k])
      }
      if ($new -ne $raw) {
        Set-Content -LiteralPath $_.FullName -Value $new -Encoding UTF8 -NoNewline
        Write-Host "  updated: $($_.FullName)"
      }
    }
}

function Rename-IfExists {
  param([string]$Path, [string]$NewName)
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $parent = Split-Path -Parent $Path
  $dest = Join-Path $parent $NewName
  if (Test-Path -LiteralPath $dest) {
    Write-Warning "Skip rename (dest exists): $dest"
    return $false
  }
  Rename-Item -LiteralPath $Path -NewName $NewName
  Write-Host "  renamed: $Path -> $NewName"
  return $true
}

function Bump-VersionFile {
  param([string]$VersionPath, [string]$Note)
  if (-not (Test-Path -LiteralPath $VersionPath)) { return $null }
  $ver = (Get-Content -LiteralPath $VersionPath -Raw).Trim()
  if ($ver -notmatch '^(\d+)\.(\d+)\.(\d+)$') { return $null }
  $newVer = "$($Matches[1]).$($Matches[2]).$(([int]$Matches[3] + 1))"
  Set-Content -LiteralPath $VersionPath -Value "$newVer`n" -Encoding UTF8
  $changelog = Join-Path (Split-Path -Parent $VersionPath) 'CHANGELOG.md'
  if (-not (Test-Path -LiteralPath $changelog)) {
    $changelog = Join-Path (Split-Path -Parent (Split-Path -Parent $VersionPath)) 'CHANGELOG.md'
  }
  if (Test-Path -LiteralPath $changelog) {
    $lines = @(Get-Content -LiteralPath $changelog)
    $out = [System.Collections.Generic.List[string]]::new()
    if ($lines.Count -gt 0) { $out.Add($lines[0]) } else { $out.Add('# Changelog') }
    $out.Add(''); $out.Add("## $newVer"); $out.Add(''); $out.Add("- $Note")
    for ($i = 1; $i -lt $lines.Count; $i++) { $out.Add($lines[$i]) }
    Set-Content -LiteralPath $changelog -Value ($out -join "`n") -Encoding UTF8
  }
  Write-Host "  version: $ver -> $newVer ($VersionPath)"
  return $newVer
}

$note = 'Rename install slug from legacy chameleon-* / cc-* to functional slug (folder, main file, text domain).'

$repoRoots = @(
  (Join-Path $scanRoot 'chameleon\woocommerce\chameleon-mailer'),
  (Join-Path $scanRoot 'chameleon\woocommerce\woo-region-stock-levels'),
  (Join-Path $scanRoot 'chameleon\other\chameleon-cron-monitor'),
  (Join-Path $scanRoot 'client\anonymous\plugins\booking'),
  (Join-Path $scanRoot 'client\anonymous\plugins\chameleon-demo-gate'),
  (Join-Path $scanRoot 'chameleon\other\cc_complete_address'),
  (Join-Path $scanRoot 'chameleon\other\cc_media_cleanup'),
  (Join-Path $scanRoot 'chameleon\other\cc-custom-online-diary-plugin')
)

foreach ($repo in $repoRoots) {
  if (-not (Test-Path -LiteralPath $repo)) {
    Write-Warning "Missing repo: $repo"
    continue
  }
  Write-Host "`n=== $repo ==="
  Replace-InTree -Root $repo -Map $slugMap
}

$mailerRoot = Join-Path $scanRoot 'chameleon\woocommerce\chameleon-mailer'
Rename-IfExists (Join-Path $mailerRoot 'plugin\chameleon-mailer.php') 'woo-mailer.php' | Out-Null
Rename-IfExists (Join-Path $mailerRoot 'scripts\build-chameleon-mailer-zip.ps1') 'build-woo-mailer-zip.ps1' | Out-Null
Bump-VersionFile (Join-Path $mailerRoot 'plugin\VERSION') $note | Out-Null

$crscRoot = Join-Path $scanRoot 'chameleon\woocommerce\woo-region-stock-levels'
Rename-IfExists (Join-Path $crscRoot 'chameleon-regional-stock-control') 'woo-region-stock-levels' | Out-Null
Rename-IfExists (Join-Path $crscRoot 'woo-region-stock-levels\chameleon-regional-stock-control.php') 'woo-region-stock-levels.php' | Out-Null
Bump-VersionFile (Join-Path $crscRoot 'woo-region-stock-levels\VERSION') $note | Out-Null

$cronRoot = Join-Path $scanRoot 'chameleon\other\chameleon-cron-monitor'
Rename-IfExists (Join-Path $cronRoot 'plugin\chameleon-cron-monitor.php') 'cron-monitor.php' | Out-Null
Bump-VersionFile (Join-Path $cronRoot 'plugin\VERSION') $note | Out-Null

$bookingRoot = Join-Path $scanRoot 'client\anonymous\plugins\booking'
Rename-IfExists (Join-Path $bookingRoot 'chameleon-booking.php') 'simple-booking.php' | Out-Null
Bump-VersionFile (Join-Path $bookingRoot 'VERSION') $note | Out-Null

$gateRoot = Join-Path $scanRoot 'client\anonymous\plugins\chameleon-demo-gate'
Rename-IfExists $gateRoot 'demo-gate' | Out-Null
$gateRoot = Join-Path $scanRoot 'client\anonymous\plugins\demo-gate'
Rename-IfExists (Join-Path $gateRoot 'chameleon-demo-gate.php') 'demo-gate.php' | Out-Null
Bump-VersionFile (Join-Path $gateRoot 'VERSION') $note | Out-Null

$ccaRoot = Join-Path $scanRoot 'chameleon\other\cc_complete_address'
Rename-IfExists (Join-Path $ccaRoot 'cc-complete-address') 'complete-address' | Out-Null
Rename-IfExists (Join-Path $ccaRoot 'complete-address\cc-complete-address.php') 'complete-address.php' | Out-Null
Bump-VersionFile (Join-Path $ccaRoot 'complete-address\VERSION') $note | Out-Null

$ccmRoot = Join-Path $scanRoot 'chameleon\other\cc_media_cleanup'
if (Test-Path -LiteralPath (Join-Path $ccmRoot 'plugin\cc-media-cleanup.php')) {
  Rename-IfExists (Join-Path $ccmRoot 'plugin\cc-media-cleanup.php') 'media-cleanup.php' | Out-Null
}
Bump-VersionFile (Join-Path $ccmRoot 'plugin\VERSION') $note | Out-Null

$ccdRoot = Join-Path $scanRoot 'chameleon\other\cc-custom-online-diary-plugin'
Rename-IfExists (Join-Path $ccdRoot 'plugin\cc-custom-online-diary') 'custom-online-diary' | Out-Null
Rename-IfExists (Join-Path $ccdRoot 'plugin\custom-online-diary\cc-custom-online-diary.php') 'custom-online-diary.php' | Out-Null
Bump-VersionFile (Join-Path $ccdRoot 'plugin\custom-online-diary\VERSION') $note | Out-Null

# Rename mailer repo folder last (path used above).
Rename-IfExists $mailerRoot (Join-Path (Split-Path $mailerRoot -Parent) 'woo-mailer') | Out-Null

# Manifest: rename keys (keep chameleon-admin).
$manifestPath = Join-Path $wpRoot '.tools\chameleon-plugin-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$newManifest = [ordered]@{}
foreach ($prop in $manifest.PSObject.Properties) {
  $key = $prop.Name
  if ($slugMap.Contains($key)) {
    $key = $slugMap[$key]
  }
  $newManifest[$key] = $prop.Value
}
($newManifest | ConvertTo-Json -Depth 10) + "`n" | Set-Content -LiteralPath $manifestPath -Encoding UTF8

# Remove legacy dist + plugins-live zips for old slugs.
$legacySlugs = @($slugMap.Keys) + @(
  'chameleon_reports', 'chameleon-reports', 'chameleon-customer-location', 'chameleon-site-scan'
)
foreach ($legacy in $legacySlugs) {
  Get-ChildItem -LiteralPath $scanRoot -Recurse -Directory -Filter 'dist' -ErrorAction SilentlyContinue |
    ForEach-Object {
      $legacyDir = Join-Path $_.FullName $legacy
      if (Test-Path -LiteralPath $legacyDir) {
        Remove-Item -LiteralPath $legacyDir -Recurse -Force
        Write-Host "Removed dist: $legacyDir"
      }
    }
  $live = Join-Path $wpRoot 'plugins-live'
  Get-ChildItem -LiteralPath $live -Filter "$legacy-*.zip" -ErrorAction SilentlyContinue |
    ForEach-Object {
      Remove-Item -LiteralPath $_.FullName -Force
      Write-Host "Removed plugins-live: $($_.Name)"
    }
}

Write-Host "`nDone. Run batch build + publish."
