<#
.SYNOPSIS
  Strip UTF-8 BOM and remove declare(strict_types=1) from plugin PHP sources.

  Cloudways/Linux fatals when a BOM precedes declare(strict_types) in any loaded file.
  Run on plugin source before commit; build-plugin-install-zip.ps1 also strips BOM at zip time.

.PARAMETER PluginDir
  Root folder containing plugin PHP (e.g. .../plugin or .../woo-region-stock-levels).

.EXAMPLE
  .\scripts\harden-plugin-php.ps1 -PluginDir "plugins-dev\chameleon\other\erp-connector\plugin"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $PluginDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PluginDir)) {
    throw "PluginDir not found: $PluginDir"
}

$pluginFull = (Resolve-Path -LiteralPath $PluginDir).Path
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$strictPattern = '(?m)^\s*declare\s*\(\s*strict_types\s*=\s*1\s*\)\s*;\s*\r?\n?'

$bomCount = 0
$strictCount = 0

Get-ChildItem -LiteralPath $pluginFull -Recurse -Filter '*.php' -File | ForEach-Object {
    $path = $_.FullName
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hadBom = $false
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
        $hadBom = $true
        $bomCount++
        Write-Warning "Stripped UTF-8 BOM: $path"
    }

    $content = $utf8NoBom.GetString($bytes)
    $original = $content

    if ($content -match $strictPattern) {
        $content = [regex]::Replace($content, $strictPattern, '')
        $strictCount++
        Write-Host "Removed strict_types: $path"
    }

    if ($hadBom -or ($content -ne $original)) {
        [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
    }
}

Write-Host "Hardened $pluginFull (BOM stripped: $bomCount, strict_types removed: $strictCount files)"
