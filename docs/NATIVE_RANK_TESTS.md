# Ranking recovery comparisons

These fixtures execute original Integral `rank/9265.b` routines at `800C3208` and compare their native C behavior. The public fixture headers contain synthetic inputs and outcomes, not game binaries.

| Suite | Cases | Evidence |
| --- | ---: | --- |
| `mgs_rank_award_test` | 18,945 | All 48 award IDs, difficulty and ratio boundaries, condition priority, unlock fields, rank texture selection and quad placement |
| `mgs_rank_graphics_test` | 2,167 | All seven recovered font/packet helpers, cursor layouts, texture-coordinate overflow, transparency, both sprite buffers, packet ordering and draw mode |
| `mgs_rank_pocket_worker_test` | 660 | Port scans, selection/cancellation, hotplug retries, format/overwrite decisions, transfer outcomes and error cleanup |
| `mgs_rank_pocket_state_test` | 5,552 | Menu-state transitions, request flag priority, inputs, callbacks, selector state and exact draw-mode packet |
| `mgs_rank_pocket_test` | 1,400 | App payload packing, character conversion, score decoding and memory-card port selection |

The award, graphics and PocketStation suites pass through CMake/CTest. The graphics comparison caught and corrected the text draw mode: the original command is `E100041E`, enabling drawing into the display area; the native packet now preserves that bit.

Pocket comparisons include 1,272 matches to the original and 128 tests of an explicit native repair. Original `800CC3D4` reserves 96 bytes for names at 12-byte strides but accepts ten records; records nine and ten overlap the mode/character arrays on its stack. Native C allocates ten names and separate ten-entry attributes. Those 128 cases verify the intended decoded records and also retain the differing original outcome in the fixture, so the test does not call this behavior equivalent. For every name, comparison covers the eight initialized characters and terminator; native padding bytes 9–11 are deterministically zero instead of copying uninitialized stack bytes.

Engine/font boundaries use identical controlled test implementations. Packet checks normalize original address tags and native pointer tags while retaining payloads, lengths and ordering. These tests do not establish pixel rendering, physical PocketStation support, or a complete ending playthrough.

The menu-state comparison identified an extra cleanup call on a null file-selector pointer. Native `PocketSelectPort` now preserves the original nonnull guard. The menu draw-mode command independently matches original `E100023F`.

The transfer-worker comparison checks ordered device/UI calls, file names, pad-reset protection, port state and final results against original `800CC798`. It uses synthetic memory cards and controlled read/write outcomes. The native worker also rejects a null file listing after deletion; the original immediately dereferences that pointer, so this error-handling extension is not included in the equivalence count.
