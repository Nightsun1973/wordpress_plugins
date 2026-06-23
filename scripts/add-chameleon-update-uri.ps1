<#
.SYNOPSIS
  Add Chameleon Update URI header to plugin main PHP files that lack it; bump patch version + changelog.

.DESCRIPTION
  Scans plugins-dev (skips archive/) for PHP files whose header contains "Plugin Name:" but not "Update URI:".
  Inserts the standard repo line after Plugin URI, Author URI, or Version.
  Bumps patch once per plugin repo (README.md ancestor) when VERSION file exists.

.EXAMPLE
  .\scripts\add-chameleon-update-uri.ps1
  .\scripts\add-chameleon-update-uri.ps1 -WhatIf
#>
param(
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$updateUriLine = ' * Update URI: https://admin.chameleoncodewing.co.uk/wp-content/uploads/plugin-repo'
$changelogNote = 'Add Update URI header for Chameleon Admin plugin repo updates.'
$wpRoot = $PSScriptRoot | Split-Path -Parent
$scanRoot = Join-Path $wpRoot 'plugins-dev'

if (-not (Test-Path -LiteralPath $scanRoot)) {
  Write-Error "plugins-dev not found: $scanRoot"
}

function Find-PluginRepoRoot([string]$startDir) {
  $cur = (Resolve-Path -LiteralPath $startDir).Path
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $cur 'README.md')) {
      return $cur
    }
    $parent = Split-Path -Parent $cur
    if (-not $parent -or $parent -eq $cur) {
      return $null
    }
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
  foreach ($name in @('CHANGELOG.md')) {
    $p = Join-Path $verDir $name
    if (Test-Path -LiteralPath $p) { return $p }
  }
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

function Add-UpdateUriToHeader([string]$raw) {
  if ($raw -match 'Update URI\s*:') {
    return $raw
  }
  if ($raw -match '(?m)^(Plugin URI\s*:.*\r?\n)') {
    return [regex]::Replace($raw, '(?m)^(Plugin URI\s*:.*\r?\n)', "`$1Update URI: https://admin.chameleoncodewing.co.uk/wp-content/uploads/plugin-repo`r`n", 1)
  }
  if ($raw -match '(?m)^(\s*\*\s*Plugin URI\s*:.*\r?\n)') {
    return [regex]::Replace($raw, '(?m)^(\s*\*\s*Plugin URI\s*:.*\r?\n)', "`$1$updateUriLine`r`n", 1)
  }
  if ($raw -match '(?m)^(\s*\*\s*Author URI\s*:.*\r?\n)') {
    return [regex]::Replace($raw, '(?m)^(\s*\*\s*Author URI\s*:.*\r?\n)', "`$1$updateUriLine`r`n", 1)
  }
  if ($raw -match '(?m)^(\s*\*\s*Version\s*:.*\r?\n)') {
    return [regex]::Replace($raw, '(?m)^(\s*\*\s*Version\s*:.*\r?\n)', "`$1$updateUriLine`r`n", 1)
  }
  if ($raw -match '(?m)^(\s*\*\s*Plugin Name\s*:.*\r?\n)') {
    return [regex]::Replace($raw, '(?m)^(\s*\*\s*Plugin Name\s*:.*\r?\n)', "`$1$updateUriLine`r`n", 1)
  }
  return $raw
}

function Bump-VersionFile([string]$versionPath) {
  $verLine = (Get-Content -LiteralPath $versionPath -Raw).Trim()
  $m = [regex]::Match($verLine, '^(\d+)\.(\d+)\.(\d+)$')
  if (-not $m.Success) {
    Write-Warning "Skip bump (not semver): $versionPath => $verLine"
    return $null
  }
  $newVer = "$($m.Groups[1].Value).$($m.Groups[2].Value).$(([int]$m.Groups[3].Value + 1))"
  if (-not $WhatIf) {
    Set-Content -LiteralPath $versionPath -Value "$newVer`n" -Encoding UTF8
  }
  return $newVer
}

