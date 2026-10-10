# Native input recording

Native movies record the controller packets consumed by the game: both ports,
buttons and all four stick axes. Keyboard and SDL gamepads use the same path.
They also store game checkpoints so playback fails at the first observed
divergence. This is a native test format, separate from BizHawk `.bk2` files.
The [TAS research](TAS_REPLAY_RESEARCH.md) explains the original replay's starting
memory cards, timing and console differences.

## Controller ports and Mantis memory

**F2** or **L3 + R3 together** exchanges the two SDL input sources assigned to
the original controller ports. Keyboard input follows the primary controller.
Axes, button packets, disconnection and rumble capabilities follow the selected
port before recording. The game still applies its original second-port rules;
move or press a game button after switching. Switch back after Mantis. The
on-screen prompt also appears without the performance overlay. Replays ignore
live port shortcuts and consume the recorded packets instead.

`-MantisMemory random` selects a fresh synthetic memory-card profile for the
introductory reading; `-MantisMemory 42` selects a repeatable one. `off` or omission
on a normal start retains real card scanning. Only the Mantis reader sees this
profile. Save directories and the encounter's actual deaths, detections and save
count remain unchanged.

The seed is recorded as `identityData.startup.mantisMemorySeed`; it is omitted
when disabled, preserving legacy recording identities. Replay inherits it and
rejects conflicting values. Resume uses the source seed during checkpoint
recovery and lets the new recording choose another seed or `off`. Starting from
a checkpoint after the reading cannot replay that earlier scene.

## Automatic access card

Add `-AutoCard` to use an owned access card for doors without selecting it in
the inventory. Door level requirements remain active. It does not change
equipped items or PAL-key checks. The native argument is `--auto-card 1`.

Sessions store `identityData.startup.autoCard` when enabled. Replay and resume
inherit it; replay rejects a conflicting value. Older sessions without the
field retain the original requirement to equip the card.

## Hot PAL key retry (Disc 2)

For the detection lockout in `run-20261010-010306-651.mgsinput`, start on the
stairs just outside the PAL room with the hot PAL key equipped:

```powershell
$p = 'D:\git\mgs-integral-native'
$r = "$p\.local\replays\run-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
& "$p\tools\run.ps1" `
  -LoadCheckpoint "$p\.local\checkpoints\pal-hot-20261010\room-entry.mgssave" `
  -Invulnerable -BonusItems `
  -Widescreen -Resolution 2560x1440 -Fullscreen -DebugOverlay `
  -RecordInput "$r.mgsinput" *>&1 | Tee-Object -FilePath "$r.log"
```

The first two PAL steps remain complete and the final insertion is pending.
The original map-entry save was recovered before detection after 122,441
verified inputs / 122,445 VSyncs. Only the key's temperature was raised from
7560 to its original maximum of 9000, with the checksum recomputed; normal
cooling still applies. Stage `s16d`, story 246, entry selector `0x2aa8`,
inventory and other story flags are preserved.

A separate 600-VSync reload confirms the outside stair position, no alert,
game status zero, story 246, hot key state 1 and temperature 8970. Source
recordings and earlier checkpoints remain intact. Provenance is in the
checkpoint's adjacent JSON; evidence is in `build/pal-reset-20261010/`.

## Cargo elevator restart (Disc 2)

For `run-20261010-004229-177.mgsinput`, retry directly in the cargo-elevator
area without repeating the furnace section:

```powershell
$p = 'D:\git\mgs-integral-native'
$r = "$p\.local\replays\run-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
& "$p\tools\run.ps1" `
  -LoadCheckpoint "$p\.local\checkpoints\cargo-20261010\ambush-entry.mgssave" `
  -Invulnerable -BonusItems `
  -Widescreen -Resolution 2560x1440 -Fullscreen -DebugOverlay `
  -RecordInput "$r.mgsinput" *>&1 | Tee-Object -FilePath "$r.log"
```

This restores the recorded transition into the ambush: Disc 2, stage `s14e`,
story word 206 and entry selector `0x2e90`. The original script selects the
encounter map `0x474d`, positions Snake and spawns the three guards. The data
was captured after 12,001 verified inputs / 12,005 VSyncs; gameplay flags were
not edited. A 600-VSync reload records 596 inputs and visibly reaches combat.
Debugger inspection confirms three live guards with health 768 each, zero
retired guards and the original encounter completion callback still registered.
Evidence is under `build/cargo-checkpoint-20261010/`; source/component hashes
are in the checkpoint's adjacent JSON.

