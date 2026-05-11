<#!
.SYNOPSIS
  Recursively scans the project tree for WordPress plugin headers and regenerates .docs/plugin-directory.html data.

.DESCRIPTION
  Finds *.php files whose first docblock contains "Plugin Name:" (WordPress style). Skips vendor, node_modules, and .git.
  Optional rules: scripts/plugin-directory-overrides.json (exclude paths, per-file overrides).

.EXAMPLE
  From project root:  .\scripts\generate-plugin-directory.ps1
#>
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path.TrimEnd('\')
$OutHtml = Join-Path $ProjectRoot '.docs\plugin-directory.html'
$OverridesPath = Join-Path $ScriptDir 'plugin-directory-overrides.json'

function Test-ExcludedPath {
    param(
        [string]$RelPathNorm,
        [string[]]$Prefixes,
        [string[]]$Files
    )
    $RelPathNorm = $RelPathNorm -replace '\\', '/'
    foreach ($p in $Prefixes) {
        if (-not $p) { continue }
        $pref = ($p -replace '\\', '/').TrimEnd('/')
        if ($RelPathNorm -eq $pref -or $RelPathNorm.StartsWith("$pref/", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    foreach ($f in $Files) {
        if (-not $f) { continue }
        $ff = ($f -replace '\\', '/')
        if ($RelPathNorm -eq $ff) { return $true }
    }
    return $false
}

function Get-FirstDocblockLines {
    param([string[]]$Lines)
    $inBlock = $false
    $block = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $Lines) {
        if (-not $inBlock -and $line -match '^\s*/\*\*') {
            $inBlock = $true
            continue
        }
        if ($inBlock -and $line -match '^\s*\*/') {
            break
        }
        if ($inBlock) {
            $block.Add($line) | Out-Null
        }
    }
    return , $block.ToArray()
}

function Get-WordPressPluginMetaFromFile {
    param([string]$LiteralPath)
    try {
        $raw = Get-Content -LiteralPath $LiteralPath -Raw -Encoding UTF8
    } catch {
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $lines = $raw -split "`r?`n"
    $blockLines = Get-FirstDocblockLines -Lines $lines
    if ($blockLines.Count -eq 0) { return $null }

    $meta = @{}
    foreach ($line in $blockLines) {
        if ($line -match '^\s*\*\s*([A-Za-z0-9 ]+)\s*:\s*(.*)$') {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim()
            if (-not $meta.ContainsKey($key)) {
                $meta[$key] = $val
            }
        }
    }
    if (-not $meta['Plugin Name']) { return $null }

    # Version sometimes appears only later in file (corrupted headers)
    if (-not $meta['Version']) {
        $scan = [Math]::Min($lines.Count, 400)
        for ($i = 0; $i -lt $scan; $i++) {
            if ($lines[$i] -match '^\s*\*\s*Version:\s*([\d.]+)') {
                $meta['Version'] = $matches[1].Trim()
                break
            }
        }
    }
    if (-not $meta['Version']) {
        $meta['Version'] = '—'
    }

    if (-not $meta['Description']) {
        $meta['Description'] = 'No Description line in header.'
    }

    $uri = $meta['Plugin URI']
    if ($uri -and ($uri.Length -gt 220 -or $uri -match 'public function|switch\s*\(|wp_verify_nonce')) {
        $meta['_corrupt'] = $true
    }

    return [pscustomobject]@{
        PluginName = $meta['Plugin Name']
        Version    = $meta['Version']
        Description = $meta['Description']
        Corrupt    = [bool]$meta['_corrupt']
    }
}

function Get-DefaultState {
    param([string]$Version, [string]$RelPathNorm)
    if ($RelPathNorm -match '(?i)email_alert_archive/') {
        return @{ state = 'legacy'; stateLabel = 'Archive copy' }
    }
    if ($Version -match '^(—|$)') {
        return @{ state = 'active'; stateLabel = 'Version unknown' }
    }
    if ($Version -match '^0\.') {
        return @{ state = 'active'; stateLabel = 'Pre-1.0' }
    }
    return @{ state = 'production'; stateLabel = 'Production' }
}

# --- Load overrides ---
$excludePrefixes = @()
$excludeFiles = @()
$overrides = @{}
if (Test-Path -LiteralPath $OverridesPath) {
    $o = Get-Content -LiteralPath $OverridesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($o.excludePathPrefixes) { $excludePrefixes = @($o.excludePathPrefixes) }
    if ($o.excludeFiles) { $excludeFiles = @($o.excludeFiles) }
    if ($o.overrides) {
        $o.overrides.PSObject.Properties | ForEach-Object {
            $overrides[$_.Name] = $_.Value
        }
    }
}

$skipDirPattern = '(?i)[\\/]\.git[\\/]|[\\/]node_modules[\\/]|[\\/]vendor[\\/]'

$phpFiles = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Filter '*.php' |
    Where-Object { $_.FullName -notmatch $skipDirPattern }

$rows = [System.Collections.Generic.List[object]]::new()

foreach ($f in $phpFiles) {
    $rel = $f.FullName.Substring($ProjectRoot.Length).TrimStart('\')
    $relNorm = $rel -replace '\\', '/'
    if (Test-ExcludedPath -RelPathNorm $relNorm -Prefixes $excludePrefixes -Files $excludeFiles) {
        continue
    }

    $meta = Get-WordPressPluginMetaFromFile -LiteralPath $f.FullName
    if (-not $meta) { continue }

    $desc = $meta.Description
    if ($meta.Corrupt) {
        $desc = 'Plugin header appears corrupted or merged with code; inspect this file. Original Description line may be unreliable.'
    }

    $version = $meta.Version
    $state = $null
    $stateLabel = $null

    if ($overrides.ContainsKey($relNorm)) {
        $ov = $overrides[$relNorm]
        if ($ov.PSObject.Properties['desc']) { $desc = [string]$ov.desc }
        if ($ov.PSObject.Properties['version']) { $version = [string]$ov.version }
        if ($ov.PSObject.Properties['state']) { $state = [string]$ov.state }
        if ($ov.PSObject.Properties['stateLabel']) { $stateLabel = [string]$ov.stateLabel }
    }

    if (-not $state) {
        $d = Get-DefaultState -Version $version -RelPathNorm $relNorm
        $state = $d.state
        $stateLabel = $d.stateLabel
    }

    $rows.Add([pscustomobject]@{
            name       = $meta.PluginName
            version    = $version
            state      = $state
            stateLabel = $stateLabel
            path       = $relNorm
            desc       = $desc
        }) | Out-Null
}

$sorted = $rows | Sort-Object { $_.name }, { $_.path }
$json = $sorted | ConvertTo-Json -Depth 6 -Compress
# Prevent closing a literal </script> if it ever appears inside JSON text
$json = $json -replace '(?i)</script>', '<\/script>'

if (-not (Test-Path -LiteralPath (Split-Path $OutHtml -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $OutHtml -Parent) -Force | Out-Null
}

$html = Get-Content -LiteralPath $OutHtml -Raw -Encoding UTF8
if ($html -notmatch 'id="plugin-directory-data"') {
    throw "Expected .docs/plugin-directory.html to contain <script type=`"application/json`" id=`"plugin-directory-data`"> placeholder. Update the template."
}

$pattern = '(?s)(<script type="application/json" id="plugin-directory-data">\s*)(.*?)(\s*</script>)'
$rxData = [regex]::new($pattern)
$newHtml = $rxData.Replace($html, {
        param($m)
        return $m.Groups[1].Value + $json + $m.Groups[3].Value
    })

$genLine = (Get-Date).ToString('yyyy-MM-dd HH:mm')
$genHtml = '<p class="gen-meta">Full tree scan via <code>scripts/generate-plugin-directory.ps1</code> &middot; last generated <time datetime="' + $genLine + '">' + $genLine + '</time></p>'
$newHtml = [regex]::Replace($newHtml, '(?s)<p class="gen-meta"[^>]*>.*?</p>', $genHtml)
if ($newHtml -notmatch 'class="gen-meta"') {
    $newHtml = $newHtml -replace '(<footer>\s*\r?\n\s*)', ('$1' + $genHtml + "`n			")
}

Set-Content -LiteralPath $OutHtml -Value $newHtml -Encoding UTF8 -NoNewline
Write-Host "Wrote $($sorted.Count) plugins to $OutHtml"
