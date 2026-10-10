# Authored dock route

This audit derives a controller route and elevator prerequisites from the original Integral disc 1 scenario and hazards. The waypoints have static wall clearance; they do not establish a completed live route or guarantee avoidance of moving guards. The runtime probe must use ordinary SDL input and observe actual movement, script flags and stage changes.

The extracted `s00a/ea54.g` is 18,712 bytes, SHA-256 `40e6084b4cbf0c38660c3044238613ad2d7b24442aa2677530df49ef71ac66c8`. Its decoded text matches the existing private `build/debug-s00a.gcl` input. The `c661.h` hazard resource is 13,464 bytes, SHA-256 `59f9fceded13b14af6e6bbdf729f9dc1d61af78d7b13509d3b6149f8b2d0b037`. Local extraction, decoded scripts, hazard coordinates and a plan view are under `.local/recovery/s00a/`.

## Route geometry

Coordinates below are world X,Z. Negative Z heads toward the elevator. World yaw is 0 for +Z, 1024 for +X, 2048 for −Z and 3072 for −X; controller direction must account for `GV_GetPadOrigin()`.

| Waypoint | Required action or constraint |
| --- | --- |
| `(-8000,-1300)` | Move west from the normal spawn near `(-5756,-1298)`. Moving north immediately hits the crate south face at Z=−2000. |
| `(-8000,-2100)` | Approach the west pipe passage and enter crawl with normal Cross input. |
| `(-8000,-4500)` | Crawl fully beyond the pipe before standing. Keep X within about 40 units of −8000. |
| `(-8000,-8375)` | Continue north, retaining the tight X tolerance until south of the crate is fully cleared. |
| `(500,-8375)` | Cross east below the container rows. Check the nearby guard before crossing. |
| `(500,-15500)` | Follow the central aisle; guard 1467 also uses its southern portion. |
| `(500,-22500)` | Continue north through the second central aisle. |
| `(3000,-22500)` | Move east to avoid the upper puddles. |
| `(3000,-26000)` | Approach the elevator area from the side. This is exposed to guards and is not an unconditional waiting spot. |
| `(1000,-26000)` | Move toward the entrance only after the arriving guard has cleared and alert is off. |
| `(1000,-28800)` | Enter the platform, release movement, and allow the authored ascent and transition. |

The pipe spans X `[−8500,−7500]`, Z `[−3250,−2625]`; its lowest solid section starts at Y=700. Both standing and crawling movement normally use a 450-unit horizontal radius. Crawling solves the height restriction, not the horizontal clearance. The first north segment has 500 units of clearance to the crate; the east crossing at Z=−8375 has 625; the central aisles and upper detour have at least 1000; the final entrance approach has 1500. These distances were checked against the original static solid walls at standing centre Y=1104. Dynamic barriers and guards remain separate constraints.

The upper detour avoids puddles around X `[−125,1875]`, Z `[−25000,−23875]`. Avoid diverting south of the spawn toward Z=0, which reaches the water edge.

## Elevator prerequisites

Original `sub_053D`, `sub_053E` and `sub_D2B3` control the elevator. Normal first entry sets flag `$f:02002D` only after 3600 game ticks; the alternate `$f:000387` branch uses 3150. These are actor ticks and pause with gameplay, not an absolute VSync deadline. If the flag was already saved, the initial retry is delayed another 1800 ticks.

Descent starts only when `$f:02002D == 1` and alert callback byte `$b:00006C == 0`. The script creates elevator B15B at `(1000,8000,-28800)` descending toward `(1000,0,-28800)` over 450 movement ticks. Its callback stores these event hashes in `$s:000040`:

| Value | Meaning |
| --- | --- |
| `F624` | Descent started |
| `EDB8` | Bottom reached |
| `361E` | Ascent started |
| `ADBF` | Top reached |

The `liftup` trap, hash `BDD5`, occupies X `[−1750,4000)`, Z `[−30500,−27750)`, Y `[0,5000)`. Snake entering it sets `$f:03002D`; leaving clears that flag. Ascent requires all of:

- Snake remains in `liftup`: `$f:03002D == 1`.
- Arriving guard 13E8 has left `lup_enemy`: `$f:040067 == 1`.
- Guards 1466 and 1467 are outside `lup_enemy`: `$f:050067 == 0` and `$f:060067 == 0`.
- `GM_AlertMode == ALERT_OFF`; `ElevatorAct_800D8EA8` rejects start messages otherwise.

`lup_enemy`, hash `D666`, occupies X `[−1000,3000)`, Z `[−31250,−27000)`, Y `[0,10000)`. Entry/leave events maintain the three guard flags. The script retries the ascent condition every 30 game ticks, so there is no need to leave and re-enter the platform when guards clear.

