# Widescreen and output resolution

The bundled SDL_GPU renderer supports a wider horizontal scene view, higher
geometry resolution and an explicit output size. These are optional launch
settings. Starting without video flags retains the existing display behaviour.

## Launch

Run from the project directory:

```powershell
./tools/run.ps1 -Widescreen -Resolution 2560x1440 -Fullscreen
```

Omit `-Fullscreen` for a 2560×1440 window. The options also work alongside
`-LoadCheckpoint`, `-ResumeInput`, `-RecordInput` and `-ReplayInput`.

| PowerShell option | Native executable option | Behaviour |
| --- | --- | --- |
| `-Widescreen` | `--widescreen` | Expand the horizontal scene view to the requested aspect ratio; default to 1280×720 when resolution is omitted. |
| `-Resolution 2560x1440` | `--resolution 2560x1440` | Set the output size and select sufficient integer internal rendering scale. Used alone, preserve the original display aspect with bars where needed. |
| `-Fullscreen` | `--fullscreen` | Start in fullscreen using the monitor's desktop dimensions and refresh rate. Used alone, configure 1280×960 output with the original aspect. |

The native equivalent, with an explicit disc image, is:

```powershell
./build/windows-x86-debug/mgs-integral-native.exe `
    --disc 'D:/games/Integral-disc1.cue' `
    --widescreen --resolution 2560x1440 --fullscreen
```

Fullscreen uses an SDL fullscreen mode matching the desktop when available,
otherwise desktop fullscreen. It does not change the monitor to the requested
`-Resolution`. That option determines rendering scale, intended game aspect and
capture dimensions; presentation fits the desktop with bars if its aspect
differs. F4 still toggles fullscreen during play.

## Scene, HUD and movies

Widescreen renders additional scene geometry at the left and right edges while
retaining the original camera and vertical composition. At 16:9, rendering uses
a 3:4 horizontal coordinate transform and wider clipping limits. The HUD retains
its proportions and occupies the central 4:3 region. Background clears and
fullscreen fade overlays cover the wider view. Cinematic bars, including their
animated gradients, span the full width. Underwater, blur and focus effects use
explicit framebuffer drawing scopes so their copies are not squeezed again.
Those scopes sample the scaled framebuffer, preserving rendered detail through
the copies, blends and masks. Ordinary texture sampling remains separate.
Translucent world polygons also blend against the scaled destination. This
prevents light halos from replacing detailed geometry with coarse background
pixels. The original glow texture remains 32×32; see the
[light-effect investigation](WIDESCREEN_LIGHTS.md).

Codec and prerecorded movies temporarily use a 4:3 canvas, centred within the
output. This preserves the Codec's original framebuffer copy coordinates,
including those used to display the frequency. Widescreen resumes after both
Codec and movie scopes have closed. Prerecorded movies retain their original
image detail.
Codec LCD segments, displaced glow copies and portrait scanlines are authored
effects; they are also present in the matching original-resolution capture.

Startup logos and complete menu screens also retain a 4:3 canvas. Their direct
framebuffer drawing and queued primitives use the same coordinates; gameplay
HUD elements continue to occupy the centre of the wider scene. Returning to a
3D stage restores the wider camera view.
Screen-aligned polygons use a resolution-aware texel offset. This prevents
adjacent image pieces from reading the next texture-atlas column at high
internal scales; world polygons retain their existing sampling rules.

### Shared rules for original 4:3 elements

The primitive's purpose determines its widescreen treatment:

| Original element | Widescreen treatment |
| --- | --- |
| Untextured screen-wide `TILE` rectangle | Fill the output width in either world or HUD drawing channels; preserve vertical clipping and original blending. |
| Screen-wide HUD `F4` / horizontally uniform `G4` band | Fill the output width, including animated cinematic bars. |
| Framebuffer copy used by water, blur or focus | Explicit canvas scope preserves full-width coordinates and scaled source detail. |
| Ordinary HUD/text/icon | Preserve proportions inside the central 4:3 region. |
| Complete logo, menu, Codec or movie canvas | Preserve the original 4:3 canvas and its framebuffer coordinates. |
| Projected world polygon | Retain the wider camera transform, even if its corners happen to match the original screen edges. |

