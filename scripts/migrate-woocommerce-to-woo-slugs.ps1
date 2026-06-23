<#
.SYNOPSIS
  One-time migration: woocommerce-* install slugs → woo-* (folders, main files, text domains).
.EXAMPLE
  .\scripts\migrate-woocommerce-to-woo-slugs.ps1
#>
$ErrorActionPreference = 'Stop'

$wpRoot = $PSScriptRoot | Split-Path -Parent
$scanRoot = Join-Path $wpRoot 'plugins-dev'

$slugMap = [ordered]@{
  'woocommerce-central-manager-hub'       = 'woo-central-manager-hub'
  'woocommerce-central-manager-satellite' = 'woo-central-manager-satellite'
  'woocommerce-export-import-customer-order-details' = 'woo-export-import-customer-order-details'
  'woocommerce-product-search'            = 'woo-product-search'
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
      $ext -contains $_.Extension.ToLower()
    } |
    ForEach-Object {
      $raw = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
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

$repos = @(
  (Join-Path $scanRoot 'chameleon\woocommerce\woo-central-hub'),
  (Join-Path $scanRoot 'chameleon\woocommerce\export-import-customer-order-details'),
  (Join-Path $scanRoot 'chameleon\woocommerce\product_search')
)

$note = 'Rename install slug from woocommerce-* to woo-* (folder, main file, text domain).'

foreach ($repo in $repos) {
  if (-not (Test-Path -LiteralPath $repo)) {
    Write-Warning "Missing repo: $repo"
    continue
  }
  Write-Host "`n=== $repo ==="
  Replace-InTree -Root $repo -Map $slugMap
}

$hubRoot = Join-Path $scanRoot 'chameleon\woocommerce\woo-central-hub'
Rename-IfExists (Join-Path $hubRoot 'woocommerce-central-manager-hub') 'woo-central-manager-hub' | Out-Null
Rename-IfExists (Join-Path $hubRoot 'woocommerce-central-manager-satellite') 'woo-central-manager-satellite' | Out-Null
Rename-IfExists (Join-Path $hubRoot 'woo-central-manager-hub\woocommerce-central-manager-hub.php') 'woo-central-manager-hub.php' | Out-Null
Rename-IfExists (Join-Path $hubRoot 'woo-central-manager-satellite\woocommerce-central-manager-satellite.php') 'woo-central-manager-satellite.php' | Out-Null

$eiRoot = Join-Path $scanRoot 'chameleon\woocommerce\export-import-customer-order-details'
Rename-IfExists (Join-Path $eiRoot 'plugin\woocommerce-export-import-customer-order-details.php') 'woo-export-import-customer-order-details.php' | Out-Null

$psRoot = Join-Path $scanRoot 'chameleon\woocommerce\product_search'
Rename-IfExists (Join-Path $psRoot 'woocommerce-product-search.php') 'woo-product-search.php' | Out-Null

Bump-VersionFile (Join-Path $hubRoot 'woo-central-manager-hub\VERSION') $note | Out-Null
Bump-VersionFile (Join-Path $hubRoot 'woo-central-manager-satellite\VERSION') $note | Out-Null
Bump-VersionFile (Join-Path $eiRoot 'plugin\VERSION') $note | Out-Null

# Manifest: rename keys
$manifestPath = Join-Path $wpRoot '.tools\chameleon-plugin-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$newManifest = [ordered]@{}
foreach ($prop in $manifest.PSObject.Properties) {
  $key = $prop.Name
  if ($slugMap.Contains($key)) {
    $key = $slugMap[$key]
  }
  $val = $prop.Value
  if ($val.PSObject.Properties['targetSlug']) {
    $val.PSObject.Properties.Remove('targetSlug')
  }
  $newManifest[$key] = $val
}
($newManifest | ConvertTo-Json -Depth 10) + "`n" | Set-Content -LiteralPath $manifestPath -Encoding UTF8

# Catalog + overrides at monorepo root
$catalogPath = Join-Path $wpRoot '.tools\live-plugin-catalog.json'
if (Test-Path -LiteralPath $catalogPath) {
  $catRaw = Get-Content -LiteralPath $catalogPath -Raw
  foreach ($k in $slugMap.Keys) { $catRaw = $catRaw.Replace($k, $slugMap[$k]) }
  Set-Content -LiteralPath $catalogPath -Value $catRaw -Encoding UTF8 -NoNewline
}

$overridesPath = Join-Path $wpRoot '.tools\scripts\plugin-directory-overrides.json'
if (Test-Path -LiteralPath $overridesPath) {
  $ovRaw = Get-Content -LiteralPath $overridesPath -Raw
  foreach ($k in $slugMap.Keys) { $ovRaw = $ovRaw.Replace($k, $slugMap[$k]) }
  Set-Content -LiteralPath $overridesPath -Value $ovRaw -Encoding UTF8 -NoNewline
}

Write-Host "`nDone. Update plugin-naming.mdc legacy note and run batch build + publish."
