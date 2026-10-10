The native REX encounter now completes both Normal-difficulty damage phases
from the declared entry fixture, survives, and follows the original victory
script into `d18a` and the `s18a` rooftop sequence. Its 17,996 recorded inputs
strictly replay through all 18,000 VSyncs without the controller probe. This is
encounter validation, not a connected New Game campaign or a human playtest.
The supplied Integral disc scripts and recovered actor rules are recorded below.

## Script progression

`s17a/ea54.g` and `s17ar/ea54.g` are identical. Story word `$w:00000A` and encounter
word `$w:00040E` serve different purposes:

| Encounter word after script execution | Original action |
| --- | --- |
| 1 | Construct REX and Snake for the radar fight; story is 255. |
| 2 | Run `sub_BF95`, the first intermission; create two Stinger pickups. |
| 3 | Run `sub_0500`, the Ninja/REX scripted actor sequence. |
| 4 | Run `sub_9A0D`, the next cinematic. |
| 5 | Run `sub_0501`, recreate REX for the cockpit fight; set story to 257. |
| Above 5 | Run `sub_9D76`, the victory cinematic. Its `sub_0520` callback sets story to 258 and calls `sub_45CF`, loading `d18a` or `d18ar`. |

The actor's damage-completion callbacks execute `sub_1E04`, which sets the restart
flag and calls the original `restart` command. The next execution of the main
procedure advances the encounter word. The preserved `RexDefaults` structure
carries the destroyed radar and remaining cockpit health across these restarts.
Starting directly at story 258 does not exercise either fight.

## Damage and controller contract

The script sets radar and cockpit health to 1500 on Very Easy/Easy, 1800 on Normal,
1950 on Hard, or 2100 on Extreme. `kojo/mgrex.c` allocates the radar target first;
after its destruction the later fight uses the cockpit target. The active target
normally has `TARGET_POWER | TARGET_SEEK` (`0x14`). After damage it spends 60 actor
updates as `TARGET_AVAIL` (`0x01`), temporarily preventing another hit and lock.

These target routines do not explicitly restrict damage to the Stinger weapon
identifier. The Stinger supplies the useful homing attack against the elevated
weakpoints. The original sight publishes `target_800BDF00`; the missile actor
steers toward that target. `OP_ShootStinger` triggers on **Square release**, and
`weapon/aam.c` permits only one live missile plus its 30-update firing cooldown.
The probe therefore aims with D-pad input, waits for the actual weakpoint lock and
damage-enabled target, then presses and releases Square. It observes ammunition
consumption and health changes; it never invokes the weapon or damage callbacks.

The first phase's vision can be blinded by Chaff; the later phase checks the
stun-grenade status instead. These are original branches in
`RexFunc_800E3C7C`. Separately, the missile actor's `Steer` routine checks Chaff
in both phases before updating its aim from Snake. Damage callbacks can refresh
REX's stored aim even while its vision is disrupted. Neither grenade cancels
every attack.

The retained probe uses finite Stinger ammunition, Chaff in both phases, Body
Armor and Rations. It no longer spends time changing to Stun grenades. It
sidesteps when disruption begins and after a nonfatal cockpit hit, using the
original R1 weapon toggle, then re-equips and aims again. Its waypoint maintains
enough horizontal separation for the original Stinger's ±512-unit (±45°) pitch
limit without always retreating farther into missile range. It repositions if
REX subsequently approaches beyond that aiming limit. Encounter phase changes
clear pending movement and firing commands. After a knockdown it presses Cross: the
original `sna_knockdown_check_getup_80056A1C` requires a fresh button press.

The item policy equips Body Armor. When missing at least 256 HP it opens the item
menu, selects a finite Ration, and presses Circle. The original
`menu/item.c:item_use_check` heals 256 HP on Normal and consumes the item. The probe
then reselects armor before closing the menu. With no Rations left it keeps armor
equipped. `UpdateLife_8004F6E8` halves
damage only for the original `a_mode == 1` attacks while armor is equipped; it
does not make Snake invulnerable. The original `s08a` script offers Body Armor
as item 8 at `(-1750,0,8250)`.