Do not use the earlier `recorded-restart.mgssave` for this retry. That file was
captured after the guards had been defeated, with story 207, and skips the
encounter. It remains preserved for existing recordings. The original Continue
bank uses selector `0x2190` and returns to the upper landing; the corrected
checkpoint uses the recorded ambush transition directly.

The guard commander still ran after the three ambush actors retired. Its sort
now places empty slots last and skips their chase-distance writes; slot counts
and completion logic remain unchanged. The patch is
`patches/mgs-cargo-guard-retirement.patch`. The fixed build matches all 13,989
original inputs / 13,993 VSyncs and survives 600 additional diagnostic VSyncs.
That continuation has no recorded state checks and deliberately ends with
failure status; it proves survival past the crash, not whole-movie completion.
Evidence is under `build/cargo-crash-20261010/`.

## Elevator ambush restart

For the crash in `run-20261009-191445-721.mgsinput`, use this direct elevator
restart to avoid repeating the tower climb and Hind fight:

```powershell
$p = 'D:\git\mgs-integral-native'
$r = "$p\.local\replays\run-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
& "$p\tools\run.ps1" `
  -LoadCheckpoint "$p\.local\checkpoints\elevator-20261009\recorded-restart.mgssave" `
  -Invulnerable -BonusItems `
  -Widescreen -Resolution 2560x1440 -Fullscreen -DebugOverlay `
  -RecordInput "$r.mgsinput" *>&1 | Tee-Object -FilePath "$r.log"
```

Run the whole block for a fresh recording name. This uses recorded script
restart globals: stage `s11e`, map `0x7df9`, story word 194, spawn `(0,2500,0)`
and heading 1024. It restarts the encounter rather than restoring an exact
frame. A 600-VSync native load check reaches the active elevator ambush and
records 596 inputs. The adjacent JSON stores the source and component hashes;
earlier saves, memory cards and the source recording remain intact.

The crash occurs after guards retire: the persistent commander still sorts
their empty actor slots while the encounter winds down. Empty slots now sort
last and receive no actor writes, using the existing prison commander's
retirement handling. Slot counts and the encounter completion state machine
are preserved. `patches/mgs-elevator-guard-retirement.patch` exports the fix.

Both builds match all 123,202 original input samples / 123,206 VSyncs. The old
build then dereferences a null guard; the fixed build survives a 600-VSync
held-input diagnostic continuation and begins loading `s11c`. The diagnostic
limit deliberately reports failure, so this establishes survival past the
reported crash rather than successful recording completion or a full
playthrough. Logs and the crash dump remain under
`build/tower-report-20261009/`.

## Torture-area restart

For the crash in `run-20261009-183217-163.mgsinput`, a direct restart is available
from the recorded script globals, without replaying Mantis or Sniper Wolf:

```powershell
$p = 'D:\git\mgs-integral-native'
$r = "$p\.local\replays\run-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
& "$p\tools\run.ps1" `
  -LoadCheckpoint "$p\.local\checkpoints\torture-20261009\recorded-restart.mgssave" `
  -Invulnerable -BonusItems `
  -Widescreen -Resolution 2560x1440 -Fullscreen -DebugOverlay `
  -RecordInput "$r.mgsinput" *>&1 | Tee-Object -FilePath "$r.log"
```

Run the whole block again for a fresh recording name. The checkpoint preserves
the captured `s03b` map `0x7df9`, script story word 157 and scripted restart
position `(-2000,1400,-3250)`. Reloading runs the original area's introduction;
it is not an exact frozen frame. A 1,200-VSync native check reaches the torture
introduction and produces a complete 1,196-input recording. The adjacent JSON
records the source, component/checkpoint hashes and validation. Earlier saves
and the source movie are preserved.

The crash was the persistent item box reading a retired player controller
while the cutscene retained a first-person camera. Labels and pickup proximity
now require a live player; normal collection distances are unchanged. All
74,909 complete original inputs match before a bounded 600-VSync crash-check
tail. Diagnostic tails intentionally return failure after their frame budget;
this verifies survival past the crash, not completion of the source recording.

## Invulnerability

Add `-Invulnerable` to a normal start, `-LoadCheckpoint`, or `-ResumeInput`:

```powershell
./tools/run.ps1 -Invulnerable -BonusItems -RecordInput .local/replays/invulnerable-run.mgsinput
```

