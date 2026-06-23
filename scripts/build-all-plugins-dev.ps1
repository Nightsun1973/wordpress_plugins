<#
.SYNOPSIS
  Build installation zips for all plugins-dev repos, then publish to plugins-live + SFTP.
.EXAMPLE
  .\scripts\build-all-plugins-dev.ps1
  .\scripts\build-all-plugins-dev.ps1 -SkipPublish
#>
param(
  [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'

$wpRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pluginsDev = Join-Path $wpRoot 'plugins-dev'

if (-not (Test-Path -LiteralPath $pluginsDev)) {
  throw "Missing plugins-dev: $pluginsDev"
}

$env:CHAMELEON_SKIP_LIVE_PUBLISH = '1'

$buildScripts = Get-ChildItem -LiteralPath $pluginsDev -Recurse -File -Filter 'build*.ps1' |
  Where-Object {
    $_.FullName -notmatch '\\archive\\' -and
    $_.DirectoryName -match '\\scripts$' -and
    $_.Name -notmatch '^(cleanup|after-build|sync|publish)' -and
    (
      $_.Name -notmatch '^build-(booking|dashboard)-zip\.ps1$' -or
      $_.FullName -match '\\client\\knowles\\'
    )
  } |
  Sort-Object FullName -Unique

$failed = @()
$built = 0

foreach ($script in $buildScripts) {
  $repoRoot = (Resolve-Path (Join-Path $script.Directory.Parent.FullName '.')).Path
  if (-not (Test-Path (Join-Path $repoRoot 'README.md'))) { continue }

  # Skip generic build-plugin-zip.ps1 when a dedicated build-*-zip.ps1 exists (e.g. mask-login stub).
  if ($script.Name -eq 'build-plugin-zip.ps1') {
    $dedicated = Get-ChildItem -LiteralPath $script.DirectoryName -File -Filter 'build-*-zip.ps1' |
      Where-Object { $_.Name -ne 'build-plugin-zip.ps1' }
  if ($dedicated.Count -gt 0) { continue }
  }

  Write-Host "`n=== BUILD $($script.Name) @ $repoRoot ==="
  try {
    Push-Location -LiteralPath $repoRoot
    & $script.FullName
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Exit code $LASTEXITCODE" }
    $built++
  } catch {
    Write-Warning "FAILED: $($script.FullName) — $($_.Exception.Message)"
    $failed += $script.FullName
  } finally {
    Pop-Location
  }
}

Remove-Item Env:CHAMELEON_SKIP_LIVE_PUBLISH -ErrorAction SilentlyContinue

Write-Host "`nBuild pass complete. Succeeded: $built. Failed: $($failed.Count)."
if ($failed.Count -gt 0) {
  $failed | ForEach-Object { Write-Host "  - $_" }
}

if (-not $SkipPublish) {
  & (Join-Path $wpRoot 'scripts\publish-all-plugins-dev.ps1')
}

if ($failed.Count -gt 0) { exit 1 }
