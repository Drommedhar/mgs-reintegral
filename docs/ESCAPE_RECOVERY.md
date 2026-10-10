# Native escape sequence

Both `s19b` and `s19br` now link recovered C for the road, player and rival jeeps, Meryl/Otacon, mounted Snake, Liquid, scene cameras, and effects. The new [patch](../patches/mgs-escape.patch) replaces 49 assembly entries containing 6,578 original instruction words. The earlier countdown recovery supplies the remaining one entry / 319 words. No stage executes the original MIPS overlay.

The two retail overlays contain 446 byte-identical functions. Their compiled data differences are padding after string, rumble, or difficulty-table termination, so the native stages share typed data. The original maps, models, scripts, sounds, and motion data still come from the selected user disc. Detailed counts, hashes, layouts, and evidence are in [the recovery ledger](data/escape_recovery.json).

## Validation

| Test | Original-MIPS comparisons |
| --- | ---: |
| Road event sequencing, routing, and floor conversion | 2,560 |
| Road finale timing, effects, and callback dispatch | 614 |
| Companion driver gate/braking/turning states | 1,536 |
| Mounted Snake input, damage, health, and death | 793 |
| Liquid damage/state priorities, vehicle steering and speed matching | 2,560 |
| Rival jeep wall contact and two-vector hazard output | 256 |

The tests extract the live recovered functions and compare synthetic cases with independently executed retail instructions. Rendering and other engine boundaries use explicit test contracts; these tests do not constitute a complete chase playthrough. The native GTE test additionally checks the recovered fixed-point square opcode with negative and fractional inputs.

Both stage variants ran their original introduction for 1,800 VSyncs with no native fault. The [incoming fixture](../tests/fixtures/s19b_story284.cdb) uses story 284, map `7df9`, and the original garage countdown of 600 seconds; it does not set a victory or route-completion flag. The original countdown constructor receives 18,000 ticks.

The `--probe escape` test sends normal SDL controller input. Mounted aim changed **+1,824** units across 60 game ticks to the left and **-1,767** across 60 ticks to the right, then the original bullet constructor successfully created **15 player bullets**. It measures gun control rather than scripted jeep travel. The [900-frame capture](../build/movie-audit/escape284-controls900.bmp) shows the mounted scene; [the log](../build/movie-audit/escape284-controls900.log) records the input checks. An extended 3,600-frame run reached the original Game Over after input was released and guards killed Snake; [its log](../build/movie-audit/escape284-controls.log) contains no native fault.

## Finale callback verification

The [road test](../tests/mgs_jeep_road_test.c) now passes **3,174 comparisons**, including 540 finale boundary cases and a 74-step continuous finale trace. Its [reference generator](../tests/reference_jeep_finale.py) executes the original finale instructions at `0x800CDE24` through `0x800CDEE7`, inside `s19b_jeep_srl_800CDAA4`, together with the original route lookup at `0x800CEDFC`. These instruction spans are byte-identical in the two retail overlays. The test extracts the existing native `UpdateFinale` and rumble data; both matched the retail results. This adds verification of recovered code, with no gameplay discrepancy found or additional gameplay code recovered.

The original contract is:

- Route event **14**, looked up with a distance of **9,600**, starts `NewFadeInOut(2, 20)` and sets the finale timer to 1.
- Advancing the timer to **31** sends the original vibration sequences at byte offsets 0 and 20 to channels 1 and 2.
- At timer **71 or later**, a nonzero final procedure runs with **NULL arguments** while `GM_GameOverTimer` is zero. Dispatch may repeat on subsequent ticks until the transition takes effect.

The fixtures check effect ordering and arguments, game-over suppression, absent callbacks, timer boundaries and wraparound, and preservation of the remaining actor, control, and road state. The continuous trace suppresses the first eligible callback through the game-over timer, then allows it on the following tick. Negative controls that dispatched one tick early or supplied non-NULL callback arguments both failed the test.

The retail `ea54.g` scripts in `s19b` and `s19br` are byte-identical (SHA-256 `b475f62e39d2cea4b596c4d129df548c4c2d77ca88b4f216cf50680a4363611a`). They pass `sub_4CF9` as the road actor's final callback. That procedure sets story state to **286**, sends sound commands `0x01FFFF0B` and `0xFF000008`, and schedules `sub_65E3` after **35 ticks**. The latter runs the visit procedure, clears `$f:000001`, and selects `s20a` or `s20ar` from `$f:000435`, loading map `7df9` with `-s 1`.

