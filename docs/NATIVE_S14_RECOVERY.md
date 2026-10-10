# Cargo elevator recovery (s14e)

`s14e` now binds all 25 original constructor entries to native C. The guard, its actions, secondary animations, effects and decision logic are recovered; the existing Zako14 commander, elevator, crow and button actors compile unchanged. The fog actor and renderer reuse code verified against the stage's original instructions. This establishes native stage construction and scenario testing, not campaign completion or a won guard encounter.

## Original evidence

The input is the user's Japanese Integral disc 2, SLPM-86248. The original `4b1f.b` overlay is 109,628 bytes at STAGE.DIR offset 43,739,136, loaded at `0x800C3208`. Its SHA-256 is `0ad69a93f9aadf2e7b0b254cf6d39ad16c118d0af9686609b9df8ebcbed8986a`.

| Original range or constructor | Recovery |
| --- | --- |
| `800C5958..800C672C`, guard constructor `800C66CC` | Guard resource setup and actor lifecycle in `overlays/s14e/animal/zako14/core.c` |
| `800C6A34..800C9838` | Guard actions and damage handling in `action.c` and `damage.c` |
| `800C9838..800CA2E4` | Secondary animations in `override.c` |
| `800CA2E4..800CA96C` | Blood, fog, ammunition, sound and firing effects in `put.c` |
| `800CA96C..800CB22C` | Vision, alert checks and movement in `zk11aact.c` |
| `800CCB60..800CDC50` | Decision and phase logic in `think_native.c` |
| `800CF44C` | Existing `animal/zako14/zako14com.c` commander constructor |

The original guard allocation is `0xC44` (3,140 bytes), matching the recovered header on the native x86 target. Its extra health field, animation table, edge-fall checks, firing sweep, capture escape timer and phase tables differ from earlier guard variants. Those differences are implemented explicitly. The original empty action at `800C7970` is preserved as an empty action.

The fog actor's 552-byte range `800D8470..800D8698` matches s12c's `800D4074..800D429C` with 20 address relocations. The 9,348-byte renderer range `800D8698..800DAB1C` matches s12c's `800D497C..800D6E00` with 97 address relocations. Instruction operations, registers and branch structure otherwise match. The native selection therefore uses the existing `takabe/fog.c` and `takabe/libdg2.c`, replacing the raw overlay tables and 30 assembly object slots.

The decoded original scenario is `ea54.g`, 28,116 bytes, SHA-256 `70d7f6a7ed6f6f6b56e1908f079103d569292a913e50b1c4da8719059828fab9`. Its own area label is `Cargo elev.`. Branch word `var_buf+8` selects the different elevator locations and ride sequences; story number alone does not initialize the stage.

## Verification

Private Unicorn scripts execute the original MIPS routines with controlled engine boundaries. The repository retains synthetic reference outputs and native tests, not original disc bytes.

| Native test | Original entry | Coverage |
| --- | --- | --- |
| `mgs_s14_action_test` | `800C96AC` | 322 cases, 46 state fields and ordered calls: damage precedence, health thresholds, standing/walking, weapon input, firing sweep, capture timing, falling and death animations |
| `mgs_s14_think_test` | `800CDC08` | 264 cases, 36 state fields and ordered calls: alert reactions, route navigation, firing/melee decisions, timing boundaries and every authored phase/route table entry |

Both tests pass in the full optimized native build. All new game translation units compile, and the complete game executable links. Actor tests isolate logic; their boundary doubles do not validate every collision mesh, script argument or rendering path.

The eight new source/header files score 100 in the scoped aislop scan with no findings. The two generated fixture headers have nonfixable file-size warnings because they retain the complete original-execution outputs. No executable test-code findings remain. The installed scan environment lacks cppcheck.

## Runtime scenarios

`tests/fixtures/s14e_arrival.cdb` selects original branch `2190`, story 205. `sub_624C` supplies the authored map, player pose and cargo-elevator actor. The 1,800-VSync run creates that actor through GCL, records 27 moving game ticks and a horizontal delta of 3,112, and exits normally. Its capture renders Snake, the cargo platform, surrounding crates and radar.

`tests/fixtures/s14e_fight.cdb` selects original branch `2e90`, story 206. `sub_6F4C` supplies the authored map and pose, and `sub_D70F` creates the commander and three guards through the original script. The 1,800-VSync run records 25 moving ticks and a delta of 1,147. Enemy attacks kill the development entry's default low-health Snake, and the original game-over/voice-stream path runs without a native crash. The probe's movement PASS does not mean this encounter was won. No health, damage, actor activation or victory condition is bypassed.

Both are explicit scenario fixtures, not checkpoints reached by playing the preceding campaign. Neither movement run recorded a collision-contact tick. Private runtime logs and captures are under `build/s14-audit/`.

## Integration

`patches/mgs-s14.patch` adds the recovered guard modules, replaces the 25 raw stage constructor addresses, and updates only s14e's source selection in the shared linker template. Per-stage writable-state restoration includes the recovered modules when the original `.b` overlay loads. The renderer boundary remains the existing replaceable PsyZ renderer module.
