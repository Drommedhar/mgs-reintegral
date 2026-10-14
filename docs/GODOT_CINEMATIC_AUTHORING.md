# Cinematic source preparation and editor preview

The editor can select a cutscene's original scenery and scrub its source camera
without launching native gameplay. Scenery edits target the containing stage.
Camera edits target the exact selected clip and are sampled at its native source
frame in game. Original tracks remain local; mods store only authored changes.

## Using the current preview

Run `tools/prepare-godot-content.ps1 -CinematicsOnly` for an existing matching map
cache, and repeat with `-Disc 2` for the second disc. Full content preparation now
includes this step. Reload the editor catalog, select the source disc, search for
the location and open a **Cinematic clip** row. The numeric clip suffix identifies
its original stream sector; no guessed human clip titles are assigned.

The map overlay opens against the scenery declared by that stream. This also
opens sets such as `opening` and `s07b` that have no startup map geometry. Select
`LocalMapReference/OriginalCameraTimeline`, choose its `Original` animation and
scrub in Godot's Animation panel. Select `OriginalCamera` to use Godot's camera
preview. To change the camera, edit or key its transform and horizontal FOV in
the `Original` animation. Save the scene normally; reopening rebuilds the
original track locally and applies the saved changes. Export ZIP uses the same
sparse scene data. Moving the camera without keying the animation changes only
the temporary editor preview.
Actor animation, audio and native script events do not run while scrubbing.

The animation uses nominal 30-frame-per-second source time, discrete pose/lens
keys and nearest interpolation. It preserves hard changes without smoothing
across cuts. A few source streams begin with all-zero camera packets; these are
not usable poses. The first valid camera key is recorded as `first_camera_frame`
and earlier blank packets are omitted from the preview. This is not proof of
native pixel parity. Runtime sampling uses the packet frame actually applied by
the native demo player; it does not advance an independent Godot clock.

Tracks support discrete or continuous updates, with nearest or linear
interpolation. Keep both pose/lens tracks, source duration and no looping. Key
easing supports 1 (linear) or 0 (hold). Keys must fall on source frames and contain a finite unscaled rotation
and FOV between 1 and 179 degrees. Unsupported edits report an error and block
ZIP export. Dedicated look-target controls remain open. Static, procedural and
native-time custom camera rigs are supported as described below.

## Authored presentation cameras

Copy `renderers/godot/project/examples/presentation_camera` into the active mod
folder and instance its Camera3D scene in a map overlay. Use normal camera preview,
transforms, parent nodes, lens, Environment and CameraAttributes. Parenting under a
native actor binding follows that actor without changing its gameplay camera.
The example script selects gameplay-only, exact cinematic clip, or whole-stage
ownership. Exact clips must exist in the prepared local catalog. Disable or hide
the camera to release ownership; unloading the stage unregisters it. Competing
eligible cameras, invalid transforms/lenses and unsupported projections report
errors instead of silently choosing another view.

Only perspective projection is currently supported for authored rigs. FOV and
Keep Aspect have ordinary Godot semantics; the original clip track's additional
widescreen conversion is not applied to an authored Camera3D. Internal metadata
and background views follow its lens/clipping/offsets while retaining their own
render layers. A camera never changes native model/effect coordinates.

Ownership changes reset FSR2/fog history. Use the example's `cut()` for an abrupt
scripted change on the same camera. Procedural scripts can connect to visual API
`camera_update_requested`; native world poses and the original/edited clip camera
are then available, before the selected rig, particle sorting and metadata view
are applied. API methods are `register_presentation_camera(camera, scope, clip)`,
`unregister_presentation_camera(camera)` and `request_camera_cut(camera)`.
The script lives in the mod folder and survives ordinary save/ZIP/reopen without
retail dependencies.

## Custom native-time camera animations

Instance `examples/presentation_camera/native_timeline.tscn` from a copy inside
your mod. Its Node3D root selects a descendant Camera3D, AnimationPlayer,
animation name and exact clip ID. The included two-second pan/zoom is authored
example content targeting the docks introduction; place the camera in the
ordinary editor preview and replace its keys with your shot.