Snake's health stays at the current maximum. Ordinary damage cannot consume
equipped Rations automatically; manual Ration use keeps the original rules.
Detection, ammunition, collision and damage reactions remain active. The native
health hooks also cover gas, drowning, electrical damage, torture, rappelling,
the Liquid fight, and the garage/jeep player actors. Scripted deaths, falling
out of the level, timers and other mission-failure conditions still apply;
this option does not suppress `GM_GameOver` globally or protect other actors.

The raw executable accepts `--invulnerable 1` (default `0`). This is a launch
setting, not an invulnerability flag written into saves. Saved health can of
course reflect the run. Omit the switch for a normal launch; use
`-Invulnerable:$false` to override inheritance when resuming an invulnerable
recording into a new play session.

Session identity includes `invulnerable: true` only when enabled, preserving
the identities of older movies. Replay inherits it and rejects a conflicting
override. Map-entry recovery replays with the source recording's setting even
when the new live run requests a different setting.

Validation: production Snake health regression covers lethal/nonlethal damage,
Ration preservation, growing maximum health and disabled behavior. Session tests
cover legacy identity, enabled recording/replay and conflicting overrides. A
600-VSync real-disc start from the user's snowfield checkpoint records 596
samples and strictly replays through `tools/run.ps1`, with invulnerability
inherited automatically. Special encounters compile; this check is not a full
invulnerable campaign playthrough.

## Record and replay

From PowerShell 7 in the project directory:

```powershell
./tools/run.ps1 -BonusItems -RecordInput .local/replays/my-run.mgsinput
```

Play normally with the Xbox controller or keyboard. Escape or closing the game
window ends the recording. Keep both the `.mgsinput` file and its neighboring
`.mgsinput.session` directory. Use a fresh name for each recording; existing
recordings are never overwritten.

Recording now enables the top-right FPS/frame-time overlay and writes slow-frame
diagnostics to `<movie>.timing.csv` automatically. `MAX` is the highest frame time
after the title menu is ready, excluding startup and the transition frame;
direct campaign/checkpoint starts arm it after loading. Audio-buffer measurements
remain in the log only. Normal NTSC
presentation targets 59.94 FPS / 16.683 ms. Only frames exceeding the target by
more than 2 ms are written, with their VSync, input-sample index, stage, game tick,
GPU submission duration and audio queue counters. Each written row is flushed
so a crash retains the preceding complete diagnostics.

Replay creates a new `<movie>.replay-<unique-id>.timing.csv` and restores recorded
resolution, widescreen and fullscreen settings unless explicitly overridden.
The session records presentation settings separately from deterministic game
identity; existing movies remain compatible. `performance.json` in the session
(or its isolated replay directory) identifies the actual executable and settings.
Timing data is observational and does not control the simulation.

Use `-DebugOverlay` on an ordinary launch, or `-DebugOverlay:$false` to hide it
while recording. `-CadenceLog <new-file.csv>` overrides the diagnostic destination.
It also uses slow-frame filtering; historical all-frame cadence traces retain
their original format. A shutdown summary in console output covers all frames.
See [performance diagnostics](PERFORMANCE_DIAGNOSTICS.md) for the capture command,
comparison tool and rendering fix.

```powershell
./tools/run.ps1 -ReplayInput .local/replays/my-run.mgsinput
```

Playback supplies recorded game input and stops at the recorded endpoint. It
reports `PASS replay` only after the endpoint checkpoint matches. Escape during
playback aborts it with a failure exit code. A crash or incomplete recording
does not become a successful test. Physical controller rumble is suppressed
during playback; recorded controller capabilities remain visible to game code.

Add `-ReplayFast` to replay without the presentation frame limiter. This mutes
audio output while the deterministic sound simulation and interrupts continue.
It retains all recorded input and checkpoint checks.

The initial memory cards are copied before recording. Recording uses the normal
save directory, so human progress saves normally. Every replay receives its own
copy of the initial cards under the session directory. Replay does not overwrite
the player's normal cards or a previous replay's output.

Startup stage, map and bonus-inventory option are restored from session metadata.
Disc images, initial cards and resource overrides must match their recorded
hashes. If recording used `-ModsRoot`, pass that same content directory when
replaying. The executable hash is retained as provenance but is not required to
match: replaying a recording against a new build is a useful regression check.

