<#
.SYNOPSIS
  Wire Chameleon Admin dependency into Chameleon product plugins.

.DESCRIPTION
  - Copies .tools/templates/chameleon-require-admin.php into each plugin includes/ folder.
  - Adds Requires Plugins: chameleon-admin header when missing.
  - Adds require_once + chameleon_plugin_require_admin_bootstrap() after ABSPATH guard.
  - Skips chameleon-admin itself, archive/, _zip_build/, backup copies.
  - Bumps patch VERSION + CHANGELOG when VERSION exists (same as add-chameleon-update-uri.ps1).

.EXAMPLE
  .\scripts\wire-chameleon-admin-dependency.ps1
#>
param(
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$wpRoot = $PSScriptRoot | Split-Path -Parent
$scanRoot = Join-Path $wpRoot 'plugins-dev'
$template = Join-Path $wpRoot '.tools\templates\chameleon-require-admin.php'
$changelogNote = 'Require (Chameleon) Chameleon Admin; block activation when missing.'
$adminMainNeedle = 'chameleon_plugin_require_admin_bootstrap'

if (-not (Test-Path -LiteralPath $template)) {
  Write-Error "Missing template: $template"
}

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
  if ($lines.Count -gt 0) {
    $out.Add($lines[0])
  } else {
    $out.Add('# Changelog')
  }
  $out.Add('')
  $out.Add("## $newVer")
  $out.Add('')
  $out.Add("- $changelogNote")
  for ($i = 1; $i -lt $lines.Count; $i++) { $out.Add($lines[$i]) }
  if (-not $WhatIf) {
    Set-Content -LiteralPath $changelogPath -Value ($out -join "`n") -Encoding UTF8
  }
}

function Get-TextDomainFromHeader([string]$raw) {
  if ($raw -match '(?m)(?:^\s*\*?\s*)Text Domain\s*:\s*([a-z0-9_-]+)') {
    return $Matches[1]
  }
  return $null
}

function Add-RequiresPluginsHeader([string]$raw) {
  if ($raw -match 'Requires Plugins\s*:') { return $raw }
  if ($raw -match '(?m)^(\s*\*\s*Requires PHP\s*:.*\r?\n)') {
    return [regex]::Replace($raw, '(?m)^(\s*\*\s*Requires PHP\s*:.*\r?\n)', "`$1 * Requires Plugins: chameleon-admin`r`n", 1)
  }
  if ($raw -match '(?m)^(Requires PHP\s*:.*\r?\n)') {
    return [regex]::Replace($raw, '(?m)^(Requires PHP\s*:.*\r?\n)', "`$1Requires Plugins: chameleon-admin`r`n", 1)
  }
  if ($raw -match '(?m)^(\s*\*\s*Version\s*:.*\r?\n)') {
    return [regex]::Replace($raw, '(?m)^(\s*\*\s*Version\s*:.*\r?\n)', "`$1 * Requires Plugins: chameleon-admin`r`n", 1)
  }
  return $raw
}

function Inject-AdminBootstrap([string]$raw, [string]$textDomain, [string]$includeRel) {
  if ($raw -match [regex]::Escape($adminMainNeedle)) { return $raw }
  $snippet = @"

require_once __DIR__ . '$includeRel';
chameleon_plugin_require_admin_bootstrap( __FILE__, '$textDomain' );

"@
  $patterns = @(
    "(?m)(defined\s*\(\s*'ABSPATH'\s*\)\s*\|\|\s*exit\s*;\s*\r?\n)",
    "(?m)(if\s*\(\s*!\s*defined\s*\(\s*'ABSPATH'\s*\)\s*\)\s*\{\s*\r?\n\s*exit\s*;\s*\r?\n\}\s*\r?\n)",
    "(?m)(if\s*\(\s*!\s*defined\s*\(\s*'WPINC'\s*\)\s*\)\s*\{\s*\r?\n\s*die\s*;\s*\r?\n\}\s*\r?\n)"
  )
  foreach ($pat in $patterns) {
    if ($raw -match $pat) {
      return [regex]::Replace($raw, $pat, "`$1$snippet", 1)
    }
  }
  return $raw
}

function Repair-AdminBootstrapNewlines([string]$raw) {
  return [regex]::Replace($raw, '(chameleon_plugin_require_admin_bootstrap\([^)]+\)\s*;)(\S)', "`$1`r`n`$2")
}

$bumpedVersions = @{}
$changed = 0

