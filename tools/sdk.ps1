[CmdletBinding()]
param(
    [ValidateSet('editor', 'prepare', 'play')][string]$Action = 'editor',
    [string]$DiscDirectory,
    [string]$DiscOne,
    [string]$DiscTwo,
    [string[]]$Discs = @('1', '2'),
    [string[]]$Stages
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$Discs = @($Discs -split ',')
if (@($Discs | Where-Object { $_ -notin @('1', '2') }).Count) { throw 'Discs must be 1, 2 or 1,2.' }
if ($Stages) { $Stages = @($Stages -split ',') }
switch ($Action) {
    'prepare' {
        $cues = @()
        if ($DiscOne -or $DiscTwo) {
            if (-not $DiscOne -or -not $DiscTwo) { throw 'Provide both -DiscOne and -DiscTwo CUE paths.' }
            $cues = @((Resolve-Path -LiteralPath $DiscOne).Path, (Resolve-Path -LiteralPath $DiscTwo).Path)
            $DiscDirectory = Split-Path $cues[0] -Parent
        }
        if (-not $DiscDirectory -and -not (Test-Path -LiteralPath (Join-Path $root '.local/content/manifest.json'))) {
            Add-Type -AssemblyName System.Windows.Forms
            $picker = [Windows.Forms.OpenFileDialog]::new()
            try {
                $picker.Title = 'Select Integral campaign discs 1 and 2 (VR optional)'
                $picker.Filter = 'Disc CUE files (*.cue)|*.cue'
                $picker.Multiselect = $true
                if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }
                $cues = $picker.FileNames
                $DiscDirectory = Split-Path $cues[0] -Parent
            }
            finally { $picker.Dispose() }
        }
        foreach ($disc in $Discs) {
            $arguments = @{Disc = $disc; DiscDirectory = $DiscDirectory; CueFiles = $cues}
            if ($Stages) { $arguments.Stages = $Stages }
            & (Join-Path $PSScriptRoot 'prepare-godot-content.ps1') @arguments
        }
    }
    'editor' {
        & (Join-Path $PSScriptRoot 'prepare-godot.ps1')
        Start-Process -FilePath (Join-Path $root '.tools/godot-4.8-dev7/Godot_v4.8-dev7_win64.exe') `
            -ArgumentList @('--editor', '--path', "`"$(Join-Path $root 'renderers/godot/project')`"") -WindowStyle Hidden
    }
    'play' { Start-Process -FilePath (Join-Path $root 'RE-INTEGRAL.exe') -WorkingDirectory $root -WindowStyle Hidden }
}
