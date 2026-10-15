param(
    [ValidateSet('editor', 'prepare', 'play')][string]$Action = 'editor',
    [switch]$ToolsOnly
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'download-tool.ps1')
try {
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'The Godot release requires 64-bit Windows.' }
    $powershell = Install-MgsTool $root 'powershell'
    Install-MgsTool $root 'godot' | Out-Null
    if ($Action -eq 'prepare') { Install-MgsTool $root 'python' | Out-Null }
    if ($ToolsOnly) { exit 0 }
    & (Join-Path $powershell 'pwsh.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'sdk.ps1') -Action $Action @args
    exit $LASTEXITCODE
}
catch {
    Write-Error "Preparation failed: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}
