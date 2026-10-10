[CmdletBinding()]
param([switch]$Check)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent

function Invoke-CheckedGit {
    param([string[]]$GitArguments)

    $output = & git @GitArguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArguments -join ' ') failed:`n$($output -join "`n")"
    }
    return $output
}

function Sync-Repository {
    param($Repository)

    $path = Join-Path $projectDirectory $Repository.path
    $newCheckout = $false
    if (-not (Test-Path -LiteralPath (Join-Path $path '.git'))) {
        if ($Check) {
            throw "Missing source checkout: $path"
        }
        Invoke-CheckedGit @('clone', '--filter=blob:none', '--no-checkout', '--no-tags', $Repository.url, $path) | Out-Host
        $newCheckout = $true
    }

    $checkoutRoot = Invoke-CheckedGit @('-C', $path, 'rev-parse', '--show-toplevel')
    if ([IO.Path]::GetFullPath($checkoutRoot) -ne [IO.Path]::GetFullPath($path)) {
        throw "Expected a separate repository at $path."
    }
    $head = Invoke-CheckedGit @('-C', $path, 'rev-parse', '--verify', 'HEAD')
    if ($head -eq $Repository.commit -and -not $newCheckout) {
        Write-Host "$($Repository.path): pinned at $head"
        return
    }
    if ($Check) {
        throw "$($Repository.path) is at $head, expected $($Repository.commit)."
    }
    $changes = Invoke-CheckedGit @('-C', $path, 'status', '--porcelain')
    if ($changes -and -not $newCheckout) {
        throw "$($Repository.path) has local changes; cannot change its revision."
    }
    Invoke-CheckedGit @('-C', $path, 'fetch', '--depth=1', 'origin', $Repository.commit) | Out-Host
    Invoke-CheckedGit @('-C', $path, 'checkout', '--detach', $Repository.commit) | Out-Host
}

function Sync-Patches {
    param($Repository)

    if ($Repository.patches.Count -eq 0) {
        return
    }
    $python = Join-Path $projectDirectory '.venv/Scripts/python.exe'
    if (-not (Test-Path -LiteralPath $python)) {
        $python = (Get-Command python -CommandType Application | Select-Object -First 1).Source
    }
    $patchArguments = @(
        (Join-Path $PSScriptRoot 'patch_stack.py'),
        '--lock', (Join-Path $projectDirectory 'sources.lock.json'),
        '--repository', $Repository.path
    )
    if ($Check) {
        $patchArguments += '--check'
    }
    & $python @patchArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Source patch stack validation failed for $($Repository.path); local changes were preserved."
    }
}

function Sync-Python {
    $venv = Join-Path $projectDirectory '.venv'
    $python = Join-Path $venv 'Scripts/python.exe'
    $requirements = Join-Path $projectDirectory 'requirements.txt'
    $stamp = Join-Path $venv 'requirements.sha256'
    $hash = (Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash
    if ((Test-Path -LiteralPath $python) -and (Test-Path -LiteralPath $stamp)) {
        if ((Get-Content -LiteralPath $stamp -Raw).Trim() -eq $hash) {
            Write-Host 'Python: local requirements are installed'
            return
        }
    }
    if ($Check) {
        throw 'The local Python environment needs provisioning; run tools/bootstrap.ps1.'
    }
    if (-not (Test-Path -LiteralPath $python)) {
        $basePython = (Get-Command python -CommandType Application | Select-Object -First 1).Source
        & $basePython -m venv $venv
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the local Python environment.'
        }
    }
    & $python -m pip install --disable-pip-version-check -r $requirements
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not install the local Python build requirements.'
    }
    Set-Content -LiteralPath $stamp -Value $hash -Encoding ascii
}

$lock = Get-Content -LiteralPath (Join-Path $projectDirectory 'sources.lock.json') -Raw | ConvertFrom-Json
if ($lock.version -ne 1) {
    throw "Unsupported source lock format: $($lock.version)"
}
foreach ($repository in $lock.repositories) {
    Sync-Repository $repository
    Sync-Patches $repository
}
Sync-Python
