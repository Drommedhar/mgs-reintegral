# Stage source recovery inventory

[stage_inventory.json](data/stage_inventory.json) records the current recovered source tree against FoxdieTeam commit `f54dbb2a58adfc2755403296c9ebb653fbec277b`. Regenerate it after source or build changes:

```powershell
.\.venv\Scripts\python.exe tools/audit_stages.py `
  --compile-commands build/gpu-validation/compile_commands.json `
  --runtime-log build/renderer-contract-new-game.log
.\.venv\Scripts\python.exe -m unittest tests.test_audit_stages
```

Omit build databases and runtime logs for a source-only audit. The tool reads source metadata and build evidence; it does not extract or include retail code. Generated counts describe source coverage, never a percentage of playable campaign completion.

## What the inventory establishes

The initial inventory, before constructor recovery, contained **92 main-game stage tables, of which 80 have linker selections**, plus **104 VR tables, of which two have selections**. The union had 694 game object slots: 564 C files without assembly pragmas, 37 partial C files containing 747 assembly pragmas, and 93 assembly-only slots. SDK library objects are outside these game-source counts. Inline assembly is counted separately. A file without an assembly pragma can still have portability or behavioral defects.

That initial inventory counted 512 literal constructor addresses across the main-game tables and 1,575 across the VR tables, including stages without linker selections. Each entry records its class identifier, table line, candidate recovered functions, and any selected assembly, address-suffixed C symbol, or resident symbol-map evidence. Class identifiers and comments supply leads; they do not establish that two stage-specific implementations are identical. Remaining literal entries require binary confirmation.

Native evidence is separate: a compile database entry plus an object newer than its C source establishes an observed compilation artifact. It does not establish current header dependencies, successful linking, stage registration, or gameplay. Runtime evidence requires both a completed probe and measured controller-driven movement. Recorded `s00a` logs include 6,000-VSync title/New Game runs with 431 units of controller-driven movement and collision observations. They do not validate the rest of the stage or campaign. The inventory records its compile database inputs; the `configured_main_stages` count describes original linker-template selections, not the native enabled-stage list.

## Recovery order

| Work | Concrete source position |
| --- | --- |
| Normal title, docks, heliport and introduction | Title uses implemented native disc validation; `d00a` has 42 additional-to-resident C slots and `d01a` has 21, with no assembly pragmas or literal constructors. Relative to docks plus heliport, the introduction adds nine files and the heliport cutscene adds six. |
| Connect early campaign stages | `s02a/b/c/d/e`, `s03a/b/c/e`, `s04a/b/c`, and `s06a` already select C sources without assembly pragmas and use named constructors. These groups compile and have bounded entry checks; connected transitions and encounter completion remain acceptance work. |
| Bind recovered constructors | `s05a` has 44 overlay C slots and 33 literal constructors; `s11a` has 32 overlay C slots and 12 literal constructors. All 45 bindings are now confirmed against original overlay bytes and both stages compile and render in bounded entry checks. Boss/scenario completion remains unverified. |
| Recovered encounter code | Mantis, Ninja, first Wolf, containers/Raven, Hind variants, and the elevator ambush now compile. Their dedicated recovery documents record instruction comparisons and bounded runtime scenarios; completion of those encounters is still unverified. Textual assembly pragmas retained in PS1-only branches are historical inputs, not selected native execution. |
| Full main-stage source selection | Rappel, REX, Liquid, garage, escape, ranking, briefing, camera and the auxiliary selectors now compile. All 92 configured main-stage identities are selected. The [campaign code audit](CAMPAIGN_CODE_AUDIT.md) compares all 184 Disc 1/Disc 2 overlay class-ID lists with the native tables and finds no active assembly body or missing constructor entry. Connected campaign behavior remains under validation. |

Complete campaign behavior remains the priority before a map editor. Save/load, bosses, movies, disc transitions, ending and credits require their own runtime acceptance. VR is a separate executable/source variant and should retain separate status.

## Evidence and recovery tools

The first recovered bindings cover all 33 constructors in `s05a`, 12 in `s11a`, and 28 in `s03d`. [constructor_bindings.json](data/constructor_bindings.json) records the original overlay digests, table addresses, constructor identities and source paths. Constructor identity does not establish equivalent behavior throughout the actor.

The `s03d` recovery adds native C for 32 guard and commander functions spanning 21 original assembly blocks. This includes resource initialization, movement and damage actions, perception, firing and grenade effects, guard respawning, and the commander sequence. [s03d_recovery.json](data/s03d_recovery.json) records their address ranges and verification: all 3,278 published instruction words match the extracted overlay; twelve vectors and the 48-entry motion table also match. All nine C files newly selected by `s03d` compile and link in the Windows x86 optimized build, including assertions for original actor sizes and field offsets. The original assembly is retained behind non-native branches; these native changes have not been tested as a matching PS1 build.

