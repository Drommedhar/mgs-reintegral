# Escape Snake controller recovery

The native escape-stage Snake controller now implements the three remaining assembly routines in `source/overlays/s19b/takabe/jeep_sne/jeep_sne.c`:

| Original entry | Original size | Behavior |
| --- | ---: | --- |
| `800D47F8` | 298 words | Actor update, attachment motion, camera follow, health, ration use, death and visibility |
| `800D519C` | 49 words | Hit selection, target invulnerability, rumble and aim displacement |
| `800D596C` | 500 words | Analog/digital input, first-person camera, mounted-gun aim and firing, authored automatic commands |

Evidence is the Integral Disc 2 `s19b/4bbc.b` overlay at load address `800C3208`, checked against the original instruction listings. The actor retains its original `0x960` allocation and the verified `0x8D4` aim and `0x910` target offsets. Native code uses the shared, fully typed `EscapeSystem`; no PS1 absolute pointers remain in these routines.

The former split integer definitions for vectors, the animation table and one rumble sequence must be consolidated in `overlay2.c`. C permits no adjacency assumption between separate globals. The recovered action table is the original ten shorts `0,1,2,3,4,5,6,7,8,0`; the gun and body offsets are `(0,1435,-925)` and `(180,-932,-340)`.

`mgs_escape_snake_test` compares 793 synthetic cases against execution of the original MIPS routines, checking 59 state fields and ordered effect-call arguments. Cases cover analog thresholds and axis reversal, digital precedence, first-person fades, authored aim commands, firing cooldowns, forced and ordinary damage, ration difficulty behavior, death and invulnerability visibility. Geometry, engine and effect calls use identical controlled test implementations on each side; these are controller comparisons, not renderer or collision proofs. The test generator extracts the live native routines and actor declaration during CMake configuration.

The recovered source compiles cleanly. Aislop reports one nonfixable function-length warning for the original combined controller; the test sources score 100. Complete escape-stage runtime integration and manual gameplay are separate validation gates.

The first integrated escape-stage boot exposed a constructor-order dependency: the vehicle creates Snake before publishing `Takabe_JeepSystem.control`, while the recovered Snake constructor reads that global to initialize its previous vehicle position. Native initialization uses the constructor's already valid `root_ctrl->mov`. The original vehicle initializes this position to zero before creating its children. This is a defined replacement for a PS1 low-memory read, not a claim that the original address-zero bytes have been verified; later camera delta updates continue to use the published shared control.

The `escape` virtual-controller probe passed in the authored incoming-state fixture (story 284, countdown 600): 60 observed left-input ticks accumulated +1824 angular units, 60 right-input ticks accumulated -1767, and Square input created 15 player bullets by VSync 900. The probe reads relative gun aim and successful bullet-constructor returns through observations that do not change actor state. Scripted Jeep translation is excluded from success. This is automated fixture evidence, not a manual campaign playthrough.
