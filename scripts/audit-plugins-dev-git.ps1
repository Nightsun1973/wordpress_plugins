# Report Git remote and sync status for every plugins-dev repository.
# Run from monorepo root: .\scripts\audit-plugins-dev-git.ps1 [-Fetch] [-ExcludeArchive]

param(
  [switch]$Fetch,
  [switch]$ExcludeArchive
)

$ErrorActionPreference = 'Continue'

$MonorepoRoot = (Get-Location).Path
if (-not (Test-Path -LiteralPath (Join-Path $MonorepoRoot 'README.md'))) {
  throw "Run from wordpress_plugins root. Current: $MonorepoRoot"
}

$PluginsDev = Join-Path $MonorepoRoot 'plugins-dev'
$gitDirs = Get-ChildItem -LiteralPath $PluginsDev -Directory -Recurse -Force -Filter '.git' -ErrorAction SilentlyContinue

$roots = [System.Collections.Generic.List[string]]::new()
foreach ($g in $gitDirs) {
  $root = $g.Parent.FullName
  if ($ExcludeArchive -and ($root -match '[\\/]plugins-dev[\\/]archive[\\/]')) {
    continue
  }
  $roots.Add($root) | Out-Null
}

$roots = $roots | Sort-Object -Unique

$rows = @()
foreach ($root in $roots) {
  $rel = $root.Substring($MonorepoRoot.Length).TrimStart('\') -replace '\\', '/'
  Push-Location -LiteralPath $root
  try {
    if ($Fetch) {
      git fetch --all --prune 2>$null | Out-Null
    }

    $remote = (git remote get-url origin 2>$null)
    $branch = (git branch --show-current 2>$null)
    $dirty = (git status --porcelain 2>$null)
    $ahead = 0
    $behind = 0

    if ($remote -and $branch) {
      $upstream = git rev-parse --abbrev-ref '@{u}' 2>$null
      if ($LASTEXITCODE -eq 0 -and $upstream) {
        $counts = git rev-list --left-right --count '@{u}...HEAD' 2>$null
        if ($LASTEXITCODE -eq 0 -and ($counts -match '^(\d+)\s+(\d+)$')) {
          $behind = [int]$Matches[1]
          $ahead = [int]$Matches[2]
        }
      }
    }

    $rows += [pscustomobject]@{
      Path   = $rel
      Branch = $branch
      Remote = if ($remote) { $remote } else { '(none)' }
      Ahead  = $ahead
      Behind = $behind
      Dirty  = if ($dirty) { 'yes' } else { 'no' }
    }
  } finally {
    Pop-Location
  }
}

$rows | Format-Table -AutoSize

$noRemote = @($rows | Where-Object { $_.Remote -eq '(none)' })
$unsynced = @($rows | Where-Object { $_.Ahead -gt 0 -or $_.Behind -gt 0 })
$dirtyRepos = @($rows | Where-Object { $_.Dirty -eq 'yes' })

Write-Host ""
Write-Host "Repositories scanned: $($rows.Count)"
Write-Host "Without origin remote: $($noRemote.Count)"
Write-Host "Ahead/behind origin: $($unsynced.Count)"
Write-Host "Uncommitted changes: $($dirtyRepos.Count)"

if ($noRemote.Count -gt 0) {
  Write-Host ""
  Write-Host "No remote - add with: git remote add origin URL"
  $noRemote | ForEach-Object { Write-Host "  - $($_.Path)" }
}

if ($unsynced.Count -gt 0) {
  Write-Host ""
  Write-Host "Out of sync with origin:"
  $unsynced | ForEach-Object {
    Write-Host ("  - {0} (ahead {1}, behind {2})" -f $_.Path, $_.Ahead, $_.Behind)
  }
}