The dock patrol lamp exposed a gap in the first rule. Its `pato_lmp.c` actor
submits an additive `TILE` at `(-160,-112)`, size `320×224`, through
`DG_ChanlOTag(0)`, which selects the world channel with draw offset `(160,112)`.
The previous renderer only recognized screen fills in the HUD channel. The
shared `IsFullWidthBand` classifier now recognizes these 2D rectangles in both
channels. This also covers the same packet forms used by `red_alrt.c`,
`fadeio.c` and `scn_mask.c`, without individual actor patches or stage names.
Those additional actors have source/packet coverage, not new runtime captures.

Recognition requires a full-width drawing area and exact rectangle edges after
the original draw offset/grid transform. Narrow rectangles and horizontally
clipped subviews retain their normal transform. The bypass lasts for one
primitive, with batching and scissor state restored before the next draw.
Textured world geometry cannot safely be classified as a screen overlay from
its size alone; new compound screen effects should use an explicit canvas scope.

## What 2560×1440 renders

`-Widescreen -Resolution 2560x1440` selects **8× internal rendering**. Geometry
is rasterized into the scaled render target: the active 320×224 framebuffer
region becomes **2560×1792**, then resolves vertically to the **2560×1440**
output. The final presentation uses linear filtering for this resolve. Texture
sampling still uses the original texture resources; increasing resolution does
not add detail to their pixels.

Internal scale is the larger of `ceil(width / 320)` and
`ceil(height / source_height)`, where `source_height` is 224 with widescreen and
240 with the original aspect. This scale is limited to 8×. A request needing
more is rejected explicitly; for example, 3840×2160 needs 12× and cannot run
through this option on the current renderer.

Resolution syntax is decimal `WIDTHxHEIGHT`, using a lowercase `x`. Parsing
accepts widths 320–7680 and heights 240–4320; the renderer's 8× limit further
restricts usable sizes. Widescreen also requires an aspect between 4:3 and 4:1.
Malformed, out-of-range or unsupported requests terminate with an error.

## Captures and recordings

With any video option active, `-Capture` reads the scaled render target and
resolves it to the configured output dimensions. For example:

```powershell
./tools/run.ps1 -Widescreen -Resolution 2560x1440 `
    -Stage s00a -Probe dock -Frames 1800 -Capture build/dock-1440.bmp