An **automated debugger fixture**, [s03d_story27.cdb](../tests/fixtures/s03d_story27.cdb), sets only the original story variable `$w:00000A` to 27 before the stage scenario. The original script advances it to 28, sets the encounter entry position and heading, runs the intro, then restarts into the room with Meryl, the commander and three guards. Virtual controller input moved Snake 1,690 units across 57 pad frames and 25 movement ticks. The run reached 2,400 VSyncs without an access violation; guards subsequently killed the idle player and the original Game Over appeared. A separate 900-VSync capture shows the room and actors and passed movement again. These are bounded integration results, not human playtesting, encounter completion or normal campaign progression. A direct entry with the initial story value 0 selects an incompatible shared-script branch and requests an animation absent from this stage.

Scoped aislop analysis of this recovery reports no errors or fixable findings. Nonfixable complexity warnings remain for the large guard file, the commander state machine and an inherited guard-thinking function. The environment lacks the scanner's `clang-format` and `cppcheck` executables, so those scanner engines did not run.

The next complete-C groups are tracked separately in [s07a_portability.json](data/s07a_portability.json), [middle_stages_portability.json](data/middle_stages_portability.json), and [tower_stages_portability.json](data/tower_stages_portability.json). These records distinguish linking from bounded runtime checks and record debugger fixtures explicitly. The s07a fixture observes Meryl's original constructor; s07c and s08a direct entries pass controller movement. Further s07c and s09a fixtures observe the original Meryl72 and dog constructors and pass movement. The s07c fixture restores the original sub_7658 incoming map, position, heading and three inventory/state values; its voice scene then ends normally. The initial s09a cutscene-only run remains recorded separately.

The tower port adapts the fog renderer's ordering-table links and packet color offsets, replaces its inline MIPS operations with synchronous GTE operations, and binds verified guard callback/message tables. A regression test checks depth-cued colors while preserving every other packet byte. The s11e and s11i commander objects use their recovered structure types with original size assertions. The s11c development entry requires a map from its own scenario (`0xf1f0`, `0xf1f1`, or `0xf1f2`); the map used by s11a is unsuitable. Successful entry and movement do not establish normal staircase traversal, boss completion, or continuous campaign progress.

The six tower/snowfield stages now each have a bounded controller movement pass. Explicit debugger fixtures restore original incoming positions for `s11i`, `s12a`, `s12b` and `s12c`; the `s11i` commander and `s12a` Wolf constructors are observed. The Wolf run reaches combat and subsequently Game Over when the player remains idle. The fog variants render their snowy geometry and pass movement. Exact setup, captures, logs and limits are recorded in the tower JSON. These are automated integration results, not human playtesting.

The shared PSG1 sight path required a separate [retail packet conversion](data/sight_packets.json). Its original `.s` resources contain four-byte PS1 headers; native packets use eight-byte headers. The port retains the original animation and text buffers, then copies GPU payloads into bounded native packets before submission. This fixes the first-frame snowfield corruption that previously read the polygon opcode `0x28000000` as a packet length. A regression checks payload preservation and invalid size rejection.

