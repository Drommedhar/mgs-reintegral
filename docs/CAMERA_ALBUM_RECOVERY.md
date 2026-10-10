# Camera album recovery

The Integral Disc 2 `camera` overlay now has native C for all **16 previously missing assembly blocks: 7,590 instruction words**. Every upstream assembly word matches the user's disc image. The existing stage entry binds hash `0x81c7` to `NewCamera_800CF388`, matching the original constructor at `0x800CF388`.

The recovered code implements photo loading and unpacking, names and the character keyboard, RGB adjustment, ghost-photo presentation, overwrite confirmation, card selection, the card worker, and save-file construction. The existing 62 C functions remain in the source pipeline with native packet and pointer adaptations.

- [Album implementation and layouts](../vendor/mgs/source/overlays/camera/unknown/camera_native.h)
- [Typed overlay data](../vendor/mgs/source/overlays/camera/overlay2.c)
- [Instruction inventory and proof counts](data/camera_album_recovery.json)

## Native changes

The original actor is 18,920 bytes. Native GPU packet headers and the resident menu structure make it 19,100 bytes; compile-time layout checks cover this expansion and the unchanged 180-byte state tail. All 39 polygon copies retain complete native packet headers and original draw depths. Fragmented upstream strings, card icons, tables, and shared state now have contiguous typed definitions. Their values come from the existing public source; no disc assets are added to the repository.

Photo unpacking uses a bounded native runlevel buffer in place of `0x801B1000`; MDEC output uses a local 16-by-16 pixel cell in place of `0x80182000`. The original 18-by-11 cell traversal still feeds the real decoder and VRAM uploads. Malformed packed input terminates with a specific error. Save-title padding is zero-filled instead of copying uninitialized original stack bytes. Format operations are bounded, and the worker yields while waiting for its shared UI response.

Initial native rendering exposed a texture-page dependency: the album's animated text executed with page zero before the resident menu's font-page setup. The album now selects font page `0x1f` at the head of its sprite submission. A regression exercises the live actor submission and checks that the page command precedes existing sprites. The other original card-menu page commands retain their exact `0xe100043f` encoding.

## Validation

Six CTest targets compare the live native implementation with **11,404 synthetic cases executed by the original MIPS instructions**:

| Target | Cases | Coverage |
|---|---:|---|
| `mgs_camera_controls_test` | 3,800 | Keyboard edges, text cursor limits, RGB control, input priority |
| `mgs_camera_animation_test` | 1,364 | Panel phases, slider geometry, ghost state, all polygon bodies/depths |
| `mgs_camera_photo_test` | 1,536 | Packed photo expansion, metadata decoding, title/header writing |
| `mgs_camera_files_test` | 1,024 | File-list state, normalized GPU packets, label and highlight calls |
| `mgs_camera_state_test` | 1,080 | Main actions, actor dispatch, overwrite phases, write completion and call order |
| `mgs_camera_card_test` | 2,600 | Worker transitions, card errors, formatting, filenames, save payloads and retries |

The card worker compares 13 shared globals at each of 20,572 SDK/UI boundaries and at return. Its 1,832 cases include both ports, hotplug, missing cards, format failure, overwrite cancellation, deletion failure, no free blocks, and read/write failure. Another 768 writer cases compare full synthetic 8/16/24 KiB payloads and filenames, including collisions and retries. Native allocation failure and 384 cooperative waits are checked separately from original-equivalence comparisons.

The photo test records decoder boundaries and verifies 198 cell uploads; it does not substitute for an end-to-end visual test of a saved photo through the real MDEC backend. Real decoder behavior is covered separately by the project's MDEC tests. All tracked fixtures contain synthetic inputs and expected hashes, not original code or assets.

The complete stage ran for 1,800 VSyncs without a fault. A subsequent 360-VSync capture verified the corrected `PHOTO DATA`, `SELECT MEMORY CARD`, both memory-card labels, and exit instruction. These runs establish initial album rendering; they do not establish a complete human photo-edit/save/reload session. Private captures are `.local/recovery/camera/render-before.bmp` and `render-after.bmp`.

All nine camera C translation units pass standalone Clang syntax checks with warnings treated as errors. Scoped Aislop reports no errors or fixable warnings; eight nonfixable source-complexity warnings remain in original-shaped interfaces and control flow. The album tests and preparation scripts have no findings.

The equipped-camera encoder is a separate resident module, [equip/jpegcam.c](../vendor/mgs/source/equip/jpegcam.c), with its own native-buffer adaptation and regression target. Recovering the album alone would not have fixed photograph capture.
