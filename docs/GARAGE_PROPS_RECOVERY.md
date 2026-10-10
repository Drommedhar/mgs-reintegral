# Garage props, vehicle, and passengers

The native garage now builds and runs its original stage-entry script. The recovered source includes the explosive drums, parked jeep, breakable gate, jeep-mounted Snake, and Meryl/Otacon passenger. Their original actor sizes are 688, 1,568, 296, 2,392 and 2,080 bytes, respectively; compile-time assertions check each layout. Six C translation units replace the missing actor implementations.

All 19 constructor-table entries are named native functions, including duplicate original entries. Both `s19a` and `s19ar` select this source. All 547 identified function ranges have identical bytes across the two retail overlays. This is a function-range comparison: the complete files differ, including string alignment and their trailing state storage. The alternate variant has not yet had a runtime check.

Drum smoke and fire reuse the REX particle implementation. Every instruction word from the two original actor ranges was compared; differences are local calls, paired callback addresses, and relocated identical source filenames. There are no differing particle-data references. The full comparison is [garage_particle_reuse.json](data/garage_particle_reuse.json).

Recovery uses complete matrix/vector objects, typed callback pointers, the original twelve-byte casing-animation script including its terminator, and correctly typed button/analog helpers. The jeep headlights use a two-vector output array. Native overlay initialization restores initialized data and clears actor state between loads. Models, motions, textures, sounds and animations retain their existing resource interfaces; the renderer still uses the documented replaceable rendering module.

The missing SDK `RotTransSV` is implemented in PsyZ. It returns saturated GTE intermediate coordinates, the original sign-extended Z/padding word and GTE flags, and accepts aliased input/output. Twenty-five boundary cases check translations, positive/negative saturation, flags and aliasing.

## Verification

- The Windows build compiles 623 game translation units and passes 56 CTest suites.
- 4,453 original-MIPS comparisons cover companion command flags, action selection, animation completion, timing, and parked-Snake input, damage and death transitions. Ordered effects and state fields are compared. These complement the guard/commander/timer checks in [NATIVE_GARAGE_RECOVERY.md](NATIVE_GARAGE_RECOVERY.md).
- The [story284 fixture](../tests/fixtures/s19a_story284.cdb) supplies only the incoming story variable. The original script supplies map and player pose and creates the gate, drums, parked jeep and commander. A 1,800-VSync run finishes without a native exception. Normal virtual-controller input moves Snake 1,286 horizontal units over 25 moving game ticks.
- The runtime log and capture are `build/cinematic-audit/s19a-story284.log` and `.bmp`. The capture shows Snake in the garage corridor and the warning timer. This run does not establish guard combat, passenger entry, driving, the transition to the escape stage, or human playability.

The seven props source/header files compile without `-Wall`/`-Wextra` warnings. Aislop reports no errors or fixable findings; four original routines retain nonfixable function-length warnings. The existing PsyZ GTE file also retains nine nonfixable complexity findings. The new GTE test and stage tables have no findings.