- The pinned [linker template](https://github.com/FoxdieTeam/mgs_reversing/blob/f54dbb2a58adfc2755403296c9ebb653fbec277b/build/linker_command_file.txt) defines object selection and overlay placement. The [build script](https://github.com/FoxdieTeam/mgs_reversing/blob/f54dbb2a58adfc2755403296c9ebb653fbec277b/build/build.py) disables some overlays that still appear in the template; selection alone does not establish an upstream successful build.
- [`functions.txt`](../vendor/mgs/build/functions.txt) supplies resident addresses, sizes and symbols. `asm/overlays/<stage>/*.s` supplies remaining instruction words and named entries. Address suffixes must be scoped to the selected stage: overlays reuse the same PS1 address range.
- [`list_assets.py`](../tools/list_assets.py) already parses Integral `STAGE.DIR` and identifies `.b` executable resources. Its public loose-mod export intentionally excludes `.b`; a recovery extractor should reuse its checked resource extents and write original overlay bytes only beneath `.local/recovery/`. Record the disc identity, stage, resource identity, offset, length and digest before analysis.
- Upstream [`decompme_asm.py`](../vendor/mgs/build/decompme_asm.py) converts published `dw` words to MIPS disassembly with Capstone and can read generated per-overlay maps. It expects optional Python dependencies and PSYQ build outputs absent from this native build. The upstream assembly reinsertion pipeline produces PS1 objects; it is not a Windows C implementation.
- LLVM's `llvm-objdump.exe` is available in the installed VS LLVM toolchain. IDA Pro 9.4 and the IDALib connector are also available for isolated binary sessions. Open a new extracted overlay or a separately constructed PS1 analysis image, set the proven load address, and retain resident call-target names. Do not change the sibling MGSR checkout or its existing IDA databases.

Keep future graphics/mod tooling at the resource conversion boundary described in [PORTING_STATUS.md](PORTING_STATUS.md). The present original-format override contract and PC-edition conversion tools do not by themselves provide a PS1 level editor.

## Prison encounter cleanup crash

The user's `full-run-20261009-154709-462.mgsinput` reaches the end of the prison
guard fight, then stops after 45,533 complete input rows. Its SHA-256 remains
`302c79edb7aa93cfaf977da995cc4192142de5dab783c7e47d141ac62ada89d6`.
Debugger replay with the recorded executable reproduced a null read at
`s03d_800D47BC`, through `s03d_800D4CE0` and `s03d_800D53EC`. Guard destruction
clears its commander entry, while the commander continues sorting the fixed
slot list during the encounter's final cleanup state.

The original overlay instructions confirm the cleared pointer at `800D4064`,
the unconditional distance read at `800D47F8`, and the subsequent range write
at `800D48EC`. The native adaptation assigns empty slots an `INT_MAX` sorting
distance and omits their range writes. Live guards retain their stable distance
order and original per-slot ranges, including guards waiting to respawn. The
slot count, registration identities and encounter state machine stay intact.
The change is pinned in [mgs-s03d-guard-retirement.patch](../patches/mgs-s03d-guard-retirement.patch);
the shared `s03dr` implementation receives it too.

The rebuilt Debug executable matches every recorded input checkpoint through
45,533 samples / 45,537 VSyncs. A further 1,800 VSyncs holding the last controller
packet passes the original crash, observes normal commander destruction, and
loads `s03b`. This continuation is diagnostic: it has no recorded checkpoints
and deliberately exits with the held-input-tail failure status. It does not
establish completion of the crashed recording or the remaining campaign.
Evidence: [original crash](../build/s03d-crash-20261009/debug-console.log),
[fixed continuation](../build/s03d-crash-20261009/fixed-console.log), and
[five passing tests](../build/s03d-crash-20261009/ctest-final.log).

The new regression executes the actual retirement and sorting definitions for
all eight removal combinations of three guards, stable ties, repeated sorting,
and a zero-slot commander. The input-session, input-resume, input-movie and
checkpoint suites also pass. All 67 MGS patches reproduce the vendor tree.
Scoped Aislop reports no errors or fixable findings; one inherited nonfixable
function-length warning remains in the commander state machine. The C lint
engine could not run because `cppcheck` is unavailable.

The existing resume tool separately verifies 37,134 inputs / 37,138 VSyncs to
the last `s03d` entry and caches its original-format save payload. Resume this
recording with `-ResumeInput` to use that cached entry without replaying the
earlier stages. A fresh `-RecordInput` path records the resumed session; the
original recording and human memory-card save are preserved.

## Snowfield claymore crash

The next human recording, `run-20261009-161256-777.mgsinput`, proceeds from the
prison entry through the armory and into `s05a`. Its SHA-256 is
`ba25af60f80e2f3bb63d88bd2c042dce6e7320a79fc988c70724dc6fb8282602`.
The debugger matches all 55,657 input rows before reproducing an access
violation during a claymore explosion. The overwritten return address appears
inside an unrelated SDL function; the caller is `NewClaymore`.

The shared `okajima/claymore.c` trajectory helper passed a single local
`SVECTOR` to `DG_PutVector` with a count of two, assuming that another local
would immediately follow it in memory. This corrupts the native stack and
leaves the intended endpoint uninitialized. The original instructions at
`800735A0..800736AC` reserve the adjacent vectors at `sp+18` and `sp+20`, before
the first saved register at `sp+28`. The corrected C allocates `SVECTOR ray[2]`
and uses its two elements consistently for the collision query and length.
The shared projectile fix applies wherever claymores are used; damage, spread,
collision flags and visual effects retain their original code.

The rebuilt game matches all 55,657 input checks / 55,661 VSyncs and continues
600 additional VSyncs through the explosion without an access violation.
The held-input tail deliberately exits with diagnostic failure status; those
extra frames have no recorded checkpoints. This does not establish Tank
encounter completion. Evidence: [reproduction](../build/s05a-crash-20261009/debug-console.log)
and [fixed continuation](../build/s05a-crash-20261009/fixed.log).

The regression extracts the actual trajectory helper and checks its known
destination capacity before transforming two vectors. Synthetic collision
boundaries cover the unobstructed ray, a wall, and a tagged floor, including
endpoint, distance and normal selection. Substituting only the old helper
fails before writing out of bounds: `caller provides 8 bytes`. The corrected
helper passes. The input-resume, checkpoint and Tank terminal suites also
pass: [four focused CTests](../build/s05a-crash-20261009/ctest.log),
[negative control](../build/s05a-crash-20261009/negative/result.log).
The Windows Debug build and all 68 pinned MGS patches verify. Scoped Aislop
reports no findings in the changed C/Python files; `cppcheck` is unavailable.

The resume export independently verifies 54,470 input samples / 54,474 VSyncs
and caches the authentic `s05a` entry. `-ResumeInput` with this recording now
loads that checkpoint immediately. An earlier recovery attempt ended before
its replay endpoint and was rejected; only the completed export is cached.
The original input file and live memory-card save remain untouched.
