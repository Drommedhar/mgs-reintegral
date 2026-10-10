# Polygon coverage and texture borders

The SDL_GPU renderer had reproducible defects relevant to the reported mesh
holes, flicker and transparent outlines. Integer polygon positions were mapped
to pixel corners instead of sampling centres. A separate UV correction depended
on the order of a triangle's vertices and on only two components of its texture
gradient. Rotating or shearing a texture could therefore select adjacent texels,
including transparent texels. The sampler already used nearest-neighbour
`texelFetch`; this was not bilinear filtering. Texture pages and palettes crossing
the VRAM boundary also made out-of-range reads instead of wrapping.

## Correction

Polygon vertices now receive half a physical framebuffer pixel of offset,
accounting for internal resolution and horizontal draw-grid scaling. At native
resolution this evaluates polygon attributes at the original integer positions.
Polygon UVs round to the nearest texel, independently of vertex order. Sprites
retain their rectangular coverage and direct texel indexing. Texture coordinates
wrap at 256 before applying the texture window. Texture and palette fetches wrap
within the 1024×512 VRAM image.

The correction stays inside the replaceable renderer. Game actors, source models,
textures, palettes, sounds and mod-resource interfaces are unchanged. Both GLSL
shaders and their regenerated SPIR-V, MSL and signed DXIL headers are included in
`patches/psyz-polygon-rasterization.patch`. Runtime results below are from SDL_GPU/D3D12 on
Windows; generating the other shader formats is not a Vulkan or Metal runtime
test. The legacy OpenGL backend is outside this change.

## Pixel evidence

- `mgs_gpu_edges_test` submits real F3/F4 packets. Five analytic triangle shapes,
  six vertex permutations, signed coordinates with draw offsets, both rectangle
  diagonals, reversed draw order and additive blending check coverage. The
  initial native baseline missed 288 pixels; the software reference passed.
  The expanded corrected native and software cases each pass **70,656 pixel
  comparisons**. Scaled shared-edge checks pass **9,216 comparisons**.
- `mgs_gpu_texture_coordinates_test` checks rotated, flipped and sheared affine
  mappings in 4-, 8- and 16-bit texture modes, including transparent texels and
  sprite coordinates crossing 255. VRAM tests include 16-bit and packed 8-bit
  pages crossing X=1024, plus a palette crossing that boundary. Before the
  correction, the final suite reported **34,468 native** and **24,232 scaled**
  mismatches. The corrected shader passes **124,980 comparisons per resolution**
  with zero mismatches. The VRAM-wrap cases independently reproduced 144 errors
  after the initial UV correction, before the wrapping fix.
  Scaled polygon checks establish vertex-order invariance, not bit-exact PS1
  output at an enhanced resolution. Explicit opaque and transparent anchors
  prevent an empty image from satisfying the scaled invariance checks.
- Existing masking, ordered blending, framebuffer/CLUT feedback and upload-arena
  tests also pass with the correction.

The scaled tests read native VRAM through `StoreImage`, after downsampling; they
do not inspect every physical high-resolution framebuffer pixel. These cases
establish the repaired contracts, not complete PS1 rasterizer accuracy or a
reproduction of every scene reported by the user.

The polygon boundary, quad splitting, order independence and coordinate rules
are described in the [PSX GPU specification](https://psx-spx.consoledev.net/graphicsprocessingunitgpu/).
Independent reference implementations also distinguish integer PS1 sampling from
modern pixel centres: [software rasterizer](https://github.com/stenzek/duckstation/blob/master/src/core/gpu_sw_rasterizer.inl)
and [hardware shader generator](https://github.com/stenzek/duckstation/blob/master/src/core/gpu_hw_shadergen.cpp).
Our scaled policy is explicit above; it does not copy DuckStation's separate
upscaled UV adjustment scheme.

Local regression logs are in `build/gpu-uv-audit`, `build/gpu-edges-audit` and
`build/gpu-edge-validation`. See also [mask/blend checks](GPU_MASKING.md) and the
[renderer module boundary](RENDERER_MODULES.md).

## Disc replay and integration

The rebuilt default executable passes **119 CTest suites**. Bootstrap verifies
**64 MGS / 16 PsyZ patches**. A frozen pre-change executable and the rebuilt one
both pass the same authentic garage recording: **6,496 samples / 6,500 VSyncs**,
ending in `s19b`. This establishes unchanged recorded gameplay state, not a
completed escape: the garage-only controller stops driving in the next stage.

A separate strict prefix passes **1,997 samples / 2,001 VSyncs**, capturing the
same jeep, Snake, Meryl, ceiling and English subtitles on both builds. The
[baseline image](../build/gpu-edge-validation/baseline/garage-2001.bmp) and
[corrected image](../build/gpu-edge-validation/fixed/garage-2001.bmp) were inspected.
The original movie and its authentic startup checkpoint remain unchanged.
[Comparison manifest](../build/gpu-edge-validation/comparison.json),
[full test log](../build/gpu-edge-validation/ctest-final.log),
[patch verification](../build/gpu-edge-validation/bootstrap.log).

The final default executable SHA256 is
`83f6b47c7aa920ae7ac9519fc5ee4443c1ead5bd8f2c87af54f1b0ee76c54fe0`.
The source/test changes introduce no Aislop errors or fixable warnings. The two
new C tests scan clean; the touched vendor C/header scope retains five nonfixable
file/function-length warnings and three informational TODO findings. cppcheck
and clang-tidy are unavailable, and Aislop does not analyze GLSL; all generated
shader formats passed their respective compilation steps.
