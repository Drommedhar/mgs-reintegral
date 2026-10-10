# Underground passage recovery (s10a / s10ar)

These stages now have recovered native constructor bindings and C implementations for the camera sequence, bloody Meryl, and the Zako10 guards and commander. Both stages boot through the original introduction and pass the automated movement probe. A separate story-149 fixture also constructs Wolf and bloody Meryl successfully. The automated checks described here do not establish manual playability or campaign completion.

## Original evidence

The input is the user's Japanese Integral disc 1, SLPM-86247. The resident executable loads at `0x80010000`; the stage overlay loads at `0x800C3208`, as returned by the original resident `mts_get_bss_tail` routine. The original stage tables contain 40 constructor entries each.

| Stage | STAGE.DIR asset | Offset | Size | SHA-256 |
| --- | --- | ---: | ---: | --- |
| s10a | 4a9b.b | 31535104 | 137536 | `95f9cb0d5def5f30bb2133c0452b3aa49438f56c95535178d61eb11a03bb2e6e` |
| s10ar | 53db.b | 64548864 | 137536 | `465959ab31568740a4bf30bf0958865e485e48538e449a6b3c696c5fd7d52f69` |

`s10a` is the underground passage containing the first Sniper Wolf encounter and wounded Meryl. Communication Tower A is `s11a`.

| Actor | Original constructor | Native source |
| --- | --- | --- |
| Camera sequence | `800D6654` | `overlays/s10a/okajima/10a_demo.c` |
| Bloody Meryl | `800DCFDC` | `overlays/s10a/okajima/meryl10/` |
| Zako10 guard | `800CA2DC` | `overlays/s10a/animal/zako10/` |
| Guard commander | `800CEEE4` | `overlays/s10a/animal/zako10/zk10com.c` |
| Sniper Wolf | `800D7B54` | Existing `okajima/wolf/` sources |

The corresponding camera, Meryl, guard and Wolf machine-code ranges are byte-identical between the two stage overlays. The 23,968-byte Wolf code range also matches s12a after instruction relocation: only 232 jump targets and 31 data-address immediates differ. It therefore uses the existing recovered Wolf2 actor, including its 2,676-byte original work layout.

Meryl's work layout is 1,976 bytes and Zako10's is 3,132 bytes. Compile-time assertions check their native 32-bit sizes and important offsets. The commander state is 288 bytes. Symbols and globals are namespaced to avoid collisions with the other simultaneously linked stages.

## Recovery and checks

Original MIPS instructions were disassembled and decompiled, then reviewed against the recovered neighboring actors and original data references. Decompiler output was treated as evidence to check, not executable truth. In particular, stage images contain leftover text in BSS and padding; literal folding of those bytes is not a valid replacement for runtime loads.

Private reference scripts execute the original MIPS routines with Unicorn. Engine boundaries receive controlled inputs and their calls are recorded. The repository stores only the resulting synthetic fixtures and native tests, not the original disc or overlay bytes.

| Check | Original routine | Coverage |
| --- | --- | --- |
| Camera sequence | `800D5F78` actor sequence | 191 updates, camera snapshots, item and pad state |
| Meryl actions | Meryl action routines | 18 cases covering damage, voice transitions, animation, death and gravity |
| Guard actions | `800CADC4` | 42 cases covering input combinations, movement, turning, aiming, firing and secondary actions |
| Guard thinking | `800CDC74` | 71 cases covering patrol routes, timed actions, detection, alerts, pursuit and returning |
| Commander | `800CEBF0` | 20 cases covering activation messages, vibration/voice calls, player tracking, distance sorting and a 301-tick alert countdown |

The fixtures compare state fields and ordered engine calls. Boundary doubles isolate actor logic; they do not validate the renderer, streamed voice playback, collision geometry, or every possible script argument. The original guard's inactive action callbacks and commander destructor are actual no-op routines in the disc code; their empty behavior is preserved deliberately.

The native C units compile independently. Source and test scans report no findings; the installed aislop environment does not include cppcheck.

## Integration

`mgs-s10-demo.patch`, `mgs-s10-meryl.patch`, and `mgs-s10-zako.patch` add the recovered actors. `mgs-s10-stages.patch` supplies both constructor tables and a linker selection of the recovered actors and their shared dependencies. Each stage retains its own registry identity. Existing overlay snapshot restoration applies to these sources when their original binary overlay is loaded.

The tests are `mgs_s10_demo_test`, `mgs_s10_meryl_test`, and `mgs_s10_zako_{action,think,commander}_test`. No game state is changed to manufacture a passing actor fixture; each fixture explicitly sets a synthetic input state and compares the resulting actor behavior with original execution.

## Runtime evidence

The full build links 478 game translation units with both stages enabled. Direct development entry at story zero follows the authored introduction; it does not skip directly to the boss encounter. `s10a` completes 9,000 VSyncs and the controller probe observes 25 moving game ticks and a horizontal delta of 2,813. `s10ar` completes 6,500 VSyncs, including 27 moving ticks and a delta of 3,139. The shorter initial runs ended during dialogue and correctly reported an incomplete probe.

An explicit debugger fixture, `tests/fixtures/s10a_story149.cdb`, selects the original story-149 encounter branch. Its input pose `(3500,-28988,22500)` and heading zero come from the preceding story-148 branch. Meryl's saved health fraction, byte `0x167 = 128`, follows the story-147 copy of her earlier health. Only these fixture inputs are set; the original scenario creates Wolf and bloody Meryl, as observed with read-only constructor breakpoints. The 2,400-frame run passes normal controller movement (8 moving ticks, one collision-contact tick) and renders both lifebars. It does not establish boss victory.

The decoded stage script is `ea54.g`, SHA-256 `ebd9daa3680017d720aa06a94b10b3f612df8dd7666941bb22b7686fcfff74d0`. Story 149 creates Wolf and bloody Meryl. Stories 151–152 create the guard commander and two guards; the exit trap sends their activation message and advances the story to 153. The story-151 fixture constructs the native commander and two guards through the original script. Their activation and capture sequence are not yet covered by the runtime probe; the differential commander/action tests cover those state transitions in isolation.

Private logs and captures are under `build/s10-audit/`: `s10a-long`, `s10ar-long`, and `s10a-story149`. The fixture is an isolated scenario test, not evidence of reaching that checkpoint through a complete campaign.
