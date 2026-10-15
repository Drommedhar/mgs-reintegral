# Godot SDK baseline — 12 October 2026

This is the M0 baseline for the [execution ledger](GODOT_SDK_PROGRESS.md), not renderer acceptance. The native build and focused runtime probes pass. Neither measured Godot workload passes the pacing gate.

## Revisions and retained inputs

- Branch: `feature/godot-renderer-sdk`; HEAD: `ef747b13123fd0d54534737979272dd0bf6b0774`.
- [Machine-readable manifest](data/godot_sdk_baseline.json) records inherited file hashes, source locks, tools, original-content fingerprints and built artifacts. Original assets and private source paths are excluded from this tracked manifest.
- Detailed local evidence: `build/godot-sdk-m0/baseline.json` and `inherited.patch`. These describe the state before this execution slice. They are not a clean checkout or a disposable patch.
- Preserve inherited FSR2 changes and authored renderer settings. No production renderer source was changed during this slice.
- Preserved input ZIP: `build/mod-exports/local-780062320.zip`, SHA-256 `bf0dbc8f98fc3f14b19bceebf4cf0f416357af1985856c37bba882ecbb30b81d`. Tests install a copy into isolated workspaces.
- Both original BIN hashes were reread and matched their import receipts. The coverage tool separately verifies each prepared `STAGE.DIR` against its receipt. It does not rehash the BIN every time.

## Builds and functional checks

Godot version is `4.8.dev7.official.c971f93e7`; CMake `3.31.8`, Ninja `1.13.1`, Python `3.11.11`. Commands below run from the repository root.

```powershell
& .\tools\build.ps1 -BuildDirectory build/windows-x86-godot -RendererModule renderers/godot/native -Target mgs-integral-native -Parallel 8
```

The current Debug native executable rebuilt successfully. Its post-build SHA-256 is `6773a9ff80597897344f79aa124b8fa56aec0c6c8b1d4e42c0dc8a75973a168e`. The starting manifest intentionally retains the different pre-build hash. Build output: `build/godot-sdk-m0/godot-build.log`.

Legacy was verified using the preserved published `reintegral-0.2.0-alpha.1-windows-x86.zip`, SHA-256 `1390213568236529c8470198ee3155decff2aa7fa7f6ebdeff2945b7c98a94cb`. Its embedded build record identifies source `a6cf2278b1d54e1d71ebfd286b3098a07cc066fe`, RelWithDebInfo, x86. This was a run of the published binary, not a fresh rebuild of that historical source. [ALPHA.md](ALPHA.md) retains the release recipe.

The Legacy executable ran with both original disc paths, a fresh working directory and:

```text
--stage s00a --probe dock --frames 1800 --resolution 1280x960
```

`build/godot-sdk-m0/legacy-boot/` records exit 0, Codec closure, movement delta 431 and probe completion. This does not establish a manual playthrough. Audio queue warnings remain in the log.

Current Godot completed the modded dock probe and the unskipped intro probe. The latter visited `title → d00a → s00a`, reached the dock Codec and applied 1,833 distinct demo ID/frame pairs with 1,387 camera positions. Only the title menu received automatic input; the intro was not skipped. Logs: `build/godot-sdk-m0/intro-boot/`, launch recipe: `build/godot-sdk-m0/run-intro.ps1`. Its native arguments were:

```text
--stage title --probe intro --frames 7200 --resolution 2560x1440 --widescreen --cadence-log <isolated timing.csv>
```

The launcher package tests passed. Four selected CTests passed: `godot_presentation_inventory`, `list_assets`, `launcher_mods`, `launcher_settings`. They cover inventory provenance, asset enumeration, package operations and settings; they do not establish full renderer coverage. Build and test logs are in `build/godot-sdk-m0/`.

## Measured pacing and preset limitations

Hardware reported by Godot: AMD Radeon RX 9070 XT, Vulkan 1.4.355, Forward+. Both new runs used the same input ZIP and FSR2 at scale 1.00, sharpness 0.80. The prepared project fingerprint was `86fdcc9cdf27c93412553c62c3b6ddfac21cac2e49ae687a8a5bb25cc62122ae`. Initial process inspection found no other game or renderer instance; competing GPU utilization was not sampled, so this is not a controlled GPU benchmark.

The requested resolution was 2560×1440. The renderer actually logged output **2560×1421**, world **1740×1344**, primitive scale **6**. Record these sizes rather than labelling the run a verified 1440p preset. The windowed client size and world viewport policy need verification before freezing M0.03's reference preset.

The input ZIP's dock scene explicitly sets SSAO and SSIL on (`ssil_intensity = 7.19`), volumetric fog on (density 0.015), and contains negative SDFGI energy. Runtime environment migration may override individual values. These are authored input observations, not an assertion of final effective GI settings. Do not silently normalize the user's ZIP; add effective-environment reporting before comparative optimization.

| Workload | Frames | Average FPS | p95 ms | p99 ms | Max ms | Frames above target + 2 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Dock, first run, inadvertently 4:3 | 2,500 measured | 59.917 | 16.6835 | 16.6872 | 21.5222 | 2 |
| Dock, corrected widescreen test | 2,500 measured | 59.844 | 16.6835 | 16.7034 | 23.5291 | 13 |
| Full unskipped intro, including loads/UI | 7,200 | 53.675 | 37.7356 | 46.1247 | 563.9306 | 742 |
| Intro subset: active `d00a` demo | 3,208 | 48.088 | 43.2607 | 48.9705 | 61.3895 | 696 |

Dock runs use 3,600 total frames and discard the first 1,100. The intro has no discarded warm-up; its stage/demo breakdown is supplementary and does not exclude loading from the full result. Intro percentiles use the nearest-rank method. The native target is approximately 16.683 ms (59.94 Hz).

The strict dock script rejects any measured frame above target + 2 ms, or mean time above target + 0.05 ms, and requires at least 600 samples. Both dock runs **fail**. The intro's active-demo slowdown also remains an open issue; it is not explained away as loading.

Evidence:

- First dock run: `build/godot-performance/f996b9c98725406db9f5bf9728cbe879/`.
- Widescreen dock run: `build/godot-performance/a119534df9694bf889a50ad8a3cf476e/`; includes settings, logs, complete timing CSV and `summary.json`.
- Intro: `build/godot-sdk-m0/intro-boot/timing.csv`, SHA-256 `ae739515ff78b74a4d47e2b8c49718854f82e42a670277fcfe097f84768af460`; breakdown in `intro-timing-summary.json`.

`tests/launcher_mods.cs` now enables widescreen for `--performance-check` and checks the native log. `tools/test-godot-performance.ps1` records that flag in its summary. This corrects the workload, not runtime performance.

```powershell
& .\tools\test-godot-performance.ps1 -ModZip .\build\mod-exports\local-780062320.zip -Resolution 2560x1440
```

## Still required before closing M0.03

- Verify actual output/world sizes and log effective environment settings; freeze the reference preset without modifying the input ZIP.
- Retain a reproducible unskipped-intro workload in the maintained test tooling rather than only the ignored local recipe.
- Isolate and measure a named UI transition. Observing the dock Codec during the intro is functional evidence, not a separately bounded UI benchmark.
- Record GPU utilization/competing load and CPU/GPU timing attribution. Existing draw/world/copy/submit counters do not identify every legacy contribution. Dedicated category diagnostics belong to M4.01.

Preserve these failing measurements as the baseline. Performance acceptance remains open.
