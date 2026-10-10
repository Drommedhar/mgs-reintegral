[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release', 'RelWithDebInfo')]
    [string]$Configuration = 'Debug',
    [string]$Target,
    [string]$RendererModule,
    [string]$BuildDirectory,
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[a-z0-9.]+)?$')]
    [string]$Version = '0.1.0-alpha.1',
    [switch]$ConfigureOnly,
    [ValidateRange(1, 128)]
    [int]$Parallel = [Environment]::ProcessorCount
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$python = Join-Path $projectDirectory '.venv/Scripts/python.exe'
$sources = Get-Content -LiteralPath (Join-Path $projectDirectory 'sources.lock.json') -Raw | ConvertFrom-Json
$missingSources = @($sources.repositories | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $projectDirectory "$($_.path)/.git"))
})
$requirementsStamp = Join-Path $projectDirectory '.venv/requirements.sha256'
$requirementsHash = (Get-FileHash -LiteralPath (Join-Path $projectDirectory 'requirements.txt')).Hash
$requirementsCurrent = (Test-Path -LiteralPath $requirementsStamp) -and
    (Get-Content -LiteralPath $requirementsStamp -Raw).Trim() -eq $requirementsHash
if (-not (Test-Path -LiteralPath $python) -or $missingSources.Count -gt 0 -or -not $requirementsCurrent) {
    & (Join-Path $PSScriptRoot 'bootstrap.ps1')
}
$toolchain = & (Join-Path $PSScriptRoot 'toolchain.ps1')
if (-not $BuildDirectory) {
    $BuildDirectory = "build/windows-x86-$($Configuration.ToLowerInvariant())"
}
$buildDirectory = [IO.Path]::GetFullPath($BuildDirectory, $projectDirectory)
$commit = & git -C $projectDirectory rev-parse --short=12 HEAD
if ($LASTEXITCODE -ne 0) { throw 'Build requires a Git checkout.' }
if ($RendererModule) {
    $RendererModule = (Resolve-Path -LiteralPath $RendererModule).Path
}

$configureArguments = @(
    '-S', $projectDirectory,
    '-B', $buildDirectory,
    '-G', 'Ninja',
    "-DPython3_EXECUTABLE=$python",
    "-DCMAKE_MAKE_PROGRAM=$($toolchain.Ninja)",
    "-DCMAKE_C_COMPILER=$($toolchain.Clang)",
    '-DCMAKE_C_COMPILER_TARGET=i686-pc-windows-msvc',
    "-DCMAKE_CXX_COMPILER=$($toolchain.ClangCxx)",
    '-DCMAKE_CXX_COMPILER_TARGET=i686-pc-windows-msvc',
    "-DCMAKE_BUILD_TYPE=$Configuration",
    "-DMGS_RELEASE_VERSION=$Version",
    "-DMGS_BUILD_COMMIT=$commit",
    "-DMGS_RENDERER_MODULE=$RendererModule"
)
& $toolchain.CMake @configureArguments
if ($LASTEXITCODE -ne 0) {
    throw "CMake configuration failed with exit code $LASTEXITCODE."
}
if ($ConfigureOnly) {
    return
}

$buildArguments = @('--build', $buildDirectory, '--parallel', $Parallel)
if ($Target) {
    $buildArguments += @('--target', $Target)
}
& $toolchain.CMake @buildArguments
if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE."
}