The differential test observes the GCL dispatch boundary; it does not execute those script procedures or load the next stage. Script inspection establishes the authored handoff contract. The independent controller-driven route below now exercises that handoff in the running game.

## Portability corrections

The upstream partial declarations conflated the 0x3FC vehicle with its 0x820 companion or 0x948 gunner. Complete layouts now have checked offsets and typed state callbacks. Vector, action, sound, and camera tables have actual contiguous storage. Native primitives use full ordering-table tags.

Two startup reads relied on PS1 low memory. Distant scenery model `f6b4` has no hazard asset and is only rendered; it now has an explicit absent collision group while the twelve driveable models require their hazards. Mounted Snake receives its initial position from the already passed vehicle control before the shared control pointer is published. Neither change supplies substitute content.

The scoped vendor scan reports zero errors or fixable warnings and eleven nonfixable complexity warnings in recovered/original code. The new Liquid test and GTE test scans report no findings.

The full route exposed an additional native recovery error during rival jeep wall contact. `s19b_spark2_m_800D9C90` allocated one `SVECTOR`, while `HZD_GetNearVector` writes two. The original MIPS routine reserves separate vectors at stack offsets `0x18` and `0x20`, before the next local at `0x28`. The [collision patch](../patches/mgs-escape-collision.patch) restores that allocation and preserves the original collision correction, including its repeated subtraction from the X coordinate. The new [reference generator](../tests/reference_escape_collision.py) and 256 fixtures cover both hazard-vector writes, collision thresholds, position correction, and spark/sound effects. The existing Liquid/vehicle test now passes **2,816 comparisons**; restoring the one-vector allocation makes the new test fault. Its scoped scan reported no findings; `cppcheck` and `clang-tidy` were unavailable.

## Full route through controller input

The [escape route driver](../src/mgs_escape_route.c), selected by `--probe escape-route`, reads live targets and road state, then returns D-pad aim and Square fire commands to the existing SDL virtual controller. It follows targets through their temporary invulnerability and respects cinematic control locks. Damage, enemy deaths, checkpoint departure, road progression, and the ending callback remain the original gameplay's decisions.

The [incoming route fixture](../tests/fixtures/s19b_route.cdb) sets story 284, countdown 600, and health/max health 768 once before stage startup. Retail `s15c` procedure `sub_9E63` constructs the life-up actor with maximum 768, `sub_8A59` also sets that maximum, and `s19a` restores current health from maximum. The fixture does not grant equipment or change state after startup. Both runs used the observed default **Easy** difficulty (`GM_GameLevel == 0`); the fixture does not set Normal. The observed incoming inventory contained three unequipped rations, which were not used.

The corrected `s19b` run completed both checkpoint departures, killed five guards, passed five original Liquid damage thresholds, reached finale timer 71 with callback `4cf9` at game tick 5,209, and loaded **`s20a`** through the retail script. Snake reached the finale with **474/768 health**, after **1,012 player bullets**. The run ended normally after 15,000 VSyncs with 14,996 recorded input samples. [The route log](../.local/recovery/s19b/route-run03/console.log) and [recording](../.local/recovery/s19b/route-run03/input.mgsinput) preserve this evidence.

A [verified replay](../.local/recovery/s19b/route-run03/replay-console.log) matched all 14,996 input samples and 15,000 VSyncs, again ending in `s20a`. It saved the authentic [next-map entry checkpoint](../.local/recovery/s19b/route-run03/s20a-start.mgssave), a 2,624-byte original save payload, for subsequent ending-stage work.

The alternate `s19br` resource set also completed the full encounter and loaded **`s20ar`**. Its [fixture](../tests/fixtures/s19br_route.cdb) additionally sets the original alternate-resource flag before startup. That [run](../.local/recovery/s19b/route-run04-alternate/console.log) cleared the same two checkpoints, five guards, and five Liquid thresholds, reached finale timer 71 at tick 5,220, and finished with **432/768 health** after **1,004 bullets**. It likewise exited normally with 14,996 input samples across 15,000 VSyncs.

