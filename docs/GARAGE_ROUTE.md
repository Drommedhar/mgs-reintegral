# Controller-driven garage route

[mgs_garage_route.c](../src/mgs_garage_route.c) implements a development probe for the original garage encounter and its handoff to `s19b`/`s19br`. It is a navigator using SDL controller input, not a gameplay replacement. The Normal/Meryl route now passes from an authentic post-Liquid checkpoint through walking, ignition, boarding, drum explosions, gate destruction and the authored escape-stage arrival. The complete recorded run also passes strict replay.

The host calls `MgsGarageRouteInit()`, then `MgsGarageRouteInput(frame, player_ready, &heading)` through the existing virtual-controller path, and finally `MgsGarageRouteFinish()`. Heading is the same world-space heading used by the dock probe; `-1` means no analog movement. The returned mask supplies ordinary D-pad and Square inputs after mounting. CMake and command-line mode integration belong to the host.

## Incoming state

The verified Liquid continuation produced a real map-entry checkpoint at `.local/recovery/d18-stages/liquid-garage01/s19a-start.mgssave`: 2,624 bytes, SHA256 `2d4d8f4a37956e3f42c40c807f0112da6bbe7cebbacde86ed214d578195c8eb2`. Its original save payload contains story **283**, map `7df9`, Normal difficulty, health **14/768**, and no earned Stealth/Bandana. The low current health is the result of the preceding fight. No health repair is needed: the original garage script restores current health from maximum after creating Snake.

This corrects the distinction between authentic entry and the earlier direct `story284` smoke fixture. Retail `d18a` procedure `sub_FCF7` sets story 283 and calls `sub_E493`, which chooses `s19a` or `s19ar` from the resource-variant flag. The garage's `story != 284` block is empty. This probe requires the authentic 283 entry, Normal/768 caps, and no bonus-loadout enablement. It changes none of those values.

The original garage main procedure selects map `7df9`, puts Snake at `(15500,-500,-3000)` with heading 3200, initializes garage phase `$w:0001EA` to zero, and releases its scripted pad lock at tick 190. At that point it starts the original 600-second countdown. Three authored ration pickups remain available; the probe neither grants nor equips them. The incoming save's zero position fields are expected because stage startup supplies the pose.

## Authored navigation and interactions

The private decoded `s19a` scenario is `.local/recovery/s19a/scenario.gcl`. The route coordinates come from the user's original `cb81.h` hazard resource: Disc 2 `STAGE.DIR` offset **53,927,572**, size **5,808**. Its format is defined in [fmt_hzd.h](../vendor/mgs/source/include/fmt_hzd.h).

| Event | Original trigger / condition |
| --- | --- |
| Approach companion | `game1`, hash `4773`: X 4500..6500, Z -5000..-1500, Y 0..2000 |
| Companion sequence | Script sends message 1 to the Meryl/Otacon demo doll. Its callback `sub_9F8A` sets phase 1, then schedules ignition message `de32` after 60 ticks. |
| Engine ready | The real companion animation sets `GarageIgnition=1`. The jeep calls `sub_63F6(1c8e)`, which sets phase 2. |
| Board | `move_jeep2`, hash `39de`: X -6000..-3500, Z 1500..2500, Y 0..2000. `sub_BC39` acts only in phase 2, sends the original boarding animation/move messages, then message `b4ac` and phase 3 after five ticks. |
| Clear exit | Shoot a drum; its explosion callback `sub_15AB` sends jeep message `89ce` and advances phase 3 to 4. The actual blast breaks the gate. |
| Leave garage | Scripted jeep driving crosses `fade_out`, then `MOVE_19b`, hash `be7e`: X -4500..3500, Z -16500..-13250, Y 0..4000. `sub_CA4F` fades for 28 ticks and invokes `sub_E9CF` after 30. |

The walking waypoints follow the hazard's connected corridor and ramp zones 3–13, then parking-floor zones toward the second boarding trigger. The navigator waits outside that trigger until the engine-ready phase, so it does not consume the enter event too early. The alternative boarding trigger, `move_jeep`/`61cd`, lies at the same X range and Z 4000..5000.

The mounted [Snake controller](../vendor/mgs/source/overlays/s19a/props_snake.c) reads D-pad/analog yaw and Square from `GV_PadData`. Its real firing helper `Garage_800DA8A0` calls `NewBullet` without consuming the on-foot weapon inventory. Ordinary non-rifle bullets have damage 64; drums begin at 150 health. The [gate](../vendor/mgs/source/overlays/s19a/props_gate.c) opens from blast attack mode 2, so shooting the gate directly is not a substitute for the [drum explosion](../vendor/mgs/source/overlays/s19a/props_drum.c). No script condition requires killing every guard.

The navigator also observes live guard homing targets. If a closer guard occupies the drum's original automatic-aim cone, it aims at that guard first using the same directional/Square input. This changes no target or damage state. A recorded firing pulse is a requested shot; the actor's normal damage response can suppress actual bullet creation.

## Mounted-aim source correction

The original controller calls overlay routine `800DF2F8`, whose 652 instruction bytes match the extracted retail `s19a.b`. That function implements `RotMatrixZYX`. The recovered native call incorrectly used `RotMatrix`, which has a different multiplication order. With roll zero, the original forward vector's Y component is `-sin(pitch)`; the incorrect call used `-cos(yaw)*sin(pitch)`. This attenuates or reverses vertical aiming as the gun turns. The correction changes that one call to `RotMatrixZYX`.

