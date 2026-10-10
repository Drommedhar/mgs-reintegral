The `s08b` and `s08br` Ninja stages now build into the Windows executable. An automated `s08b` encounter ran for 1,800 VSyncs: the original intro released control, controller movement passed, and the captured lab scene shows Ninja attacking Snake. Neither boss completion nor a human playtest is claimed. `s08br` shares the recovered code but has not had a separate runtime test.

Recovery uses FoxdieTeam commit `f54dbb2a58adfc2755403296c9ebb653fbec277b` and the user's Integral disc 1 (`SLPM_862.47`). All 122 missing assembly blocks match the original `s08b` overlay byte for byte: 10,445 instruction words, covering 129 Ninja routines and three sphere/plasma routines. Typed C replaces the missing native bodies while the PS1 assembly path remains available. Original overlay bytes and private IDA databases stay under ignored `.local/recovery/`.

The native implementation retains the original actor layout, attack and cinematic states, callback timing, route selection, sound selection and effect behavior. Three stage constructors are bound from their original functions, allocation sizes, actor filenames and resource setup: glass at `0x800DB50C`, the blood-circle effect at `0x800D6AF4`, and blur at `0x800D8D84`. [Evidence metadata](data/ninja_recovery.json) records the exact overlay hashes and patch.

The port repairs concrete translation hazards:

- Action callbacks receive the original timer value before its increment; an incorrectly typed decompiler call had lost that argument.
- The original `0x800CE0A4` routine accepts the actor pointer, and `0x800CFC64` returns its tail-called helper's result. Upstream declarations obscured both facts.
- Three transformed shadow vertices and animation prescripts use real C aggregates, preserving their original contiguous layout.
- GPU effects use native packet fields, including the eight-byte packet header. Runtime function addresses and animation pointers use native symbols.
- Route-table scans use the actual array boundary instead of depending on separate globals remaining adjacent.

The clone actor needs one deliberate native compatibility adjustment: original `Bunsin2` initialization (`0x800D5850`) never sets its lighting-position pointer at offset `0x108`, but its update (`0x800D5814`) reads through that pointer. Both original calls and the constructor confirm a three-argument API; no position argument was lost. Windows cannot perform the original low-memory read. The native actor samples lighting at its actual clone world position instead. This is a documented behavior correction, not a verified reproduction of the console's low-memory values.

The `s08br` data translation unit is mapped to `s08b` during source selection, including overlay-state reset registration. The original files share all machine code and meaningful initializers; observed binary differences begin in string/script alignment padding and extend into the unused tail. Their published `overlay2.c` initializers are equivalent despite one string being expressed as four-byte chunks.

Validation currently consists of a clean 12-translation-unit compile, a linked optimized Windows build with 498 game translation units, and all 36 CTest suites passing. The new helper test checks 383 outputs against execution of the original MIPS instructions: 143 position-boundary cases and 240 route cases. The only emulation hook supplies the documented `GV_RandU(8)` input; route helpers execute their original instructions. These tests do not establish full encounter behavior.

The subsequent optimized integration run reached the original Ninja constructor, completed its introduction and released Snake at frame 1,090. Virtual controller Up input moved Snake 1,049 horizontal world units over 26 movement ticks and 57 input frames. The run exited cleanly at frame 1,800. The inspected capture shows the laboratory, the Ninja life meter, and the boss attacking Snake. Local evidence is `build/s08b-encounter-fixed-console.log` and `build/s08b-encounter-fixed.bmp`; the refreshed optimized build also passes all 36 CTest suites. This checks encounter startup and a short active combat interval, not the later boss phases or victory transition.

For a bounded encounter test, [the debugger fixture](../tests/fixtures/s08b_story77.cdb) restores exactly the post-demo state assigned by original `s08b` procedure `sub_CE82`: story variable 77, position `(-6378, 2304, 55)`, heading 2371 and stance 0. The original `77 <= story < 78` branch then creates Snake and Ninja. Use map `0x7df9` and `--probe stage`; the probe controls only the virtual controller. This is an explicit automated scenario fixture, not campaign progress or production startup behavior.

Aislop reports no errors or fixable findings in the recovered scope. Twelve nonfixable complexity warnings remain in the original-sized actor state machines and files. The first-party integration/test scope scores 100 with no findings. LLVM formatting and lint tooling ran; cppcheck is unavailable.

## Terminal callback verification

The existing [Ninja test](../tests/mgs_ninja_helpers_test.c) now passes **2,518 original-MIPS comparisons**: the earlier 383 spatial/route cases and **2,135 terminal/callback cases**. The new [reference generator](../tests/reference_ninja_terminal.py) executes eight original functions, comprising 288 instruction words, identical in `s08b` and `s08br`. It covers the victory dispatcher `800D2DB0`, its wait and route helpers, the sphere sequence `800D2158`/`800CFA80`, and the auxiliary callback `800D1738`. No gameplay discrepancy was found in these functions; this adds verification of existing recovered code, not newly recovered gameplay behavior.

The retail `s08b/ea54.g` script binds three distinct Ninja callbacks. The `-e` procedure `sub_39BD` sets story **78**, requests the fade and control lock, and restarts after 35 ticks; the next original script branch sets story **79** and plays the post-fight cinematic. The `-b` procedure `sub_D4E2` switches music, while `-w` procedure `sub_AEEA` sets bit 5 at variable byte `0x3D6`. The latter two are not the victory transition.

