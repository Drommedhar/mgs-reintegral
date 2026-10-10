# Mantis encounter recovery

`s07b` and `s07br` now compile and run native encounter code. All 157 assembly placeholders in the Meryl and Psycho Mantis actor files have been replaced with C. This is recovered-source and automated-runtime evidence; a complete boss fight and human playability remain unverified.

The two original 143,856-byte overlays were extracted from the user's Integral Disc 1. All 13,193 instruction words in those 157 upstream assembly blocks match both original overlays. The overlay hashes, extents, block addresses, and 57 constructor bindings are recorded in [the recovery ledger](data/s07b_recovery.json). The repeat stage uses the same source group as the original upstream linker configuration.

The native actor definitions preserve the original Meryl layout (0x97c bytes). Mantis grows from 0xae8 to 0xb10 because its ten embedded GPU packets have native pointer tags. Its rendering uses typed packet fields and native ordering-table pointers. Original callback arguments, signed movement arithmetic, prop state counters, weapon damage configuration, and resident globals were checked against original instructions. IDA output was a starting point: raw instructions corrected, among other details, an incorrect constant string folded into a camera position copied from mutable BSS.

The changes are reproducible through `patches/mgs-mantis.patch`. Retail overlays, analysis databases, scenario scripts, screenshots, and build logs remain ignored local evidence.

## Checks

- Fourteen added translation units compile; both stages link into the Debug executable.
- `mgs_mantis_helpers_test` passes 58 comparisons against original MIPS execution in Unicorn 2.1.4. The reference run executes the selected routines and resident `GV_DiffDirS` without function hooks. Cases cover turn wrapping/clamping, trap membership, damage-field reset, immunity masks/timers, dodge blinking, and gravity/wrapping. These are helper comparisons, not exhaustive combat-state or HP-damage tests.
- A 3,600-VSync `s07b` checkpoint run observed both actor constructors, Mantis's main attack, the HIDEO blackout and return, psychic projectiles, chair attacks, and pot attacks. The normal-input probe moved Snake 3,033 units after the blackout. The resulting capture shows the room, Snake, Mantis, and both encounter health bars.
- The corresponding `s07br` run completed 1,800 VSyncs, observed both actors, HIDEO and a psychic projectile, and passed movement by 3,141 units.
- Scoped Aislop: 13 vendor files, zero errors or fixable warnings, 15 nonfixable complexity warnings in recovered routines. Optional external scan engines unavailable in this environment are not counted as passing checks.

The runtime setup is explicit in [the debugger fixture](../tests/fixtures/s07b_story129.cdb). It selects original story checkpoint 129, uses the incoming position from `sub_6716`, heading from `sub_9AE1`, and supplies saved encounter health values. The original scenario then creates and drives the actors. This isolates a checkpoint; it does not prove that the campaign reached it naturally. An earlier checkpoint-125 experiment omitted saved Meryl health and ended at game over; it is excluded from encounter-completion evidence.

Rebuild the helper test with `./tools/build.ps1 -Configuration Debug -Target mgs_mantis_helpers_test`, then run `build/windows-x86-debug/mgs_mantis_helpers_test.exe`. For runtime, use the fixture with x86 CDB and the Debug executable, passing `--disc <user Disc 1.cue> --stage s07b --stage-map 0x7df9 --probe stage --frames 3600`. Substitute `s07br` for the repeat-stage check.

Remaining validation: defeat Mantis through ordinary input, exercise possession and the ending scenes, and traverse the authored incoming/outgoing stage chain. The helper tests and idle combat run do not establish those behaviors.

## HIDEO and controller ports (9 October)

The user's `run-20261009-175121-774.mgsinput` strictly replayed all 52,951 inputs
through 52,955 VSyncs. Mantis remained active, with port 1 selected; its blackout
counter had already reached two. A capture during the blackout exposed the visual
bug: black covered only the bottom-right quadrant and most of HIDEO was off-screen.
The actor was submitting screen coordinates to the centered 3D channel.

