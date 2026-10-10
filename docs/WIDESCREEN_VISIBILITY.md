# Gameplay visibility during wider rendering

The original `DG_OBJS.bound_mode` is read by actor logic as well as the renderer.
For example, the garage guard checks it in
[`action.c`](../vendor/mgs/source/overlays/s19a/guard/action.c). Expanding that
value for widescreen changed guard behavior: an existing strict recording
diverged at sample 1642 / VSync 1646 with widescreen, while the original aspect
and a resolution-only launch passed.

The native [bounds pass](../vendor/mgs/source/libdg/bound.c) now computes both
classifications from the same projected vertices and depth results. The seven
rendering units see the wider values. At the end of
[`DG_SortChanlSystem`](../vendor/mgs/source/libdg/chanl.c), a
[host sidecar](../src/mgs_visibility.c) restores classic group and model values.
The actor structures, projection coordinates and GTE operations are unchanged.
Stopped rendering and the screen-only path create no snapshots. Each new pass
clears the snapshot list, including passes using a replacement bounds callback.

Packet allocation remains real. Failure on a classically visible model preserves
the original group failure and early-return behavior. Failure on a model visible
only in widescreen stops that group's rendering but still evaluates the remaining
classic visibility results. It cannot manufacture an off-screen gameplay result
solely because an additional widescreen packet failed to allocate.

The isolated [regression](../tests/mgs_visibility_test.c) extracts the production
classifiers, bounds pass and sort dispatcher. It checks wide values during all
five downstream rendering units, restored classic values, left/right/partial
frustum cases, one projection per required box, both allocation-failure cases,
unvisited model values, custom callbacks, stopped/screen-only passes, default
width, and sidecar growth beyond 1,024 entries. Projection and packet allocation
are controlled test boundaries; this test does not claim to emulate the GPU.

The private Windows x86 test passes. Removing only the restoration call makes
the same test fail at its first classic group assertion with exit code 3. The
existing clipping regression also passes. The fog bounds callback in
`takabe/libdg2.c` applies the same separation while retaining its original
depth/cache bits and allocation behavior; its extracted-source regression also
passes.

The real-disc strict garage prefix now passes all 1,997 input samples / 2,001
VSyncs at 2560×1440 widescreen fullscreen, including the previously divergent
guard interaction. The log and final scene capture are
`build/widescreen-validation/garage-wide-fixed.log` and `.bmp`. Original-aspect
and resolution-only checks of the same prefix also passed. This is a specific
cross-aspect integration check, not full campaign acceptance.

The final full recording also passes all **6,496 samples / 6,500 VSyncs** in
2560×1440 widescreen fullscreen and reaches `s19b` with every recorded state
check unchanged. See `build/widescreen-validation/garage-full-final.log`.
The copied input file is byte-identical to the authentic garage recording;
the original recording and initial cards remain preserved.

The scoped scan reports no errors or fixable warnings. Two inherited findings
remain in `chanl.c`: the seven-argument `SetParam` helper and a false unreachable
code report at an existing `goto` label. Four inherited function-length findings
remain in the touched fog implementation. No scan rules were changed.
