# Native compatibility decisions

## Chaff particle drawing offset

The native Chaff effect supplies a static `RECT {0,0,0,0}` to its 64 TILE
particles. This defines a zero screen-space offset while retaining the original
random 1–2 pixel widths/heights, positions, colors, timing and gameplay effect.
The renderer still requires a valid rectangle for this primitive type. Patch:
[mgs-chaff-particles-native.patch](../patches/mgs-chaff-particles-native.patch).

The original Integral constructor at `80077014` passes type `0x409`, count 64,
the actor's vertex array, and a null rectangle to `DG_MakePrim`; the fifth
argument is explicitly zero at `800770B0`. Original renderer
`_MakeXYZRectangleSingle` at `8001B1E8` reads the rectangle's first two signed
shorts unconditionally at `8001B1F8`/`8001B1FC`. These are drawing offsets, not
particle dimensions. Exact PlayStation low-memory values have not been measured;
the explicit zero offset is a documented native compatibility choice, not a
claim of bit-exact console positioning. The nonnative branch remains unchanged.

The user's second recording, `.local/replays/xbox-02.mgsinput`, exposes this
access violation when a thrown Chaff Grenade bursts. Its SHA-256 is
`c235639706ec69cbbee1af3328bc2dd2b8c0d5cb3277fca1f3924cdc2f1f90a0`.
All 3,752 completed rows were flushed before the crash; there is no clean footer.
The original file and session remain unchanged. The separate diagnostic copy
adds a derived endpoint at sample 3,752/VSync 3,756, then holds the last controller
packets for a clearly labeled, unrecorded tail.

The old executable faults at `prim.c:341` through
`_MakeXYZRectangleSingle → MakePrimsRectangleSingle → DG_PrimChanl` with a null
rectangle and 64 particles. [Original trace](../build/xbox-02-crash/original-replay.log).
The corrected executable matches every retained input checkpoint, renders the
effect at game tick 2,038, releases its primitive at tick 2,340 with the Chaff flag
cleared, and remains alive at tick 2,398 with health 256. Its 720-VSync diagnostic
tail exits with the expected incomplete-recording failure, not an access
violation. [Corrected trace](../build/xbox-02-crash/fixed-replay.log).

The regression extracts the actual constructor helpers, primitive allocator,
rectangle packet writer and destructor. Its 6,953 checks cover both 64-particle
buffers, sizes/colors, signed coordinates and depth, preservation of packet
fields, allocation failure and cleanup. Restoring the old null argument fails
before dereference. All [106 CTest suites](../build/xbox-02-crash/final-ctest.log)
pass; bootstrap verifies 59 MGS and 15 PsyZ patches. The final default executable
also [survives the diagnostic tail](../build/xbox-02-crash/final-replay.log).
The new tests have no Aislop findings. The Chaff source
retains one inherited, nonfixable function-length warning for `Act`; cppcheck
and clang-tidy are unavailable in this installation.

## Cinematic footprint eligibility

The original Integral `ending/ea54.g` creates the footprint actor (class `02C4`)
before the story-292 cinematic, without creating a player controller. Resident
initialization sets `GM_WhereList[0]` to `DummyPlayer`, whose map is NULL, and clears
`GM_PlayerStatus`. In the retail ending overlay, `NewAsiatoKun` at `0x800C6CA0`
installs the update at `0x800C6AF8`. Its eligibility routine at `0x800C69EC` reads
the control's map at `0x800C6A04`, then its hazard pointer at `0x800C6A0C`, before
calling the movement check at `0x800C6A10`. With the dummy player this reads PS1
address `0x00000008`; the nonmoving branch discards the value.

Native `asiato_800D17BC` checks movement eligibility before that lookup. This avoids
the unused low-memory read while preserving the hazard lookup, wet-foot timer,
foot selection and emission behavior for eligible players. It does not substitute
a map or skip an invalid lookup for a moving player. The original instruction
ordering remains in the PS1 branch; the actual PS1 low-memory value is unverified.
The change is exported in
[mgs-cinematic-footprints-native.patch](../patches/mgs-cinematic-footprints-native.patch).

The regression extracts the production actor update and its helpers. Its 3,446
cases cover cinematic startup without a player map, movement restrictions, both
feet, pool/floor eligibility, all wetness counts from 0 through 60, and footprint
ring limits. The x86 Debug-style (`-O0`) test passes; restoring only the original
eager-read ordering makes the same test fail with `0xC0000005`. Source and tests
have no scoped Aislop findings. These checks establish the compatibility fix,
not complete ending audiovisual fidelity.

## Player pose during the dock restart

The native build defines a player-position query between Snake actors as the last
actual position and yaw, recorded before the previous actor is destroyed. It logs
this use and exits with an error if no player pose has ever been recorded. Live
actors continue to supply their current pose.

This intentionally replaces a PlayStation low-memory read; it is not a verified
bit-exact reproduction. The original Integral disc 1 `s00a/ea54.g` script requests
this sequence:

