<#
.SYNOPSIS
  Upload live-plugins zips and index.json to the public repo over SFTP (SSH).

.DESCRIPTION
  Uses the Posh-SSH module (SSH.NET). FTP/FTPS is not supported here; Cloudways and many hosts expose SFTP on port 22.

  Install once (current user):
    Install-Module -Name Posh-SSH -Scope CurrentUser -Force

  Environment variables (set in scripts/live-plugins-ftp.env or the process):

  Preferred (SFTP):
    CHAMELEON_LIVE_PLUGINS_SFTP_HOST
    CHAMELEON_LIVE_PLUGINS_SFTP_USER
    CHAMELEON_LIVE_PLUGINS_SFTP_PASSWORD   (omit if using key only)
    CHAMELEON_LIVE_PLUGINS_SFTP_REMOTE_DIR  absolute path on server, e.g. /applications/.../plugin-repo

  Backward-compatible aliases (same values as before):
    CHAMELEON_LIVE_PLUGINS_FTP_HOST, _FTP_USER, _FTP_PASSWORD, _FTP_REMOTE_DIR

  Optional:
    CHAMELEON_LIVE_PLUGINS_SFTP_PORT              default 22
    CHAMELEON_LIVE_PLUGINS_SFTP_KEY_FILE        OpenSSH private key path (password = key passphrase if set)
    CHAMELEON_LIVE_PLUGINS_SFTP_ACCEPT_HOST_KEY  set to 1 to auto-accept new host key (first connect)
    CHAMELEON_LIVE_PLUGINS_SFTP_NO_STRICT_HOSTKEY set to 1 for -Force on session (insecure; dev only)

.EXAMPLE
  . .\scripts\load-live-plugins-ftp-env.ps1
  .\scripts\sync-live-plugins-repo-ftp.ps1 -SmokeTest
