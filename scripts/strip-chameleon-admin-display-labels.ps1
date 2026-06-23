<#
.SYNOPSIS
  Remove (Chameleon) from admin/UI strings; keep it only in Plugin Name header lines.

.EXAMPLE
  .\scripts\strip-chameleon-admin-display-labels.ps1
#>
param(
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$wpRoot = $PSScriptRoot | Split-Path -Parent
$scanRoot = Join-Path $wpRoot 'plugins-dev'
$changedFiles = 0
$totalReplacements = 0

function Strip-ChameleonFromLine([string]$line) {
  if ($line -match 'Plugin Name\s*:') { return $line }
  $newLine = $line
  # Suffix: 'Name (Chameleon)' or 'Name (Chameleon) v%s' etc.
  $newLine = [regex]::Replace($newLine, "(['\`"])([^'\`"]*?)\s+\(Chameleon\)", '${1}${2}')
  # Prefix: '(Chameleon) Name' in quoted UI strings (not dependency boilerplate on same line)
  if ($newLine -notmatch 'requires.*Chameleon Admin' -and $newLine -notmatch 'Chameleon Admin is required') {
    $newLine = [regex]::Replace($newLine, "(['\`"])\(Chameleon\)\s+([^'\`"]+)", '${1}${2}')
  }
  # Docblocks / comments: * Widget Name (Chameleon)
  $newLine = [regex]::Replace($newLine, '(\*\s+[^*\r\n]*?)\s+\(Chameleon\)', '${1}')
  return $newLine
}

Get-ChildItem -LiteralPath $scanRoot -Recurse -Filter '*.php' -File |
  Where-Object {
    $_.FullName -notmatch '\\archive\\|\\_zip_build\\' -and
    $_.Name -notmatch '-backup|-corrupted|install-check'
  } |
  ForEach-Object {
    $path = $_.FullName
    $lines = @(Get-Content -LiteralPath $path)
    $out = [System.Collections.Generic.List[string]]::new()
    $fileChanged = $false
    $fileCount = 0

    foreach ($line in $lines) {
      $newLine = Strip-ChameleonFromLine -line $line
      if ($newLine -ne $line) {
        $fileChanged = $true
        $fileCount++
      }
      $out.Add($newLine)
    }

    if ($fileChanged) {
      if (-not $WhatIf) {
        Set-Content -LiteralPath $path -Value ($out -join "`n") -Encoding UTF8
      }
      Write-Host "Labels: $path ($fileCount line(s))"
      $changedFiles++
      $totalReplacements += $fileCount
    }
  }

# Refresh deployed copies of the require-admin helper from canonical template.
$template = Join-Path $wpRoot '.tools\templates\chameleon-require-admin.php'
if (Test-Path -LiteralPath $template) {
  $copied = 0
  Get-ChildItem -LiteralPath $scanRoot -Recurse -Filter 'chameleon-require-admin.php' -File |
    Where-Object { $_.FullName -notmatch '\\archive\\' } |
    ForEach-Object {
      if (-not $WhatIf) {
        Copy-Item -LiteralPath $template -Destination $_.FullName -Force
      }
      $copied++
    }
  if ($copied -gt 0) {
    Write-Host "Synced $copied chameleon-require-admin.php copy/copies from template."
  }
}

Write-Host "Done. Updated $changedFiles file(s), $totalReplacements line(s)."
