<#
.SYNOPSIS
  Upload everything under plugins-live/ (all *.zip + index.json) to the Chameleon plugin repo server over SFTP.

.DESCRIPTION
  Loads scripts/live-plugins-ftp.env when that file exists, then runs sync-live-plugins-repo-ftp.ps1.
  Use this after a local publish if you skipped SFTP, or to re-push the current folder without rebuilding.

.EXAMPLE
  From wordpress_plugins root:
    .\scripts\push-plugins-live-to-server.ps1
#>
$ErrorActionPreference = 'Stop'

$wpRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$ftpEnvFile = Join-Path $wpRoot 'scripts\live-plugins-ftp.env'
$ftpEnvLoader = Join-Path $wpRoot 'scripts\load-live-plugins-ftp-env.ps1'
if ((Test-Path -LiteralPath $ftpEnvFile) -and (Test-Path -LiteralPath $ftpEnvLoader)) {
  . $ftpEnvLoader
}

$sync = Join-Path $wpRoot 'scripts\sync-live-plugins-repo-ftp.ps1'
$liveDir = Join-Path $wpRoot 'plugins-live'
& $sync -LivePluginsDir $liveDir