The stage's repeating `sub_2C10` procedure supplies Stinger ammunition, Chaff,
stun grenades and Rations under its inventory/proximity conditions. Among the
Stinger pickup coordinates are `(16500,0,-25000)`, `(16500,0,-5000)` and
`(-16500,0,-5000)`; the first intermission creates two additional five-missile
pickups near `(-16500,0,26250)` and `(-15750,0,27000)`.

## Explicit integration fixture

[s17a_complete_encounter.cdb](../tests/fixtures/s17a_complete_encounter.cdb) supplies
story 255 and encounter word zero before the original stage script executes.
Position `(378,1104,279)`, heading 2048 and standing stance come from `d16e`
procedure `sub_E2B2`. Use Disc 2, stage `s17a`, map `0x7df9`, and the `rex-fight` probe.

The finite inventory fixture selects Normal difficulty, health/max health 768,
35 Stinger missiles with capacity 35, nine Chaff and nine Stun grenades, each with capacity 27,
five Rations with capacity five, and one Body Armor. The
health cap is the original `s15c/sub_9E63` post-Vulcan life-up value; that stage's
`sub_8A59` Normal branch specifies the ammunition and ration capacities. Equipped
weapon and item start as None. The probe selects them through the original menus.
This is a declared incoming-state fixture, not a recorded campaign save. It makes
no later writes to health, targets, inventory, progression, actor state or position.

`src/mgs_rex_probe.c` requires observed damage to both original 1800-HP weakpoints,
their destruction, encounter phases 1 through 5, consumed player missiles, and
the authored `d18a`/`d18ar` load at story 258, or its immediate startup advance to
259, before reporting success. Death,
unexpected entry values or a destination load without those observations fails.

`tests/mgs_rex_probe_test.c` checks aim directions, Square press/release timing,
lock/immunity/live-missile restrictions, original inventory-menu button output,
Chaff throw/release in both phases, armor/Ration selection, knockdown recovery, and rejection of
incomplete progression.
It verifies that the helper leaves
synthetic game variables and actor structures unchanged. These are controller
policy tests using synthetic observations, not boss-fight completion evidence.
The grenade wait counts only unpaused actor ticks: `GV_Time` continues while an
inventory menu pauses the level-5 grenade actor. The focused regression advances
1,000 paused ticks without shortening the wait, rejects duplicate reads of one
tick, then expires after 180 unpaused ticks. Removing only the pause guard fails
that regression; this corrects the probe, not the game clock or grenade code.

Original decoded scripts and overlay analysis remain under ignored
`.local/recovery/{s17a,s15c,cinematics}`. See [REX recovery](REX_RECOVERY.md) for the
separate original-MIPS comparison coverage and existing runtime limits.

The first 3,600-VSync run of this probe used a stationary shooting tactic. Eight
real Stinger missiles depleted the radar's 1800 HP and the original callback
advanced through encounter phases 2 and 3. It consumed all five Rations, and the
run ended during the Ninja sequence with 256 player HP. This establishes the
first damage phase only. Its log is `build/rex-probe-audit/rex-second3600.log`;
the subsequent tactics are recorded below.

A movement-only attempt (`rex-recovery12000.log`) recovered from real knockdowns
but died during the radar fight. Chaff with stationary radar aiming
(`rex-chaff14000.log`) advanced through phases 1–5 and inflicted 1,664 of the
cockpit's 1,800 HP before death. Adding movement to the radar phase
(`rex-combined14000.log`) consumed more supplies and also failed. None of these
runs is a completion result. An armor policy that waited until low health before
equipping Rations also failed: a subsequent lethal hit arrived while armor was
equipped.

