<#
.SYNOPSIS
  Move plugin zips from dist/<slug>-<ver>.zip into dist/<slug>/<slug>-<ver>.zip.
.EXAMPLE
  .\scripts\fix-misplaced-plugin-zips.ps1
  .\scripts\fix-misplaced-plugin-zips.ps1 -WhatIf
#>
param([switch]$WhatIf)

$ErrorActionPreference = 'Stop'
$wpRoot = $PSScriptRoot | Split-Path -Parent
$pluginsDev = Join-Path $wpRoot 'plugins-dev'
$moved = 0

Get-ChildItem -LiteralPath $pluginsDev -Recurse -Directory -Filter 'dist' -ErrorAction SilentlyContinue |
    ForEach-Object {
        $distPath = $_.FullName
        Get-ChildItem -LiteralPath $distPath -File -Filter '*.zip' -ErrorAction SilentlyContinue |
            ForEach-Object {
                $zip = $_
                $m = [regex]::Match($zip.Name, '^(?<slug>.+)-(?<ver>\d+\.\d+\.\d+).*\.zip$')
                if (-not $m.Success) {
                    Write-Warning "Skip (unparsed name): $($zip.FullName)"
                    return
                }
                $slug = $m.Groups['slug'].Value
                $destDir = Join-Path $distPath $slug
                $dest = Join-Path $destDir $zip.Name
                if ($zip.FullName -eq $dest) { return }
                Write-Host "MOVE $($zip.FullName) -> $dest"
                if (-not $WhatIf) {
                    if (-not (Test-Path -LiteralPath $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }
                    Move-Item -LiteralPath $zip.FullName -Destination $dest -Force
                }
                $moved++
            }
    }

Write-Host "Done. Moved $moved zip(s)."