For a bounded development recording, add `-Stage s00a -Frames 2400`. For an
unattended dock input fixture, use `-Probe dock -Frames 1800`. Probes provide
their own virtual controller and disable physical controllers inside that
process; omit `-Probe` when recording human gameplay.

## Resume at the last map entry

```powershell
./tools/run.ps1 -ResumeInput .local/replays/xbox-01.mgsinput
```

This resumes from the original saved entry of the recording's last fully loaded
campaign map. For `xbox-01`, that is the heliport (`s01a`). The first use prepares
and strictly replays a prefix once, then caches the original game's `0xA40` save
payload under `.local/checkpoints/`. Subsequent uses load the checkpoint directly.
The original recording and its initial memory-card snapshots remain untouched.
Recovery playback uses isolated cards.

To continue playing and record a new segment:

```powershell
./tools/run.ps1 -ResumeInput .local/replays/xbox-01.mgsinput -RecordInput .local/replays/xbox-02.mgsinput
```

Use a fresh recording name each time. Its session includes a copy of the starting
checkpoint, so `-ReplayInput .local/replays/xbox-02.mgsinput` automatically restores
that start without replaying the older recording. The checkpoint hash joins the
recording identity; disc and mod hashes are still checked. Existing recordings
retain their identities and replay behavior.

Resume restores the original map-entry inventory, equipped items, health,
difficulty, story variables, spawn and radio memory. It runs the original stage
script again, so entry cinematics or calls may play again. Actions and pickups
after entering the map are rolled back according to the original save system.
This is a game checkpoint, not an exact mid-frame emulator save state.

Crash recordings can be recovered when their complete prefix remains valid.
A partial final row is ignored only for recovery; malformed complete rows and
replay divergence still fail. If the final visit was not fully loaded, the tool
reports its fallback to the last loaded campaign visit. It also refuses export
when the game's stored checkpoint belongs to a different map. A successfully
verified derived prefix does not establish that the original crash recording
completed successfully.

The native `--load-checkpoint`/`--save-checkpoint` adapter uses the original save
serializer and loader. It chooses the original normal, Very Easy or tuxedo
resident resources before loading the saved map, validates the payload and CRC,
and preserves missing bonus items without regranting them. Asset and rendering
interfaces are unchanged.

The saved disc number selects Disc 1 or the supplied `-DiscTwo` before filesystem
initialization. Missing required discs fail explicitly. Disc 2 selection is unit
tested; the real recording used for the runtime check below is on Disc 1.

Verified with the supplied Xbox recording: its 13,153-sample derived prefix
exports `s01a`, then a fresh process boots `init_ve` → `s01a`. The loaded entry
matches position `(-4605,1104,20452)`, health 256, Stealth equipped and inventory
checksum `-178662692`. A 3,000-VSync recording uses normal SDL Cross/Start controls
to skip entry dialogue, then moves 63 horizontal units over 13 moving ticks
(17 collision ticks). Its replay passes all checkpoints and produces identical
final pixels. This is limited movement validation, not a full heliport playthrough.

Evidence: [movement](../build/input-resume-audit/heliport-movement.log),
[replay](../build/input-resume-audit/heliport-movement-replay.log),
[105 passing CTest suites](../build/input-resume-audit/final-ctest.log).
The initial short probes expired during authored entry scenes before reaching
movement; the final probe handles the original inline voice cancellation input.
First-party scoped Aislop scans have no findings. Four inherited, nonfixable
size/complexity warnings remain in vendor `gamed.c`/`script.c`; cppcheck and
clang-tidy are unavailable, and PowerShell is not scored by this installation.

## Xbox controls

Input uses SDL3. Both MGS controller ports initialize in analog mode; explicit
digital mode remains available to the original controller API.

| Xbox | PlayStation input |
| --- | --- |
| A / B / X / Y | Cross / Circle / Square / Triangle |
| LB / RB | L1 / R1 |
| LT / RT | L2 / R2 |
| View / Menu | Select / Start |
| Stick clicks | L3 / R3 |
| D-pad and both sticks | Corresponding D-pad and analog axes |

Integral uses **B/Circle to confirm** and **A/Cross to cancel** in menus. Hold
LT/L2 to open the item menu. Stealth and Bandana are ordinary selectable items
when `-BonusItems` is enabled; only one can be equipped at a time. See
[bonus inventory](BONUS_ITEMS.md) for persistence and original effect limits.

## Checkpoints and limitations

