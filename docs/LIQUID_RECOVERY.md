# Liquid rooftop fight

The Normal-difficulty `s18a` retry scenario now completes the entire fight
through ordinary SDL controller input. Liquid loses all 255 health over 54
damage events; Snake survives with 14 of 768 health. The original victory
script advances story277 → 278 and loads `d18a`, whose script advances to279.
This is a supplied late-game encounter, not a completed campaign playthrough.

## First encounter reached from completed REX

The completed Normal [REX encounter](REX_ENCOUNTER_CONTRACT.md#completed-normal-encounter-and-strict-replay)
now supplies the original story 259 `s18a` map-entry checkpoint. Loading it and
following the authored rooftop scenes reaches story 277 with prior-attempt
count zero. The first fight starts at VSync 18,731 with Snake at 768/768,
Liquid at 255, no equipped item or weapon, and no Stealth/Bandana. No new
gameplay fixture is applied; the diagnostic debugger changes only presentation
pacing. This establishes the incoming REX-to-Liquid transition, not victory.

Local recordings preserve each attempt:

| Run under `.local/recovery/s18a/` | Input controller | Result |
| --- | --- | --- |
| `rex-entry01` | Previous chase/punch controller, 16,000 VSyncs | Limit reached during the preceding cinematic. |
| `rex-entry02` | Previous controller, 60,000 VSyncs | Snake dies at 25,679; Liquid has 34 HP. All 59,996 samples strictly replay. |
| `rex-entry03` | Retreat during Liquid's knockdown/get-up kick, 34,000 VSyncs | Snake dies at 26,673; Liquid has 4 HP after 54 damage events. No completed handoff. |
| `rex-entry04` | Experimental two-punch controller loaded from the authentic story 277 entry, 18,000 VSyncs | Snake dies at 6,895; Liquid has 42 HP. Experiment discarded; frozen source/executable retained locally. |
| `rex-entry05` | Return toward the original arena centre while Liquid climbs | Snake dies at 26,067; Liquid has 23 HP. |
| `rex-entry06` | Also avoid the roundhouse strike window | Snake dies at 25,449; Liquid has 43 HP. |
| `rex-entry07` | Closer punch range, reloaded story 277 entry | Snake dies at 9,249; Liquid has 6 HP. |
| `rex-entry08` | Also sidestep the full charge strike window | Snake dies at 10,033; Liquid has 9 HP. The input sequence first differs from the preceding run at VSync 8,905; the 150-HP charge is avoided, but subsequent edge exchanges still kill Snake. |
| `rex-entry09` | Also send D-pad Up during Snake's confirmed climb action | Session closes normally at 6,368 VSyncs / 6,364 samples; incomplete encounter, no observed native exception. |

The user then explicitly stopped automated encounter tuning and reserved the
playthrough for themselves. These controller experiments are not outstanding
scene-code implementation requirements. No further gameplay runs are scheduled.

The strict replay of `rex-entry02` exports the original first-fight map-entry
snapshot, rather than the live state after death:
[`liquid-entry.mgssave`](../.local/recovery/s18a/rex-entry02/liquid-entry.mgssave).
Its 2,624-byte payload has a valid CRC, Normal difficulty, story 277, attempt
count zero, and entry health 640/768 before the original script refills it.
SHA-256 is `67642948400140552066ed26d4a49afea3dcd8967848ca5fafd84ba6fbbf3868`.
It allows further first-encounter checks without replaying the REX rooftop
cinematics or inventing a new incoming state. Its reload timing differs from
the complete story 259 sequence, so the latter still needs a passing fight.

The diagnostic controller avoids Liquid's original get-up kick: action 23 emits
its strike at actor tick 32. It sends retreat input during actions 21/22 and
through tick 33 of action 23, then resumes attacking. The standalone probe test
checks four retreat directions, stopping distance, input recovery, read-only
boss state and the original victory/handoff gates. It also checks charge-side
selection and D-pad Up delivery during Snake's original `800D01D8` climb routine,
which accepts input despite setting `PLAYER_ACT_ONLY`. This changes only the
automated player; no Liquid or Snake gameplay routine was changed. The final
build passes all 146 CTest suites; first-party scoped scans have no findings,
with cppcheck unavailable. These experiments do not prove first-encounter
completion. The user's playthrough is the next gameplay acceptance pass.

## Action timer repair and full encounter

The full encounter exposed a lost callback argument in `liquid_800CC2A0`.
Recovered C cast the primary action to a one-argument function and also declared
the secondary action with only one argument. Both original calls supply the
actor and the action's pre-increment timer: `800CC2FC` loads primary `a1` from
offset934 and `800CC340` loads secondary `a1` from offset938. The timer fields
are incremented before the respective callback executes. Typed two-argument
calls now preserve this ordering, including the existing null-primary default.
The change is reproducible through `patches/mgs-liquid-action-timers.patch`.

Before this repair, the same controller strategy landed hits but Liquid stayed
at255 health, did not attack correctly, and the original countdown expired.
Afterward, both actors exchange damage and the authored victory callback runs.
Private artifacts are `build/liquid-fight/run01` (before), `run02` (initial
repair), and `run03` (strict initial inventory). The latter records7,196 input
samples over7,200 VSyncs, reaches victory handoff at6630, and renders the following
Meryl cinematic with English text. The unpaced recording clock is diagnostic;
it does not establish real-time audio or presentation performance.

`tests/fixtures/s18a_complete_fight.cdb` supplies only the incoming Normal
story277, prior-attempt count1, life/max768, and absent earned bonus items.
The health cap is authored by the earlier `s15c` life-up; `s18a` itself refills
life from that cap. `--probe liquid-fight` then only reads state and sends
movement/Circle through the virtual SDL controller. It never writes health,
damage, countdown, positions, victory, or stage transitions. Its success check
requires the initial contract, observed damage, victory story and loaded handoff.
The debugger fixture is required to reproduce these raw diagnostic recordings;
they are not standalone saved sessions.

The subsequent hazard-output audit corrected a second issue in Liquid's climb
action: its recovered local held one vector, while the original reader writes
two. The [audit and 840 original-MIPS comparisons](HZD_OUTPUT_AUDIT.md) verify the
original allocation and preserve the climb behavior. With both repairs applied,
`build/liquid-fight/final-retry` repeats the complete Normal victory. Its recorded
7,196 inputs replay through all 7,200 VSyncs with matching state and an identical
final screenshot (SHA-256
`bc09e3b05071ae867f46bf1970546065fedc87eb21eee808fa0f4a1c6f34d812`).

The earlier incoming `d18a` story275 fixture reached the fight, but its controller
died before defeating Liquid. An experimental defensive strategy instead ran
out of time and was discarded. These were automated-player limits, not passing
connected encounters. The authentic REX checkpoint attempts above supersede
that fixture for incoming-transition evidence. None is a human playability claim.

## Connected garage handoff

The frozen `final-retry` executable, symbols, and exact `fight.cdb` fixture also
ran a longer [recording](../.local/recovery/d18-stages/liquid-garage01/input.mgsinput)
through the original post-victory scenes into **`s19a`**. Its first 7,196 input
and state records match the previously verified fight byte for byte. The run
finished normally after 40,000 VSyncs and 39,996 input samples, with the Liquid
probe passing. The recording's [input inspection](../.local/recovery/d18-stages/liquid-garage01/input-summary.json)
found no button presses anywhere in `d18a` or `s19a`.

The original Meryl branch plays `s2603a0.dmo` at story 279, runs the 141.12 Codec
call at story 281, then plays `s2603c0.dmo` at story 282. Its `sub_FCF7` callback
sets story **283** and calls `sub_E493`, which loads `s19a`, map `7df9`. The
garage script then restores current life from maximum and supplies its original
starting position. No post-fight story, callback, health, or transition fixture
was applied.

The earliest fully loaded garage boundary was sample 25,164 at VSync 25,168.
A derived prefix [replayed successfully](../.local/recovery/d18-stages/liquid-garage01/replay-console.log)
through **25,165 samples / 25,169 VSyncs**, then exported an authentic
[map-entry checkpoint](../.local/recovery/d18-stages/liquid-garage01/s19a-start.mgssave).
Its original 2,624-byte payload passes CRC validation and contains `s19a`, map
`7df9`, story **283**, Normal difficulty, health **14/768**, zero completions,
and absent earned Stealth/Bandana; [the checkpoint report](../.local/recovery/d18-stages/liquid-garage01/checkpoint.json)
records its hash and fields. The stored zero spawn coordinates precede the
garage script's original positioning and health restoration; the live recording
ends there at 768 health.

This extends the supplied retry encounter into an authored garage entry. It
does not establish a New Game campaign lineage or completion of the garage.
Recording and replay used private memory-card directories. Replaying the fight
prefix still requires its documented incoming debugger fixture; loading the
exported checkpoint requires only the original two discs and no new gameplay
fixture. The new checkpoint is ready for a separate garage route test.

## Recovery and earlier checks

The native Liquid implementation contains 227 recovered routines plus typed
actor data, camera state, motion tables, routes, and callback tables. It compiles
without warnings under the Windows x86 native options. Both `s18a` and `s18ar`
are selected, with native Snake18, LensFlare, countdown and 16 named constructor
bindings. Compilation is not a gameplay claim.

The source evidence is Disc 2 `s18a/4b9b.b`, 135,620 bytes at stage archive
offset 52,033,536, SHA-256
`4f605b802aef5c69ce4cc875165d41139acde9af1e9fdf419d0e4cee2bc7087e`.
The original actor allocation is `0xA4C` bytes. Native assertions preserve its
strike target, action callback, eight update slots, and sound-list offsets.
The primary recovery spans original addresses `800C5108` through `800D0F24`,
excluding the separately recovered countdown module.

Two decompiler omissions required instruction-level recovery: the 30-entry
action dispatcher at `800C736C` and the directional branch table at `800CCA88`.
Both now use C callbacks/control flow rather than PS1 callable addresses.
The shadow constructor passes the original four-short joint aggregate by value;
matrix stack aggregates use complete native `MATRIX` objects. Model and motion
names remain the original `liquid` and `lqd_18a` resource identifiers.

`mgs_liquid_leaf_test` passes 7,680 comparisons with original-MIPS execution:
60 complete state routines, each with 128 boundary-state inputs. Each comparison
checks all 2,636 actor bytes, 64 bytes of shared voice state, and meaningful
query return values. Inputs cover action completion, damage modes, distance
thresholds, player stance/action flags, health boundaries, and frame phases.
These checks cover state updates; they do not cover every action, camera path,
constructor, or a completed fight on their own.

The missing 76-byte BlackSmoke actor is also implemented. It parses up to four
authored positions and preserves each original eight-tick emission phase. Its
existing shared animation descriptor and 63-byte script match the original
Liquid overlay. It remains on the normal asset/animation interfaces.

All 581 identified function ranges in `s18ar` have identical instruction bytes
to `s18a`. The 33 differing bytes are alignment after the 15-entry demo motion
table, NUL-terminated strings, or terminated animation scripts. Their locations
are recorded in [liquid_variants.json](data/liquid_variants.json). Both variants
share native code and load their own original assets and scripts.

The story277 fixture changes only the incoming story variable. The original
script creates Liquid and Snake18, supplies the pose and health, and runs the
introduction. A 1,800-VSync run renders dialogue without a native exception.
A longer run reaches the end of the introduction and releases control around
frame3747. Runtime checks exposed two original low-memory assumptions in Snake18;
the native port now avoids the pre-allocation laser-sight write and the unused
wall-pointer read when no wall direction exists.

The separate retry fixture also supplies the original prior-attempt count of
one. The original script chooses its shorter retry introduction. Virtual input
moves Snake and reaches rooftop edge/climb behavior. That path exposed a stack
overwrite: the original hazard query writes two vectors, while the recovered
caller allocated one. The native caller now provides both vectors. A subsequent
1,800-VSync retry run completed without a native exception and traversed three
edge/climb actions. The generic movement probe reports incomplete because Snake
ends hanging rather than ready for normal movement; it is not a fight-completion
test. This earlier result is superseded for fight completion by the dedicated
Normal encounter above. `s18ar` still has build evidence but no runtime check.

A separate no-input fixture follows the original `d18a` story-275 cinematic into
`s18a` over 7,200 VSyncs. Its authored callback creates Liquid, Snake18 and the
countdown. See [cinematic transition evidence](D18_CINEMATIC_VALIDATION.md).

The source scan has zero errors or fixable warnings after formatting. Twelve
nonfixable function/file-size findings remain in recovered original action and
state code. Original images, extracted overlays, and private analysis databases
remain outside the distributable source tree.

## Dispatcher regression against original instructions

[mgs_liquid_dispatch_test.c](../tests/mgs_liquid_dispatch_test.c) adds 864
comparisons with the retail dispatcher. The tested `800CC2A0..800CC488` range is
122 instruction words, byte-identical to Disc 2 `s18a/4b9b.b`, with SHA-256
`97cc1108b38667ec58ef90233e64c5e388062b5b78166a3af45b1e855897e0d3`.
[reference_liquid_dispatch.py](../tests/reference_liquid_dispatch.py) executes
those original MIPS instructions in a private resident-plus-overlay image.
Only synthetic states, hashes and ordered call traces enter the fixture header.

The native test extracts the complete dispatcher plus `liquid_800CC1F0`,
`liquid_800CC278` and original `GV_NearExp2`; it does not implement another copy
of their logic. It compares all 2,636 actor bytes, both 72-byte targets, the
72-byte object header, return value, and action/adjustment call traces. Native
pointer identities are normalized before comparison. Action callbacks and the
external Snake adjustment boundary are controlled test doubles on both sides.

Cases cover zero, positive, negative and signed-wrap timers; null-primary default
selection; absent/present secondary actions; primary callbacks that reset timers
and replace or remove the secondary callback; player target flags; invincibility
and capture resets; every dispatcher gravity mode; grounded state and signed
16-bit position/velocity truncation. The trace observes both callback arguments
and the already-incremented stored timers, so incorrect ordering also fails.

All 864 cases pass the fixed source under Win32 `-Wall -Wextra -Werror`. Restoring
only the old one-argument calls in a private extracted copy fails case zero with
both actor-state and callback-trace mismatches, exit code 1. The test executable
is named `mgs_liquid_action_test.exe` to avoid Windows' installer-name heuristic
for unmanifested executable names containing `patch`.

A follow-up cast audit found no second confirmed dropped-timer call in the
inspected earlier boss dispatchers. Mantis, Meryl07b and Ninja already pass their
explicit timer arguments. The `s03d` Zako update-slot cast is genuinely
one-argument: original `800D0F9C` calls the slot and its delay slot sets only
`a0=work`; the native table contains one-argument functions. Selected Snake18
uses a typed two-argument call; its older unselected wrapper also retains both
arguments. The cinematic `VoidMakeChara` casts preserve the explicit argument
lists and erase return type; they are not evidence of the Liquid failure.

Scoped scans of the four new regression files score 100 with no findings after
Python formatting/import cleanup. Reference and generated-data files excluded
by the normal scan were additionally checked as byte-identical temporary copies.
The installed C/C++ scan lacks cppcheck and clang-tidy.
