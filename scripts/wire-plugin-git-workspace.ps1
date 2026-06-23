# Initialise Git + origin remote for a plugins-dev project and refresh the multi-root workspace.
#
# Run from wordpress_plugins root:
#   .\scripts\wire-plugin-git-workspace.ps1 -PluginPath plugins-dev/chameleon/other/my-plugin
#   .\scripts\wire-plugin-git-workspace.ps1 -PluginPath plugins-dev/chameleon/other/my-plugin -RemoteUrl https://github.com/Nightsun1973/my-plugin.git
#   .\scripts\wire-plugin-git-workspace.ps1 -PluginPath plugins-dev/chameleon/other/my-plugin -CreateRemote -GitHubRepo my-plugin
#
# After wiring, open plugins-dev-active.code-workspace in Cursor (File -> Open Workspace from File).

param(
  [Parameter(Mandatory = $true)]
  [string]$PluginPath,

  [string]$RemoteUrl = '',

  [string]$GitHubRepo = '',

  [switch]$CreateRemote,

  [ValidateSet('private', 'public')]
  [string]$Visibility = 'private',

  [switch]$SkipWorkspaceRefresh
)

$ErrorActionPreference = 'Stop'

$MonorepoRoot = (Get-Location).Path
if (-not (Test-Path -LiteralPath (Join-Path $MonorepoRoot 'README.md'))) {
  throw "Run from wordpress_plugins root. Current: $MonorepoRoot"
}

function Resolve-PluginRoot([string]$InputPath) {
  if ([System.IO.Path]::IsPathRooted($InputPath)) {
    $candidate = $InputPath
  } else {
    $candidate = Join-Path $MonorepoRoot ($InputPath -replace '/', '\')
  }

  if (-not (Test-Path -LiteralPath $candidate)) {
    throw "Plugin path not found: $candidate"
  }

  $root = (Resolve-Path -LiteralPath $candidate).Path
  $readme = Join-Path $root 'README.md'
  $hasPlugin = (Test-Path -LiteralPath (Join-Path $root 'plugin')) -or
    (Test-Path -LiteralPath (Join-Path $root 'plugins'))

  if (-not (Test-Path -LiteralPath $readme) -or -not $hasPlugin) {
    throw "Not a plugin project root (need README.md and plugin/ or plugins/): $root"
  }

  if ($root -notmatch '[\\/]plugins-dev[\\/]') {
    Write-Warning "Path is outside plugins-dev/: $root"
  }

  return $root
}

function Get-DefaultBranch {
  param([string]$Root)
  Push-Location -LiteralPath $Root
  try {
    $current = git branch --show-current 2>$null
    if ($current) { return $current }
    return 'master'
  } finally {
    Pop-Location
  }
}

$pluginRoot = Resolve-PluginRoot -InputPath $PluginPath
$slug = Split-Path -Leaf $pluginRoot
if (-not $GitHubRepo) { $GitHubRepo = $slug }

Push-Location -LiteralPath $pluginRoot
try {
  $hasGit = Test-Path -LiteralPath (Join-Path $pluginRoot '.git')

  if (-not $hasGit) {
    Write-Host "Initialising Git in $pluginRoot"
    git init
    if (-not (Test-Path -LiteralPath (Join-Path $pluginRoot '.gitignore'))) {
      Write-Warning "No .gitignore found — add one before the first commit (see prompt-wordpress-plugin-starter.md)."
    }
  } else {
    Write-Host "Git repo already exists: $pluginRoot"
  }

  $remote = git remote get-url origin 2>$null
  if ($LASTEXITCODE -ne 0) { $remote = '' }

  if (-not $remote -and $CreateRemote) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
      throw "GitHub CLI (gh) not found. Pass -RemoteUrl or install gh and authenticate (gh auth login)."
    }

    Write-Host "Creating GitHub repo: $GitHubRepo ($Visibility)"
    if ($Visibility -eq 'public') {
      gh repo create $GitHubRepo --public --source=. --remote=origin
    } else {
      gh repo create $GitHubRepo --private --source=. --remote=origin
    }
    $remote = git remote get-url origin 2>$null
  } elseif (-not $remote -and $RemoteUrl) {
    Write-Host "Adding origin: $RemoteUrl"
    git remote add origin $RemoteUrl
    $remote = $RemoteUrl
  } elseif (-not $remote) {
    Write-Warning "No origin remote. Pass -RemoteUrl or -CreateRemote -GitHubRepo <name>"
  } else {
    Write-Host "Origin already set: $remote"
  }

  $branch = Get-DefaultBranch -Root $pluginRoot
  $status = git status --porcelain 2>$null
  $hasCommits = git rev-parse HEAD 2>$null

  if ($remote) {
    Write-Host ""
    Write-Host "Next steps (from plugin root):"
    if ($status) {
      Write-Host "  git add -A && git commit -m `"Initial commit`""
    } elseif (-not $hasCommits) {
      Write-Host "  git add -A && git commit -m `"Initial commit`""
    }
    Write-Host "  git push -u origin $branch"
  }
} finally {
  Pop-Location
}

if (-not $SkipWorkspaceRefresh) {
  Write-Host ""
  $discover = Join-Path $MonorepoRoot 'scripts\discover-plugins-dev-workspace.ps1'
  & $discover
}

Write-Host ""
Write-Host "Verify: .\scripts\audit-plugins-dev-git.ps1 -ExcludeArchive"
Write-Host "Open:   File -> Open Workspace from File -> plugins-dev-active.code-workspace"