1. The main procedure sets progression variable `$w:00000A` to 6 and opens Codec
   with procedure `AD2D` as its completion callback.
2. `AD2D` executes `restart`, which destroys the stage actors. Snake's destructor
   clears `GM_PlayerControl`.
3. The main procedure runs again and calls `B31E` or `B31F`. Each starts with
   `func -s`, before the Snake constructor near the end of the main procedure.
4. `FuncCmd` originally reads position and yaw through `GM_PlayerControl`, which
   is NULL at this point. Windows faults on those reads.

The original camera setup consequently performs one position query before the
player is recreated. The native query uses the recorded pose, so that initial
camera query may differ from a PlayStation run. The restart, actor teardown,
scenario branches, later camera updates, and actor constructors still execute.

The exact low-memory values for an Integral PlayStation run have not been
measured. They must not be assumed to be zero: the independently researched
[PSX BIOS memory map](https://psx-spx.consoledev.net/ps1/kernelbios/memory-map/)
describes BIOS-dependent instruction bytes and CD-ROM writes in the first 16
bytes of RAM. A hardware or emulator trace is needed to quantify the camera
difference.

The evidence comes from the user-owned disc, decoded locally with
`mgs_compilation_tools` revision `4fd41810eee0bec636addee5bf7b551fce6d17fd`, and the
pinned recovered source: `game/gamed.c`, `game/script.c`, and
`chara/snake/sna_init.c`. Extracted scripts remain in the ignored build directory.

## Overlay initialization

PS1 stage loading overwrites an overlay's code and data. A native executable
instead links selected stage functions once and resets their writable data when
the original loader requests a `.b` overlay. Each selected source unit gets a
COFF subsection range, captured before game initialization. Reloading restores
its C initializers and zero-initialized BSS, including function-local statics.
Resident engine data is excluded. A script restart with `GM_LoadRequest & 0x40`
does not load an overlay and therefore does not reset this state.

The pinned upstream `build/build.py` explains that shipped overlay BSS and
padding can contain arbitrary bytes reinjected for binary matching. Native
initialization deliberately uses the C definitions; it does not reproduce those
uninitialized bytes. Tests cover relocation-bearing pointers, alignment, shared
source units and preservation of resident variables. Native `SECTION` ignores
the original PS1 `.bss`/`.sbss` placement so those variables cannot escape the
generated reset ranges.

## Native title disc validation

The original `SafetyCheck` sends physical CD-controller authentication commands
that a BIN/CUE does not represent. `src/mgs_safety.c` validates the supported
Integral image layout and original file/sector structures instead. It checks
raw sectors, XA subheader consistency, ISO extents, system/executable identity,
stage table and image length, and reports invalid content explicitly.

The original title call adds the 150-sector CD lead-in twice before passing its
probe position, so the native check accepts that recovered calling convention
while validating the actual stage table at its ISO origin. This is a host image
integrity/compatibility check, not reproduction of physical-disc authentication.

## Original undefined behavior reached in additional stages

The original demo camera code writes all three coordinate differences into
`diff.vx`, then reads uninitialized `vy` and `vz` when deriving control rotation.
The native branch assigns the three intended vector components. Original MIPS
evidence is recorded in `build/intro-audit/original-camera-evidence.txt`; this is
a deliberate defined-behavior correction, not a claim that the original stack
garbage is reproduced.

The `s04a` dummy-floor grenade path clears a grenade pointer and reads address
zero in the original overlay. The native branch checks occupied grenade slots
and applies the floor test to the grenade's real control position, following the
neighboring furnace/elevator handling. Original code remains under the PS1
branch. See [early-stage evidence](EARLY_STAGE_VALIDATION.md) for the original
addresses, behavior difference and runtime limits.

## Integral SDK square-root overflow

The tower supplies negative signed values after a squared-distance sum overflows.
Original `SquareRoot0` at `0x80092708` counts leading sign bits through GTE LZCS/LZCR,
normalizes with arithmetic shifts and indexes the table at `0x800A4C00`. For negative
inputs other than -1, its indices are -320 through -129: the original memory reads
land in the preceding sine table at `0x800A43E0`. Clamping or wrapping into the
square-root table changes the original result.

`MgsSquareRoot0` reproduces this through bounded accesses to the existing SDK
sine and square-root tables, preserving the GTE register side effects. All 1,025
quarter-sine values and 192 square-root values were checked against the supplied
Integral executable. For example, -2120157696 returns 31592 in the original.
Unsigned shifts preserve MIPS wrap and final logical-shift behavior without
out-of-bounds native reads. This binding applies to recovered MGS calls only;
it does not assume other PsyZ games share Integral's adjacent table layout.
The evidence and original instruction listing are in
`build/tank-tower-audit/sqrt-evidence.json` and `original-sqrt-candidates.txt`.
