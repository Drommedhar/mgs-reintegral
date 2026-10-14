[CmdletBinding()]
param(
    [string]$Archive = 'build/alpha-0.2-published/reintegral-0.2.0-alpha.1-mpl-source.zip',
    [string]$CommonBuild = 'build/windows-x86-relwithdebinfo',
    [string]$OutputDirectory = 'build/legacy-parity-reference'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$archivePath = [IO.Path]::GetFullPath($Archive, $repo)
$output = [IO.Path]::GetFullPath($OutputDirectory, $repo)
$expectedHash = 'c46959c2296b89e7dc9de4fc0feb8017d1f977b05d0b468bb0ce37cf036e49fd'
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Reference must be the preserved 0.2.0-alpha.1 MPL source archive.'
}
$source = Join-Path $output 'src'
New-Item -ItemType Directory -Path $source -Force | Out-Null
$archiveFile = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    foreach ($entry in $archiveFile.Entries) {
        if (-not $entry.FullName.StartsWith('platform/') -or $entry.FullName.EndsWith('/')) { continue }
        $destination = [IO.Path]::GetFullPath($entry.FullName, $source)
        if (-not $destination.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Reference archive path escapes its source directory.'
        }
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
    }
} finally { $archiveFile.Dispose() }
Get-ChildItem (Join-Path $repo 'vendor/psyz/psyz/src') -Filter '*.h' | Copy-Item -Destination $source
$native = Join-Path ([IO.Path]::GetFullPath($CommonBuild, $repo)) 'vendor/psyz/psyz'
$libraries = @("$native/psyz.lib", "$native/sdl/SDL3-static.lib")
foreach ($library in $libraries) {
    if (-not (Test-Path -LiteralPath $library)) { throw "Build the native Psyz target first: $library" }
}
$libraries += @('-lkernel32', '-luser32', '-lgdi32', '-lwinmm', '-limm32', '-lole32', '-loleaut32', '-lversion', '-luuid', '-ladvapi32', '-lsetupapi', '-lshell32', '-ldinput8', '-lws2_32', '-lwinspool', '-lcomdlg32', '-loldnames')
$includes = @("-I$repo/vendor/psyz/psyz/include", "-I$repo/vendor/psyz/external/SDL/include", "-I$repo/vendor/psyz/external/SDL/src/video/khronos")
$backend = '-DMGS_LEGACY_BACKEND="' + (Join-Path $source 'platform/sdl3_gpu.c').Replace('\','/') + '"'
$toolchain = & (Join-Path $PSScriptRoot 'toolchain.ps1')
& $toolchain.Clang --target=i686-pc-windows-msvc -O2 -D__psyz -DMGS_LEGACY_GPU_CAPTURE $backend `
    -D_CRT_SECURE_NO_WARNINGS -D_MT -Xclang --dependent-lib=libcmt @includes `
    (Join-Path $repo 'tests/mgs_legacy_parity_fixture.c') (Join-Path $repo 'tests/legacy_gpu_capture.c') `
    (Join-Path $source 'platform/sdl3_software.c') @libraries -fuse-ld=lld-link -o (Join-Path $output 'fixture.exe')
if ($LASTEXITCODE -ne 0) { throw 'Reference backend build failed.' }
[ordered]@{
    archive_sha256 = $expectedHash
    backend_sha256 = (Get-FileHash (Join-Path $source 'platform/sdl3_gpu.c')).Hash.ToLowerInvariant()
    fixture_sha256 = (Get-FileHash (Join-Path $output 'fixture.exe')).Hash.ToLowerInvariant()
    common_psyz_sha256 = (Get-FileHash $libraries[0]).Hash.ToLowerInvariant()
    common_sdl_sha256 = (Get-FileHash $libraries[1]).Hash.ToLowerInvariant()
} | ConvertTo-Json | Set-Content (Join-Path $output 'reference.json')
Write-Host "Built archived Legacy graphics backend with current common Psyz/SDL: $output"
