# Frame pacing and input recording

The default presentation target is NTSC 59.94 FPS, approximately 16.683 ms per
frame. Actor animation can retain the original lower update rate. These numbers
describe presentation cadence, not a conversion of authored animation to 60 FPS.

```powershell
$record = "D:\git\mgs-integral-native\.local\replays\full-run-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
& D:\git\mgs-integral-native\tools\run.ps1 `
    -Widescreen -Resolution 2560x1440 -Fullscreen -DebugOverlay -BonusItems `
    -RecordInput "$record.mgsinput" *>&1 |
    Tee-Object -FilePath "$record.log"
```

Choose New Game. Preserve the `.mgsinput`, `.mgsinput.session` directory,
`.mgsinput.timing.csv` and console `.log` together. Keyboard and Xbox input use
the same recording path. The recording contains inputs and state checks, not video.
`-BonusItems` grants Stealth and Bandana for New Game; equip or remove them
through the original item menu. Replay restores this option from the recording.

The top-right host overlay shows a rolling FPS average, latest frame time and
the highest frame time after the title menu becomes ready (`MAX`). It shows
`--` during startup, excludes the transition frame, and never periodically
resets afterward. A direct stage/checkpoint launch starts tracking once its
campaign stage has loaded. Startup slow frames remain in the diagnostic log.
The panel is drawn into the swapchain after the
game image, so it cannot enter emulated VRAM, water feedback, blur or game HUD
layout. Audio measurements are intentionally confined to diagnostics.

Timing CSVs contain only frames exceeding the target by more than 2 ms
(approximately 18.683 ms for NTSC). Healthy frames still contribute to the
overlay and the shutdown summary. Logged rows include the exact VSync and
input-sample count, stage, game tick, cinematic frame, CPU draw duration,
GPU-submission duration and SDL audio queue measurements. Empty audio refills
mean the SDL input queue was exhausted at a refill; they are not hardware
underrun measurements. Wall times are never deterministic replay assertions.

```powershell
& D:\git\mgs-integral-native\tools\run.ps1 `
    -ReplayInput "$record.mgsinput" -CadenceLog "$record.replay.timing.csv"
& D:\git\mgs-integral-native\.venv\Scripts\python.exe `
    D:\git\mgs-integral-native\tools\analyze_performance.py `
    "$record.mgsinput.timing.csv" --compare "$record.replay.timing.csv"
