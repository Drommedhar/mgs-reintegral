# Raven actor recovery

All eleven missing assembly blocks in `s15c`'s Valcan actor are now recovered C. Their 2,039 original instruction words match the user's Integral Disc 2 overlay. [The evidence ledger](data/s15c_valcan_recovery.json) records the overlay hash, block extents, tests, and patch. Complete stage runtime is a separate integration step.

The native actor keeps its original 0x954-byte layout. Motion segments, rotations, shadow vertices, and turn state have real C storage instead of accesses beyond placeholder fields. Two adjacent stack vectors are an actual array. Shadow corners, target dimensions, and muzzle displacement use typed constants. Shared container state and Raven's position follow the addresses actually loaded by the original instructions; several upstream symbol suffixes were shifted by four bytes.

`mgs_valcan_navigation_test` passes 352 comparisons against original MIPS execution:

- 256 cases cover four recovered navigation routines, grid positions, directions, movement modes, collapsed-container states, and deterministic random choices. The original helper instructions remain active; only the random service is intercepted.
- 96 cases exercise the recovered damage/update routine across difficulty, attack modes, immunity, damage limits, timer transitions, and death signaling. These compare 20 state fields and ordered engine-boundary traces. Existing engine services and actor helpers are deterministic test boundaries, so this does not validate their rendering or audio behavior.

The native test extracts unchanged definitions from the recovered source. Run `./tools/build.ps1 -Configuration Debug -Target mgs_valcan_navigation_test`, then `build/windows-x86-debug/mgs_valcan_navigation_test.exe`. Original reference execution scripts and intermediate results are retained under ignored `.local/recovery/valcan` and `build/movie-audit`; expected inputs/results are tracked in `tests/mgs_valcan*_fixtures.h`.

`patches/mgs-valcan.patch` contains only `valcan.c` and its new layout header. A fresh temporary Git index verified exact reproduction from the pinned patch stack. It depends on the shared container declarations and storage recovered with DynCon. Scoped Aislop reports zero errors/fixable warnings and twelve nonfixable complexity warnings in the actor; the test files have no findings. The tests establish source behavior for their cases, not a completed Raven fight or human playability.
