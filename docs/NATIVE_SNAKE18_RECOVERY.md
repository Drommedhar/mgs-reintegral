# Snake18 controller recovery

The Snake controller used by the final confrontation and its cinematic stages now has native C implementations for all 160 routines in the original controller range. Eighteen translation units and one shared header replace the partial upstream source's remaining assembly blocks. Stage integration and runtime validation are tracked separately; compilation and isolated logic comparisons do not establish a playable final fight.

## Original evidence

The input is the user's Japanese Integral disc 2. The `d18a` overlay `cb93.b` is 97,756 bytes at STAGE.DIR offset 4,702,208, loaded at `0x800C3208`. Its SHA-256 is `c388e19be2811a05075a0da664b5b4264040ecd7e2f6eb6cd761d8e579c35103`.

The controller occupies `800CABEC..800D4F20`; its constructor is `800D4E94`. In the `s18a` overlay, the corresponding range is `800D5464..800DF798`, with constructor `800DF70C`. Across that range, all 900 changed instruction words are address relocations. Opcodes, register fields and branch structure match. Code addresses move by `0xA878`, initialized data by `0x020C`, strings by `0x9540`, and BSS by `0x9458`. This supports sharing the recovered controller between these overlays.

The original constructor allocates `0x940` bytes. The native x86 structure includes the tail fields missing from the partial upstream declaration and checks that complete size at compile time. Motion packs, callbacks, equipment constructors, vibration sequences and target definitions use native typed pointers instead of original RAM addresses. Primitive setup uses the native GPU packet layout. Script options are evaluated in their original order.

Recovered functions retain original address names for comparison. Existing recovered C was retained where practical, and missing routines were reconstructed from typed decompilation checked against original instructions. Two functions previously declared `void` actually return values used by callers: `800CB908` returns the target operation result and `800CBBC8` returns the input dispatch result. Original-execution tests exposed both errors.

## Verification

Private Unicorn harnesses execute the original MIPS code with explicit engine boundaries. Committed fixtures contain synthetic state and call outputs, not original disc bytes.

| Native test | Original routines | Coverage |
| --- | --- | --- |
| `mgs_snake18_state_test` | 22 routines in `800CD64C..800CEA84` | 352 cases, 28 state fields and ordered calls: stance, wall movement, controller input, animation boundaries, alert and movement flags |
| `mgs_snake18_target_test` | `800CB908`, `800CB9CC`, `800CBA64`, `800CBBC8` | 632 cases, 13 outputs and ordered calls: weapon flags, ammunition availability, input dispatch, attack and capture targets, and C4 placement |
| `mgs_snake18_wall_test` | `800CAEC0` | 150 cases: no-contact movement with a null wall pointer, wall flag `0x40`, angle wrapping and quarter-turn clamp boundaries |

All 1,134 comparisons pass. All 18 translation units pass the x86 Clang syntax check with `-Wall` and the project's native options, without diagnostics. These tests cover the listed logic and engine call boundaries, not complete collision, animation, rendering or combat behavior.

The source scan scores 89 with eight nonfixable function-length warnings in recovered state handlers. No errors or fixable warnings remain. The four test and fixture files score 100 with no findings. The installed scan environment lacks cppcheck. The long original handlers remain explicit pending wider state coverage rather than being split without sufficient behavior checks.

## Defined native compatibility

Original initialization calls the weapon-change handler `800CD040` before `800D4784` creates the laser-sight primitive. That handler writes the visibility flag through the still-null primitive pointer, into PS1 low memory at `0x24`. The native handler updates visibility only when the primitive exists. Its subsequent allocation and texture lookup still run and still report failure. `patches/mgs-snake18-startup.patch` records this bounded startup correction.

The original wall-steering helper reads wall flags before checking whether any wall exists. Before the first collision, the wall direction is `-1` and the flags pointer is null. `patches/mgs-snake18-wall.patch` checks the negative direction first and returns the original input angle. This equals the original result regardless of the low-memory flag value. Actual wall contact still applies the original flags and angle limits; the new comparison cases cover both paths.

The climb helper `800CC490` reserves two vectors for `HZD_GetNearVector` in its original stack frame. The initial decompilation incorrectly represented that storage as one vector, allowing the second output to overwrite a saved native register. `patches/mgs-snake18-climb.patch` restores the full output array. A debugger trace confirmed the message pointer itself remained valid and exposed the corrupted register, avoiding an incorrect message-system workaround.

The original C4 creation call at `800D2248` supplies four register arguments but does not initialize the fifth stack argument consumed by the resident constructor. Its original stack value is unverified. The native call supplies the controller's actual captured-target pointer (`f834`), matching the resident controller's current explicit constructor API. This is a defined compatibility choice, not a claim that the original unspecified stack value always held that pointer.

Actor destruction records the final player pose through the existing native player-lifetime adapter before clearing the global control pointer. This preserves the documented pre-constructor camera query behavior across actor replacement. Graphics remain behind the existing renderer module boundary.

## Integration

`patches/mgs-snake18.patch` contains only the 19 new Snake18 source/header files. It does not modify the shared linker template or stage constructor tables. The native constructor API remains `d18a_snake18_800D4E94(int name, int where)`.
