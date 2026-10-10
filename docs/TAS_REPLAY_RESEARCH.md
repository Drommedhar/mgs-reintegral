# Prerecorded inputs for native gameplay tests

The primary candidate is **theenglishman's Metal Gear Solid: Integral all-bosses tool-assisted speedrun**, [TASVideos movie 3161](https://tasvideos.org/3161M), recorded with BizHawk 1.11.4. The input archive has been downloaded and inspected. It has not been replayed successfully in this native port, and the port currently has no general BK2 playback command.

This is a useful source for bounded gameplay segments because it targets Integral and visits the bosses. It does not establish full campaign coverage: the recording still uses glitches, manipulates enemy behavior, and skips dialogue and cinematics. The related [any-percent movie 3164](https://tasvideos.org/3164M) skips every Disc 1 boss and is less suitable for broad actor coverage. Keep the independent [unskipped intro and cadence tests](INTRO_TIMING.md) and [normal startup test](NORMAL_STARTUP.md).

## Verified download and starting conditions

Inspection date: 2026-10-09. All downloads and extracted replay data remain in ignored `.local/replays/`; no disc image, BIOS, video or game resource was downloaded for this inspection.

| Item | Verified value |
| --- | --- |
| Publication / submission | [3161M](https://tasvideos.org/3161M) / [5139S](https://tasvideos.org/5139S) |
| Author | theenglishman |
| Game | Japanese Integral, Disc 1 SLPM-86247 and Disc 2 SLPM-86248, as specified by the submission |
| Emulator / core | Header: `Version 1.11.4`, `Octoshock`, platform `PSX` |
| Input count | 313,202 rows; submission timing uses 59.94005994005994 frames/second |
| Initial state | `StartsFromSaveRam True`; `MovieSaveRam.bin` is 262,144 bytes; no embedded emulator core state |
| Controllers | Two DualAnalog SCPH-1180 devices; no multitaps; both memory-card slots enabled |
| Other sync setting | `EnableLEC: false` |
| Firmware identifier | Header `PSX_Firmware_J`: `343883A7B555646DA8CEE54AADD2795B6E7DD070` |
| Archive metadata | Header game name is `mgsintegral`; no game-image hash is present in that header |
| Local Disc 1 identity | Serial `SLPM_862.47`; independently computed image SHA-1 `16f6672456baf5e6c46e1abba5cdc68ec124b633` matches the Integral version listed on [TASVideos](https://tasvideos.org/1004G) |

The [author's submission](https://tasvideos.org/5139S) specifies Extreme difficulty, Normal Round, and SRAM plus an unlock code. These starting conditions differ from a new installation with empty cards. An emulator memory-card image is not an emulator savestate and should not be treated as native runtime memory. Any future importer must inspect and explicitly prepare compatible disposable card files through the native card backend.

The user's Disc 1 image was hashed directly at its original Downloads path with
PowerShell `Get-FileHash -Algorithm SHA1`; the image was not modified. Matching
the image removes one version uncertainty. It does not establish equivalent
save data, language/options, RNG state, input sampling, or loading timing.

## What the publication tags mean for acceptance

| Tag or property | Consequence for our tests |
| --- | --- |
| Starts from SRAM | This particular archive supplies memory-card data, not an emulator CPU/RAM savestate. Prepare and verify its starting options and Extreme Normal Round before attempting whole-movie synchronization. |
| Intentional damage | Check expected health changes or bounds; a deliberate hit is not automatically a defect. Unexpected death or a missed checkpoint still fails the segment. |
| Heavy luck manipulation | Exact state and input timing matter. A replay can diverge before the visible failure, so compare intermediate checkpoints. |
| Heavy glitch abuse / forgoes time-saving glitches | Both tags can apply: it uses some exploits and declines others. The all-bosses objective does not make this a glitchless or complete-coverage run. |
| In-game time / entertainment tradeoffs | Do not use elapsed desktop time or fastest completion as the acceptance criterion. Preserve source-frame inputs and check the game state reached. |

These are testing implications drawn from the tags and the inspected archive,
not claims that its timing already matches the native port.

Local artifacts:

| Path under `.local/replays/` | Bytes | SHA-256 |
| --- | ---: | --- |
| `theenglishman-tasvideos-3161M.zip` | 288,494 | `3a8abe88bd543809472b767a4034d9f41cd28e19d8412ca20087843b00fd1920` |
| `theenglishman-mgs-integral-all-bosses.bk2` | 378,388 | `8f433916cb219a243499f75b92f6a90d3f5333b671e53a846f37dc5733732a7a` |

The outer archive's original filename is `theenglishman-metalgearsolidintegral-allbosses.bk2`. The extracted local name above is shorter. [Inspection metadata](../.local/replays/all-bosses-inspection.json) preserves the author, source links, header, settings, frame count, axis ranges and command transitions. The BK2 also contains `Input Log.txt`, `Comments.txt` and `Subtitles.txt`; the latter two contain only line endings.

## Actual input schema

BK2 is a ZIP container. Its [documented format](https://tasvideos.org/BizHawk/BK2Format) represents input frames as lines beginning with `|`. For this archive, each row has these groups:

```text
|Disc Select,Open Close Reset|P1 LX,LY,RX,RY,buttons|P2 LX,LY,RX,RY,buttons|
```

This is a structural description, not a literal row. Each numeric field occupies five characters followed by a comma. Each controller has four axes, followed by 17 boolean characters in this order:

```text
Up Down Left Right Select Start Square Triangle Circle Cross L1 R1 L2 R2 L3 R3 MODE
```

`.` means released; any other boolean character means pressed. Marker letters are for readability and must not be validated as fixed button names. Axes are bytes from 0 to 255, centered at 128. The `LogKey` records the actual ordering; other BK2 controller configurations need not use this schema.

The settings encode device type 3 on each physical port. The [BizHawk 1.11.4 enum](https://github.com/TASEmulators/BizHawk/blob/1.11.4/BizHawk.Emulation.Cores/Consoles/Sony/PSX/OctoshockDll.cs) identifies this as **DualAnalog**, while DualShock is type 2. Both ports use analog input in the movie. Port 1 also uses L3 for two frames; neither port presses MODE or R3. Controller 2 cannot be discarded: its first non-neutral input is at row 74,791.

All indices here are zero-based. The first Start press occupies rows 1,485–1,487. Tray Open occurs at 181,883, Disc Select becomes 2 at 181,893, and Close occurs at 181,906. Later Disc Select values change with the lid closed. The original core ignores such changes until the tray is open; an importer must preserve that behavior. No Reset command is used.

The [original core's frame advance](https://github.com/TASEmulators/BizHawk/blob/1.11.4/BizHawk.Emulation.Cores/Consoles/Sony/PSX/Octoshock.cs) applies input before stepping an emulated frame, then checks whether either controller was polled. Therefore lag and loading rows still belong to the recording. Do not remove them or consume input only when an actor updates. The publication's nominal frame rate is a timing convention, not proof that native loading and emulator timing agree.

## Available inspector and frame export

[`tools/inspect_bk2.py`](../tools/inspect_bk2.py) validates the complete input
stream and optionally exports a selected range as CSV. It supports this
Octoshock schema with two direct DualAnalog or DualShock controllers. Every
frame, all buttons and axes, and the disc/reset commands are retained. It rejects
unsupported layouts and malformed input instead of dropping fields.

```powershell
./.venv/Scripts/python.exe tools/inspect_bk2.py `
    .local/replays/theenglishman-mgs-integral-all-bosses.bk2 `
    --start-frame 2849 --end-frame 3264 `
    --output .local/replays/all-bosses-dock-pipe.csv
```

The end frame is exclusive. This exported 415-frame interval contains the
initial westward movement, pipe crawl and following turn described in the
[dock input reference](DOCK_ROUTE_SCRIPT.md). The command also writes a
`.csv.metadata.json` sidecar containing the author, source archive hash,
controller configuration, initial save-RAM hash and original frame range.
Existing output files are never overwritten. The full original archive and
publication attribution above remain the reference for this derived segment.

The parser's 14 tests cover every control on both ports, malformed and unsupported
input, frame-range bounds, attribution, and failures beyond an exported slice.
The local acceptance test independently counts all 313,202 original rows and
compares exported disc-change frames with the source fields. Ruff and scoped
Aislop checks report no findings. These are format-conversion tests, not gameplay
tests: exported metadata explicitly records `native_playback_verified: false`.

## Proposed bounded playback workflow

The inspector completes the format-reading step. Native playback and checkpoint
acceptance remain implementation work:

1. Parse and validate the archive without running it. Preserve source URL, author, hashes, frame ranges, initial-card requirements and controller configuration with every derived segment. Keep the original input unchanged alongside any adaptation.
2. Replay controls through two ordinary SDL virtual gamepads. Extend the current [input probe](../src/mgs_probe.c) to cover all buttons and four axes on each port. The current native `AxisToByte` conversion can reproduce each recorded byte exactly using SDL value `(byte << 8) - 32768`. Confirm the controller protocol/mode as well as axis values; a matching axis stream alone does not establish equivalent controller behavior.
3. Advance from a defined VSync/input-sampling phase, not wall-clock sleeps, renderer presents, or game-actor ticks. Bootstrap through normal title controls and begin a short segment only after its documented starting checkpoint is observed. Handle actual disc changes through the existing host media boundary, separately from pad input.
4. First attempt a short dock movement segment. Compare expected stage, position tolerance, stance, alert state and health at fixed checkpoints using read-only observations. Record input index, VSync, game tick and stage together with [cadence data](INTRO_TIMING.md#per-frame-cadence-recording). The [dock route audit](DOCK_ROUTE_SCRIPT.md) supplies original geometry and elevator prerequisites.
5. Fail and stop on a missed checkpoint or deadline, reporting the last matching checkpoint and actual state. Do not warp Snake, change health, patch flags, silently skip input, or report a successful run after divergence. If loading requires a different wait, record that adaptation and validate the new segment independently.

Synchronization is an open engineering question. The author reports loading-time differences even between PCSX and BizHawk, affecting rooms, Codec and cutscenes. Native resource loading, audio scheduling, input polling and RNG can likewise change the state reached by the same frame-indexed input. Segment checkpoints can detect this; they cannot make an unchanged full-game movie deterministic by themselves. A test that reaches every boss also does not cover every branch, ending, effect or cinematic.

## Earlier supplied link: original USA recording

The initial link, [movie 2003](https://tasvideos.org/2003M), was downloaded before the correction to 3161. It is another run by theenglishman, for **original MGS USA v1.0**, recorded with **PSXjin 2.0.2**, rather than Integral. Its [submission](https://tasvideos.org/3462S) records 330,540 frames at nominal 60 Hz and requires preinitialized card data to unlock Extreme.

The local `tasvideos-2003M.zip` contains `theenglishman-metalgearsolid-bigboss.pjm`. Header inspection finds PJM version 2, text input, two standard digital controllers, NTSC, power-on plus embedded memory cards, and CD identifiers `slus00594` / `slus00776`. The savestate, cheat-list and emulator-hack flags are clear. These fields follow the [PJM format](https://tasvideos.org/EmulatorResources/PSXjin/PJM). The PJM is 11,250,799 bytes, SHA-256 `9375a2bf8e9406d79edf7c0eec64f9cf32b3226536396514786c0b638240e757`; its outer ZIP is 62,562 bytes, SHA-256 `9a7e13b163022f9cf3029f1b1b4fa7810ee4fc9e81011641f862dda1800eff06`.

This older run can provide route comparisons, but the corrected Integral BK2 is the better first input source for this port. Neither archive has been executed by the native build.

## Attribution and reuse

Credit **theenglishman** and **TASVideos**, identify the recordings as tool-assisted speedruns, and link their publication pages rather than direct download endpoints. The publication pages request that attribution and labeling and specify conditions for republishing their video/audio. The site's [license page](https://tasvideos.org/SiteLicense), checked on the inspection date, states that site content is under Creative Commons Attribution 2.0. That statement does not grant rights to separately obtained game or BIOS assets. No replay or game asset is added to tracked sources by this research.
