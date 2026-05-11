$ErrorActionPreference = 'Stop'

<# 
.SYNOPSIS
  Syncs the latest shared prompts + Cursor rules into a plugin repo.
.DESCRIPTION
  This is the **master** copy for the shared workspace.

  Run from a plugin repo root (folder containing README.md and prompts/).
  The script searches the development root for the highest prompts/VERSION and copies:
  - prompts/*  -> <repo>/prompts/
  - .cursor/rules/*.mdc -> <repo>/.cursor/rules/

  Development root is chosen in this order:
  1) Environment variable CHAMELEON_DEV_ROOT (if set)
  2) Path in file .chameleon-dev-root in the project root (one line)
  3) Parent of the project (one level above)
.EXAMPLE
  .\.tools\scripts\sync-chameleon-standards.ps1
#>

$projectRoot = Get-Location
$readmePath = Join-Path $projectRoot 'README.md'
$promptsDir = Join-Path $projectRoot 'prompts'
$versionPath = Join-Path $promptsDir 'VERSION'

if (-not (Test-Path $readmePath)) {
  Write-Error "Run this script from the project root (folder containing README.md). Current directory: $projectRoot"
}

$devRoot = $null
if ($env:CHAMELEON_DEV_ROOT) {
  $devRoot = $env:CHAMELEON_DEV_ROOT.Trim()
}
if (-not $devRoot) {
  $devRootFile = Join-Path $projectRoot '.chameleon-dev-root'
  if (Test-Path $devRootFile) {
    $firstLine = Get-Content $devRootFile -First 1 -ErrorAction SilentlyContinue
    $line = if ($firstLine) { $firstLine.Trim() } else { $null }
    if ($line) {
      if ([System.IO.Path]::IsPathRooted($line)) {
        $devRoot = $line
      } else {
        $devRoot = (Resolve-Path (Join-Path $projectRoot $line) -ErrorAction SilentlyContinue).Path
      }
    }
  }
}
if (-not $devRoot) {
  $devRoot = Split-Path $projectRoot -Parent
}
if (-not $devRoot -or -not (Test-Path $devRoot)) {
  Write-Host "Development root not found or invalid; nothing to scan. Set CHAMELEON_DEV_ROOT or .chameleon-dev-root. Current: $devRoot"
  exit 0
}

function Get-VersionFromFile {
  param([string]$path)
  if (-not (Test-Path $path)) { return $null }
  $content = Get-Content $path -First 1 -ErrorAction SilentlyContinue
  $line = if ($content) { $content.Trim() } else { $null }
  if (-not $line) { return $null }
  if ($line -match '^(\d+)\.(\d+)\.(\d+)') {
    try { return [System.Version]$line } catch { return $null }
  }
  return $null
}

$currentVersion = Get-VersionFromFile $versionPath
if (-not $currentVersion) { $currentVersion = [System.Version]'0.0.0' }

$versionFiles = Get-ChildItem -Path $devRoot -Recurse -Filter 'VERSION' -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Directory.Name -eq 'prompts' }

$bestVersion = $currentVersion
$bestSourceRoot = $null
foreach ($f in $versionFiles) {
  $sourceRoot = $f.Directory.Parent.FullName
  $v = Get-VersionFromFile $f.FullName
  if (-not $v) { continue }
  if ($v -gt $bestVersion) {
    $bestVersion = $v
    $bestSourceRoot = $sourceRoot
  }
}

if (-not $bestSourceRoot) {
  Write-Host "No newer prompts/VERSION found under development root ($devRoot). Current: $currentVersion"
  exit 0
}

$sourcePrompts = Join-Path $bestSourceRoot 'prompts'
$sourceRules = Join-Path (Join-Path $bestSourceRoot '.cursor') 'rules'
$destRules = Join-Path (Join-Path $projectRoot '.cursor') 'rules'

if (-not (Test-Path $sourcePrompts)) {
  Write-Host "Source prompts not found at $sourcePrompts"
  exit 0
}

Write-Host "Syncing from $bestSourceRoot (version $bestVersion) into $projectRoot"

if (-not (Test-Path $promptsDir)) { New-Item -ItemType Directory -Path $promptsDir -Force | Out-Null }
Copy-Item -Path (Join-Path $sourcePrompts '*') -Destination $promptsDir -Recurse -Force
Write-Host "  Copied prompts/"

if (Test-Path $sourceRules) {
  $cursorDir = Join-Path $projectRoot '.cursor'
  if (-not (Test-Path $cursorDir)) { New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null }
  if (-not (Test-Path $destRules)) { New-Item -ItemType Directory -Path $destRules -Force | Out-Null }
  Copy-Item -Path (Join-Path $sourceRules '*.mdc') -Destination $destRules -Force
  Write-Host "  Copied .cursor/rules/"
}

Write-Host "Done. This project now has prompts and rules version $bestVersion."