This diagnostic used an unlimited presentation rate together with the deterministic recording clock. It demonstrates encounter and transition behavior; it does not measure normal playback smoothness or audio quality. Its recording requires the same documented incoming fixture when replayed, because those debugger startup writes are external to the movie's session metadata.

## Connected Normal garage and escape

The `--probe garage-escape` mode composes the existing garage and escape controller drivers. Each retains its stage checks, and both must pass at completion. A [recorded run](../.local/recovery/s19b/connected-normal01/input.mgsinput) started from the authentic `s19a` checkpoint produced by the [Normal Liquid retry encounter and its outgoing cinematics](LIQUID_RECOVERY.md). It supplied no new gameplay fixture. The incoming checkpoint contained story **283**, difficulty **Normal**, and **14/768 health**; the original garage script restored health to maximum. No rations, Stealth, or Bandana were available or used.

The original garage-to-escape load uses `-n`, preserving the garage retry snapshot. Exporting a standalone `s19b` checkpoint correctly refused that mismatched snapshot. The combined run therefore continued through the real transition without a save-state substitution. Garage movement, ignition, guard spawns, mounting, both drum explosions, gate opening, and departure all passed. The loaded `s19b` entry occurred at VSync **2,677**, with **408/768 health**.

The chase cleared both checkpoints, killed five guards, passed all five Liquid damage thresholds, and reached finale timer 71 with callback `4cf9` at game tick **7,156**. The original script loaded **`s20a`** at VSync **14,088**, with **30/768 health** after **1,206 player bullets**. The [input summary](../.local/recovery/s19b/connected-normal01/input-summary.json) confirms zero non-neutral input samples in `s20a`. Both probes passed, and the movie ended with **17,996 samples / 18,000 VSyncs**, a complete footer at `s20a`, and difficulty 1.

A [strict replay](../.local/recovery/s19b/connected-normal01/replay-console.log) matched every input sample and recorded state check. The guarded exporter then wrote the authentic [s20a entry checkpoint](../.local/recovery/s19b/connected-normal01/s20a-start.mgssave). Its original CRC is valid; SHA-256 is `05eece393944bd9c302855c6c49268d5b0cc94bf207289e3e6b79f9b20ff25a4`. The [payload report](../.local/recovery/s19b/connected-normal01/checkpoint.json) records story 286, Normal, 30/768 health, zero completions/unlock, no rations or bonus items, and zero rations used. The [manifest](../.local/recovery/s19b/connected-normal01/manifest.json) identifies the copied executable, movie, startup checkpoint, and logs.

From the project directory, the normal paced runner can repeat the controller route with a fresh recording path:

```powershell
./tools/run.ps1 -LoadCheckpoint .local/recovery/d18-stages/liquid-garage01/s19a-start.mgssave -Probe garage-escape -Frames 18000 -RecordInput .local/recordings/garage-escape-normal-01.mgsinput
```

The command requires the generated local checkpoint and configured original discs. The acceptance recording and strict replay used a copied build, isolated empty cards, and a presentation-only debugger change to uncap rendering while retaining the deterministic recording clock. The paced command does not apply that change. This evidence connects the supplied Liquid retry lineage through garage and escape; it does not establish a New Game campaign playthrough or normal-rate audiovisual quality. The Normal checkpoint's subsequent credits, ranking, save and reload are recorded below; the Easy ending run remains separate evidence.

## Connected ending from the escape checkpoint

A separate [recorded run](../.local/recovery/s20a/connected-ending02/input.mgsinput) loaded a copy of the [earlier Easy escape checkpoint](../.local/recovery/s19b/route-run03/s20a-start.mgssave) through `--load-checkpoint`, with both original discs and private memory-card directories. The session metadata snapshots and hashes the checkpoint. Its inherited state was story **286**, **Easy**, Meryl, zero completions, and no completion unlock. This run supplied no new story, health, equipment, or completion fixture. The debugger changed only the presentation cap and observed stage loads; the deterministic recording clock remained active.