function Sync-VersionInPhp([string]$phpPath, [string]$newVer) {
  $raw = Get-Content -LiteralPath $phpPath -Raw
  $updated = [regex]::Replace($raw, '(?m)^(\s*\*\s*Version\s*:\s*)\d+\.\d+\.\d+(\s*)$', "`${1}$newVer`${2}", 1)
  $updated = [regex]::Replace($updated, "(define\s*\(\s*['\`"][\w_]+_VERSION['\`"]\s*,\s*['\`"])\d+\.\d+\.\d+(['\`"]\s*\))", "`${1}$newVer`${2}", 1)
  if ($updated -ne $raw -and -not $WhatIf) {
    Set-Content -LiteralPath $phpPath -Value $updated -Encoding UTF8
  }
  return $updated -ne $raw
}

function Prepend-Changelog([string]$changelogPath, [string]$newVer) {
  $lines = @(Get-Content -LiteralPath $changelogPath)
  $out = [System.Collections.Generic.List[string]]::new()
  if ($lines.Count -eq 0) {
    $out.Add('# Changelog')
  } else {
    $out.Add($lines[0])
  }
  $out.Add('')
  $out.Add("## $newVer")
  $out.Add('')
  $out.Add("- $changelogNote")
  for ($i = 1; $i -lt $lines.Count; $i++) {
    $out.Add($lines[$i])
  }
  if (-not $WhatIf) {
    Set-Content -LiteralPath $changelogPath -Value ($out -join "`n") -Encoding UTF8
  }
}

$bumpedVersions = @{}
$changed = 0
$skipped = 0

Get-ChildItem -LiteralPath $scanRoot -Recurse -Filter '*.php' -File -ErrorAction SilentlyContinue |
  Where-Object {
    $_.FullName -notmatch '\\archive\\' -and
    $_.FullName -notmatch '\\wordpress-plugin\\' -and
    $_.FullName -notmatch '\\_zip_build\\' -and
    $_.Name -notmatch '-backup\.php$|-corrupted\.php$|install-check\.php$'
  } |
  ForEach-Object {
    $phpPath = $_.FullName
    $head = (Get-Content -LiteralPath $phpPath -TotalCount 60) -join "`n"
    if ($head -notmatch 'Plugin Name\s*:') { return }
    if ($head -notmatch 'Version\s*:') { return }
    if ($head -match 'Update URI\s*:') { return }

    $raw = Get-Content -LiteralPath $phpPath -Raw
    $newRaw = Add-UpdateUriToHeader -raw $raw
    if ($newRaw -eq $raw) {
      Write-Warning "Could not insert Update URI: $phpPath"
      $skipped++
      return
    }

    $repoRoot = Find-PluginRepoRoot -startDir (Split-Path -Parent $phpPath)
    $newVer = $null
    $versionPath = $null
    if ($repoRoot) {
      $versionPath = Find-VersionFile -repoRoot $repoRoot -phpPath $phpPath
    }
    if ($versionPath) {
      if (-not $bumpedVersions.ContainsKey($versionPath)) {
        $newVer = Bump-VersionFile -versionPath $versionPath
        if ($newVer) {
          $bumpedVersions[$versionPath] = $newVer
          $changelog = Find-ChangelogFile -versionPath $versionPath -repoRoot $repoRoot
          if ($changelog) {
            Prepend-Changelog -changelogPath $changelog -newVer $newVer
          } else {
            Write-Warning "No CHANGELOG near $versionPath"
          }
        }
      } else {
        $newVer = $bumpedVersions[$versionPath]
      }
    } elseif ($repoRoot) {
      Write-Warning "No VERSION file for: $phpPath"
    }

    if (-not $WhatIf) {
      Set-Content -LiteralPath $phpPath -Value $newRaw -Encoding UTF8
    }

    if ($newVer) {
      Sync-VersionInPhp -phpPath $phpPath -newVer $newVer | Out-Null
    }

    Write-Host "Updated: $phpPath$(if ($newVer) { " (v$newVer)" })"
    $changed++
  }

Write-Host ""
Write-Host "Done. Changed $changed file(s); skipped $skipped."