```

Replay retains input/state checks and restores recorded display settings. Timing
outputs require fresh names. `-ReplayFast` is useful for game-state checks but
is unsuitable for real-time performance/audio comparison. The analysis joins
sparse rows by VSync rather than row number. Missing rows can represent healthy
frames or an unfinished run; successful replay completion is established by
the input subsystem's `PASS replay` result. Percentiles of the CSV describe
logged slow frames only. Truncated CSV rows are reported rather than counted.

## Map loading

Enable **Gameplay → Faster map loading (experimental)** in a rebuilt launcher,
or add `-FastLoading` to `tools/run.ps1` (`--fast-loading 1` directly). It defaults
off and is available with the reference and modern renderers. Replay inherits
the recorded presentation setting; `-FastLoading:$false` overrides it without
changing the recording's gameplay identity.

This implementation preserves the CD sector cadence, resource callbacks,
texture staging and frame-based memory cleanup. It selects the existing
deterministic game clock before startup and temporarily removes presentation
waits between `FS_LoadStageRequest` and `FS_LoadStageComplete`. The previous
presentation mode is restored afterward, including unlimited diagnostic replay.
Authored fades and gameplay/cutscene pacing outside loading retain their normal
rate. The log's `[loading]` line measures only that resource-loading phase.

Host audio generated during accelerated loading is discarded. The SPU, sound
tasks and interrupts still run for every simulated sample; output resumes with
a fresh buffer after loading. This suppression is independent of the caller's
audio pause state. BGM reset and continuation follow the original game.

Unlike the discarded sector-batching experiment, this does not process a whole
stage inside one loader frame or change decoded-texture allocation lifetimes.

On 10 October 2026, local 2560x1440 modern-renderer comparisons with all three
geometry options enabled measured:

| Load | Normal | Accelerated | Final capture |
| --- | ---: | ---: | --- |
| PAL checkpoint, `s16d` | 3720.3 ms | 32.7 ms | Byte-identical |
| Ninja checkpoint, `s08b` | 2836.1 ms | 27.0 ms | Byte-identical |

Both normal-speed replays retained every state check: 596 inputs / 600 VSyncs
for PAL and 1396 / 1400 for Ninja. A separate PAL launch without input recording
also produced the identical image (30.1 ms map load). These are local resource
phase measurements, not whole-transition or other-hardware guarantees.
Evidence is under `build/map-loading/`.

The existing 4996-input New Game replay passes through `init`, `title`, `d00a`
and loaded `s00a`. The 2496-input unattended opening replay also passes and
retains its earlier capture exactly. Those two correctness checks use
`-ReplayFast`, so their wall times are not real-time comparisons. One older
campaign recording diverges at `s11e` VSync 648 with fast loading both disabled
and enabled; it is not used as acceptance evidence for later transitions.

All 167 modern and 163 reference CTests pass. Loading tests verify restoration
of each presentation mode across repeated loads. Audio tests compare identical
timer/SPU/task traces, verify suppression preserves an independent pause, and
check playback resumes afterward. Whole-campaign fast-loading acceptance
remains user testing.

## Dock puddle rendering

The 2560×1440 repro showed GPU submission waits around 40 ms during the puddle
effect, while CPU draw work was often below 1 ms. The SDL input audio queue
drained during these waits. The original scaled renderer downsampled the native
framebuffer after every drawing batch, including each small translucent polygon.

The SDL GPU backend now accumulates changed bounds and resolves the native
mirror when a texture/palette reads those pending pixels, when native image
operations/readback need them, or when changing internal resolution. Indexed
textures, palette wrapping, mask operations and framebuffer feedback retain
their ordering. High-resolution destination snapshots still preserve exact
translucent blending. These changes are confined to the replaceable renderer.

The frame limiter also stops compensating a late frame with shortened subsequent
frames. After a stall it resumes the normal frame period. This is a pacing
correction, not high-FPS gameplay support.

Local measurements and replay evidence are in `build/dock-performance/`.
The initial `baseline.csv` and `instrumented.csv` contain every frame; later
logs use the requested slow-frame filter. The intermediate `fixed.csv` run
still had drops; the later `deferred.csv` run includes deferred native resolves.

## Verified on 9 October 2026

The same 4,996-sample / 5,000-VSync recording passes strict replay through the
dock Codec after the change. At 2560×1440, slow intro frames above 18.683 ms fell
from 191 in the instrumented baseline to two. The puddle-burst window, VSyncs
1590–1770, went from 77 slow frames to zero. The user also reported that the
running fix works. This is a targeted intro check, not a complete playthrough.

Two isolated intro spikes remain at VSyncs 1801/1802 (37.516/26.271 ms); they are
retained in the sparse log. Four additional slow frames occurred during startup
or title loading. The whole run averages 59.77 FPS including initialization;
its minimum frame time is 16.683 ms. No shortened catch-up frames occur.

All 148 CTest suites pass, including 1×/2×/8× framebuffer, texture, mask and
feedback regressions. Unit coverage checks late-frame recovery, lifetime maximum,
the slow-frame threshold and sparse comparison alignment. A separate 300-VSync
record/replay verifies automatic timing filenames, display-setting restoration,
and preservation of the original timing file.

PsyZ's 18-patch bootstrap stack verifies with the new performance patch. Scoped
Aislop scans report no errors or fixable warnings. Five existing renderer
size/complexity warnings remain; cppcheck is unavailable. The fixer also
normalized Python test-helper formatting/imports beyond the requested file
filter; the complete test suite passed afterward.

The menu-start MAX follow-up passes the four relevant timing, analysis,
input-session and bonus-item suites. A real-disc title replay passes all 415
inputs / 419 VSyncs and observes the readiness hook. Evidence is in
`build/menu-peak-validation/`. The recovered title actor has 22 inherited,
nonfixable size/complexity findings; edited first-party files have none.