The earlier run, `build/rex-probe-audit/rex-clock14000.log`, uses the corrected
unpaused grenade wait and manual Ration consumption. It observed all five
scenario phases, 1,800 radar damage and 768 cockpit damage, then the original
player death. Twelve Stinger missiles, three Chaff grenades and all five Rations
were consumed. The helper reports failure and does not retry or grant supplies.
The run reached its 14,000-VSync limit, captured the original Game Over screen in
`rex-clock14000.bmp`, and exited with the probe's failure status 1. There was no
observed native access violation. The best earlier result remains
1,664 cockpit damage with 136 HP left; it is not promoted to a completion claim.

Two subsequent 18,000-VSync attempts are preserved in
`.local/recovery/s17a/fight01` and `fight02`, each with its own copied executable,
entry fixture and 17,996-sample input recording. The first replaced the fixed
evasion waypoint with a retreat relative to the weakpoint and healed before
moving; it inflicted 1,800 radar and 512 cockpit damage before death. The second
added the finite Stun inventory above, gated the initial grenade on an active
weakpoint, and used the original Chaff/Stun disruption signal before a single
sidestep. It reached the cockpit with 640 HP and two Rations, but inflicted only
640 cockpit damage before death. Both correctly exit with probe failure.
Their recordings require the corresponding debugger entry fixture; they are
not standalone campaign replays. Tests cover the new startup, disruption,
retreat and grenade-wait policies, including rejection of inherited 99-Stun
debug inventory. Only the test controller and declared fixture changed.

`fight03` added cockpit Chaff but retained frequent Stun changes and evasions
after radar hits. It dealt only 384 cockpit damage before death. `fight04`
removed Stun changes and adjusted spacing; it reached 1,024 cockpit damage but
stalled at the Stinger pitch limit when REX walked closer. These failed attempts
remain preserved with their own executable, fixture and recording.

## Completed Normal encounter and strict replay

`.local/recovery/s17a/fight05` contains the first complete run. The retained
controller detects the pitch limit and clears movement/fire state at phase
changes. The original radar loses 1,800 HP, the scenario advances through phases
1–5, and the cockpit then loses 1,800 HP. Snake consumes 24 of 35 Stinger rounds,
eight of nine Chaff grenades and all five Rations; Stun grenades remain unused.
Snake survives with 640/768 HP. No inventory, health, damage or progression
writes occur after the declared entry fixture.

The recording enters `d18a` at VSync 14,530 / story 259 and `s18a` at VSync
15,975. The controller uses the original Start/Cross inputs during REX
intermissions and Codec; after recognizing victory it sends no further input.
At 18,000 VSyncs the rooftop confrontation is still a cinematic, not a completed
Liquid fight. A separate strict replay passes every one of the **17,996 input
samples** and has a byte-identical final screenshot. Replaying requires the
recording's copied `fixture.cdb`, because the REX entry fixture is external to
the input-session format.

The replay exports an original CRC-valid `s18a` map-entry checkpoint, story 259,
Normal difficulty, Disc 2, map `7df9`, health 640/768. Its SHA-256 is
`9bd689bb43ff22b5913a4c846d5675f33b1ba11bdd7b2e3c24639a678556b03f`.
The original outgoing script has removed ordinary equipment. Stealth is -1 and
Bandana is zero; neither is selectable (`menu/item.c` requires a positive item
value). This checkpoint preserves the actual REX handoff and needs no debugger
gameplay fixture to load. Reload and completion of that first Liquid encounter
are the next connected-progression checks.

Local evidence includes `console.log`, `replay-console.log`, `input.mgsinput`,
`rex-to-liquid.mgssave`, `rex-to-liquid.json`, matching `frame.bmp` / `replay.bmp`,
and a hashed `manifest.json`. The run uses unpaced presentation with the
recording clock, so it is not real-time audio/performance evidence.

The focused probe/helper/terminal suites pass. Isolated negative controls that
remove pitch-range recovery, phase reset or cockpit Chaff are rejected by the
new tests. Those test executables also compile with `-Wall -Wextra -Werror`.
First-party Aislop scores 100; cppcheck is unavailable. No recovered REX gameplay
source was changed to accommodate the controller. The alternate `s17ar` variant
and entry from a connected New Game campaign remain unvalidated.
