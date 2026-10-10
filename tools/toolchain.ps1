[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PortableTool {
    param(
        [string]$Directory,
        [string]$Executable,
        [string]$Url,
        [string]$Sha256
    )

    $toolPath = Join-Path $Directory $Executable
    if (Test-Path -LiteralPath $toolPath -PathType Leaf) {
        return $toolPath
    }

    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $archive = Join-Path $Directory 'download.zip'
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $archive
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $Sha256) {
        throw "Checksum mismatch for $archive."
    }

    Expand-Archive -LiteralPath $archive -DestinationPath $Directory -Force
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) {
        throw "The tool archive did not provide $toolPath."
    }
    return $toolPath
}

function Initialize-ClangEnvironment {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw 'Visual Studio 2022 with C++ desktop tools and Clang is required.'
    }

    $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $installation) {
        throw 'No Visual Studio installation with C++ desktop tools was found.'
    }
    $clang = Join-Path $installation 'VC/Tools/Llvm/x64/bin/clang.exe'
    if (-not (Test-Path -LiteralPath $clang -PathType Leaf)) {
        throw "Install the C++ Clang tools component in Visual Studio: $installation"
    }

    Import-Module (Join-Path $installation 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $installation -DevCmdArguments '-arch=x86 -host_arch=amd64' -SkipAutomaticLocation | Out-Null
    return $clang
}

$clang = Initialize-ClangEnvironment
$toolsDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) '.tools'
$cmake = Get-PortableTool -Directory (Join-Path $toolsDirectory 'cmake-3.31.8') `
    -Executable 'cmake-3.31.8-windows-x86_64/bin/cmake.exe' `
    -Url 'https://github.com/Kitware/CMake/releases/download/v3.31.8/cmake-3.31.8-windows-x86_64.zip' `
    -Sha256 '81aa9964dbabd71fe02e7ec50472fd3ad56138c49944515ece9001efbff8d719'
$ninja = Get-PortableTool -Directory (Join-Path $toolsDirectory 'ninja-1.13.1') `
    -Executable 'ninja.exe' `
    -Url 'https://github.com/ninja-build/ninja/releases/download/v1.13.1/ninja-win.zip' `
    -Sha256 '26a40fa8595694dec2fad4911e62d29e10525d2133c9a4230b66397774ae25bf'

[pscustomobject]@{
    CMake = $cmake
    Ninja = $ninja
    Clang = $clang
    ClangCxx = Join-Path (Split-Path $clang -Parent) 'clang++.exe'
}
