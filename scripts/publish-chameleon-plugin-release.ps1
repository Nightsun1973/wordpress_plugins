<#
.SYNOPSIS
  Full publish: optional patch bump, build zip, publish-live-plugins (local + manifest + optional FTP), optional git commit.

.DESCRIPTION
  Run from the plugin project root (folder containing README.md), or pass -PluginRepoRoot.

  1. If -BumpPatch: increment plugin/VERSION or VERSION, sync * Version: in the main plugin PHP under plugin/,
     and prepend a ## entry to plugin/CHANGELOG.md or CHANGELOG.md when -ChangelogNote is set.
  2. Run the build script (auto-detect common names if -BuildScriptRelative omitted).
  3. Call ..\.tools\scripts\publish-live-plugins.ps1 (copies zips, regenerates index.json, FTP if env set).
  4. If -GitCommit: commit in wordpress_plugins (plugins-live/index.json) and/or in the plugin repo (version files).

.PARAMETER PluginRepoRoot
  Defaults to current directory.

.EXAMPLE
  cd chameleon\other\email-send-and-log
  .\..\..\..\scripts\publish-chameleon-plugin-release.ps1 -BumpPatch -ChangelogNote "Fix foo." -GitCommit

.EXAMPLE
  .\scripts\publish-chameleon-plugin-release.ps1 -PluginRepoRoot "C:\...\email-send-and-log" -BuildScriptRelative "scripts\build-plugin-zip.ps1" -GitCommit -CommitMessage "email-send-and-log: v1.1.5"
#>
param(
  [Parameter(Mandatory = $false)]
  [string]$PluginRepoRoot = '.',

  [Parameter(Mandatory = $false)]
  [string]$BuildScriptRelative = '',

  [Parameter(Mandatory = $false)]
  [switch]$BumpPatch,

  [Parameter(Mandatory = $false)]
  [string]$ChangelogNote = '',

  [Parameter(Mandatory = $false)]
  [switch]$GitCommit,

  [Parameter(Mandatory = $false)]
  [string]$CommitMessage = ''
)

$ErrorActionPreference = 'Stop'

function Find-WordpressPluginsRoot([string]$start) {
  $cur = (Resolve-Path -LiteralPath $start).Path
  while ($true) {
    if ((Split-Path -Leaf $cur) -eq 'wordpress_plugins') { return $cur }
    $parent = Split-Path -Parent $cur
    if (-not $parent -or $parent -eq $cur) { return $null }
    $cur = $parent
  }
}

