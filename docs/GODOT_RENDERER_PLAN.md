# Godot renderer migration

## Accepted scope

The first playable prototype must cover normal startup/main menu, docks (`s00a`),
helipad (`s01a`), Codec and transitions between them. Gameplay stays in the recovered
C runtime. Original visuals are the reference. Enhanced lighting and fog are opt-in
stage overrides. The initial editor is Godot with an MGS plugin; model replacements
must retain the original rig and attachment slots initially.

The campaign-complete baseline is commit `faf31a1`, tag
`campaign-complete-2026-10-10`. Its replay archive is retained in `test-data/`.
Renderer work uses branch `prototype/godot-renderer` and a separate build directory.

## Engine and process boundary

Pin Godot **4.8-dev7**, official commit `c971f93e7`, using Forward+.
[Official archive](https://godotengine.org/download/archive/).
[Volumetric fog requires Forward+](https://docs.godotengine.org/en/latest/tutorials/3d/volumetric_fog.html).
The current game uses 32-bit pointers; the editor uses a 64-bit process. A versioned
local transport avoids changing recovered gameplay layouts just to embed an engine.
Only fixed-width values cross that boundary. The C runtime owns simulation, audio,
replay timing and saves. Godot owns the visible window and GPU rendering.

Two rendering layers are necessary:

1. A compatibility command renderer in Godot RenderingDevice preserves palette
   uploads, draw ordering, framebuffer reads, masks, HUD, menus, Codec and effects.
   It receives vertices and texture transfers, never a frame rasterized by SDL.
   Reuse the existing packet decoder and PS1 shaders; do not recreate gameplay.
2. A semantic scene layer transfers unprojected meshes, camera, model instances and
   joint transforms into Godot meshes. This layer enables perspective-correct
   geometry, depth, replacement models, lights and fog. Compatibility-only rendering
   is a migration step, **not completion of the scene renderer**.

Port layers incrementally with an explicit per-draw ownership classification so a
world object is not drawn twice. Keep compatibility UI/effects until their scene
equivalents have been checked against reference captures. A full-screen effect
must declare whether it covers the viewport, the camera frame or a fixed UI panel.

## Asset identity and preparation

Canonical IDs contain edition, disc/stage namespace, resource type and original
resource ID. Content hashes describe revisions, not identity. Instances get separate
generation-aware IDs; addresses and draw queue indices are never mod identifiers.
Cross-edition equivalences require explicit aliases rather than assuming the same
16-bit resource hash means the same asset everywhere.

The preparation tool reads a user's verified local disc extraction. KMD/ZMD mesh
definitions become glTF 2.0 with deterministic part/bone names and attachment slots.
PCX palettes become textures with transparent-zero and STP metadata retained.
Sidecars retain source provenance, original material modes and rig compatibility.
Generated content, thumbnails, recordings and Godot imports remain in ignored local
directories; the repository contains converters, schemas and synthetic fixtures.
No installer or example mod includes original game content.

## Order of delivery

1. Build the compatibility backend in Godot; validate uploads, masking, blending,
   readback, menus and input with synthetic fixtures, then actual disc resources.
2. Run docks, helipad and Codec with the original simulation. Check scene loading,
   input recording and transitions. Record what was actually verified.
3. Add semantic scene extraction, stable IDs and disc preparation for these stages;
   demonstrate a real mesh replacement and optional light/fog override.
4. Package the focused editor plugin, mod manifest/priority rules and rig checks.
   Expand the renderer across the campaign before calling it a complete replacement.
5. Publish the broader modding API/SDK after renderer contracts have runtime evidence.

## Acceptance evidence

Compilation, Godot shader validation, loaded scenes, interactive playability and
human campaign completion are separate statuses. Preserve comparison captures and
replay metadata locally. A frame limit or an empty window is not proof of a working
scene. Do not tune automated campaign players for this task.

## Progress

- Baseline and replay archive preserved; isolated renderer branch created.
- Exact Godot development executable downloaded and SHA-256 verified.
- Godot RenderingDevice compatibility backend built and booted against the local disc.
  No native SDL GPU device is created. Synthetic clear/draw/mask/upload/move/readback
  checks pass. Dock and English Codec captures are present under ignored `build/`.
- Existing bounded dock probe closes Codec and verifies Snake movement through the
  Godot backend. This is an automated input check, not a human playthrough.
- Disc preparation produces 1,736 catalog entries, including 140 rigged glTF models
  across normal/Very Easy/tuxedo resident sets, menu and opening stages. All 140 pass
  the Khronos glTF validator with zero errors/warnings. Original normals, texture
  coordinates, bones, seam ownership and live per-face lighting are preserved.
- Live model registration, actor lifetime IDs, model changes, camera and bone
  snapshots are implemented. Godot meshes render; world/UI composition is in place.
  Some transparent/runtime-textured parts stay in the Godot command layer.
  See the visual correction work below for current composition behavior.
- Asset bounds/palette/seam/UV/shading-coordinate tests: six passed. Godot synthetic
  GPU tests, mod path/priority/rig tests and the two relevant CTest suites pass.
- The user's retained Xbox prefix replay passed 15,675 samples / 15,679 VSyncs,
  including menu, opening, docks, authored elevator transition, helipad and Codec.
  Game-state checkpoints matched. Average 59.61 FPS; 18 frames exceeded the 2 ms
  tolerance; zero audio-empty refills. This predates the final shadow classification
  and UV/normal corrections, which were covered by the subsequent dock replay.
- A new dock recording passed 1,446 samples / 1,450 VSyncs with modified mesh
  geometry, cyan material and optional Forward+ lighting/volumetric fog. The final
  run had five frames over tolerance, including scene export/first-use work, and
  one audio-empty refill. F7 export and initial pipeline work are still synchronous.
- A 480-sample menu prefix passed and its difficulty-selection screen was captured.
  Closing the Godot window was also checked: native shutdown completed normally
  and finalized a 415-sample input recording instead of reporting a lost connection.
  Independent dock and helipad movement probes passed. The old navigation probe
  stalled waiting for a script flag; it was stopped without changing gameplay or
  tuning the player. Transition evidence comes from the user's recorded inputs.
- Vendor changes exported as incremental patches; both pinned stacks verified.
- MGS Visuals editor plugin, model/texture replacement manifests, rig/bind validation,
  stage light/fog overrides, disc preparation wrapper and local examples implemented.
  Original content and generated examples remain ignored. The baseline replay
  archive SHA-256 still matches the campaign-complete milestone.
- Scoped Aislop scan: zero errors/warnings on 13 supported source files. C lint
  engines cppcheck/clang-tidy are unavailable; GDScript is validated with Godot.
  A separate scan of six modified vendor files has no errors/fixable warnings;
  seven nonfixable complexity warnings remain (large backend functions/files and
  recovered actor routines). Its eighth warning is a false positive: `chanl.c`'s
  `found:` label is reached by `goto` before the intervening `return`. No rules
  were disabled. Patch-file blank context lines are required unified-diff syntax;
  source whitespace checks exclude those patch containers.

## Handoff and next work

The default scene renderer has serious visual defects reported during testing.
The earlier readiness claim was premature: replay checks established matching
game state, not correct rendering. Visual comparison against the native baseline
is now the blocking work, including moving scenes and effect ordering.
See [the editor/modding guide](GODOT_MODDING.md) for replacements and optional effects.
Local evidence is under `build/godot-*.log`, `build/godot-*.png` and `.local/replays`.

Next migrate transparent meshes, particles, palette animation, thermal/stealth
materials and framebuffer effects into depth-aware Godot passes; then raise the
internal resolution and reintroduce widescreen. Expand stage coverage and replace
full-scene snapshots with retained resources/changed transforms after correctness
is established. The transport and manifest are prototype contracts; a broader
public gameplay/audio/mod SDK follows the renderer migration.

## Visual correction work, 2026-10-10

The default `-Scene3D` path, without example mods, had reproducible defects.
Same-input dock captures showed the command renderer matching native output while
the semantic scene disappeared during an underwater view. The raw Godot scene
was present: a later original framebuffer clear erased the early world blit.
Compositing all remaining primitives over one flattened scene also broke occlusion.
The visible menu included 16 blank rows because the bridge used GPU mode height
instead of the active display range.

- Replaced channel-entry/sky-boundary blits with depth intervals inserted around
  populated original ordering-table buckets. Godot color/depth is merged before
  and after those effects. Original force/preserve-mask bits apply to world pixels.
- A CompositorEffect copies the actual Godot depth buffer into bridge-owned linear
  depth. It uses the rendering camera's inverse projection. This follows the
  [CompositorEffect lifecycle](https://docs.godotengine.org/en/latest/classes/class_compositoreffect.html)
  and avoids retaining the engine's temporary scene buffers.
- Active display height is used for both presentation and renderer screenshots.
  A captured difficulty menu now fills the window without the extra bottom band.
- Packet ownership includes live opcode and texture-page type. Semitransparent or
  framebuffer-sampling materials such as stealth stay on the command path.
- Presentation sequence capture is available via `MGS_GODOT_CAPTURE_EVERY` and
  `MGS_GODOT_CAPTURE_FILE`; optional raw world images isolate composition defects.
- New GPU overlap test checks measured depths at 2/4 metres, near/far occlusion
  across an intermediate effect, and world mask output. Protocol GPU tests and
  video/visibility CTests pass. Native campaign executable and recordings preserved.
- The depth-composition build replayed all 15,675 input samples through docks,
  the elevator, helipad and Codec. Captures include the repaired underwater view,
  menu, Codec and helipad. This predates the final live stealth classification;
  its separate 3,300-sample replay passed, with underwater and stealth captures
  checked against the original command rendering.
- Both vendor patch stacks verified with bootstrap (`81` MGS, `22` Psyz patches).
  Scoped Aislop found no errors or fixable warnings. Eight nonfixable vendor
  warnings remain: seven inherited size/complexity findings and the existing
  `chanl.c` goto-label false positive. The optional cppcheck engine is unavailable.

Remaining limits: compatibility polygons still sort in the original 256-unit
depth buckets; they do not yet have per-fragment depth testing. These fixes do not
establish complete visual equivalence. Capture/readback overhead also makes the
diagnostic replay unsuitable for a frame-pacing acceptance claim. Original source
captures and all local retail-derived evidence stay ignored under `build/`.

## Unskipped cinematic correction, 2026-10-10

The retained Xbox replay skipped the opening shots reported in the next visual
review. An unskipped intro recording reproduced the missing scenery and incorrect
placement. `DemoScreenModelsSingle` subtracts the camera position before storing
static part `.world` matrices, while animated part `.world` matrices remain absolute.
Exporting both as absolute world poses applied the camera translation twice to
scenery. The final `.screen` matrices already contain the correct transformation.

- Protocol v3 exports those final local-to-view part matrices, undoing vertical
  overscan before transport. Godot reconstructs world poses with the inverse view.
  Models remain independent replaceable resources with their original rigs.
- WORLD now carries separate viewport and clip rectangles. Drawing offsets place
  the image; cinematic clipping crops it without scaling or moving its projection.
- Rebuilt the Godot native executable. The same 4,496-sample unskipped recording
  passed through 4,500 VSyncs in both scene and command modes. Compared opening
  camera cuts, underwater walls, ceiling/platform credits shots, Snake beside the
  pipe, and the elevator guards. Large displaced/missing scenery in those captures
  is corrected. This is scoped visual evidence, not a full renderer certification.
- Evidence: `build/unskipped-before`, `build/unskipped-fixed`, and
  `build/unskipped-matched-reference`; input under `.local/godot-tests`.
- The existing dock recording also passed all 1,446 samples through 1,450 VSyncs
  with the new pose export (`build/godot-dock-pose-replay.log` and `.bmp`). A separate
  420-VSync direct-stage probe stopped during the opening Codec before its movement
  checks could complete; that truncated probe is not a pass. The campaign archive
  retains its recorded SHA-256 and the native campaign executable was not rebuilt.
- Extended the GPU composition test to prove a restricted clip does not resize
  geometry. It passes alongside protocol GPU tests and video/visibility CTests.
  Bootstrap verifies all 81 MGS and 22 Psyz patches. Aislop reports no project
  errors/warnings; the touched vendor backend retains five nonfixable size/complexity
  warnings. Optional C lint tools cppcheck/clang-tidy remain unavailable.

The user also noticed brief camera holds. A capture-free scene replay confirmed
18 slow frames during the active cinematic, at 20.4–27.2 ms versus the 16.68 ms
presentation budget. Most clustered
around VSyncs 1647–1723. Camera animation retains its original 30 Hz cadence, but
these additional presentation delays are real. Frame pacing remains unresolved.
`build/unskipped-clean-timing.log` identifies the retained timing CSV: 4,496 samples
passed, 4,500 VSyncs, no empty audio refills. Screenshot runs have additional capture
overhead and must not be used for performance acceptance.

## Startup without input, 2026-10-10

Normal startup failed after the logos when no buttons were pressed. The native
runtime entered `opening`, which was missing from the converter's default stage
list. Godot reported `Prepared model missing:
mgs/integral-j/disc1/stage/opening/d82d.k` and closed its connection. The local
reproduction stopped at VSync 814. The earlier title/New Game tests skipped this
startup sequence and therefore did not cover it.

Added `opening` to default disc preparation and regenerated the local cache from
the verified disc import: 35 additional models and 247 textures. These use the same
stable stage/resource IDs and mod replacement pipeline; no retail data is tracked.
Asset conversion tests pass (six checks), and scoped Aislop has no errors/warnings.

## Paused renderer checkpoint, 2026-10-10

The Godot experiment is preserved on branch `godot`. The user chose to evaluate
Remix Plus separately from the SDL campaign baseline, `faf31a1`, rather than
continue this renderer now. The native executable and replay archive are intact.

The no-input startup recording reached 12,000 VSyncs after adding the missing
`opening` assets. Rendering defects remain in that sequence.

This checkpoint deliberately includes unfinished protocol v4 work: scene-update
ordering barriers, live packet UV/ordering export, and shared reference material
and metadata shaders. Scene decoding, metadata camera setup, composition and GPU
tests have not yet been updated to consume all of those changes. The working
sources are not runnable as a matched renderer/runtime pair. Do not treat this
preservation commit as a validated build or overwrite the saved SDL executable.

Local recordings and captures remain in `.local/godot-tests`, `.local/replays`
and `build`; converted retail assets remain ignored. The separate Remix Plus
worktree must use its own vendor trees and build directories.
