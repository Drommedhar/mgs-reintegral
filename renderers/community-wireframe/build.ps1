[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
$output = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $output) { throw "Choose a new output file: $output" }
& $compiler /nologo /target:exe /platform:x86 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Web.Extensions.dll `
    "/out:$output" (Join-Path $PSScriptRoot 'Program.cs') (Join-Path $PSScriptRoot 'Surface.cs') (Join-Path $PSScriptRoot 'Wire.cs')
if ($LASTEXITCODE -ne 0) { throw 'Community renderer compilation failed.' }
