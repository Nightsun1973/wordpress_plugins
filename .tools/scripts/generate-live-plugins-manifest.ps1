param(
  [Parameter(Mandatory = $false)]
  [string]$LivePluginsDir = $null,

  [Parameter(Mandatory = $false)]
  [string]$OutputPath = $null,

  # Optional HTTPS base (no trailing slash). When set, each plugin row includes package_url = <base>/<filename>.
  [Parameter(Mandatory = $false)]
  [string]$PublicBaseUrl = $null
)

$ErrorActionPreference = 'Stop'

function Find-WordpressPluginsRoot([string]$start) {
  $cur = (Resolve-Path -LiteralPath $start).Path
  while ($true) {
    if ((Split-Path -Leaf $cur) -eq 'wordpress_plugins') { return $cur }
    $parent = Split-Path -Parent $cur
    if (-not $parent -or $parent -eq $cur) { return $null }
    $cur = $parent
  }
}

function Parse-SlugVersionFromZipName([string]$name) {
  $m = [regex]::Match($name, '^(?<slug>.+)-(?<ver>\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\.zip$')
  if (-not $m.Success) { return $null }
  return [pscustomobject]@{ slug = $m.Groups['slug'].Value; version = $m.Groups['ver'].Value }
}

function Parse-PluginHeader([string]$phpText) {
  # Minimal WP header parse from the top of file.
  $top = $phpText
  if ($top.Length -gt 20000) { $top = $top.Substring(0, 20000) }
  $fields = [ordered]@{}
  foreach ($key in @('Plugin Name','Description','Version','Author','Text Domain','Plugin URI','Author URI')) {
    $m = [regex]::Match($top, [regex]::Escape($key) + '\\s*:\\s*(?<v>.+)$', 'Multiline')
    if ($m.Success) { $fields[$key] = $m.Groups['v'].Value.Trim() }
  }
  return [pscustomobject]$fields
}

function Extract-Shortcodes([string]$phpText) {
  $pattern = 'add_shortcode\s*\(\s*[''"](?<tag>[^''"]+)[''"]'
  $matches = [regex]::Matches($phpText, $pattern, 'IgnoreCase')
  $tags = @()
  foreach ($m in $matches) { $tags += $m.Groups['tag'].Value }
  return ($tags | Sort-Object -Unique)
}

function Read-Catalog([string]$wpRoot) {
  $path = Join-Path (Join-Path $wpRoot '.tools') 'live-plugin-catalog.json'
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  try { return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) } catch { return $null }
}

function Catalog-Plugin([object]$catalog, [string]$slug) {
  if (-not $catalog -or -not $catalog.plugins) { return $null }
  return $catalog.plugins.$slug
}

if (-not $LivePluginsDir) {
  $wpRoot = Find-WordpressPluginsRoot -start (Get-Location).Path
  if (-not $wpRoot) { throw 'Could not locate wordpress_plugins root.' }
  $LivePluginsDir = Join-Path $wpRoot 'plugins-live'
}
if (-not $OutputPath) { $OutputPath = Join-Path $LivePluginsDir 'index.json' }

Add-Type -AssemblyName System.IO.Compression.FileSystem

$wpRootForCatalog = Find-WordpressPluginsRoot -start $LivePluginsDir
$catalog = if ($wpRootForCatalog) { Read-Catalog -wpRoot $wpRootForCatalog } else { $null }

$publicBase = $null
if ($PublicBaseUrl -and $PublicBaseUrl.Trim().Length -gt 0) {
  $publicBase = $PublicBaseUrl.Trim().TrimEnd('/')
}

$zips = Get-ChildItem -LiteralPath $LivePluginsDir -File -Filter *.zip -ErrorAction SilentlyContinue | Sort-Object Name

$items = @()
foreach ($z in $zips) {
  $parsed = Parse-SlugVersionFromZipName $z.Name
  if (-not $parsed) { continue }

  $sha256 = (Get-FileHash -LiteralPath $z.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

  $pluginName = $null
  $pluginDescription = $null
  $textDomain = $null
  $shortcodes = @()

  $zip = [System.IO.Compression.ZipFile]::OpenRead($z.FullName)
  try {
    # Try main file slug/slug.php first
    $mainEntry = $zip.Entries | Where-Object { $_.FullName -ieq ("$($parsed.slug)/$($parsed.slug).php") } | Select-Object -First 1
    if (-not $mainEntry) {
      # Fall back: any php file at zip root folder level
      $pattern = '^' + [regex]::Escape($parsed.slug) + '/[^/]+\.php$'
      $mainEntry = $zip.Entries | Where-Object { $_.FullName -match $pattern } | Select-Object -First 1
    }

    if ($mainEntry) {
      $sr = New-Object System.IO.StreamReader($mainEntry.Open())
      try {
        $txt = $sr.ReadToEnd()
      } finally {
        $sr.Dispose()
      }

      $hdr = Parse-PluginHeader $txt
      $pluginName = $hdr.'Plugin Name'
      $pluginDescription = $hdr.'Description'
      $textDomain = $hdr.'Text Domain'
    }
    if (-not $pluginName) { $pluginName = $parsed.slug }

    # Shortcode scan: all php entries (best effort)
    $allTags = @()
    foreach ($e in $zip.Entries | Where-Object { $_.FullName -like '*.php' }) {
      $sr2 = New-Object System.IO.StreamReader($e.Open())
      try { $t2 = $sr2.ReadToEnd() } finally { $sr2.Dispose() }
      $allTags += (Extract-Shortcodes $t2)
    }
    $shortcodes = ($allTags | Sort-Object -Unique)
  } finally {
    $zip.Dispose()
  }

  $row = [ordered]@{
    slug = $parsed.slug
    version = $parsed.version
    filename = $z.Name
    size_bytes = $z.Length
    last_write_utc = $z.LastWriteTimeUtc.ToString('o')
    sha256 = $sha256
    plugin_name = $pluginName
    description = $pluginDescription
    text_domain = $textDomain
    shortcodes = @(
      $shortcodes | ForEach-Object {
        [pscustomobject]@{ tag = $_; description = $null }
      }
    )
  }
  if ($publicBase) {
    $row['package_url'] = "$publicBase/$($z.Name)"
  }
  $items += [pscustomobject]$row

  # Merge catalog descriptions (if present)
  $cPlug = Catalog-Plugin -catalog $catalog -slug $parsed.slug
  if ($cPlug) {
    if ($cPlug.description) {
      $items[-1].description = $cPlug.description
    }
    if ($cPlug.shortcodes) {
      foreach ($sc in $items[-1].shortcodes) {
        $d = $cPlug.shortcodes.$($sc.tag)
        if ($d) { $sc.description = $d }
      }
    }
  }
}

$manifest = [pscustomobject]@{
  generated_utc = (Get-Date).ToUniversalTime().ToString('o')
  live_plugins_dir = $LivePluginsDir
  plugins = ($items | Sort-Object slug)
}

$json = $manifest | ConvertTo-Json -Depth 10
Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8

Write-Host \"WROTE $OutputPath\"