The retail `s20a` script defines the intervening sequence: `s2801a0.dmo` calls `sub_AAA9`, which sets story 288 and restarts; the resulting radio call to 140.85 sets story 290 and restarts through `sub_AD2D`; `s2801c0.dmo` sets story 292 and calls `sub_27B1` to load `ending`. The [runtime log](../.local/recovery/s20a/connected-ending02/console.log) records story 286 at VSync **142**, `ending` at **29,857**, both original ending states 293/294, all five credits phases, and the ranking constructor at **70,767**. The ending probe sent no input before ranking and used ordinary controller input for the save menus and PocketStation No prompt.

The original ranking procedure increased completions to **1**, set unlock **1**, granted the **Bandana**, and wrote a completed-game memory-card save. The authored save callback reached title at VSync **72,154**. All three original payload copies in that private 8,192-byte card file passed CRC validation and contained stage `rank`, difficulty 0, completions 1, unlock 1, Bandana 1, and Stealth -1; [the payload report](../.local/recovery/s20a/connected-ending02/save-payloads.json) records the values and offsets.

The run exited normally at **100,000 VSyncs**, with **99,996 input samples**, a complete movie footer at title, and every ending-probe check passing. Inspection of [the recorded input](../.local/recovery/s20a/connected-ending02/input-summary.json) confirmed that all non-neutral buttons occurred in `rank`: 182 Circle samples and 18 Right samples, first at VSync 70,800. Later title/opening transitions were the original unattended attract sequence.

This connects the completed escape encounter to its outgoing cinematics, Codec call, ending, credits, ranking, save, and title across an authentic map-entry checkpoint. It is not a continuous campaign recording from New Game. The connected ending recording has not yet undergone a separate verified replay, and the completed save has not been loaded again in this diagnostic.

## Normal ending, strict replay and earned-save reload

The authentic Normal `s20a` checkpoint from `connected-normal01` now completes
the remaining ending chain. A fresh process loaded its unchanged story-286,
30/768-health payload with no new gameplay fixture. The debugger changed only
the presentation limit; deterministic input recording retained the emulated
clock. Private empty card directories kept the user's saves separate.

The run entered `s20a` at VSync 133, `ending` at 29,848, `roll` at 41,737,
`rank` at 70,661 and title at 72,145. It observed both ending story states,
all five credit phases, one completion, the original Bandana award, the original
save write and the PocketStation No callback. All non-neutral inputs were in
ranking: 182 Circle samples and 18 Right samples. The remaining 80,000-VSync
limit includes the title's unattended attract sequence; the footer is `opening`.

All **79,996 recorded inputs / 80,000 VSyncs** then passed a separate strict
replay with every recorded state check unchanged. The earned one-block save
has SHA-256 `631c6b4392e0a2f6928064abee19e805d21d9d1a1c7936210848027ea06ad4d4`.
All three 2,624-byte payload copies pass the original CRC and contain Normal,
one completion, unlock 1, Bandana 1 and Stealth -1.
The separate replay produces a byte-identical card file, so it also reproduces
the original save output.

The existing completed-save acceptance test loaded a copy through the original
title → `abst` → `d00a` → `s00a` sequence, retained the earned item and completion
state, and observed 453 units of movement over 24 controlled game ticks. It
verified that the source and copied saves remained byte-identical. This reload
uses ordinary cinematic skip input and is distinct from the unskipped ending.

Evidence is under `.local/recovery/s20a/connected-normal01/`: `console.log`,
`input.mgsinput`, `replay-console.log`, `input-summary.json`, `save-payloads.json`,
`completed-load/` and `manifest.json`. Executable SHA-256 is
`2f63994e063a201ec1d7b1826a2a5856e78fd68678d1a87d607c0e0659129a8c`.
This extends the supplied Normal Liquid retry lineage through garage, escape,
ending, save and next-round startup across original map-entry checkpoints.
It remains distinct from a connected New Game campaign and from human play or
normal-rate audiovisual acceptance. No gameplay code change was needed.

## Remaining evidence

The full route, rival-jeep encounter, finale, and authored next-stage transition have now completed under automated controller input for both resource variants on Easy, and for the connected base route on Normal. A human campaign playthrough, normal-rate visual/audio review of the complete chase, and other difficulty/loadout combinations remain unverified. The route probe is not a claim of full-game playability.
