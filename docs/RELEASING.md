# Preparing the Godot game and SDK release

The 0.3 workflow produces separate game and SDK ZIPs from the same optimized
native build. The game package omits the editor plugin, examples and extension
development sources. `sdk.json` identifies the package kind, version, native
build, source revision and whether the source worktree was dirty.

## Local preparation

Use the normal source build prerequisites. Keep existing mods, prepared data
and settings in place. Choose a new evidence directory for each candidate.

```powershell
./tools/bootstrap.ps1 -Check
./tools/build.ps1 -Configuration RelWithDebInfo -RendererModule renderers/godot/native -BuildDirectory build/windows-x86-godot-relwithdebinfo -Version 0.3.0-alpha.1
./tools/prepare-godot-release.ps1 -Version 0.3.0-alpha.1 -BuildDirectory build/windows-x86-godot-relwithdebinfo -OutputDirectory build/evidence/release-candidate
./.venv/Scripts/python.exe tools/test_godot_release.py --sdk build/evidence/release-candidate/reintegral-sdk-0.3.0-alpha.1-windows-x86.zip --game build/evidence/release-candidate/reintegral-0.3.0-alpha.1-windows-x86.zip --output "build/evidence/release-smoke"
```

The preparation script runs package/bootstrap tests, builds both archives,
checks each extracted inventory and writes matching symbol/checksum files.
The smoke check downloads tools into a relocated SDK, imports both projects
headlessly and exercises Open ZIP and Save As, including Python installation
and repair. It uses authored scenes and a synthetic provenance catalog without
retail data; normal users still prepare their discs for provenance checks.
Godot's dummy renderer reports a null texture while saving an editor thumbnail;
the smoke check permits that exact diagnostic and rejects other errors.
Run relevant native CTests against the build as well. GPU/real-disc acceptance
requires a separate local run; hosted CI cannot establish it. Keep diagnostic
capture disabled for performance runs. Do not run competing GPU probes while
someone is testing the game.

Review [release notes](RELEASE_0.3.md), scope, notices and unresolved publication
items. Move previous deliverables to `build/releases/archive/` and copy validated
current outputs to `build/releases/current/`. Preserve logs and unique assets;
remove verified duplicate staging only. Source edits and local commits do not
authorize a push, tag or GitHub release.

## Tool and content provenance

`sources.lock.json` pins download URLs, archive hashes and required tool-file
hashes. Windows PowerShell5.1 starts the bootstrap; downloaded PowerShell7 runs
the SDK commands. `Editor.cmd` and `Play.cmd` need Godot/PowerShell; preparation
and editor ZIP/fork operations also need Python. Successful installations work offline. Failed or interrupted
downloads cannot replace an installed tool, and subsequent runs can retry.

Preserved Legacy0.2 comes from its pinned public player/source archives. Its
executable is also checked against the recorded SDK baseline. No developer's
private `build/alpha-0.2-published` folder is required by CI.

`config/sdk-original-sha256.txt` contains33,597 known-original fingerprints,
without filenames, paths or asset bytes. It is the exact union from the prepared
campaign catalogs and content receipts when recorded. CI requires this index;
local catalogs, when present, add fingerprints to it. Packaging retains reviewed
resource/binary allowlists, directory exclusions, complete inventory checks and
recursive archive inspection. New supported source data should add its hashes
to the index through a reviewed change; never disable the audit to package it.

## Manual GitHub workflow

**Build Godot game and SDK** is manual. Its version input defaults to
`0.3.0-alpha.1`; **publish defaults to false**. It builds pinned sources and the
Godot host, runs tests without retail discs or a physical GPU, creates the same
two audited packages and saves workflow artifacts. The old native alpha workflow
remains separate and also defaults to no publication.

For a future authorized publication, resolve the release-note publication items,
commit reviewed source, select that revision and explicitly enable publish.
The workflow refuses an existing tag/release, uploads a draft first, and only
publishes after successful asset upload. It does not commit or push source.
These workflow instructions are not authorization to run it.
