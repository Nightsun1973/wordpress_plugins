# Generate wordpress_plugins.code-workspace from plugins-dev Git repos and plugin roots.
# Run from monorepo root: .\scripts\discover-plugins-dev-workspace.ps1 [-ExcludeArchive]
#
# Opens the umbrella repo plus every discovered plugins-dev project so Cursor/VS Code
# Source Control lists each nested repository (required for Git Graph per plugin).

param(
  [switch]$ExcludeArchive
)

$ErrorActionPreference = 'Stop'

$MonorepoRoot = (Get-Location).Path
if (-not (Test-Path -LiteralPath (Join-Path $MonorepoRoot 'README.md'))) {
  throw "Run from wordpress_plugins root (folder containing README.md). Current: $MonorepoRoot"
}

$PluginsDev = Join-Path $MonorepoRoot 'plugins-dev'
if (-not (Test-Path -LiteralPath $PluginsDev)) {
  throw "Missing plugins-dev at: $PluginsDev"
}

function Get-RelativePath([string]$Root, [string]$FullPath) {
  $r = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
  $f = (Resolve-Path -LiteralPath $FullPath).Path.TrimEnd('\')
  if ($f.Length -le $r.Length) { return '.' }
  return ($f.Substring($r.Length).TrimStart('\') -replace '\\', '/')
}

function Test-UnderPath([string]$Child, [string]$Parent) {
  $c = (Resolve-Path -LiteralPath $Child).Path.TrimEnd('\') + '\'
  $p = (Resolve-Path -LiteralPath $Parent).Path.TrimEnd('\') + '\'
  return $c.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-PluginProjectRoot([string]$Dir) {
  $readme = Join-Path $Dir 'README.md'
  if (-not (Test-Path -LiteralPath $readme)) { return $false }
  return (Test-Path -LiteralPath (Join-Path $Dir 'plugin')) -or
    (Test-Path -LiteralPath (Join-Path $Dir 'plugins'))
}

function Get-WorkspaceFolderName([string]$RelPath) {
  $parts = $RelPath -split '/'
  if ($parts.Count -ge 2) {
    return ($parts[-1] + ' (' + ($parts[-2] + '/' + $parts[-1]) + ')')
  }
  return $parts[-1]
}

function Build-WorkspaceFolders {
  param(
    [bool]$SkipArchive
  )

  $gitRoots = [System.Collections.Generic.List[string]]::new()
  Get-ChildItem -LiteralPath $PluginsDev -Directory -Recurse -Force -Filter '.git' -ErrorAction SilentlyContinue |
    ForEach-Object {
      $root = $_.Parent.FullName
      if ($SkipArchive -and ($root -match '[\\/]plugins-dev[\\/]archive[\\/]')) { return }

      $isNested = $false
      foreach ($existing in $gitRoots) {
        if ((Test-UnderPath -Child $root -Parent $existing) -and ($root -ne $existing)) {
          $isNested = $true
          break
        }
      }
      if (-not $isNested) {
        for ($i = $gitRoots.Count - 1; $i -ge 0; $i--) {
          if ((Test-UnderPath -Child $gitRoots[$i] -Parent $root) -and ($gitRoots[$i] -ne $root)) {
            $gitRoots.RemoveAt($i)
          }
        }
        $gitRoots.Add($root) | Out-Null
      }
    }

  $extraRoots = [System.Collections.Generic.List[string]]::new()
  Get-ChildItem -LiteralPath $PluginsDev -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
    ForEach-Object {
      if ($SkipArchive -and ($_.FullName -match '[\\/]plugins-dev[\\/]archive[\\/]')) { return }
      if (-not (Test-PluginProjectRoot -Dir $_.FullName)) { return }
      $underGit = $false
      foreach ($g in $gitRoots) {
        if (Test-UnderPath -Child $_.FullName -Parent $g) { $underGit = $true; break }
      }
      if (-not $underGit) {
        $extraRoots.Add($_.FullName) | Out-Null
      }
    }

  $allRoots = @($gitRoots) + @($extraRoots) | Sort-Object { Get-RelativePath $MonorepoRoot $_ }

  $folders = [System.Collections.Generic.List[object]]::new()
  $folders.Add([ordered]@{ name = 'wordpress_plugins (umbrella)'; path = '.' }) | Out-Null

  foreach ($full in $allRoots) {
    $rel = Get-RelativePath -Root $MonorepoRoot -FullPath $full
    $hasGit = Test-Path -LiteralPath (Join-Path $full '.git')
    $suffix = if ($hasGit) { '' } else { ' [no .git]' }
    $folders.Add([ordered]@{
        name = (Get-WorkspaceFolderName -RelPath $rel) + $suffix
        path = $rel
      }) | Out-Null
  }

  return [pscustomobject]@{
    Folders  = $folders
    GitCount = $gitRoots.Count
    ExtraCount = $extraRoots.Count
  }
}

function Write-WorkspaceFile {
  param(
    [string]$OutPath,
    [object]$Folders
  )

  $workspace = [ordered]@{
    folders = $Folders.ToArray()
    settings = [ordered]@{
      'git.autoRepositoryDetection'         = 'subFolders'
      'git.repositoryScanMaxDepth'          = 10
      'git.detectSubmodules'                = $true
      'git.openRepositoryInParentFolders'   = $false
      'git.showProgress'                    = $true
      'scm.repositories.visible'            = 10
      'intelephense.stubs'                  = @('wordpress')
    }
    extensions = [ordered]@{
      recommendations = @(
        'bmewburn.vscode-intelephense-client'
        'mhutchie.vscode-git-graph'
        'eamodio.gitlens'
      )
    }
  }

  $json = $workspace | ConvertTo-Json -Depth 6
  Set-Content -LiteralPath $OutPath -Value $json -Encoding UTF8
}

$full = Build-WorkspaceFolders -SkipArchive:$ExcludeArchive
$fullPath = Join-Path $MonorepoRoot 'wordpress_plugins.code-workspace'
Write-WorkspaceFile -OutPath $fullPath -Folders $full.Folders

Write-Host "Wrote $($full.Folders.Count) workspace folders to $fullPath"
Write-Host "  Git repos: $($full.GitCount)"
Write-Host "  Plugin roots without .git: $($full.ExtraCount)"

$active = Build-WorkspaceFolders -SkipArchive $true
$activePath = Join-Path $MonorepoRoot 'plugins-dev-active.code-workspace'
Write-WorkspaceFile -OutPath $activePath -Folders $active.Folders

Write-Host "Wrote $($active.Folders.Count) workspace folders to $activePath (archive excluded)"
Write-Host "  Git repos: $($active.GitCount)"

if ($full.ExtraCount -gt 0) {
  Write-Host '  Folders marked [no .git] are not separate Git repos yet.'
}

Write-Host ""
Write-Host "Open in Cursor: File -> Open Workspace from File -> wordpress_plugins.code-workspace"
Write-Host "  (smaller list: plugins-dev-active.code-workspace)"
Write-Host "Git status audit: .\scripts\audit-plugins-dev-git.ps1"
