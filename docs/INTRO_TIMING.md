# New Game intro timing

The `intro` input probe selects New Game through the original title controls and releases every button once the title stage changes. It does not skip the `d00a` cinematic or the opening Codec. A successful result requires the observed `title` → `d00a` → `s00a` sequence and an open dock Codec. This is automated input evidence, not a human playthrough.

```powershell
./tools/run.ps1 -BuildDirectory build/movie-audit -Probe intro -Frames 12000 `
    -Capture build/cinematic-audit/intro-timing12000.bmp -CaptureEvery 300
```

`-CaptureEvery` requires `-Capture` and `-Frames`. Intermediate files append `.000300.bmp`, `.000600.bmp`, and so on to the supplied capture path; the final capture retains the supplied name. Capture uses a synchronous VRAM readback and can affect that frame's timing. The intro probe samples `Psyz_VideoStats` before this readback and logs 300-VSync window averages/maxima, the game tick and the original sound-stream counter. Normal launches without `-Probe` and `-CaptureEvery` retain their existing behavior.

## Baseline before the SPU scheduling correction

The local trace is [intro-timing12000.log](../build/cinematic-audit/intro-timing12000.log). It used the Debug `movie-audit` executable with the current underwater packet changes and temporary renderer counters, before the sound scheduling repair. These artifacts contain original game imagery and stay outside tracked sources.

| Observation | Evidence |
| --- | --- |
| Title loaded | VSync 228, game tick 207. |
| `d00a` loaded | VSync 693, game tick 521. |
| Underwater infiltration renders | Captures at VSync 900 and 2100 show the swimming view and green underwater effect. |
| Dock credits and environment render | Captures at VSync 1800 and 3000 show the dock and credits. |
| Authored transition reaches `s00a` | VSync 7709, game tick 4134; the opening Codec follows without further input. |
| Sound clock is slow | Stream counter 167, 463, 753 and 1038 at VSync 900, 1200, 1500 and 1800: about 58 ticks/second. |
| Drawing has isolated stalls | Maximum observed draw times include 283.7 ms and 669.7 ms; many later windows average below 2 ms. Frame cadence is otherwise close to 16.683 ms. |

The recovered sound driver uses silent SPU voice 23 at pitch 4096, alternating IRQ addresses 256 ADPCM bytes apart. That interval represents 448 decoded samples, or 98.4375 IRQs/second at 44.1 kHz. `FS_StreamGetTick` retains the original `ticks * 64 / 105 + 1` conversion, and demo playback divides this by two. The measured counter rate therefore cannot maintain the authored cinematic cadence. The affected implementation is the asynchronous mixer/IRQ handoff, not that conversion: the audio callback can advance thousands of samples while one IRQ remains latched until the game thread services it.

The original New Game clip has 1981 demo frames. It is authored at stream offset `0x1441`; adding the disc's `DEMO.DAT` base sector 2970 produces the logged absolute sector 8155. In this baseline, the loaded `d00a` → loaded `s00a` interval is roughly 117 seconds, including transition/loading overhead, rather than the clip's roughly 66-second authored duration. See [normal startup](NORMAL_STARTUP.md) for the separate unattended submarine opening before the title menu.

This run establishes that the New Game underwater content executes and transitions naturally. It does not establish accurate audio synchronization, correct rendering throughout the sequence, completion of the opening Codec, or continuous human gameplay. Corrected timing and visual acceptance must be recorded after the backend fixes.

## Cold startup submarine evidence

A separate launch used no stage override and no controller probe:

```powershell
./tools/run.ps1 -BuildDirectory build/movie-audit -Frames 8400 `
    -Capture build/cinematic-audit/cold-opening8400.bmp -CaptureEvery 600
```

It exited successfully after the original `init` → `title` → `opening` loads. The log requests absolute stream sector 2970, the opening script's first demo at relative offset zero. The [VSync 4800 capture](../build/cinematic-audit/cold-opening8400.bmp.004800.bmp) visibly labels the room **Ohio Class Nuclear Submarine Discovery**, with English narration about the Shadow Moses nuclear disposal facility. The [VSync 5400 capture](../build/cinematic-audit/cold-opening8400.bmp.005400.bmp) shows the submarine's sonar room and the Next-Generation Special Forces subtitle. This is fresh normal startup evidence, rather than a direct `-Stage opening` fixture.

The original first opening part has 3439 demo frames. Its authored camera enters the water view at frame 392, starts submarine wake effects at 578, enters the submarine room at 991 and returns to the overhead hull view at 1546. The narration starts at subtitle cue 897; these cues use the sound counter divided by four, not process VSync. Private parsed source records are `.local/recovery/opening-audit/part0.json`.

