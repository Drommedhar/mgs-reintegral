# Native ranking and PocketStation menus

The selected `rank` stage now builds entirely from native game C. Its four previously incomplete components contained **97 assembly blocks**: ten ranking routines, 23 PocketStation menu/transfer routines, 28 background routines, and 36 name-entry routines. All are replaced by recovered C, with original constructors bound by their ten script IDs. Existing save-menu and window actors are reused.

Recovered data uses typed tables and complete strings. Polygon buffers follow the native renderer's packet sizes; shared entry buffers retain their original resident-state alias. The bundled PocketStation application image remains a data payload, not executable Windows game code.

The original PS1 MCX hardware driver is replaced at the platform boundary by [the device-provider interface](../include/mgs_pocket_device.h). The default reports **no device**. A provider may implement detection, serial lookup, configuration, and launch; registering a partial provider fails. This preserves actual menu failure/cancellation paths without inventing a connected peripheral. Memory-card file storage still uses the native card backend. Physical PocketStation communication is not implemented.

## Evidence

The optimized build contains **677 game translation units**, and all **71 CTest suites** pass. Ranking-specific suites exercise **39,970 cases**: 39,842 comparisons with original instructions and 128 explicit repaired-overlap cases. They cover all 48 awards, statistics, font packets, background animation, name entry, menu states, port selection, transfers, cancellation, and failure cleanup. Allocation-failure and device-provider checks provide additional native coverage. See [the ranking comparisons](NATIVE_RANK_TESTS.md) and [background recovery](POCKET_BACKGROUND_RECOVERY.md).

Direct Disc 2 entry ran for **1,800 VSyncs** without an access violation. The [capture](../build/cinematic-audit/rank1800.bmp) displays the animated score panel, original font, counters, award name, special-item label, and background. The [log](../build/cinematic-audit/rank1800.log) records the original script loading the native overlay. This uses default development-entry statistics; it does not establish a campaign ending, save completion, or hardware transfer.

The comparison tests corrected a text draw-mode bit and a spurious null cleanup call. The recovered score decoder also repairs the original ten-record stack overlap: it allocates ten separate names and attributes, and deterministically initializes name padding. Its deliberately different cases remain identified in the tests. A missing post-deletion file list now produces an explicit failure instead of a null dereference.

All blocking scan findings were corrected. Remaining nonfixable findings concern inherited function complexity, the original embedded application data's file size, and one false-positive unreachable-code warning at a label reached by tested transfer-error branches. They are retained rather than suppressing scan rules.

The renderer remains independently replaceable through the existing renderer-module boundary. Ranking textures, scripts, and sounds continue to use the normal resource loader and mod overrides; this work does not introduce a second rendering or asset path.