function Get-RelativePathFrom([string]$FromDir, [string]$AbsolutePath) {
  $f = (Resolve-Path -LiteralPath $FromDir).Path.TrimEnd('\')
  $a = (Resolve-Path -LiteralPath $AbsolutePath).Path
  if ($a.StartsWith($f, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $a.Substring($f.Length).TrimStart('\')
  }
  return $null
}

function Get-RepoRelativeGitPath([string]$repoRoot, [string]$filePath) {
  $r = (Resolve-Path -LiteralPath $repoRoot).Path.TrimEnd('\')
  $f = (Resolve-Path -LiteralPath $filePath).Path
  if (-not $f.StartsWith($r, [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
  return $f.Substring($r.Length).TrimStart('\').Replace('\', '/')
}

$repoRoot = (Resolve-Path -LiteralPath $PluginRepoRoot).Path
$wpRoot = Find-WordpressPluginsRoot -start $repoRoot
if (-not $wpRoot) { throw "Could not find wordpress_plugins root above: $repoRoot" }

$readme = Join-Path $repoRoot 'README.md'
if (-not (Test-Path -LiteralPath $readme)) {
  throw "Not a plugin repo root (README.md missing): $repoRoot"
}

$publishScript = Join-Path $wpRoot '.tools\scripts\publish-live-plugins.ps1'
if (-not (Test-Path -LiteralPath $publishScript)) { throw "Missing: $publishScript" }

$gitPathsWp = [System.Collections.Generic.List[string]]::new()
$pluginRelGitAdds = [System.Collections.Generic.List[string]]::new()

Push-Location -LiteralPath $repoRoot
try {
  if ($BumpPatch) {
    $versionPath = $null
    foreach ($rel in @('plugin\VERSION', 'VERSION')) {
      $p = Join-Path $repoRoot $rel
      if (Test-Path -LiteralPath $p) { $versionPath = $p; break }
    }
    if (-not $versionPath) { throw "BumpPatch: no VERSION file at plugin\VERSION or VERSION under $repoRoot" }

    $verLine = (Get-Content -LiteralPath $versionPath -Raw).Trim()
    $m = [regex]::Match($verLine, '^(\d+)\.(\d+)\.(\d+)$')
    if (-not $m.Success) { throw "BumpPatch: VERSION must be semver x.y.z, got: $verLine" }
    $major = [int]$m.Groups[1].Value
    $minor = [int]$m.Groups[2].Value
    $patch = [int]$m.Groups[3].Value + 1
    $newVer = "$major.$minor.$patch"
    Set-Content -LiteralPath $versionPath -Value "$newVer`n" -Encoding utf8
    Write-Host "Bumped VERSION => $newVer"

    $relV = Get-RelativePathFrom -FromDir $wpRoot -AbsolutePath $versionPath
    if ($relV) { $gitPathsWp.Add($relV) }
    $prV = Get-RepoRelativeGitPath -repoRoot $repoRoot -filePath $versionPath
    if ($prV) { [void]$pluginRelGitAdds.Add($prV) }

    $pluginDir = Join-Path $repoRoot 'plugin'
    if (Test-Path -LiteralPath $pluginDir) {
      $mainPhp = $null
      foreach ($phpFile in (Get-ChildItem -LiteralPath $pluginDir -File -Filter *.php -ErrorAction SilentlyContinue)) {
        $head = (Get-Content -LiteralPath $phpFile.FullName -TotalCount 80) -join "`n"
        if ($head -match 'Plugin Name\s*:') {
          $mainPhp = $phpFile.FullName
          break
        }
      }
      if ($mainPhp) {
        $raw = Get-Content -LiteralPath $mainPhp -Raw
        $updated = [regex]::Replace($raw, '(?m)^(\s*\*?\s*Version\s*:\s*)\d+\.\d+\.\d+(\s*)$', "`${1}$newVer`${2}", 1)
        if ($updated -eq $raw) {
          Write-Warning "BumpPatch: no * Version: x.y.z line updated in $(Split-Path -Leaf $mainPhp); check main plugin file."
        } else {
          Set-Content -LiteralPath $mainPhp -Value $updated -Encoding utf8
          Write-Host "Updated Version header in $(Split-Path -Leaf $mainPhp)"
        }
        $relP = Get-RelativePathFrom -FromDir $wpRoot -AbsolutePath $mainPhp
        if ($relP) { $gitPathsWp.Add($relP) }
        $prP = Get-RepoRelativeGitPath -repoRoot $repoRoot -filePath $mainPhp
        if ($prP) { [void]$pluginRelGitAdds.Add($prP) }
      } else {
        Write-Warning 'BumpPatch: no main plugin PHP with Plugin Name: under plugin/.'
      }
    }

    if ($ChangelogNote) {
      $changelog = $null
      foreach ($rel in @('plugin\CHANGELOG.md', 'CHANGELOG.md')) {
        $p = Join-Path $repoRoot $rel
        if (Test-Path -LiteralPath $p) { $changelog = $p; break }
      }
      if ($changelog) {
        $lines = Get-Content -LiteralPath $changelog
        $out = New-Object System.Collections.Generic.List[string]
        if ($lines.Count -eq 0) {
          $out.Add('# Changelog')
        } else {
          $out.Add($lines[0])
        }
        $out.Add('')
        $out.Add("## $newVer")
        $out.Add('')
        $out.Add("- $ChangelogNote")
        for ($i = 1; $i -lt $lines.Count; $i++) {
          $out.Add($lines[$i])
        }
        Set-Content -LiteralPath $changelog -Value ($out -join "`n") -Encoding utf8
        Write-Host "Updated CHANGELOG: $(Split-Path -Leaf $changelog)"
        $relC = Get-RelativePathFrom -FromDir $wpRoot -AbsolutePath $changelog
        if ($relC) { $gitPathsWp.Add($relC) }
        $prC = Get-RepoRelativeGitPath -repoRoot $repoRoot -filePath $changelog
        if ($prC) { [void]$pluginRelGitAdds.Add($prC) }
      } else {
        Write-Warning 'BumpPatch: no plugin\CHANGELOG.md or CHANGELOG.md; skipped changelog.'
      }
    } elseif ($BumpPatch) {
      Write-Warning 'BumpPatch: supply -ChangelogNote to append a changelog entry, or add CHANGELOG manually.'
    }
  }

  $buildScript = $null
  if ($BuildScriptRelative -and $BuildScriptRelative.Trim()) {
    $buildScript = Join-Path $repoRoot $BuildScriptRelative.Trim()
  } else {
    foreach ($cand in @(
        'scripts\build-plugin-zip.ps1',
        'scripts\build-zip.ps1',
        'scripts\build-erp-connector-zip.ps1',
        'scripts\build-chameleon-plugin-updates-zip.ps1',
        'scripts\build-kore-sim-manager-zip.ps1',
        'scripts\build-wccm-hub-zip.ps1',
        'scripts\build-wccm-satellite-zip.ps1',
        'scripts\build-mask-login-zip.ps1',
        'scripts\build-hello-update-test-zip.ps1'
      )) {
      $p = Join-Path $repoRoot $cand
      if (Test-Path -LiteralPath $p) { $buildScript = $p; break }
    }
  }
  if (-not $buildScript -or -not (Test-Path -LiteralPath $buildScript)) {
    throw "Build script not found. Pass -BuildScriptRelative e.g. scripts\build-plugin-zip.ps1"
  }
  Write-Host "BUILD: $buildScript"
  & $buildScript
} finally {
  Pop-Location
}

Write-Host "PUBLISH-LIVE-PLUGINS: $repoRoot"
& $publishScript -RepoRoot $repoRoot

if ($GitCommit) {
  $msg = if ($CommitMessage.Trim()) { $CommitMessage.Trim() } else { 'chore: plugin release (plugins-live + version)' }
  if (Test-Path -LiteralPath (Join-Path $wpRoot '.git')) {
    Push-Location -LiteralPath $wpRoot
    try {
      git add -- 'plugins-live/index.json'
      foreach ($p in $gitPathsWp) {
        git add -- $p 2>$null
      }
      $porcelain = git status --porcelain
      if ($porcelain) {
        git commit -m $msg
        Write-Host "GIT (wordpress_plugins): committed"
      } else {
        Write-Host 'GIT (wordpress_plugins): nothing to commit'
      }
    } finally {
      Pop-Location
    }
  } else {
    Write-Host 'GIT: no .git at wordpress_plugins root; skipped wp-root commit.'
  }

  if ($BumpPatch -and (Test-Path -LiteralPath (Join-Path $repoRoot '.git')) -and $pluginRelGitAdds.Count -gt 0) {
    Push-Location -LiteralPath $repoRoot
    try {
      foreach ($r in $pluginRelGitAdds) {
        git add -- $r
      }
      $porcelain = git status --porcelain
      if ($porcelain) {
        git commit -m $msg
        Write-Host "GIT (plugin repo): committed ($($pluginRelGitAdds.Count) path(s))"
      } else {
        Write-Host 'GIT (plugin repo): nothing to commit'
      }
    } finally {
      Pop-Location
    }
  }
}

Write-Host 'Done.'