Edit transform and camera lens tracks in Godot's Animation panel. Native playback
samples the animation at the applied clip frame divided by 30; repeated frames
hold the pose and skipped frames seek directly. A shorter animation holds its
last pose, and an animation longer than the native clip reports an error. Native
clip end, abort, stage exit or disabling the root releases ownership. Marks in
the animation act as cuts; crossing a mark or restarting the clip resets history.

Runtime autoplay is disabled before the child player initializes. The player is
sampled manually with event processing disabled. Method, audio, animation-playback,
capture and looping tracks are rejected; tracks may only target transforms or
camera lens properties on descendant pivots/cameras. Root tracks are rejected to
preserve map coordinate conversion. Missing prepared clip IDs report an error
before playback. This keeps cinematic events and audio
under native control. Normal editor scrubbing remains available. The adapter
reports errors through the visual API's `set_presentation_camera_error(owner,
message)`; an empty message clears that owner's error. Save and ZIP export retain
the authored animation and portable script, with no original timeline dependency.

## Hard cuts

In `OriginalCameraTimeline`'s `Original` animation, add a named marker at the first
source frame of each new shot using Godot's Animation panel. Each marker is a
hard cut. Key both transform and FOV at that frame. Discrete tracks already hold
their previous pose. On continuous tracks, set the preceding key's easing to 0
on both tracks so the editor and runtime hold the old shot until the cut. Other
segments can still interpolate normally. Markers must lie on source frames
inside the original duration; invalid cuts block save/export with a diagnostic.

Marker names, colors, frames and hold-key changes are saved with the sparse
camera edit, without copying unchanged original poses/lenses. Removing a marker
removes its history reset; restoring easing and keys removes the remaining edit.
Playback resets history once when a marker is crossed, including when native
streaming skips that exact frame. Pausing or repeating the same frame does not
reset it again. Clip entry/exit, generation changes and stage reconfiguration
also request a reset. Native timing, audio and events stay authoritative.

Godot 4.8.dev7 `c971f93e7` does not expose a direct FSR2 accumulation-reset API:
its [Forward+ source](https://github.com/godotengine/godot/blob/c971f93e7/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp)
always supplies a false reset flag. `camera_history.gd` uses the pinned
[RenderingServer sharpness setter](https://github.com/godotengine/godot/blob/c971f93e7/servers/rendering/renderer_viewport.cpp)
with the existing value to rebuild the viewport's temporal buffers once before
the cut frame. Resolution, FSR2 mode and sharpness remain unchanged. Volumetric
fog uses a temporary copy of the active environment with history weight zero for
that frame, still writing fresh history for the next frame. The authored
environment is restored after both world and background views render.

This is a version-specific buffer recreation path, not a lightweight engine
reset API. The GPU regression test verifies fresh output and continued clean fog,
but its small test viewport does not prove full-resolution cut-frame pacing.
Recheck this path when upgrading Godot. Existing source shots without authored
markers do not yet have semantic per-shot cut notifications.

Normal map changes use the existing sparse overlay workflow. Switching clips
retains authored nodes, including children attached to an original preview.
The chosen clip ID and source digest are saved with the scene so reopening can
rebuild the same reference. Saving strips original geometry, camera keys and
AnimationLibrary resources, retaining only changed/added/removed keys and changed
interpolation/update modes, hold keys and cut markers in `mgs_camera_edits`. Reverting to original keys removes
redundant edits. Export rejects copied original animation resources
when their retail provenance metadata is preserved. The general transitive
provenance audit remains an open SDK requirement.

Scenery edits apply to all clips that use that stage; camera keys select an exact
disc/clip identity within that stage overlay. A row with no static scenery explains
that an actor-only preview is not available. An unavailable row must not be
replaced with arbitrary geometry from another stage.

## Source evidence and identity

- `game/script.c::DemoCmd` reads `demo -s`, passes nonnegative stream codes to
  `GM_DemoStream`, and uses negative codes for placeholder messages. Native
  `game/strctrl.c` / `libfs/stream.c` resolve disc stream offsets. The new importer
  uses the original GCX literal sector values, including sector zero.
- `tools/language_script.py::procedures` parses main and named procedures and
  nested blocks structurally. `cinematic_scenes.py` records literal demo references
  with procedure ID and command ordinal. It lists runtime-dependent selectors
  explicitly; it does not evaluate script conditions or prove reachability.
- `include/fmt_dmo.h` defines DMO_DEF, DMO_MAP and DMO_DAT. `kojo/demoexec.c`
  validates map cache dependencies, creates cinematic models, and applies the
  eye/target/roll/projection-distance fields in `FrameRunDemo`. Prepared scenery
  resolves exact model names in the defining stage or its same-disc resident set.
  Current linked map records use ordinary KMD cache IDs; packed source provenance
  remains separate work.
- `kojo/demothrd.c::ActStream` chooses native packets from the stream clock, skips
  overdue samples and calls `FrameRunDemo`. Offline scrubbing must not replace
  this scheduler or replay its callbacks. Protocol 15.7 context exposes stream
  disc/sector, generation, duration, applied frame and active state. Camera edits
  consume these values without changing that scheduler or the native camera.
- IDs are `mgs/integral-j/discN/demo/<eight-hex-sector>`. Preparation checks the
  DEMO.DAT receipt hash, retains the complete stream digest and fingerprints each
  generated camera JSON. Stage/script fingerprints and exact bindings accompany
  the preview. The content loader validates files before mounting them; changed
  files and mismatched saved source digests fail explicitly.

The locally prepared main GCX references identify 79 distinct disc-1 clips through
172 stage bindings in 38 stages, and 40 disc-2 clips through 67 bindings in 18
stages. All those selectors are literal in these scripts. This does not account
for every native-selected/theater/file demo or close the scenario inventory.
Six bindings have no static map declaration and remain unavailable as scenery
previews; their camera data is still prepared.

## Earlier MGSR reuse review — M6.01

Inspected `D:\git\MGSR\archive\godot-20260924` read-only:

| Source | Reusable approach | Difference in this SDK |
| --- | --- | --- |
| `scripts/StageCutsceneCameraPath.cs` | Eye/target Path3D edits tied to original frame IDs; finite-value and key-count checks | It duplicates a complete original motion library and patches points. We need sparse changes/custom tracks whose packages contain no original keys. |
| `src/content-compiler/GodotContentImporter.ScenePaths.cs` | Discover demo references from parsed scripts and expose normal scene nodes | Its `OriginalVoiceAsset` maps PC stream names. Integral uses verified disc/sector IDs, not PC filenames. |
| `src/content-compiler/DmoAnimationCompiler.cs` | Native AnimationLibrary resources, discrete camera/model channels and source-key verification | Current preview imports camera transform/lens only. Actor rigs, effects and native time sampling remain separate work. |
| `scripts/DmoCameraTrack.cs`, `scripts/Original/DmoCamera.cs` | Explicit eye, target, roll and lens values; a camera-specific basis | The old app has its own PC-derived runtime/rotation math. Confirm Integral `FrameRunDemo` and the existing scene renderer's projection instead of copying that runtime. |
| `docs/research/dmo.md` | Keep stream timing, skipped packets and callback lifecycle distinct from authored animation | Earlier validation is evidence for that PC-based project, not validation of the Integral bridge. |

Current prepared meshes use `(x,-y,-z)/1000`; the editor reference root rotates
them back into native Y-up world space. Camera preview uses the same conversion,
native up, source roll in 4096 units/revolution and horizontal
`2*atan(160/projection_distance)` lens. Position, forward/up axes, roll direction,
lens changes and discrete cuts have synthetic checks. The earlier scene paths
cannot be copied directly into renderer coordinates.

## Next implementation boundary

Verify live skip/abort/finish and stage-unload ownership across representative
clips. Authored marker and clip-lifecycle history handling is implemented; native
source shots without markers still need explicit cut evidence. Native event/audio scheduling is
unchanged. Protocol 15.8 submits active owned meshes outside native bounds,
retains their live material packets and sends registered world effects without
native projection rejection. Billboards use their centre and rectangle dimensions
and face the presentation camera. Runtime converts camera-relative poses/effect
centres using the native camera first, then applies the presentation camera.
M4.02/M6.08 remain open for actors that suppress visual updates or emitter creation
before submission, unsupported primitive paths and full-resolution cut-frame pacing.
Complete actor preview, conditional map groups and complete source/provenance
validation remain open.
