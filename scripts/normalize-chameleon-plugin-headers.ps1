<#
.SYNOPSIS
  Normalize Chameleon plugin headers: (Chameleon) prefix, Lee Carter author, descriptions.

.DESCRIPTION
  - Plugin Name => (Chameleon) {displayName} (list grouping only; see plugin-naming.mdc)
  - Author => Lee Carter
  - Description => from manifest or existing (trimmed)
  - Bumps patch VERSION + CHANGELOG when changed

.EXAMPLE
  .\scripts\normalize-chameleon-plugin-headers.ps1
  .\scripts\normalize-chameleon-plugin-headers.ps1 -WhatIf
#>
param(
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$wpRoot = $PSScriptRoot | Split-Path -Parent
$scanRoot = Join-Path $wpRoot 'plugins-dev'
$manifestPath = Join-Path $wpRoot '.tools\chameleon-plugin-manifest.json'
$changelogNote = 'Normalize plugin header from manifest (name, author, description).'
$listPrefix = '(Chameleon) '

if (-not (Test-Path -LiteralPath $manifestPath)) {
  Write-Error "Missing manifest: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

function Find-PluginRepoRoot([string]$startDir) {
  $cur = (Resolve-Path -LiteralPath $startDir).Path
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $cur 'README.md')) { return $cur }
    $parent = Split-Path -Parent $cur
    if (-not $parent -or $parent -eq $cur) { return $null }
    $cur = $parent
  }
}