In the victory dispatcher, state 23 first waits through original helper `800D06A0`. Completion requires the route counter to be at least 3; the dispatcher sets its terminal state and calls a nonnegative `-e` procedure with **NULL arguments**, only while Snake is alive and game over is inactive. The fixtures cover the 121/301-tick wait boundaries, early action completion, route progression, absent/zero/retail callback IDs, death suppression, and adjacent states. The sphere sequence additionally checks callback timing, voice gating, construction at tick 70, and completion from tick 161 after the stream ends. The `-w` cases preserve its original distinction between voice suppression and callback dispatch.

Tests extract the actual recovered definitions and compare all **6,964 actor bytes**, return values where defined, and ordered service calls with actor timer/state recorded at each call. Three continuous traces contribute 496 steps, checking that terminal transitions stop callback repetition. Stream services, GCL dispatch, hazard lookup, and sphere construction are explicit boundaries; original timer arithmetic and route logic execute unchanged. Private negative controls that passed non-NULL callback arguments or advanced the wait one tick early both failed. The Win32 test passed independently of the shared build; enabling `-Wextra` also reports the pre-existing signed/unsigned route-table comparison in `800CEFF4`.

The three edited/generated-test source files passed scoped Aislop with no findings; cppcheck was unavailable. The generated fixture header contains only synthetic inputs and instruction-derived outcomes. This verifies callback contracts, not a full Ninja fight, execution of the outgoing GCL procedures, or the complete post-fight cinematic. Those connected gameplay checks remain open.

## Hit-driven phase transitions — 9 October 2026

The user's `run-20261009-171125-195.mgsinput` reproduces the stalled fight:
all 47,087 inputs / 47,091 VSyncs match on the preceding executable. At its
endpoint, the primary Ninja has zero health, phase 3, group 6 and action state 23.
Further punches keep subtracting health before the actor clamps it back to zero.

Three native hit dispatchers (`800CF354`, `800CF464`, `800CF54C`) had lost their
entire nonzero-hit switch bodies during the initial translation. Their original
MIPS jump tables at `800E3960`, `800E3978` and `800E3990` select group/action
transitions, damage-reaction classification, route selection, and the opening
phase's hit counter. Returning success without these writes lets damage
animations run while bypassing the recovery states that advance the encounter.
This is a reconstruction defect independent of the invulnerability option;
these gates do not require Snake to lose health.

`mgs-ninja-hit-transitions.patch` restores all three switches, including the
original no-op hit types and no-hit behavior. The same code serves `s08br`.
No new health threshold or forced phase skip is introduced. The reference is
the original Integral `s08b/479c.b`, SHA-256
`21c5534dd17e5579404b2b0b2f3c47fb324b27a363a108669e3818a3dee15ded`.

[The hit reference generator](../tests/reference_ninja_hits.py) adds 960 cases
covering every defined hit type, out-of-range values, protected action states,
game-status flags and hit-counter values. Tests compare the complete actor,
return value, global counter, and route-call order/state with original MIPS
execution. Only the two route-selection boundaries are hooked for these cases.
The old native handlers fail fixture 96; the restored handlers pass all cases.
The Ninja suite now passes **3,478 original-MIPS comparisons**. The Windows Debug
build and five focused CTests pass (Ninja, invulnerability, input sessions,
resume selection, and checkpoints); the 72-patch MGS stack verifies.

The recorded failure was reproduced, and the corrected branches are verified
against original instructions. Full connected boss completion after this fix
remains for the user's playthrough. Evidence is under
`build/ninja-phase-20261009/`. Aislop reports no errors or fixable findings;
one pre-existing vendor file-size warning remains, and `cppcheck` is unavailable.

The corrected executable also strictly replays the prefix through 39,701 inputs /
39,705 VSyncs, after the original introductory restart and before the changed hit
responses. Attempts to export the game's stored checkpoint at both the first
loaded `s08b` frame and this later combat entry are rejected: the original save
serializer still names another stage. No Ninja checkpoint was created, save
validation was not bypassed, and existing checkpoints were preserved. Automatic
last-map recovery therefore remains unavailable for this recording's Ninja entry.

### Direct Ninja retry checkpoint

Recovered a separate checkpoint from the same recording's **live entry state**,
captured read-only at `NewNinjaBoss` during a strict replay. This bypasses reliance
on the older Continue save bank without altering that bank or changing gameplay
code. The original script had already assigned story 77, map `7df9`, spawn
`(-6378,2304,55)`, heading 2371 and standing stance. The captured inventory,
script variables, area history, radio memory and play time were packaged in the
existing Integral save format, with the normal size/hash/CRC checks retained.
No story or inventory values were invented. This restarts the boss encounter;
it does not restore an arbitrary frame or the boss's mid-fight health.

Local file: `.local/checkpoints/ninja-20261009/recorded-entry.mgssave`.
SHA-256: `26174d538bf011c5c28e6818d92942386e7115f5f3c173159d54251a6563b2c3`.
The accompanying JSON records provenance and hashes of all captured parts.
Native loading restores `s08b` directly and the 1,400-VSync check reaches active
combat with Snake and Ninja visible. Stealth and bandana ownership are both 1.
The load check records 1,396 inputs and strictly replays all 1,400 VSyncs;
evidence, capture and exporter are under
`build/ninja-checkpoint-20261009/`. The exporter passes scoped Aislop without
findings. Original recordings and earlier checkpoints remain untouched.