Thus the native startup does contain the submarine briefing before the title menu. The original New Game callback separately loads the underwater infiltration in `d00a`. This cold capture does not establish completion of all three opening parts or the eventual return to the title menu; its timing still predates the SPU scheduling fix.

## Per-frame cadence recording

`-CadenceLog path.csv` records every VSync without generating input. It can be combined with `-Probe intro` or used on a normal launch. The read-only native demo hooks record the desired stream frame, successfully applied demo frame, application count, total length and actual authored camera eye/target. Each row also records wall time, game tick, pause status, game flags, frame divisor, sound-stream tick and renderer timing.

This separates a missing animation update from an authored stationary camera shot, pause or underwater 20 Hz rendering interval. The recovered water actor deliberately changes the frame divisor from two to three while underwater; the recorder leaves it unchanged. A long wall-time gap with only one VSync advancing identifies a blocked host frame; many VSyncs with advancing sound/desired frames and an unchanged applied frame identify a different stream or actor scheduling problem.

After the process exits and closes the CSV, summarize the intervals with:

```powershell
./.venv/Scripts/python.exe tools/analyze_cadence.py build/cinematic-audit/intro-audio-fixed5000.csv
```

The summary reports observed intervals and their pause/camera context; it does not automatically classify every long camera hold as a rendering fault.

## After the SPU scheduling correction

The fixed 5000-VSync run completed the full unskipped New Game chain and exited successfully. Its [CSV](../build/cinematic-audit/intro-audio-fixed5000.csv) contains every VSync; the [summary](../build/cinematic-audit/intro-audio-fixed5000-summary.json) is generated by the analysis tool above.

- Sound advances 492–493 ticks per 300 VSyncs, matching approximately 98.4 Hz.
- Applied demo frames run from 1 through 1981 in 67.155 seconds, including the remaining host stalls. The actor applies 1978 updates; the original desired-clock selection omits frames 6, 451 and 1020.
- Between updates, 1966 intervals span two VSyncs, seven span three, and four span one. None spans more than three VSyncs. This run has no recurring many-VSync animation plateau.
- Three wall-time gaps exceed 250 ms: 286.643 ms at VSync 723–725, 284.328 ms at 725–726, and 701.949 ms at 1614–1615. Each has advancing desired/applied frames and camera, no pause, and only one or two VSyncs. Renderer diagnostics attribute these host stalls to buffer mapping/upload. All other update intervals are at most 64.071 ms.
- The frame divisor stays two throughout this particular `d00a` run. The naturally loaded dock arrives at VSync 4903, compared with 7709 before the audio correction.

This isolates the remaining long pauses to host rendering in the measured run. It does not claim that the renderer stalls are already fixed, or that every cinematic has been surveyed.

## After the GPU upload arena correction

A subsequent 5000-VSync run uses both corrections. The [CSV summary](../build/cinematic-audit/intro-arena5000-summary.json) reaches applied frame 1981 and the dock Codec naturally. First-to-last applied frame time is 66.049 seconds. Its maximum observed animation-update gap is 50.050 ms, maximum active draw time 5.588 ms, and maximum active video frame time 16.831 ms. There are no update gaps above 250 ms or audio starvation warnings in this run. Of the update intervals, 1970 span two VSyncs, five span three and four span one.

These measurements no longer reproduce the periodic long animation stops in this cinematic. They cover this unskipped opening sequence, not every campaign scene. See the [upload-arena implementation and pixel regression](GPU_UPLOAD_ARENA.md) for the renderer change and its independent native/2× validation.

The rebuilt **default Debug executable** separately passed the same 5000-VSync unskipped intro check. Its [summary](../build/cinematic-audit/default-intro5000-summary.json) records 66.083 seconds of active demo samples, a maximum update interval of 50.077 ms, maximum draw time of 7.226 ms and maximum frame time of 16.713 ms, with no long animation plateaus or audio starvation warnings. It reaches frame 1981 through the original clock-based selection and naturally opens the dock Codec. This confirms the launcher's normal build received the fixes; it is separate from the earlier audit-directory executables.

The final **13,500-VSync default cold startup** also completes the unattended submarine presentation and returns to the title screen through the original completion callback. No controller input, probe, stage override or build-directory override is used. Its [cadence summary](../build/cinematic-audit/default-cold13500-summary.json) records all three opening parts reaching frames 3439, 870 and 1450, with maximum animation-update intervals of 33.407, 33.442 and 33.603 ms respectively. There are no gaps above 250 ms or audio starvation warnings during these clips; one audio warning occurs before initialization. See [normal startup verification](NORMAL_STARTUP.md) for the final title capture and complete transition evidence. This supersedes the earlier 8400-VSync partial-opening validation above.
