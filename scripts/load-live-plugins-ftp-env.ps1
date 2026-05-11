<#
.SYNOPSIS
  Loads scripts/live-plugins-ftp.env into the current process (for publish + SFTP sync).

.DESCRIPTION
  Dot-source this file so variables apply to your session:

    . .\scripts\load-live-plugins-ftp-env.ps1

  Copy live-plugins-ftp.env.example to live-plugins-ftp.env first (gitignored).
#>
$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot 'live-plugins-ftp.env'
if (-not (Test-Path -LiteralPath $envFile)) {
  Write-Error "Missing $envFile - copy scripts\live-plugins-ftp.env.example to scripts\live-plugins-ftp.env and edit."
}
Get-Content -LiteralPath $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -match '^\s*#' -or $line -eq '') { return }
  $parts = $line -split '=', 2
  if ($parts.Count -ne 2) { return }
  $name = $parts[0].Trim()
  $value = $parts[1].Trim()
  if ($name) {
    Set-Item -Path "Env:$name" -Value $value
  }
}
Write-Host ('Loaded FTP env from: ' + $envFile)
