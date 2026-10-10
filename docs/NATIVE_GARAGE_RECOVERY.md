# Garage guard and countdown recovery

The native garage implementation reconstructs the original Integral s19a/s19ar guard, commander, and textured countdown actors. It does not establish complete campaign playability. Stage runtime integration is separate from the unit comparisons below.

## Evidence and scope

The local disc-two `4bbb.b` overlay is 122,064 bytes at offset 53,151,744 in `STAGE.DIR`. Its SHA-256 is `48390084a9a716bef980627c57df1867763a6502ad5109d2a6b3712e652840d7`. The original load address is `800C3208`. Both stage constructor tables select the same garage entry points:

| Actor | Hash | Original constructor | Native constructor |
| --- | --- | --- | --- |
| Guard | 31ec | 800CDBF4 | s19a_800CDBF4 |
| Commander | 8e88 | 800D7724 | s19a_800D7724 |
| Countdown | 22c6 | 800C5330 | NewS19Timer |

The guard/commander scope contains 191 routines in `800CCD5C..800D2544` and `800D3A4C..800D77A0`. Nearby earlier routines belong to another actor and are excluded. The original guard allocation is 3,136 bytes; a compile-time layout assertion preserves this. Initialized vectors, animation mappings, attack flags, and commander arrays were decoded from the overlay; native overlay initialization supplies their restored data and zeroed BSS.

The countdown recovers `800C4320..800C53B8` using typed native `POLY_FT4` packets. Its four number quads and colon retain the original coordinates, texture subdivision, tint, transparency, 30 Hz counter, per-second callback argument in ticks, and one-shot expiry callback. Failed primitive allocation or missing `0123`/`dot2` textures now returns constructor failure rather than dereferencing null.

## Recovery corrections

Original instructions, rather than decompiler guesses, determine the two action callback time arguments, cross-map navigation arguments, commander remainder return, shadow bone vector, item-drop structure, and eight-element sorting workspace. The original native conversion had not yet shipped when these recovery mistakes were corrected. Shared footprints, gun light, sight, effects, and projectile routines retain their existing engine APIs.

One deliberate original-game bug fix is required. At `800D57F4`, arrival helper `800D4960` is called with radius 500. Its successful path leaves MIPS register `a2 = -500`. The subsequent helper `800D4AF8` forwards that stale register to `NextAsiato` as a position pointer. Native code supplies the live guard position (`work->control.mov`) explicitly. This is a defined native correction, not a claim to reproduce the original invalid address read. The selected footprint index and found/missing transitions are retained. No real low-address memory value is assumed.

Some original routines are genuine empty or constant-return functions; their bodies remain such. No missing actor or asset is replaced by a success stub. Human-readable original source filenames are retained for actor diagnostics; verbose packet-initialization debug prints are omitted from the timer.

## Verification

All 13 C translation units compile for Windows x86 with `-Wall`, without diagnostics. Four tests pass:

- 322 original-MIPS guard action cases compare 46 state fields and ordered effects: input, walking/running, animation changes, damage, capture, knockdown, falling, and firing.
- 264 original-MIPS commander cases compare alert transitions and stable distance sorting for one through eight guards, including ties.
- 80 original-MIPS timer cases compare 87 state/packet fields and callback traces across minute/second/zero boundaries, both draw buffers, and optional callbacks. Additional native assertions verify the enlarged packet layout and allocation/texture failures.
- 16 native compatibility cases verify that footprint queries receive the live guard position and preserve found/missing index transitions. These are interface tests, not original-invalid-pointer equivalence tests.

The fixture headers contain synthetic inputs and results, not retail executable or asset bytes. The private original-MIPS generators and analysis database remain under ignored local recovery/build directories.

Aislop scans the 14 production files at 87/100: eight non-fixable function-length warnings in original state/resource routines; no errors or fixable warnings. Four test sources score 100/100. File-size warnings were resolved by splitting source at function boundaries. Remaining long routines preserve the original branches for comparison; this is an explicit maintainability limitation.