Read-only `GCL_GetVar` calls can inspect private script variables with four-byte tokens: `{0x14,bit,0,offset}` for these flags, `{0x16,0,0,0x40}` for the elevator event, and `{0x12,0,0,0x6C}` for the alert callback byte. No variable writes are required.

## Guards and observations

Normal guard 1466 starts on route 20 and changes to route 13 after 450 ticks. Guard 1467 starts on route 17, which includes `(250,-8500)` and `(250,-15500)` before heading east. When the arriving guard enters `enemy_trap00`, the scenario redirects the other guards. Guard 13E8 subsequently passes through `(750,-25500)` and looks in both horizontal directions; waiting at `(1000,-26000)` during his arrival is unsafe.

Their named entries in `GM_WhereList` expose positions and `CONTROL.radar_param` without actor-layout casts. `dir` is the live sight direction, `dis` the distance, and `range` the **full** angular width. Normal half-width is 512 angle units. Normal sight distance is 4000 at difficulty ≤1, 5000 at difficulty 2, and 6000 above that; the original code also notices targets another 2000 units beyond that range. At distance below 500 the facing check is bypassed. Prone alone does not disable detection.

There is no `HZD_LineCheck` API. The original sight routine calls `HZD_OnlineHazardCheck`, but that function modifies shared scratch memory and GTE registers. Calling it from a VSync observer is not a pure observation. A probe may conservatively intersect its own local ray with the read-only wall geometry, excluding `HZD_SEG_NO_PLAYER` walls and checking interpolated vertical bounds. Omitting dynamic walls, floors and target occlusion makes such a gate more cautious than the engine's visibility decision.

## Authored transition chain

The elevated `move01A` trap, hash `6C10`, occupies X `[−1500,3750)`, Z `[−30750,−27250)`, Y `[3000,6000)`. Entering it sets story 7, disables pad/menu and schedules the next load after 150 game ticks.

The normal chain is:

1. `s00a → d00a`: story 7 selects `s0103a0.dmo`, sets story 9, then its completion callback loads `d01a`.
2. `d01a`: story 9 becomes 10 and plays `s0104a0.dmo`; completion restarts the stage.
3. The next branch sets story 12 and opens mandatory Codec `14085 / 0201013D`, mode 3; completion restarts again.
4. The next branch sets story 14 and plays `s0104c0.dmo`; completion loads `s01a` with position `(-4605,469,20452)` and yaw 1024.

The two additional scenario hashes are `a71b18fa3e86e79f5e1e7b849e49ef6e4c809a353a15d5eb34d7e552f05e95d3` for `d00a/ea54.g` and `ddab0ff0beac7e2e0212ecc26d85a71a3620bb9cf5ef9a04f268a0743985d0a3` for `d01a/ea54.g`. A route acceptance result should observe this actual progression and restored player control in `s01a`, rather than count reaching the lift or starting a cinematic as completion.

## Timing and failed-route recheck

The 3600-update permission timer is scheduled in the story-6-or-later branch after the opening Codec callback restarts the scenario (`sub_AD2D`). It does not run from process startup or from the start of the infiltration movie. `DelayCmd` passes the count unchanged to `GM_DelayedExecCommand`; the delay actor decrements once per permitted actor update. At normal 30 Hz gameplay this is about 120 seconds, excluding gameplay pauses. `GV_Time` itself advances during pauses, so elapsed `GV_Time` alone cannot prove the timer has expired. Observe `$f:02002D` directly. Sources: [DelayCmd](../vendor/mgs/source/game/script.c), [delay actor](../vendor/mgs/source/game/delay.c), [actor pause masks](../vendor/mgs/source/libgv/actor.c), and [GV daemon](../vendor/mgs/source/libgv/gvd.c).

The elevator has no call-button requirement. Boarding and the script's repeated condition checks send its movement message. Alert blocks acceptance of a new movement message; it does not stop an already moving elevator. The elevated transition trap begins at Y=3000, before the platform's Y=8000 endpoint. A successful route can therefore begin the authored `d00a` load before the final `ADBF` event is observed. Source: [elevator state machine](../vendor/mgs/source/takabe/elevator.c).

The scenario also creates an `asioto` actor with noise enabled for the `pool` hazard name. Running footsteps within these ground-level pool volumes produce `GM_SetNoise(100,4,position)`:

| Pool | X interval | Z interval |
| --- | --- | --- |
| West crossing | `[−4500,−2250)` | `[−10000,−8500)` |
| East aisle | `[5500,8500)` | `[−19250,−16500)` |
| Upper west | `[−125,875)` | `[−25000,−23875)` |
| Upper east | `[875,1875)` | `[−24875,−24000)` |

