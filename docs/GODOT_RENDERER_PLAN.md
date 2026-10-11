# Godot renderer migration

## Active direction, 11 October 2026

The user selected Godot as the primary renderer and modding SDK/editor direction.
This supersedes the paused checkpoint below. Remix Plus remains a separate
experiment, with further integration work deferred. Reuse its verified findings
about coordinates, live materials and composition where they apply to the shared
native scene data; changes to the Godot renderer still require their own checks.

The recovered C runtime owns gameplay, collision, animation, audio, saves and
timing. Godot owns rendering and the visual authoring workflow. The native alpha
is the playable reference while this integration is completed.

### Runtime fixes following the SDK handoff

The current pair uses protocol v9, including the selected widescreen projection.
Cutscene map variants inherit gameplay overlays,
and supported transparent model/water surfaces and physical particles receive
Godot lighting. It restores the native performance overlay in
the Godot window, corrects scaled 2D pixel-center alignment, removes original blob
shadows/static emitter halos from the 3D path, and avoids redundant framebuffer
copies. A faster command loop reduces synchronous bridge delays while native
VSync retains gameplay timing. Bounded socket writes, draining incoming data,
buffered native logging and per-character material reuse remove the remaining
steady dock stalls in the scoped 1440p check. Existing ZIPs remain compatible.
Native temporary lights and weapon attachments now provide shadow-casting omni
and spot lights, with normal Godot light templates in map scenes. SDFGI is an
optional authored Environment setting; original static map geometry contributes,
while animated actors and transparent effects receive it without static injection.
Remaining cutscene pacing work is deferred at the user's request while the editor
and mod workflow continues.
See the latest [progress entry](../PROGRESS.md) for measured frame-time distributions,
the repeatable performance check and validation limits.

### Implemented: matched v4 renderer and visual mod workflow

The user's follow-up on 11 October adds GDExtension visual mod hooks, dynamic
lights/shadows, PBR maps/materials and map overlays in MGS Visuals. These are now
implemented and covered by a compiled native-extension test, GPU lighting tests,
map removal/export tests and a real dock replay from a relocated mod package.
Original map references remain local; exports contain edits and custom assets.
The user chose visual removal only, preserving native collision/gameplay.
See [the authoring guide](GODOT_MODDING.md) and the latest progress-ledger entry.

The Godot scene consumer now matches native protocol v4: live per-face UVs,
visibility and original ordering accompany the bone and lighting palettes.
A separate metadata camera supplies ordering, mask and color-quantization flags.
Composition checks metadata against scene depth so custom foreground geometry
does not inherit a background object's packet data. Scene barriers draw color
and metadata together before the native WORLD command consumes them.

Model/texture replacements, optional Godot lighting and disc-backed editor maps
use this path. Material validation follows native draw ownership: unused runtime
textures on compatibility parts are allowed, while missing textures on visible
Godot meshes fail explicitly. Stage changes retain definition-stage asset IDs;
retired models leave the scene immediately. The protocol document now includes
both v4 palettes and the 52-byte WORLD payload.

Validation on 11 October:

- Rebuilt `build/windows-x86-godot/mgs-integral-native.exe`. Four scoped native
  video/visibility CTests pass. `tools/test-godot.ps1` passes scene snapshot,
  mod contract, six asset conversion, GPU protocol and GPU composition checks.
  The latter cover depth/clipping, ordering, STP, dithering, live UVs, custom
  geometry and face visibility.
- Verified local disc startup without input through 1,800 VSyncs. The unskipped
  opening matches all 4,496 recorded inputs / 4,500 VSyncs in scene and command
  modes; matched captures provide scoped visual comparison.
- Re-preparation reproduces all 2,018 asset identities, including 175 models.
  A combined model/checker-texture/lighting mod replay passes 1,446 inputs /
  1,450 VSyncs in the docks with no Godot errors. Captures show all three overrides.
  Stage preview export excludes internal metadata and the runtime compositor;
  the snapshot test verifies reloading and stable asset identity.
- The historical Xbox route currently diverges at inventory sample 3,606 in
  both scene and command modes, with the same expected/actual checksums. Its
  earlier full-route pass below is historical evidence, not a pass for this build.
- A separate heliport checkpoint replay passes 2,996 inputs / 3,000 VSyncs,
  including Codec and movement, in both scene and command modes without Godot
  errors. Matched Codec captures and a scene-mode gameplay capture were inspected.
  This verifies stage loading independently of the blocked dock-to-helipad recording.
- Performance acceptance is deferred: the user was running another game during
  these checks. Do not attribute the observed timings to renderer changes.

Remaining acceptance work includes current dock-to-helipad transition evidence,
broader visual/effect comparison and frame pacing under isolated conditions.
Campaign-wide rendering, widescreen and broader gameplay,
audio and script APIs remain subsequent milestones. Public SDK contracts remain
provisional. Local evidence is in `build/godot-v4-*` and `build/godot-tests/`.

## Accepted scope

The first playable prototype must cover normal startup/main menu, docks (`s00a`),
helipad (`s01a`), Codec and transitions between them. Gameplay stays in the recovered
C runtime. Original visuals are the reference. Enhanced lighting and fog are opt-in
stage overrides. The initial editor is Godot with an MGS plugin; model replacements
must retain the original rig and attachment slots initially.

The campaign-complete baseline is commit `faf31a1`, tag
`campaign-complete-2026-10-10`. Its replay archive is retained in `test-data/`.
The original renderer prototype was preserved on branch `godot`; its sources are
also present in the current `main` checkout. Use the separate
`build/windows-x86-godot` directory for renderer work.

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
materials and framebuffer effects into depth-aware Godot passes, and reintroduce
widescreen. Internal resolution now follows the launcher's output selection.
Expand stage coverage and replace
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

At that checkpoint, sources included unfinished protocol v4 work: scene-update
ordering barriers, live packet UV/ordering export, and shared reference material
and metadata shaders. Scene decoding, metadata camera setup, composition and GPU
tests had not yet been updated to consume all of those changes. That preservation
commit was not a runnable matched renderer/runtime pair. The 11 October
implementation above supersedes this limitation; the saved SDL executable remains
the gameplay baseline.

Local recordings and captures remain in `.local/godot-tests`, `.local/replays`
and `build`; converted retail assets remain ignored. The separate Remix Plus
worktree must use its own vendor trees and build directories.

## Fog backgrounds, 12 October 2026

The background WORLD range renders environment fog/sky without geometry, before
native foreground packets. GPU fixtures cover regular and volumetric fog, scene
lights and foreground ordering. Native regression tests cover repeated sorting
around pause/Codec transitions.

The user rejected the shallow-puddle reflection experiment after testing it in the
game. Protocol v13 removes its water snapshots, replacement planes, reflection
probes and custom ripples. Native puddles and ripple effects are restored. The
probe-specific test and engine-warning exception were removed with the feature.