function Find-VersionFile([string]$repoRoot, [string]$phpPath) {
  $phpDir = Split-Path -Parent $phpPath
  $local = Join-Path $phpDir 'VERSION'
  if (Test-Path -LiteralPath $local) { return $local }
  foreach ($rel in @('plugin\VERSION', 'VERSION')) {
    $p = Join-Path $repoRoot $rel
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return $null
}

function Find-ChangelogFile([string]$versionPath, [string]$repoRoot) {
  $verDir = Split-Path -Parent $versionPath
  $local = Join-Path $verDir 'CHANGELOG.md'
  if (Test-Path -LiteralPath $local) { return $local }
  $bookingDoc = Join-Path $repoRoot '.docs\booking\CHANGELOG.md'
  if ((Split-Path -Leaf $verDir) -eq 'booking' -and (Test-Path -LiteralPath $bookingDoc)) {
    return $bookingDoc
  }
  foreach ($rel in @('plugin\CHANGELOG.md', 'CHANGELOG.md')) {
    $p = Join-Path $repoRoot $rel
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return $null
}

function Bump-VersionFile([string]$versionPath) {
  $verLine = (Get-Content -LiteralPath $versionPath -Raw).Trim()
  $m = [regex]::Match($verLine, '^(\d+)\.(\d+)\.(\d+)$')
  if (-not $m.Success) { return $null }
  $newVer = "$($m.Groups[1].Value).$($m.Groups[2].Value).$(([int]$m.Groups[3].Value + 1))"
  if (-not $WhatIf) {
    Set-Content -LiteralPath $versionPath -Value "$newVer`n" -Encoding UTF8
  }
  return $newVer
}

function Prepend-Changelog([string]$changelogPath, [string]$newVer) {
  $lines = @(Get-Content -LiteralPath $changelogPath)
  $out = [System.Collections.Generic.List[string]]::new()
  if ($lines.Count -gt 0) { $out.Add($lines[0]) } else { $out.Add('# Changelog') }
  $out.Add('')
  $out.Add("## $newVer")
  $out.Add('')
  $out.Add("- $changelogNote")
  for ($i = 1; $i -lt $lines.Count; $i++) { $out.Add($lines[$i]) }
  if (-not $WhatIf) {
    Set-Content -LiteralPath $changelogPath -Value ($out -join "`n") -Encoding UTF8
  }
}

function Get-SlugFromPath([string]$phpPath, [string[]]$manifestSlugs) {
  $base = [System.IO.Path]::GetFileNameWithoutExtension($phpPath)
  if ($manifestSlugs -contains $base) { return $base }
  $dir = Split-Path -Parent $phpPath
  $folder = Split-Path -Leaf $dir
  if ($base -eq $folder) { return $base }
  if ($folder -eq 'plugin') {
    return [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Parent $dir))
  }
  return $base
}

function Derive-DisplayName([string]$pluginNameLine) {
  $name = $pluginNameLine -replace '^\s*\*?\s*Plugin Name\s*:\s*', ''
  $name = $name.Trim()
  if ($name -match '^\(Chameleon\)\s+(.+)$') { return $Matches[1].Trim() }
  if ($name -match '^(.+?)\s+\(Chameleon\)\s*$') { return $Matches[1].Trim() }
  return $name
}

function Set-HeaderField([string]$raw, [string]$field, [string]$value) {
  if ([string]::IsNullOrEmpty($raw)) { return $raw }
  $escaped = [regex]::Escape($field)
  $replacement = '${1} ' + $value
  if ($raw -match "(?m)^(\s*\*?\s*$escaped\s*:).*$") {
    return [regex]::Replace($raw, "(?m)^(\s*\*?\s*$escaped\s*:).*$", $replacement, 1)
  }
  if ($raw -match "(?m)^($escaped\s*:).*$") {
    return [regex]::Replace($raw, "(?m)^($escaped\s*:).*$", $replacement, 1)
  }
  return $raw
}

function Get-HeaderField([string]$raw, [string]$field) {
  if ($raw -match "(?m)^\s*\*?\s*$([regex]::Escape($field))\s*:\s*(.+)$") {
    return $Matches[1].Trim()
  }
  if ($raw -match "(?m)^$([regex]::Escape($field))\s*:\s*(.+)$") {
    return $Matches[1].Trim()
  }
  return $null
}

$script:bumpedVersionPaths = [System.Collections.Generic.List[string]]::new()
$changed = 0

# Build lookup: mainFile basename -> manifest slug
$slugByMain = @{}
foreach ($prop in $manifest.PSObject.Properties) {
  $slug = $prop.Name
  $entry = $prop.Value
  $main = if ($entry.mainFile) { $entry.mainFile } else { "$slug.php" }
  $slugByMain[$main] = $slug
  $slugByMain[$slug] = $slug
}

$manifestSlugs = @($manifest.PSObject.Properties | ForEach-Object { $_.Name })

$phpFiles = Get-ChildItem -LiteralPath $scanRoot -Recurse -Filter '*.php' -File |
  Where-Object {
    $_.FullName -notmatch '\\archive\\|\\_zip_build\\|\\wordpress-plugin\\' -and
    $_.Name -notmatch '-backup|-corrupted|install-check'
  }

foreach ($fileItem in $phpFiles) {
  $phpPath = $fileItem.FullName
  try {
    $head = (Get-Content -LiteralPath $phpPath -TotalCount 40) -join "`n"
    if ($head -notmatch 'Plugin Name\s*:') { continue }
    if ($head -notmatch 'Version\s*:') { continue }

    $fileName = $fileItem.Name
    $slug = $slugByMain[$fileName]
    if (-not $slug) {
      $slug = Get-SlugFromPath -phpPath $phpPath -manifestSlugs $manifestSlugs
    }
    if ($manifestSlugs -notcontains $slug) { continue }

    $entry = $manifest.$slug
    if (-not $entry) { continue }
    $displayName = $entry.displayName
    $listName = "$listPrefix$displayName"
    $description = $entry.description
    $targetAuthor = 'Lee Carter'

    $raw = Get-Content -LiteralPath $phpPath -Raw
    if ([string]::IsNullOrEmpty($raw)) { continue }
    $currentName = Get-HeaderField -raw $raw -field 'Plugin Name'
    $currentAuthor = Get-HeaderField -raw $raw -field 'Author'
    $currentDesc = Get-HeaderField -raw $raw -field 'Description'

    if (-not $displayName) {
      $displayName = Derive-DisplayName -pluginNameLine "Plugin Name: $currentName"
      $listName = "$listPrefix$displayName"
    }

    $newRaw = $raw
    $didChange = $false

    if ($currentName -ne $listName) {
      $newRaw = Set-HeaderField -raw $newRaw -field 'Plugin Name' -value $listName
      $didChange = $true
    }

    if ($currentAuthor -ne $targetAuthor) {
      $newRaw = Set-HeaderField -raw $newRaw -field 'Author' -value $targetAuthor
      $didChange = $true
    }

    if ([string]::IsNullOrWhiteSpace($currentDesc) -or ($description -and $currentDesc -ne $description)) {
      if ($description) {
        $newRaw = Set-HeaderField -raw $newRaw -field 'Description' -value $description
        $didChange = $true
      }
    }

    if (-not $didChange) { continue }

    $repoRoot = Find-PluginRepoRoot -startDir (Split-Path -Parent $phpPath)
    $newVer = $null
    if ($repoRoot) {
      $versionPath = Find-VersionFile -repoRoot $repoRoot -phpPath $phpPath
      if ($versionPath) {
        if (-not $script:bumpedVersionPaths.Contains($versionPath)) {
          $newVer = Bump-VersionFile -versionPath $versionPath
          if ($newVer) {
            $script:bumpedVersionPaths.Add($versionPath) | Out-Null
            $changelog = Find-ChangelogFile -versionPath $versionPath -repoRoot $repoRoot
            if ($changelog) { Prepend-Changelog -changelogPath $changelog -newVer $newVer }
          }
        } else {
          $verLine = (Get-Content -LiteralPath $versionPath -Raw).Trim()
          if ($verLine -match '^(\d+\.\d+\.\d+)$') { $newVer = $Matches[1] }
        }
        if ($newVer) {
          $verReplacement = '${1}' + $newVer + '${2}'
          $newRaw = [regex]::Replace($newRaw, '(?m)^(\s*\*?\s*Version\s*:\s*)\d+\.\d+\.\d+(\s*)$', $verReplacement, 1)
        }
      }
    }

    if (-not $WhatIf) {
      Set-Content -LiteralPath $phpPath -Value $newRaw -Encoding UTF8
    }

    Write-Host "Normalized: $phpPath => $listName$(if ($newVer) { " (v$newVer)" })"
    $changed++
  } catch {
    Write-Warning "Failed: $phpPath - $($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber)"
  }
}

Write-Host "Done. Normalized $changed plugin header(s)."