[reference_garage_aim.py](../tests/reference_garage_aim.py) executes those original MIPS instructions for 520 signed pitch/yaw/roll combinations, including the captured mounted angle `(19,764,0)`. No rotation implementation is substituted during original execution. Instruction SHA256: `3879c490689fd745672fbef0ec0a938885f12ca2e262c671501c022cdd242a51`.

[mgs_garage_aim_test.c](../tests/mgs_garage_aim_test.c) compares all 520 matrices with the real native SDK. It then exercises the extracted **live controller matrix block**, the complete live `Garage_800DA8A0` firing helper, and real DG/GTE transformations for three parent matrices: 1,560 gun/muzzle/bullet-step compositions. The expected compositions are calculated independently from the MIPS-produced matrices. Sound, casing and bullet allocation are observed test boundaries; this is not a whole-controller, collision or damage test. The original incorrect caller fails fixture zero at `(19,764,0)`; the corrected caller passes all cases. Fixtures contain synthetic results, not disc code or assets.

Before the correction, `.local/recovery/s19a/garage-route01` recorded 5,996 input samples through 6,000 VSyncs and replayed them with strict state checks. The route walked 44,977 units across 403 moving ticks, observed phases 0–3, ignition and the real mounted actor, then died at frame 3,291 without damaging a drum. A second bounded run with guard-priority input also failed at that point. Neither run is a garage-completion pass.

Read-only debugger traces confirmed actual player bullets, correct side/map masks, and both drums' original 150 health. At tick 1,200 their centers were `(-3000,625,-3500)` and `(-2000,625,-4000)`, half-size `(550,635,550)`. A nearer guard inside the automatic-aim cone affected pitch selection; sampled bullets crossed the drum's Z range near Y 1,600–1,700, above its 1,260 upper boundary. That observation led to checking the original rotation call rather than modifying hitboxes, health or damage.

## Connected runtime and replay

With the corrected original call, `.local/recovery/s19a/garage-route03/console.log` records the same ordinary-input route passing:

| Observed original event | Game tick / host frame |
| --- | --- |
| First drum hit, health 150→86 | tick 1,198 |
| Further hits, 86→22→-42 | ticks 1,213 and 1,216 |
| First drum explosion | tick 1,217 |
| Authored phase 3→4; blast damages second drum | tick 1,223 |
| Second drum explosion | tick 1,224 |
| Broken gate and original jeep driving | frame 2,400 |
| Loaded `s19b`, live road/jeep/player, health 408, countdown 571 | frame 2,678 |

The final acceptance result includes all phases, both explosions, gate destruction, driving, arrival, 20 firing-request pulses and the original 44,977 units of foot travel. The 6,500-VSync capture run exits successfully. Its complete movie contains **6,496 input samples**; `.local/recovery/s19a/garage-route03/replay.log` reports strict replay PASS for all samples and the final `s19b` state. Movie SHA256: `bd720b6f276bd995e423bd6e372b933f756e02d8b4b779e80cb49c8cd38d6b5a`. The frame-3,000 capture `garage.bmp.003000.bmp` visibly shows the mounted player on the escape jeep in the tunnel.

These artifacts use a copied executable/PDB, original Disc 1 plus Disc 2, private card directories and an unchanged copy of the verified garage checkpoint. Fast presentation was used during deterministic recording/replay; audio output backlog messages do not establish a real-time audio/cadence failure. The route stops supplying navigation input after arrival, so this does **not** claim completion of the subsequent escape battle.

The earliest-loaded escape prefix, `escape-prefix.mgsinput`, independently passes **2,674 samples / 2,678 VSyncs**. Its SHA256 is `5b0a69e84507493ee1b3bc520dd4baf7e7a83a4831c4598070fa0f24a11cabe8`. It is a derived verified input boundary, not an original save checkpoint.

**The original game deliberately retains the garage retry snapshot across this transition.** Retail `sub_E9CF` uses `load "s19b" -n` (or `s19br`). [LoadCmd](../vendor/mgs/source/game/script.c) omits load flag `0x10` for `-n`; [gamed.c](../vendor/mgs/source/game/gamed.c) consequently does not call `GCL_SaveVar`. The [original serializer](../vendor/mgs/source/libgcl/variable.c) still contains the saved `s19a` entry. Exporting a standalone `s19b` checkpoint therefore correctly fails with `Stored map entry does not belong to the loaded stage`; no checkpoint was written and no snapshot fields were changed. Further connected acceptance should continue controller input from the genuine garage checkpoint rather than manufacture a different retry boundary.

## Acceptance and limits

The probe observes live actor and script state. It requires all garage phases **0→1→2→3→4** in order, active original guards, ignition, the mounted player actor, actual drum damage and explosion, the gate's broken state, original jeep travel past the fade-out approach, and a loaded matching escape stage with live road, jeep and player controls. It also requires at least 30 moving game ticks and 10,000 units of on-foot travel. The stage name alone cannot pass the probe.

Actor inspection is read-only. It retains the resident actor-list sentinel rather than a destroyed on-foot actor, and reacquires stage props each frame. Guards run at level 4 and are read through the original commander's registered watcher array. Props run at level 5; the mounted actor runs at level 6 and is reached through the jeep's own child pointer. Missing spent drums do not stop later gate/drive observations. Input pauses during authored control locks and the gunner's damage/death states.

No position, health, inventory, hazard, damage, script, callback, or victory state is written. This does not test a human route, every guard-combat option, both resource variants, or every difficulty. Those claims require separate runtime evidence.
