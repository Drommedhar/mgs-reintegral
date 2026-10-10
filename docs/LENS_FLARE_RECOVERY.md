# Lens-flare actor

[LensFlare](../vendor/mgs/source/okajima/lens_fl.c) is recovered from original Integral `s18a` code `800D1CCC..800D2388`: seven functions, 431 instruction words, and a 252-byte actor. Its native API is `NewLensFlare(MATRIX *world, int lifetime)`.

The actor projects eight textured quads using the original integer scales, emits the original stun particles, maintains the caller-specified lifetime, updates stun state, and triggers the original sound and fade timings. Its two packet buffers retain the native full-pointer header. The constructor writes the same shared stun position and applies the original noise priority rules. The previously private resident stun-position variable is exposed as `GM_StunBlastPosition` so both actors share one data object.

The native constructor also corrects an original failure-path ownership problem: partial primitive allocations are released once by the destructor, and each pointer is cleared. Missing textures or allocation failures return a failed constructor. Valid-resource behavior is unchanged.

`mgs_lens_flare_test` passes 384 independent original-MIPS comparisons: 256 timer/state/projection cases and 128 packet cases. The projection service is a deterministic boundary in these tests; the recovered quad geometry, state transitions, callback order, sound/fade timing, all 36 packet payload bytes and packet lengths are compared against original execution. Additional tests cover every partial allocation count from zero through eight and repeated cleanup without double freeing.

The new source and tests have no Aislop findings. The resident file retains one inherited, nonfixable warning for its 91-line `GetResources` function. This actor has not yet been observed during a native Liquid encounter; stage integration and runtime evidence are separate work.

[The evidence ledger](data/lens_flare_recovery.json) records original addresses, source-disc provenance and validation scope. [The incremental patch](../patches/mgs-lens-flare.patch) contains the recovered actor and shared-position declaration. Original assets and analysis databases remain untracked.