All four occupy Y `[0,2000)`. The footstep routine excludes `PLAYER_GROUND` and `PLAYER_CAUTION` from this running-noise path; crawling across a pool therefore avoids this particular noise source, but does not grant visual invisibility. The commander can send an eligible nearby guard to investigate power-100 noise within its configured 8000-unit limit. Sources: [footsteps](../vendor/mgs/source/enemy/asioto.c), [hearing selection](../vendor/mgs/source/enemy/command.c), and [guard perception](../vendor/mgs/source/enemy/enemy.c).

In `build/dock-route/route3-4500.log`, the probe reached the west crossing near `(-8032,-8303)` but drifted north while moving east. Alert was first recorded at game tick 1034, position `(-1802,-9057)`, long before elevator eligibility. That path can cross the noisy west pool. The log lacks the perception state needed to distinguish hearing from sight, so this is a plausible contributor, not a proven cause. The proposed Z=−8375 crossing has only 125 units of separation from the pool boundary: steering must retain a margin south of Z=−8500, or use crawl throughout the crossing while still checking guard sight.

Guard routes are not fixed wall-clock schedules. Noise changes their behavior, and original route commands include conditional timing. The arriving guard's route passes `(750,-25500)` while turning and then proceeds toward `(750,-20000)`. Use live positions/headings to choose when to board; do not treat `(1000,-26000)` as a safe waiting position merely because it clears walls. These findings constrain an ordinary controller route; they do not constitute a completed native dock-to-heliport run.

On normal round, the arriving guard's `enemy_trap00` entry explicitly redirects guard 1467 to route 14 and leaves guard 1466 on route 13. Route 14 stays between Z=−7500 and Z=−15250, repeatedly crossing between the centre and east aisles. Waiting for elevator arrival therefore removes 1467's earlier visits to the upper dock, but does not make the central crossing or `(500,-10500)` safe indefinitely. Guard 1466 still visits `(500,-24000)` and follows the centre aisle south to `(500,-16000)`. The arriving guard follows route 15 through `(750,-25500)`, `(750,-20000)`, and the upper east aisle. In alternate round, the same event instead sends 1466 to route 24 and 1467 to route 23. The distinct route sets must not be mixed when interpreting a replay or selecting a crossing window.

## TAS reference limits and initial input anchors

The [theenglishman all-bosses publication](https://tasvideos.org/3161M) supplies a BizHawk replay for Integral. The [author's submission notes](https://tasvideos.org/5139S) identify Extreme difficulty, Normal Round, pre-existing SRAM and an unlock code; they also describe extensive glitches and manipulation elsewhere in the run. It is useful reference material, but does not establish an ordinary stealth route or native replay compatibility.

The local `.local/replays/theenglishman-mgs-integral-all-bosses.bk2` has SHA-256 `8f433916cb219a243499f75b92f6a90d3f5333b671e53a846f37dc5733732a7a`, 313202 input rows, and a BizHawk 1.11.4 / Octoshock header with `StartsFromSaveRam True`. Its 262144-byte memory-card payload contains a port-1 save named `BISLPM-86247G:E0pBAA`, with a title identifying Normal, 00:00, Dock. Port 2 has a zeroed card image. Both the comments and subtitles entries are empty: there are no embedded stage names or stage-change frame markers.

Exact zero-based input-row anchors, using the log's declared left-stick X,Y order:

| Frames, inclusive | Left stick | Buttons | Reference use |
| --- | --- | --- | --- |
| 1485–1487 | `(128,128)` | Start | First non-neutral input |
| 1572–1573 | `(128,128)` | Circle, L2, R2 | Menu/setup sequence; preserve its SRAM and difficulty assumptions |
| 1614–2422 | `(128,128)` | Start, Cross | Sustained skip input; unsuitable for verifying the full intro |
| 2849–2951 | `(0,104)` | None | First substantial movement, mostly west |
| 2952–2961 | `(128,0)` | None | North approach |
| 2962–2963 | `(126,0)` | Cross | Crawl toggle while moving north |
| 2964–3117 | `(126,0)` | None | Sustained crawl input |
| 3118–3119 | `(126,0)` | Cross | Second toggle |
| 3120–3135 | `(126,0)` | None | Continue north |
| 3136–3161 | `(130,0)` | None | Continue north with slight horizontal adjustment |
| 3162–3263 | `(255,21)` | None | Northeast movement |

The published video was sampled independently: its early dock passage visibly uses the west pipe, followed by repeated close encounters and guard takedowns. That supports using the initial movement sequence as a reference for pipe navigation; it does not show that our later centre-aisle stealth waypoints are safe. Video time has not been synchronized to individual BK2 rows, and the input file contains no position/state snapshots. Exact elevator or stage-transition input frames therefore remain unverified. Replaying these absolute frame numbers against native loading times, a fresh card, or another difficulty would be an untested assumption. A native test should anchor to observed title/menu, restored dock control, pipe clearance, guard positions and actual stage changes.
