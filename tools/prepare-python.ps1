$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'sdk-paths.ps1')
Get-MgsPython (Split-Path $PSScriptRoot -Parent) | Out-Null