```

The BMP is 2560×1440, including presentation bars where applicable. Capture
dimensions remain the requested dimensions even if fullscreen uses a different
desktop size. Launches without video flags retain native framebuffer captures.
Capture readback can stall its frame; it is intended for inspection and tests.

Video options are separate from input-session identity, startup saves and memory
cards. Replaying still checks recorded gameplay state strictly. Original
visibility values used by game actors are restored after wider rendering;
see [gameplay visibility](WIDESCREEN_VISIBILITY.md). The strict garage prefix
passes 1,997 input samples / 2,001 VSyncs at 2560×1440 widescreen, including the
guard interaction that originally diverged. The final full garage recording
also passes all **6,496 samples / 6,500 VSyncs** in widescreen fullscreen and
loads `s19b`. This verifies that recording, not every campaign interaction.

## Implementation and validation

The launch contract and scoped canvas state are in
[`src/mgs_video.c`](../src/mgs_video.c). Projection clipping hooks remain in
recovered `libdg`; drawing transforms, scaled rasterization and presentation
remain behind the [replaceable renderer interface](RENDERER_MODULES.md). These
options retain existing resource overrides for models, textures, sounds and
scripts. They do not provide new asset formats or a replacement graphics engine.

The default build passes **145 CTest suites**; see the
[test log](../build/widescreen-validation/screen-fill-ctest.log). These include parsing,
launcher forwarding, canvas scopes, normal/fog visibility, effect packet order,
pixel output and existing renderer regressions. GPU checks at 1×, 2× and 8×
verify split logo textures, HUD atlas boundaries and scaled framebuffer copies.
They also cover all four translucency modes, additive-black light borders,
overlapping lights and mask-preserved detail outside framebuffer-copy scopes.
The 2D test also requires the entire world control image to remain unchanged
after entering and leaving 2D scopes.
The widescreen pixel suite now tests world-channel screen fills at 1×, 2× and
8×, both framebuffer pages, centred and zero X origins, the lamp's additive
blend, one-row scanlines, vertical scissoring and state restoration. Projected
polygons, 319-pixel rectangles and partial drawing areas are negative controls.
The new lamp test fails against the previous renderer at its first outer-edge
pixel (`expected 0x4048, got 0`), then passes with the shared rule.

Real-disc checks at 2560×1440 include cold startup logo captures and strict
recording prefixes ending at the title menu (415 samples / 419 VSyncs) and dock
Codec (1,297 samples / 1,301 VSyncs). The startup logo's previously reproduced
vertical seam is absent in the rebuilt capture. These checks are separate from
full campaign playability and do not establish that every 2D screen or effect
is correct.

The final unskipped intro probe completes 5,000 VSyncs through title → `d00a`
→ `s00a` and observes the dock Codec, with no input after title. Its captures
show the full-width underwater effect and cinematic bars. Image readback stalls
some frames and the run logs audio queue warnings; it is visual/stage-transition
evidence, not a clean performance benchmark.

The dock-lamp follow-up reruns that unskipped 5,000-VSync intro before and after
the shared screen-fill fix, at 2560×1440 with captures every 60 VSyncs. Both
runs reach the dock Codec and produce byte-identical 4,996-sample input files.
Matching lamp frames
at VSyncs 3,540, 3,600 and 4,020 preserve every central 4:3 pixel while extending
the tint into both outer strips. At 3,600 the median RGB discontinuity across
the old edges drops from `(83,16,0)` to `(0,0,0)` over the inspected rows.
The [before](../build/screen-fill-validation/before.bmp.003600.bmp) and
[after](../build/screen-fill-validation/after.bmp.003600.bmp) captures were
visually inspected. Pixel comparisons and capture hashes are in
[`image-comparison.json`](../build/screen-fill-validation/image-comparison.json).
This establishes the reported dock-lamp repair, not every campaign effect.

Local evidence is under `build/widescreen-validation/`: `startup-aligned.*`,
`title-final.*`, `codec-final.*`, `intro-blend.*`, `garage-wide-fixed.*` and
`garage-full-final.*`. Captured frames
contain original disc imagery and remain ignored build artifacts.

## Sky and vignette coverage

The 9 October follow-up changes `thing/sphere.c` and `sphere2.c` to allocate
enough panorama tiles for the active viewport, extend the horizontal starting
position, and wrap the texture map. Tile dimensions and the central view remain
unchanged. This also handles widths that are not a whole number of tiles.

`takabe/gas_efct.c` retains all sixteen original gradient quads and adds an outer
ring of flat quads only in widescreen. They share the existing outer vertices,
current edge color, fade and blend mode. The original center is not stretched;
thermal-vision suppression still applies. Additional packets use the existing
portable renderer interface and no replacement artwork is embedded.

Three regression executables check both buffers, every covered viewport pixel
at selected widths (4:3 through 32:9), 241 panorama headings, texture wrapping,
unchanged center texels and unchanged vignette gradient packets. These and the
four existing framebuffer-effect tests pass. The full user's recorded prefix
also matches through its canyon/cave visits. These are coverage and runtime
checks; visual acceptance of the reported scenes remains for the playthrough.
The changes are exported in `patches/mgs-wide-sky-vignette.patch`.

### Sky texture seams

The rooftop recording exposed a second issue after coverage was widened:
panorama tiles still used the world polygon's half-texel sampling offset.
At higher internal resolutions their last fragments sampled the neighboring
texture-atlas row or column, producing the visible grid over the sky.

Both panorama actors now bracket their tiles with `MGS_VIDEO_BACKGROUND` and
`MGS_VIDEO_WORLD` packets. Background mode retains the wider scene transform
but uses resolution-aware 2D texture alignment. World sampling resumes before
the remaining scene geometry. The scope uses the existing portable GPU API;
the textures and renderer module boundary are unchanged. The ordering-table
insertion order requires the begin packet at the end of the primitive array
and the restore packet at its start. Both packets use the tiles' depth.

GPU tests reproduce the atlas bleed with legacy world sampling at 2× and 8×
and require zero tile-edge contamination with alignment at 1×, 2× and 8×.
Packet checks cover both buffers and state restoration. Real-disc captures at
VSync 45,805 of `run-20261009-191445-721.mgsinput`, in `s11b` at 2560×1440,
show the grid in the old build and its removal in the new build:
[before](../build/tower-report-20261009/recorded-sky-before.bmp),
[after](../build/tower-report-20261009/fixed-visual.bmp.045805.bmp).
The vendor changes are in `patches/mgs-sky-texture-alignment.patch`.

The original source stack exports earlier changes as `mgs-widescreen.patch` and
`psyz-widescreen-output.patch`; bootstrap verifies 65 MGS / 17 PsyZ patches.
Scoped first-party scans have no findings. Touched vendor code retains inherited
function/file-size warnings and a `goto`-label false positive; no errors or
fixable warnings remain. The C/C++ scan lacks cppcheck and clang-tidy.