Get-ChildItem -LiteralPath $scanRoot -Recurse -Filter '*.php' -File |
  Where-Object {
    $_.FullName -notmatch '\\archive\\|\\_zip_build\\|\\wordpress-plugin\\' -and
    $_.Name -notmatch '-backup|-corrupted|install-check' -and
    $_.FullName -notmatch '\\chameleon-admin\\plugin\\chameleon-admin\.php$'
  } |
  ForEach-Object {
    $phpPath = $_.FullName
    $head = (Get-Content -LiteralPath $phpPath -TotalCount 60) -join "`n"
    if ($head -notmatch 'Plugin Name\s*:') { return }
    if ($head -notmatch 'Version\s*:') { return }
    if ($head -notmatch 'Plugin Name\s*:\s*\(Chameleon\)') { return }

    $raw = Get-Content -LiteralPath $phpPath -Raw
    $needsHeader = $raw -notmatch 'Requires Plugins\s*:'
    $needsBootstrap = $raw -notmatch [regex]::Escape($adminMainNeedle)
    if (-not $needsHeader -and -not $needsBootstrap) { return }

    $phpDir = Split-Path -Parent $phpPath
    $includesDir = Join-Path $phpDir 'includes'
    if (-not (Test-Path -LiteralPath $includesDir)) {
      if (-not $WhatIf) { New-Item -ItemType Directory -Path $includesDir -Force | Out-Null }
    }
    $destInclude = Join-Path $includesDir 'chameleon-require-admin.php'
    if (-not $WhatIf) {
      Copy-Item -LiteralPath $template -Destination $destInclude -Force
    }

    $textDomain = Get-TextDomainFromHeader -raw $raw
    if (-not $textDomain) {
      $textDomain = [System.IO.Path]::GetFileNameWithoutExtension($phpPath)
      $textDomain = $textDomain.ToLowerInvariant()
    }

    $newRaw = $raw
    if ($needsHeader) {
      $newRaw = Add-RequiresPluginsHeader -raw $newRaw
    }
    if ($needsBootstrap) {
      $newRaw = Inject-AdminBootstrap -raw $newRaw -textDomain $textDomain -includeRel '/includes/chameleon-require-admin.php'
    }
    $newRaw = Repair-AdminBootstrapNewlines -raw $newRaw

    if ($newRaw -eq $raw -and (Test-Path -LiteralPath $destInclude)) { return }

    $repoRoot = Find-PluginRepoRoot -startDir $phpDir
    $newVer = $null
    if ($repoRoot) {
      $versionPath = Find-VersionFile -repoRoot $repoRoot -phpPath $phpPath
      if ($versionPath) {
        if (-not $bumpedVersions.ContainsKey($versionPath)) {
          $newVer = Bump-VersionFile -versionPath $versionPath
          if ($newVer) {
            $bumpedVersions[$versionPath] = $newVer
            $changelog = Find-ChangelogFile -versionPath $versionPath -repoRoot $repoRoot
            if ($changelog) { Prepend-Changelog -changelogPath $changelog -newVer $newVer }
          }
        } else {
          $newVer = $bumpedVersions[$versionPath]
        }
        if ($newVer) {
          $newRaw = [regex]::Replace($newRaw, '(?m)^(\s*\*?\s*Version\s*:\s*)\d+\.\d+\.\d+(\s*)$', "`${1}$newVer`${2}", 1)
        }
      }
    }

    if (-not $WhatIf) {
      Set-Content -LiteralPath $phpPath -Value $newRaw -Encoding UTF8
    }

    Write-Host "Wired: $phpPath$(if ($newVer) { " (v$newVer)" })"
    $changed++
  }

Write-Host "Done. Wired $changed plugin(s)."

$repaired = 0
Get-ChildItem -LiteralPath $scanRoot -Recurse -Filter '*.php' -File |
  Where-Object {
    $_.FullName -notmatch '\\archive\\|\\_zip_build\\' -and
    $_.Name -notmatch '-backup|-corrupted|install-check'
  } |
  ForEach-Object {
    $raw = Get-Content -LiteralPath $_.FullName -Raw
    if ($raw -notmatch 'chameleon_plugin_require_admin_bootstrap') { return }
    $fixed = Repair-AdminBootstrapNewlines -raw $raw
    if ($fixed -eq $raw) { return }
    if (-not $WhatIf) {
      Set-Content -LiteralPath $_.FullName -Value $fixed -Encoding UTF8
    }
    Write-Host "Repaired newlines: $($_.FullName)"
    $repaired++
  }

if ($repaired -gt 0) {
  Write-Host "Repaired newline merges in $repaired file(s)."
}