#>
param(
  [Parameter(Mandatory = $false)]
  [string]$LivePluginsDir = $null,

  [Parameter(Mandatory = $false)]
  [switch]$SmokeTest
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

function Get-EnvFirst([string]$primary, [string]$fallback) {
  $a = Get-Item -Path "Env:$primary" -ErrorAction SilentlyContinue
  if ($a -and $a.Value.Trim()) { return $a.Value.Trim() }
  $b = Get-Item -Path "Env:$fallback" -ErrorAction SilentlyContinue
  if ($b -and $b.Value.Trim()) { return $b.Value.Trim() }
  return ''
}

function Normalize-RemoteDir([string]$dir) {
  $d = $dir.Trim().Replace('\', '/')
  while ($d.Length -gt 1 -and $d.EndsWith('/')) { $d = $d.Substring(0, $d.Length - 1) }
  if (-not $d.StartsWith('/')) { $d = '/' + $d.TrimStart('/') }
  return $d
}

# --- main ---

if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
  throw @"
SFTP requires the Posh-SSH module. Install (once):

  Install-Module -Name Posh-SSH -Scope CurrentUser -Force

Then re-run this script.
"@
}
Import-Module Posh-SSH -ErrorAction Stop

$sftpHost = Get-EnvFirst 'CHAMELEON_LIVE_PLUGINS_SFTP_HOST' 'CHAMELEON_LIVE_PLUGINS_FTP_HOST'
if (-not $sftpHost) {
  Write-Host 'SFTP sync skipped: CHAMELEON_LIVE_PLUGINS_SFTP_HOST (or CHAMELEON_LIVE_PLUGINS_FTP_HOST) is not set.'
  exit 0
}

$user = Get-EnvFirst 'CHAMELEON_LIVE_PLUGINS_SFTP_USER' 'CHAMELEON_LIVE_PLUGINS_FTP_USER'
$passPlain = Get-EnvFirst 'CHAMELEON_LIVE_PLUGINS_SFTP_PASSWORD' 'CHAMELEON_LIVE_PLUGINS_FTP_PASSWORD'
$remoteDir = Get-EnvFirst 'CHAMELEON_LIVE_PLUGINS_SFTP_REMOTE_DIR' 'CHAMELEON_LIVE_PLUGINS_FTP_REMOTE_DIR'

if (-not $user) { throw 'CHAMELEON_LIVE_PLUGINS_SFTP_USER (or _FTP_USER) is required when host is set.' }
if (-not $remoteDir) {
  throw 'CHAMELEON_LIVE_PLUGINS_SFTP_REMOTE_DIR (or _FTP_REMOTE_DIR) is required, e.g. /applications/.../plugin-repo'
}

$keyFile = ''
if ($env:CHAMELEON_LIVE_PLUGINS_SFTP_KEY_FILE -and $env:CHAMELEON_LIVE_PLUGINS_SFTP_KEY_FILE.Trim()) {
  $keyFile = $env:CHAMELEON_LIVE_PLUGINS_SFTP_KEY_FILE.Trim()
}

if (-not $keyFile -and [string]::IsNullOrEmpty($passPlain)) {
  throw 'Provide CHAMELEON_LIVE_PLUGINS_SFTP_PASSWORD (or _FTP_PASSWORD) and/or CHAMELEON_LIVE_PLUGINS_SFTP_KEY_FILE.'
}

$port = 22
if ($env:CHAMELEON_LIVE_PLUGINS_SFTP_PORT -and $env:CHAMELEON_LIVE_PLUGINS_SFTP_PORT.Trim()) {
  $port = [int]$env:CHAMELEON_LIVE_PLUGINS_SFTP_PORT.Trim()
}

$emptySec = New-Object System.Security.SecureString
if (-not [string]::IsNullOrEmpty($passPlain)) {
  $sec = ConvertTo-SecureString -String $passPlain -AsPlainText -Force
} else {
  $sec = $emptySec
}
$cred = New-Object System.Management.Automation.PSCredential ($user, $sec)

$start = if ($LivePluginsDir) { $LivePluginsDir } else { (Get-Location).Path }
$wpRoot = Find-WordpressPluginsRoot -start $start
if (-not $LivePluginsDir) {
  if ($wpRoot) {
    $LivePluginsDir = Join-Path $wpRoot 'live-plugins'
  } else {
    $LivePluginsDir = $start
  }
}

if (-not (Test-Path -LiteralPath $LivePluginsDir)) {
  throw "Live plugins directory not found: $LivePluginsDir"
}

$remoteNorm = Normalize-RemoteDir $remoteDir

$connTimeout = 120
if ($env:CHAMELEON_LIVE_PLUGINS_SFTP_CONNECTION_TIMEOUT_SEC) {
  $tout = 0
  if ([int]::TryParse($env:CHAMELEON_LIVE_PLUGINS_SFTP_CONNECTION_TIMEOUT_SEC.Trim(), [ref]$tout) -and $tout -gt 0) {
    $connTimeout = $tout
  }
}

$sessionParams = @{
  ComputerName = $sftpHost
  Credential = $cred
  Port = $port
  ConnectionTimeout = $connTimeout
  ErrorAction = 'Stop'
}
if ($keyFile) {
  if (-not (Test-Path -LiteralPath $keyFile)) { throw "SSH key file not found: $keyFile" }
  $sessionParams['KeyFile'] = $keyFile
}
if ($env:CHAMELEON_LIVE_PLUGINS_SFTP_ACCEPT_HOST_KEY -eq '1') {
  $sessionParams['AcceptKey'] = $true
}
if ($env:CHAMELEON_LIVE_PLUGINS_SFTP_NO_STRICT_HOSTKEY -eq '1') {
  $sessionParams['Force'] = $true
}

Write-Host "SFTP: connecting to $sftpHost`:$port ..."
$session = New-SFTPSession @sessionParams
try {
  $sid = $session.SessionId

  if (-not (Test-SFTPPath -SessionId $sid -Path $remoteNorm)) {
    Write-Host "SFTP: creating remote directory $remoteNorm ..."
    New-SFTPItem -SessionId $sid -Path $remoteNorm -ItemType Directory -Recurse -ErrorAction Stop | Out-Null
  }

  if (-not $SmokeTest) {
    $zips = Get-ChildItem -LiteralPath $LivePluginsDir -File -Filter *.zip -ErrorAction SilentlyContinue
    foreach ($z in $zips) {
      Write-Host "SFTP: uploading $($z.Name) ..."
      Set-SFTPItem -SessionId $sid -Path $z.FullName -Destination $remoteNorm -Force -ErrorAction Stop
    }
  } else {
    Write-Host 'SmokeTest: skipping zip uploads (index.json only).'
  }

  $idx = Join-Path $LivePluginsDir 'index.json'
  if (Test-Path -LiteralPath $idx) {
    Write-Host 'SFTP: uploading index.json ...'
    Set-SFTPItem -SessionId $sid -Path $idx -Destination $remoteNorm -Force -ErrorAction Stop
  } else {
    Write-Host 'WARN: index.json missing locally.'
  }

  Write-Host 'SFTP sync finished.'
} finally {
  $null = Remove-SFTPSession -SessionId @($session.SessionId) -ErrorAction SilentlyContinue
}
