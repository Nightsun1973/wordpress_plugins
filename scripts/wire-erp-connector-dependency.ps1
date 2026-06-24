<#
.SYNOPSIS
  Wire ERP Connector dependency into ERP-dependent Chameleon plugins.

.DESCRIPTION
  - Copies .tools/templates/chameleon-require-erp.php into each plugin includes/ folder.
  - Adds require_once + chameleon_plugin_require_erp_bootstrap() after require-admin bootstrap.
  - Targets main plugin files that call erp_connector(), excluding erp-connector and optional ERP users.
  - Bumps patch VERSION + CHANGELOG when VERSION exists.

.EXAMPLE
  .\scripts\wire-erp-connector-dependency.ps1
#>
param(
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$wpRoot = $PSScriptRoot | Split-Path -Parent
$scanRoot = Join-Path $wpRoot 'plugins-dev'
$template = Join-Path $wpRoot '.tools\templates\chameleon-require-erp.php'
$changelogNote = 'Gracefully deactivate when ERP Connector is missing or disconnected; shared require-erp bootstrap.'
$erpMainNeedle = 'chameleon_plugin_require_erp_bootstrap'

$excludeMainPatterns = @(
    '\\erp-connector\\plugin\\erp-connector\.php$'
    '\\php-reports\\plugin\\php-reports\.php$'
)

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
        Set-Content -LiteralPath $versionPath -Value "$newVer`n" -Encoding UTF8NoBOM
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
        Set-Content -LiteralPath $changelogPath -Value ($out -join "`n") -Encoding UTF8NoBOM
    }
}

function Get-TextDomainFromHeader([string]$raw) {
    if ($raw -match '(?m)(?:^\s*\*?\s*)Text Domain\s*:\s*([a-z0-9_-]+)') {
        return $Matches[1]
    }
    return $null
}

function Inject-ErpBootstrap([string]$raw, [string]$textDomain) {
    if ($raw -match [regex]::Escape($erpMainNeedle)) { return $raw }
    $snippet = @"

require_once __DIR__ . '/includes/chameleon-require-erp.php';
chameleon_plugin_require_erp_bootstrap( __FILE__, '$textDomain' );

"@
    if ($raw -match 'chameleon_plugin_require_admin_bootstrap\s*\([^)]+\)\s*;') {
        return [regex]::Replace(
            $raw,
            '(chameleon_plugin_require_admin_bootstrap\s*\([^)]+\)\s*;)',
            "`$1$snippet",
            1
        )
    }
    $patterns = @(
        "(?m)(defined\s*\(\s*'ABSPATH'\s*\)\s*\|\|\s*exit\s*;\s*\r?\n)",
        "(?m)(if\s*\(\s*!\s*defined\s*\(\s*'ABSPATH'\s*\)\s*\)\s*\{\s*\r?\n\s*exit\s*;\s*\r?\n\}\s*\r?\n)"
    )
    foreach ($pat in $patterns) {
        if ($raw -match $pat) {
            return [regex]::Replace($raw, $pat, "`$1$snippet", 1)
        }
    }
    return $raw
}

function Test-IsErpDependentMainFile([string]$phpPath, [string]$raw) {
    foreach ($pat in $excludeMainPatterns) {
        if ($phpPath -match $pat) { return $false }
    }
    if ($raw -notmatch 'erp_connector\s*\(') { return $false }
    return $true
}

$bumpedVersions = @{}
$changed = 0

Get-ChildItem -LiteralPath $scanRoot -Recurse -Filter '*.php' -File |
    Where-Object {
        $_.FullName -notmatch '\\archive\\|\\_zip_build\\|\\wordpress-plugin\\' -and
        $_.Name -notmatch '-backup|-corrupted|install-check'
    } |
    ForEach-Object {
        $phpPath = $_.FullName
        $head = (Get-Content -LiteralPath $phpPath -TotalCount 60) -join "`n"
        if ($head -notmatch 'Plugin Name\s*:') { return }
        if ($head -notmatch 'Version\s*:') { return }

        $raw = Get-Content -LiteralPath $phpPath -Raw
        if (-not (Test-IsErpDependentMainFile -phpPath $phpPath -raw $raw)) { return }
        if ($raw -match [regex]::Escape($erpMainNeedle)) { return }

        $phpDir = Split-Path -Parent $phpPath
        $includesDir = Join-Path $phpDir 'includes'
        if (-not (Test-Path -LiteralPath $includesDir)) {
            if (-not $WhatIf) { New-Item -ItemType Directory -Path $includesDir -Force | Out-Null }
        }
        $destInclude = Join-Path $includesDir 'chameleon-require-erp.php'
        if (-not $WhatIf) {
            Copy-Item -LiteralPath $template -Destination $destInclude -Force
        }

        $textDomain = Get-TextDomainFromHeader -raw $raw
        if (-not $textDomain) {
            $textDomain = [System.IO.Path]::GetFileNameWithoutExtension($phpPath).ToLowerInvariant()
        }

        $newRaw = Inject-ErpBootstrap -raw $raw -textDomain $textDomain

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
            [System.IO.File]::WriteAllText($phpPath, $newRaw, (New-Object System.Text.UTF8Encoding $false))
        }

        Write-Host "Wired ERP: $phpPath$(if ($newVer) { " (v$newVer)" })"
        $changed++
    }

Write-Host "Done. Wired $changed ERP-dependent plugin(s)."
