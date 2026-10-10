# Native build validation

Recorded on Windows on 8–9 October 2026. Current milestones are in
[PROGRESS.md](../PROGRESS.md). The current builds have 738 game translation units
and all 92 configured campaign/menu stages. The default Debug build passes
145 CTest suites. The optimized renderer-module build's earlier 94-suite result
is a separate historical baseline; it has not been rerun for the latest
widescreen changes. Runtime acceptance continues. See [early-stage evidence](EARLY_STAGE_VALIDATION.md) and the
[renderer module validation](RENDERER_MODULES.md).

The current 65 MGS and 17 PsyZ patches pass bootstrap validation. Full unskipped
New Game cinematics complete through the dock Codec in optimized and default
Debug builds, with the reproduced long animation stalls removed. Timing, pixel
and original-instruction evidence is recorded in [intro timing](INTRO_TIMING.md)
and [GPU upload validation](GPU_UPLOAD_ARENA.md).

The remaining sections preserve the **earlier 213-source dock milestone** and
its patch/scan counts. They are historical evidence, not current scope or a
claim of campaign completion. Current dependency revisions and patch order are
in [sources.lock.json](../sources.lock.json).

## Build and automated checks

Both Debug and RelWithDebInfo build as standalone Windows x86 executables from
213 recovered game C files plus the host adapters and PsyZ. All ten CTest suites
pass in both configurations. RelWithDebInfo imports the release Microsoft C
runtime; no original retail executable is linked or invoked.

```powershell
./tools/bootstrap.ps1 -Check
./tools/build.ps1 -Configuration Debug
./tools/build.ps1 -Configuration Debug -Target test
./tools/build.ps1 -Configuration RelWithDebInfo
./tools/build.ps1 -Configuration RelWithDebInfo -Target test
```

Fresh temporary Git indices were initialized at each pinned dependency commit
and all locked patches applied in order. The resulting trees exactly match the
working sources: 98 changed MGS files, 16 changed PsyZ files, and unchanged SDL.
Bootstrap validation and an ordinary repeated bootstrap both pass without
changing the source. Earlier isolated checks also verified conflicting-patch
rejection and preservation of unrelated edits.

## Original content and runtime

All three supplied Integral BIN/CUE pairs were identified and imported into
ignored local storage. The runtime reads the original disc 1 image. Imported
assets are not a substitute for missing stage implementations.

The Debug dock probe reached 3,600 VSyncs, advanced the original Codec through
normal controller input, executed the authored restart and verified movement.
It observed 57 directional pad frames and a horizontal displacement of 431 game
units. The final framebuffer shows the dock, Snake and radar. No access violation
or unsupported GPU packet was logged during that run. See
[the local capture](../build/dock-radar-probe.bmp).

The final RelWithDebInfo executable repeated the full 3,600-VSync probe directly,
without a debugger, and exited with code 0. It produced the same 431-unit movement
and 57 observed input frames, loaded the loose texture override, and finished with
the game unpaused in `s00a`. The [final capture](../build/dock-final.bmp) and
[runtime log](../build/dock-final.log) record that run.

The corrected Codec was separately captured from an optimized run that exited
successfully at 600 VSyncs. Its frequency reads **140.85** and its signal bars are
lit. [Local Codec capture](../build/codec-frequency-fixed.bmp).

The GPU regression reproduces the old renderer's incorrect pixel result and
passes after the texture/palette dependency fix. It covers sprite copies,
chained copies, flat/Gouraud textured polygons and palette writes.

The real loose-resource path loaded `stages/s00a/f072.p` with 14,900 bytes. That
validation copy contains the original bytes: it proves replacement selection,
not edited artwork or resized-resource support.

To repeat the dock input and capture check using the imported-disc manifest:

```powershell
./tools/run.ps1 -Configuration RelWithDebInfo -Probe dock -Frames 3600 `
    -ModsRoot .local/mods -Capture build/dock-final.bmp
```

## Static analysis and limits

Aislop reports 100 across 37 first-party code/tool/test files with no findings.
The changed vendor scope has no errors or fixable warnings. It retains 206 MGS
and 19 PsyZ nonfixable warnings, predominantly inherited function/file
complexity. Some engines lack `cppcheck`, `clang-tidy`, or `clang-format`.

These checks do not establish full dock acceptance, campaign progression,
save/load, audio fidelity, movies, disc switching or VR missions. The
[backend gaps](BACKEND_GAPS.md), [native behavior adjustment](NATIVE_COMPATIBILITY.md)
and [remaining porting work](PORTING_STATUS.md) describe those boundaries.
Captures, logs, imported content and build outputs stay in ignored local folders.
