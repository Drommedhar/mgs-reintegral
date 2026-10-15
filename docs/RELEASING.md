# Preparing the Godot game and SDK release

The 0.3 workflow produces separate game and SDK ZIPs from the same optimized
native build. The game package omits the editor plugin, examples and extension
development sources. `sdk.json` identifies the package kind, version, native
build, stable channel, source revision and whether the source worktree was dirty.
Both ZIPs include the launcher, Godot host/project and the preserved Legacy 0.2
renderer. CI builds the launcher and Godot host from source; it downloads and
verifies the pinned Legacy executable and matching source archive.

## Local preparation

Use the normal source build prerequisites. Keep existing mods, prepared data
and settings in place. Choose a new evidence directory for each candidate.

```powershell
./tools/bootstrap.ps1 -Check
./tools/build.ps1 -Configuration RelWithDebInfo -RendererModule renderers/godot/native -BuildDirectory build/windows-x86-godot-relwithdebinfo -Version 0.3.0
./tools/prepare-godot-release.ps1 -Version 0.3.0 -BuildDirectory build/windows-x86-godot-relwithdebinfo -OutputDirectory build/evidence/release-candidate
./.venv/Scripts/python.exe tools/test_godot_release.py --sdk build/evidence/release-candidate/reintegral-sdk-0.3.0-windows-x86.zip --game build/evidence/release-candidate/reintegral-0.3.0-windows-x86.zip --output "build/evidence/release-smoke"
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

After merging the release changes into `main`, open **Actions → Release game
and modding SDK → Run workflow**. Select **main**, leave version at `0.3.0` and
leave **publish** checked. Publication defaults to enabled and is allowed only
from `main`. The workflow runs manually; normal pushes and merges do not start it.

It builds pinned sources, the launcher and Godot host, runs CPU tests, packages
both renderers and the SDK, audits inventories and native versions, and checks
relocated editor operations. Only after all checks pass does it upload the game,
SDK, symbols and aggregate checksums to a draft and publish **v0.3.0** as a normal
release marked **Latest**, with prerelease explicitly disabled. The tag targets
the exact tested workflow commit. An existing release or tag is rejected;
failed uploads remain drafts rather than publishing incomplete downloads.

Uncheck **publish** for a build without release/tag creation; its downloads are
retained as workflow artifacts for three days. This mode also permits branch
validation. Alpha/beta/RC version suffixes are rejected in both modes. The old
native **Build alpha release** workflow remains separate and defaults to no
publication; it is not the 0.3 game/SDK release workflow.

Resolve the publication items recorded in the release notes before public upload.
Local preparation does not push source, dispatch CI, create a tag or publish
a release. The manual workflow performs publication when **publish** is checked.
