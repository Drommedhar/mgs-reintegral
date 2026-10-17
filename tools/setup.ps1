[CmdletBinding()]
param([switch]$Install)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Run this script in PowerShell 7 (pwsh).' }
if ($Install) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Install Microsoft App Installer to use winget, or install the documented prerequisites manually.' }
    $packages = @(
        @{ Id = 'Git.Git'; Extra = @() },
        @{ Id = 'Python.Python.3.12'; Extra = @() },
        @{ Id = 'Microsoft.VisualStudio.2022.BuildTools'; Extra = @('--override', '--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --add Microsoft.VisualStudio.Component.VC.Llvm.Clang') }
    )
    foreach ($package in $packages) {
        $options = @('install', '--id', $package.Id, '--exact', '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements') + $package.Extra
        & winget @options
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget failed for $($package.Id) (exit $LASTEXITCODE)." }
    }
    Write-Host 'Open a new PowerShell 7 terminal and run ./tools/setup.ps1 to verify and bootstrap.'
    return
}
foreach ($command in @('git', 'python')) {
    if (-not (Get-Command $command -CommandType Application -ErrorAction SilentlyContinue)) { throw "Missing $command. Run ./tools/setup.ps1 -Install or follow README prerequisites." }
}
& python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'
if ($LASTEXITCODE -ne 0) { throw 'Python 3.11 or newer is required.' }
$null = & (Join-Path $PSScriptRoot 'toolchain.ps1')
& (Join-Path $PSScriptRoot 'bootstrap.ps1')
Write-Host 'Ready. Build both renderer choices with ./tools/build.ps1 -Configuration RelWithDebInfo -BuildDirectory build/windows-x86-godot -RendererModule renderers/godot/native -Version 0.3.0, then open build/windows-x86-godot/RE-INTEGRAL.exe.'
