# Dock underwater packet correction

The native underwater view keeps the original framebuffer distortion, tint, mask
commands, strip ordering and double buffering. Four memory defects are corrected:

- `DR_PRIO` now aliases the SDK's `DR_STP` in both the actor and `SetPriority`.
  Both packets contain two GPU command words. The shared type supplies the native
  eight-byte address/length header; the former four-byte declaration put the
  `0xE6000001` mask command in the length field.
- Both scratch lists use the relocated scratchpad. The second list previously
  retained the absolute PlayStation address `0x1F800400`. List lengths now use
  pointers inside the scratchpad allocation.
- Sprite initialization fills exactly 122 elements per bank. The original loop
  wrote 123 elements, crossing into the next bank or tile array.
- Leaving the water clears the delayed-free pointer. Destroying the actor after
  that transition no longer queues the same allocation for deletion again.

## Original evidence

Reference image: Disc 1 `s00a/469b.b`, 122,720 bytes, loaded at `0x800C3208`.
SHA-256: `533cb8e9b6ffdcc442c25ba51eb3d83e90cb1ad2831d3870395333398c8402bc`.
Private extraction and generator are under `.local/recovery/s00a`; copyrighted
image data is not part of the tracked fixtures.

| Original function | Address |
| --- | --- |
| Left sprite initialization | `0x800DB800` |
| Right sprite initialization | `0x800DB8F4` |
| Actor update | `0x800DB9E8` |
| Actor destruction | `0x800DBBF0` |
| Packet allocation/setup | `0x800DBEB8` |
| Sine table setup | `0x800DC0CC` |
| Distortion packet generation | `0x800DC128` |
| SDK mask command setup | `0x800DFB9C` |

The reference executes the original MIPS instructions for actor update, allocation
setup, sprite setup, sine calculation, distortion and GPU packet builders. Only
the engine allocation boundary returns controlled test storage. Packet links are
walked in rendering order. Hashes cover packet lengths and command payloads;
addresses are normalized by walking links, and the unused CLUT of direct-color
sprites is excluded because the original leaves it uninitialized.

`mgs_water_test` extracts the live actor functions and links the actual native SDK.
Its 256 original traces cover all 32 distortion phases, both frame buffers and
four RGB colors. Each case matches 228 or 230 drawing packets and the two-packet
mask/clear chain. Another 25 original mask-command combinations verify nonzero
input handling, length, payload and preserved link address. Native lifetime tests
cover allocation failure, retry, pause, exit, re-entry and destruction; canaries
check both sprite-bank boundaries. These intentional memory-safety corrections
are tested separately from original rendering equivalence.

Validation: the target passes CTest in `build/movie-audit`; the test translation
unit also passes `-Wall -Wextra -Werror`. Aislop reports no errors or fixable
warnings. Existing nonfixable warnings remain for `WaterViewDraw` length and the
unrelated `SetDrawEnv2` length/constant conditional in the SDK file.

## Above-water mesh audit

The dock uses three `ShakeModel` water meshes (`6d44`, `6d45`, `6d46`) with
amplitudes 100, 70 and 50. Their actor uses relocated `DG_MDL` vertex pointers,
the original eight-byte `SVECTOR` stride, and the native scratchpad macro. No
packet-layout regression was found in this path.

The water-area actor deliberately changes `DG_FrameRate` from 2 to 3 while the
camera is underwater, then restores 2 on exit. That authored timing difference
does not establish the cause of the user's reported host stutter. These packet
tests establish rendering-command equivalence; they do not claim that every
reported visual or timing symptom is resolved in a live run.