Original `s07b_800CC174` reads the ordering table at `0x800b19ec + 0x1ec`, the
overlay channel (`DG_Chanls[2]`, exposed as `DG_Chanl(1)`). The reconstructed C
incorrectly used `DG_Chanl(0)`. `patches/mgs-mantis-hideo-channel.patch` corrects
that selection without changing blackout duration or boss behavior. Actual
1280x720 widescreen captures now show full coverage and both large and small
HIDEO lettering. The earlier milestone-only runtime check established execution,
not correct on-screen presentation.

F2 or clicking both sticks together (L3 + R3) now exchanges SDL host inputs
between the two emulated ports. Keyboard, analog axes, disconnection and rumble
follow the exchange. A host overlay displays the current port and shortcut even
without FPS diagnostics. It remains visible over HIDEO, and while port 2 remains
selected after the fight. The original game notices port 2 when input arrives;
move or press a button after switching, and switch back afterward. Live shortcuts
are ignored during replay. Vendor support is exported in
`patches/psyz-controller-ports.patch`.

SDK tests use SDL virtual controllers and keyboard input to check both shortcuts,
held/repeated input, simultaneous stick clicks, replay isolation, both packet
streams, axes and rumble routing. A 1,600-VSync real-disc test loads the retry
checkpoint, enters HIDEO, routes movement through port 2, and returns to combat.
The debugger changes only the host-port mapping at HIDEO time 32; it does not
advance combat or set the game's controller flag. Resulting input packets replay
strictly: **1,596 samples, 1,600 VSyncs**, final stage `s07b`, second-controller
flag set. Evidence is in ignored `build/mantis-port-20261009/`. Captured game
frames exclude the host FPS/prompt panel. Full encounter completion is for the
user's playthrough.

## Optional synthetic memory reading

`-MantisMemory random` generates a seed; `-MantisMemory 42` uses a chosen seed.
Without it, Mantis scans the real memory cards. When enabled, only the Mantis
reader receives a temporary in-memory card listing of 3–6 unique recognized
titles from the active original table. The existing matcher, genre thresholds
and dialogue selector produce his reading. It consumes no game RNG and never
writes card files or changes the actual play statistics he also evaluates.

Integral's English dub explicitly excludes Japanese-only title/developer lines
in that table; the synthetic profile honors those masks. Session identity stores
the seed for deterministic replay and checkpoint recovery. Tests exercise
determinism, different seeds, recognized and unique names, valid dialogue bits,
duplicate files across cards, unknown filenames, seed validation and preservation
of real card files. The change is exported in
`patches/mgs-mantis-memory-profile.patch`. This is an optional native feature,
not recovered original randomization. Full voiced introduction with this option
remains for the playthrough; the direct battle checkpoint is after that reading.

## Direct Mantis retry checkpoint

`.local/checkpoints/mantis-20261009/recorded-entry.mgssave` uses the recorded live
restart data captured at the end of the user's strict replay. It preserves story
129, map `0x7df9`, spawn `(-670, 0, 875)`, heading 2048, recorded Mantis/Meryl restart
health 904/284, and stealth/bandana inventory. This is a map restart, not an exact
mid-frame savestate. It loads directly into the Mantis encounter without repeating
Ninja or earlier bosses. Its SHA-256 is
`74fd1bffc8817d0b962a752ab4b6d2a8b2e5681e9d1379d5956b879aa68a8114`.
The adjacent JSON records source and component hashes. Native loading, movement
and the strict replay above validate it; original recordings/cards were preserved.

Final checks: the Debug executable builds; seven focused CTest suites pass
(SDL SDK, input packets, input movie, input log, session identity, resume and
Mantis helpers). The original 58 MIPS reference cases still pass alongside the
new rendering and memory-profile checks. All 74 MGS and 19 PSYZ patches verify.
Scoped Aislop reports zero errors/fixable warnings and no new diagnostics;
12 inherited nonfixable vendor complexity warnings remain, plus four inherited
TODO notes. `cppcheck` is unavailable, and Aislop does not scan these PowerShell
files; PowerShell syntax checks and session/resume tests pass. The executable
SHA-256 is `72f9a8a88d1cc9baf9d523f34102fe9e985a0a70d9987e97f706af4d7e8b2daf`.
