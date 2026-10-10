# Renderer replacement contract

Recovered game actors and stage scripts submit graphics through the recovered
`libdg`/PSY-Q layer. A renderer can be replaced at build time without editing
those actors, the scheduler, resource loaders, save system, or audio mixer.

`MGS_RENDERER_MODULE` selects a CMake source directory. It must define a
`psyz_renderer` library target that supplies PsyZ's drawing and platform/video
endpoints. The regular `sdl3_gpu.c` and `sdl3_software.c` implementations are then
excluded from PsyZ itself. Missing endpoints fail at link time.

The included [reference module](../renderers/psyz-gpu/CMakeLists.txt) builds the
existing patched renderer through this boundary:

```powershell
./tools/build.ps1 -Configuration RelWithDebInfo `
    -RendererModule renderers/psyz-gpu -BuildDirectory build/renderer-contract
./tools/run.ps1 -BuildDirectory build/renderer-contract
```

Use a separate build directory when developing a replacement. Removing the
`-RendererModule` option selects the bundled renderer again. Modules receive
`PSYZ_SOURCE_ROOT`, and SDL's `SDL3::SDL3` target already exists. They may link
their own graphics dependencies through their target. Source paths may be
outside this checkout; no vendor-file edits are required to select a module.

## Required behavior

The concrete interfaces are pinned with the PsyZ revision in
[sources.lock.json](../sources.lock.json):

- [`src/draw.h`](../vendor/psyz/psyz/src/draw.h): primitive submission, drawing
  environment, texture pages/palettes, VRAM copies and transfers, display area,
  synchronization and framebuffer masks.
- [`psyz/video.h`](../vendor/psyz/psyz/include/psyz/video.h): presentation,
  frame timing, display controls and framebuffer capture.
- The backend's platform lifecycle and input endpoints. The existing SDL
  backends implement these through
  [`sdl3_common.h`](../vendor/psyz/psyz/src/platform/sdl3_common.h). A replacement
  can reuse that shared implementation, including actual gamepad input and
  window events, or implement the same endpoints itself.

Explicit output options also require `Psyz_VideoConfigureWindow`,
`Psyz_VideoSetPresentation`, `Psyz_VideoAllocPresentedFrame`,
`Psyz_GpuSetFrameTransform`, `Psyz_GpuSetFramebufferSampling`, and
`Psyz_GpuSetTextureAlignment` from the public
video/GPU headers. Presentation dimensions specify an aspect ratio; capture
dimensions remain the requested window resolution, including black bars and
display blanking. Ordered game command `F3` selects HUD, world, or full-canvas
drawing. The canvas mode copies framebuffer effects without squeezing their
geometry and enables scaled direct-color framebuffer source reads; leaving it
restores native source texture sampling. At increased internal resolution, all
semi-transparent blending and destination-mask tests read the scaled framebuffer,
including ordinary world polygons. A native-resolution destination would erase
fine background detail even beneath an additive-black light texture. Explicit 2D alignment uses
a half-physical-pixel UV bias so an upscaled atlas quad does not read its
neighboring texel; world polygons retain the native sampling rule. Indexed
textures and CPU VRAM transfers keep their original layout. Backends must reject unsupported
requests explicitly. Full-width untextured `TILE` screen overlays must cover
the output even when queued in the world channel, as the dock lamp does. Keep
vertical scissoring and restore the previous transform immediately afterward.
HUD bands also expand, while projected world polygons and ordinary HUD elements
keep their existing transforms. See the [shared 2D policy](WIDESCREEN.md#shared-rules-for-original-43-elements).
Relevant checks are `mgs_video_*`, `mgs_widescreen_gpu_test`
(1×/2×/8×), `mgs_gpu_output_test`, `mgs_video_config_test`, and
`mgs_gpu_framebuffer_scale_test` and `mgs_gpu_2d_atlas_test` at 1×, 2×, and 8×.

Preserve command ordering, render-to-texture feedback, palette updates, and
readback. The Codec frequency is an actual regression case: batching a texture
read ahead of its preceding framebuffer write makes the number disappear.
Run the mask, upload-arena and `mgs_gpu_feedback_test` pixel suites, controller
tests, and the unskipped `intro` runtime probe against a replacement, then
validate additional game scenes. The older `new-game` probe deliberately skips
cinematics and is useful for reaching controllable Snake. Passing those
checks alone does not prove full rendering fidelity.

This is a **source-level backend contract**, not a stable DLL ABI. It currently
receives PlayStation drawing primitives and VRAM semantics. A future renderer
that wants unprojected geometry, modern materials, or replacement model formats
will also need a higher-level interface at `libdg`'s object/mesh boundary. Keep
that work out of actor logic and preserve the resource identities used by
scripts, animation and collision. The present interface does not claim PNG,
glTF, arbitrary-size textures, or modern mesh rendering already works.

## Bevy as a future option

Bevy is a plausible candidate for the later graphics overhaul. Its documented
features include custom render pipelines, modern meshes/materials, asset hot
reloading and cross-platform support. It is implemented in Rust and organizes
its engine through ECS and plugins. See [Bevy's feature overview](https://bevy.org/).

Our recommendation is to finish the faithful C rebuild first, then evaluate
Bevy behind an explicit C/Rust interface. The recovered game logic can remain C.
Using the current primitive interface would still require correct PS1 blending,
texture feedback and VRAM behavior; modern replacement models instead need the
higher-level mesh/camera/material interface described above. Engine ownership,
window/input integration and target architecture also need a prototype before
choosing Bevy. The stable original renderer provides the comparison reference.

The reproduced dock stalls were fixed in the existing backend: one defect lost
audio interrupt events and another allocated GPU buffers for every small batch.
Changing graphics engines would still leave the original audio-clock behavior
to implement. See [the measured fix](GPU_UPLOAD_ARENA.md).
