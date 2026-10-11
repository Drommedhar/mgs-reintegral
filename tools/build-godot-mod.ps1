[CmdletBinding()]
param([ValidateRange(1, 64)][int]$Jobs = 2)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$lock = Get-Content (Join-Path $projectDirectory 'sources.lock.json') -Raw | ConvertFrom-Json
$source = Join-Path $projectDirectory $lock.godotCpp.path
if (-not (Test-Path -LiteralPath $source)) {
    & git clone --no-checkout --filter=blob:none --no-tags $lock.godotCpp.url $source
    if ($LASTEXITCODE -ne 0) { throw 'Cannot clone pinned godot-cpp.' }
    & git -C $source fetch --depth=1 origin $lock.godotCpp.commit
    if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch pinned godot-cpp.' }
    & git -C $source checkout --detach $lock.godotCpp.commit
    if ($LASTEXITCODE -ne 0) { throw 'Cannot check out pinned godot-cpp.' }
}
$revision = & git -C $source rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision -ne $lock.godotCpp.commit) { throw 'godot-cpp differs from sources.lock.json.' }
$changes = & git -C $source status --porcelain
if ($LASTEXITCODE -ne 0 -or $changes) { throw 'godot-cpp has local changes; export a patch before building.' }
$toolchain = & (Join-Path $PSScriptRoot 'toolchain.ps1')
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
Enter-VsDevShell -VsInstallPath $installation -DevCmdArguments '-arch=amd64 -host_arch=amd64' -SkipAutomaticLocation | Out-Null
$buildDirectory = Join-Path $projectDirectory 'build/godot-sdk-x64'
if (-not (Test-Path -LiteralPath (Join-Path $buildDirectory 'CMakeCache.txt'))) {
    & $toolchain.CMake -S (Join-Path $projectDirectory 'renderers/godot/sdk') -B $buildDirectory -G Ninja `
        "-DCMAKE_MAKE_PROGRAM=$($toolchain.Ninja)" '-DCMAKE_CXX_COMPILER=cl' '-DCMAKE_BUILD_TYPE=Release' `
        "-DPython3_EXECUTABLE=$(Join-Path $projectDirectory '.venv/Scripts/python.exe')"
    if ($LASTEXITCODE -ne 0) { throw 'Godot mod configuration failed.' }
}
& $toolchain.CMake --build $buildDirectory --target mgs_visual_mod --parallel $Jobs
if ($LASTEXITCODE -ne 0) { throw 'Godot mod build failed.' }
Write-Host "[godot] Native visual mod: $buildDirectory/mod/mod.json"
