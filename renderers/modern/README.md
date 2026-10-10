# Experimental modern renderer

This is the first RE:INTEGRAL renderer module with explicit projected geometry.
It adds perspective-correct model textures, subpixel model projection and a
per-pixel floating-point depth buffer. Each enhancement is independently opt-in.
The default PsyZ renderer remains the comparison baseline.

```powershell
./tools/build.ps1 -Configuration RelWithDebInfo `
    -RendererModule renderers/modern -BuildDirectory build/windows-x86-modern
./build/windows-x86-modern/RE-INTEGRAL.exe
```

Enable the desired options on the launcher's **Graphics** tab, or run:

```powershell
./tools/run.ps1 -BuildDirectory build/windows-x86-modern `
    -Widescreen -Resolution 1280x720 `
    -TextureCorrection -GeometryPrecision -DepthBuffer
```

The corresponding engine flags are `--texture-correction`,
`--geometry-precision` and `--depth-buffer`. The regular renderer rejects these
enhancements explicitly. Existing launcher settings load with them disabled;
new settings persist all three. Record/replay presentation metadata records the
options separately from the gameplay identity.

## Geometry and passes

The game adapter attaches float screen X/Y and camera-space Z to model packet
vertices. It reads the current model-to-camera matrix and projection registers
without changing the GTE state, gameplay coordinates, original packet layouts
or ordering tables. Direct faces, attached parent vertices and subdivided faces
carry this metadata through `libdg`. Two independent tables follow the game's
double-buffered packets. Rebuilding a frame invalidates its old entries; lookup
also verifies that its packed XY word still matches.

The synchronous `PsyzGeometryCallback` provides this geometry at submission.
A polygon uses it only when every vertex has valid geometry. Saturated,
near-plane-invalid, untracked or rewritten vertices retain original rendering.
Camera matrices, animation and source model coordinates remain fixed-point;
subpixel projection reduces raster snapping but is not a floating-point rewrite
of the game's simulation or every stage effect.

The renderer uses three GPU pipelines:

| Pass | Depth behavior | Interpolation |
| --- | --- | --- |
| Projected opaque models | Test and write D32 float reversed depth | Optional perspective UVs; affine vertex color |
| Projected semitransparent models | Test, without depth writes | Same UV/color policy; original PS1 blending |
| HUD, sprites, framebuffer effects and untracked primitives | Original ordered drawing; no depth attachment | Original interpolation |

Depth is cleared at the start of each submitted game frame and recreated when
the internal resolution changes. Transparent texels are discarded before depth
writes. The target has the same resolution as the color framebuffer. Depth is
preserved between batches and framebuffer feedback operations within a frame.
The implementation follows SDL's [depth attachment](https://wiki.libsdl.org/SDL3/SDL_GPUDepthStencilTargetInfo)
and [pipeline depth state](https://wiki.libsdl.org/SDL3/SDL_GPUDepthStencilState)
interfaces.

This is an experimental model-rendering foundation. The game still culls and
subdivides geometry with its original rules. Legacy effects without model
geometry retain their original path. Transparency remains sorted by the game,
and depth testing can expose assumptions in overlapping surfaces or intentional
ordering offsets. These limitations need scene review before enabling the
enhancements by default. This interface does not yet supply modern materials,
replacement meshes, a general scene graph, lighting or postprocessing.

## Validation

`mgs_texture_correction_test` covers projection, copied vertices, stale XY,
frame isolation, table growth and invalid near-plane inputs.
`mgs_modern_gpu_1x_test` and `mgs_modern_gpu_4x_test` read actual rendered pixels
to check depth occlusion/reset, transparent depth reads, perspective UVs,
whole-polygon handling of missing metadata and subpixel coverage. Existing GPU
feedback, masks, widescreen and atlas tests also run against this module.

See [the progress ledger](../../PROGRESS.md) for real-disc checks and current
acceptance limits. The earlier completed campaign used the original renderer.

## Provenance and shader builds

`sdl3_gpu.c`, `sdl3_draw.h` and `shaders/` derive from Xeeynamo/PsyZ revision
`6d9c5730c414da327dbb12a8e6600b7774b49201`, with the cumulative RE:INTEGRAL
PsyZ patches in `sources.lock.json` through
`psyz-godot-command-transport.patch` as their starting baseline. These derived
files retain **MPL 2.0**, including regenerated shader bytecode. Godot transport
branches are removed from this module. `depth_target.h` and the game adapter
are original RE:INTEGRAL contributions. See [third-party scopes](../../docs/THIRD_PARTY.md).

SDL hosting, input, audio and the original VRAM compatibility operations remain
shared with PsyZ. The module is selected at build time through the existing
[renderer contract](../../docs/RENDERER_MODULES.md). It is currently tested on
Windows x86/D3D12. Its projected-geometry contract must also be carried through
PsyZ's packet repacking when the game is ported to x64.

To regenerate all shader formats after a GLSL change:

```powershell
./.venv/Scripts/python.exe tools/build_gpu_shaders.py `
    --source-directory renderers/modern/shaders --shader psx.vert --shader psx.frag `
    --glslang <glslang.exe> --spirv-cross <spirv-cross.exe> --dxc <dxc.exe>
```

Checked-in DXIL, SPIR-V and MSL headers make normal builds independent of shader
compiler installations. Only the Windows backend has runtime validation here.