Recording and playback opt into a deterministic simulation clock. Scheduler
ticks, root-counter events and SPU sample/interrupt progression use the same
timeline: 60000/1001 VBlanks per second in NTSC mode, 50 in PAL, and 44,100 audio
samples per second. Rendering remains paced by the host. Device audio queue
consumption and host stalls cannot advance gameplay time. A paused or backed-up
device may discard presentation audio while all emulated samples and interrupts
still execute. Ordinary play without recording retains its existing timing.

Each sampled packet has an input-sample index and host VSync ordinal. Checkpoints
include game tick, stage/loading state, pause and status flags, player position,
health, equipped item and weapon, ammunition, difficulty, stage-visit byte `000000`, alert
mode, configuration, inventory checksum and item restrictions. A clean end
record represents the last completed VSync boundary.

Version 1's scenario-byte field was initially labeled “story”; it has always
stored byte `000000`, not the separate authored story word at `00000A`. The label
is corrected without changing recorded data or compatibility.

Each complete input row is flushed to the operating system. A process crash can
still leave an incomplete row or omit the clean footer. Preserve such a file;
normal replay rejects an incomplete end. For crash investigation, an explicitly
prepared valid-prefix copy can use `-ReplayTailFrames N` to hold its last input
for a bounded diagnostic tail. That tail has no recorded checkpoints and always
ends with failure status; it is not completion of the original recording. See
the [heliport pickup crash](HELIPORT_PICKUP_CRASH.md) for an actual use and its
provenance limits.

These checkpoints catch observed divergence; they do not hash every actor,
audio sample or rendered pixel. A passing short recording is not proof that
every campaign route will replay, nor that the native timing matches a PS1 TAS.
Native process restarts currently require a new recording. Stage transitions
within one process are part of the same stream. Asset changes deliberately
invalidate the session identity; make a new recording for changed mods.

Implementation: [game adapter](../src/mgs_input_movie.c),
[portable file format](../src/mgs_input_log.c),
[session and save isolation](../tools/input-session.ps1).

## Validation status

The file parser, save isolation, input sampling, both virtual-controller ports,
stick quantization, keyboard mapping and replay rumble suppression have passing
automated tests. SDL recognizes the connected Xbox One Elite 2 Controller.
Human controller gameplay is still to be verified.

The default Debug build passes **103 CTest suites**, including 61 output-path
rejection cases, 944 input-format checks and the input-session isolation tests.
The deterministic clock test observes 654 identical timer/SPU/task events across
97,064 samples despite host jitter, a 250 ms stall and an audio-device pause.
New first-party C has no scoped Aislop findings. The inherited long `gamed.c`
actor function remains a nonfixable complexity warning; `cppcheck` is unavailable.

Verified native fixtures:

| Fixture | Result |
| --- | --- |
| Connected Xbox, direct dock startup | 596 input samples / 600 VSyncs replay with matching checkpoints |
| Original menus equip/remove Stealth and Bandana | 2,396 samples / 2,400 VSyncs replay; final framebuffer files have identical SHA-256 |
| Default Debug, normal window-close recording | 825 samples / 829 VSyncs; clean exit and successful replay to its footer |
| Default Debug, title → New Game → `d00a` → dock | 2,996 samples / 3,000 VSyncs replay; 431 units of recorded movement, 21 collision-contact ticks and identical final framebuffer SHA-256 |
| Deliberately altered health checkpoint | Replay rejects sample 0 with exit code 1 and reports expected/actual health |

The New Game fixture uses the existing automated probe's normal cinematic and
Codec skip buttons. It verifies replay across those stage transitions and
movement; it does not verify unskipped cinematic playback. The separate intro
playback evidence remains in [INTRO_TIMING.md](INTRO_TIMING.md).

The initial wall-clock prototype rejected a boot scheduling difference; the
fixed simulation clock resolves it without skipping checkpoints or changing
game state to match the recording. The first normal window-close test also
exposed a double destruction of SDL audio during shutdown. PsyZ now clears its
audio resources before SDL teardown; the repeated window-close test exits zero.

Local evidence: [bonus recording](../build/input-movie-bonus-record01.log),
[bonus replay](../build/input-movie-bonus-replay01.log),
[window-close replay](../build/input-window-close-replay02.log),
[New Game recording](../build/input-default-new-game-record01.log),
[New Game replay](../build/input-default-new-game-replay01.log),
[mismatch rejection](../build/input-bad-checkpoint01.log),
[CTest](../build/input-default-ctest.log).
