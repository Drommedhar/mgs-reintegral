# Widescreen light effects

The dock light halos exposed a renderer defect separate from the resolution of
the original artwork: ordinary translucent world primitives blended against a
320-pixel-wide framebuffer copy even when geometry was rendered at 8x. This
could replace detailed geometry beneath a glow with coarse pixels. The glow
texture itself is an original 32x32 image and remains that size.

Evidence was inspected on 2026-10-09 using
`build/widescreen-validation/intro-hd-feedback.log` and its numbered BMPs.
The log places frames 1000, 2000, 3000 and 4000 in `d00a`, loaded at VSync 694;
the next stage, `s00a`, finishes loading at 4865. Frame 1000 shows the underwater
view, and frame 2000 shows the blue dock halos and rails. These captures do not
exercise the separate `opening` submarine stage.

The original `d00a` script creates five `chara 32e5` actors with thirteen light
positions in total. The stage
registry resolves this to `NewEmitter` in
[`thing/emitter.c`](../vendor/mgs/source/thing/emitter.c). It creates world-space
`POLY_FT4` billboards, enables semi-transparency and samples `sfex0236`.
There is no framebuffer-copy operation in this actor. `NewSubEfct` and
`NewFocusView` are not registered in `d00a`; adding a screen-effect scope to
either would not fix this scene.

The asset was read directly from the supplied Disc 1 `MGS/STAGE.DIR`, using the
existing `tools/list_assets.py` parser. No retail asset is committed here.

| Property | Original value |
| --- | --- |
| Texture name / resource | `sfex0236` / `23e1.p` |
| Resource size | 1260 bytes |
| PCX bounds | `(0,0)` to `(31,31)`, inclusive |
| Texture format | 32x32, 8-bit indexed; 65 palette entries used |
| Native texture flags | `0x19`: indexed texture, additive blending |
| SHA-256 | `cf2c660363e86a9867e92b72cd328b0efc7152fb9cef10e50a77185f1eb4fc4a` |

All 1024 source texels carry the semi-transparency bit after the original
[`LoadPalette`](../vendor/mgs/source/libdg/loader.c) conversion. Palette entry
zero is `(7,7,7)`, which becomes `0x8000`: additive black, not a discarded
transparent texel. Therefore even the dark border of a glow billboard writes
the sampled background back to the render target.

At diagnosis, [`psx.frag.glsl`](../vendor/psyz/psyz/src/platform/shaders/psx.frag.glsl)
selected the high-resolution destination only when framebuffer *source*
sampling was enabled by a `CANVAS` scope. Other primitives sampled their
destination through `gl_FragCoord / renderScale` from native VRAM.
[`sdl3_gpu.c`](../vendor/psyz/psyz/src/platform/sdl3_gpu.c) likewise allocated,
updated and bound the scaled snapshot only for those source-sampling scopes.
For this additive light, that combination coarsens the background across the
billboard, regardless of the source glow's texture resolution.

The implemented backend repair separates destination sampling from
framebuffer-source sampling. Translucent and mask-preserving batches now
snapshot and read the scaled destination independently of `CANVAS`; the
light's indexed source texture retains its original palette and coordinates.
No native actor changes were required.

[`mgs_gpu_framebuffer_scale_test.c`](../tests/mgs_gpu_framebuffer_scale_test.c)
passes at 1x, 2x and 8x with 37,800, 151,200 and 2,419,200 exact channel
comparisons respectively. These totals include the existing framebuffer-source
tests; half of each total covers world blending and mask preservation. The new
cases cover all four PSX blend modes, additive-black borders, two ordered
overlapping additive quads and an untextured mask-preserving draw across a
subpixel edge. Expected blending uses integer PSX arithmetic and independently
rendered opaque RGB5 values, checked against raw `StoreImage` output.

The old backend fails the additive-black case with 48 mismatched channels at
2x and 1344 at 8x; the repaired backend has zero. Logs are
`build/gpu-output-audit/world-blend-{baseline,final}{1,2,8}.log`.
The full 144-test CTest suite also passes, recorded in
`build/widescreen-validation/ctest-final-verified.log`.

The subsequent 5000-VSync `intro-blend.log` run passes the unskipped
`title -> d00a -> s00a` sequence and reaches the dock Codec without input after
the title. Its `intro-blend.bmp.001000.bmp` and `.002000.bmp` captures show
cleaner geometry beneath the water and glow effects. These files are under
`build/widescreen-validation/`. This runtime check establishes the tested intro
path; it does not establish that every campaign effect is visually correct.

The underwater distortion is a separate, already scoped framebuffer effect in
[`wt_view.c`](../vendor/mgs/source/takabe/wt_view.c). Its authored distortion
uses one- and two-native-pixel-high strips with integer source-row offsets.
Those steps can remain visible at high resolution even when each strip samples
the high-resolution framebuffer correctly. The diagnosis above does not claim
that every visible lamp edge, water step or texture pixel has the same cause.
