# Godot visual modding: technical reference

Start with the [mod creator guide](MOD_CREATOR_GUIDE.md) for an editor walkthrough,
or the [player guide](PLAYER_GUIDE.md) to install finished mods. This reference
covers the underlying resource, scripting and extension contracts.

Godot is the primary renderer and modding editor direction. The matched protocol
v15.32 implementation supports the workflows below, retaining compatibility with
package-pinned v15.30/31 clients; campaign-wide renderer
coverage and a stable public SDK remain follow-up work.

This is the first renderer-facing API, not a finished campaign SDK. The C runtime
still owns gameplay, collision, animation, audio, saves and input timing. Godot
owns all GPU rendering. Use the editor project at `renderers/godot/project`.

## Prepare from your discs

```powershell
$p = (Get-Location).Path # Run from the source checkout root.
& "$p\tools\prepare-godot-content.ps1" -DiscDirectory 'C:\My Games\Integral'
& "$p\tools\run-godot.ps1" -Build -Scene3D
```

The Integral importer reads BIN/CUE files without modifying them. The converter
verifies extraction receipts and writes glTF/PNG previews under `.local/godot-content`
and `.local/godot-content-disc2`. The configured Integral Japan campaign covers both
discs, English resources and normal/Very Easy/tuxedo resident assets. Preparation
covers the configured map declarations and cinematic sources; it does not establish
native playability or complete Godot campaign fidelity. Different editions require
explicit identity mappings and are not currently accepted.

No original models, textures or sounds are included in source. `mods/`,
`.generated/`, `.godot/` and `.local/` are ignored. Generated examples and editor
captures may contain your disc's content; keep them local. The tracked example
lighting scene contains only authored Godot nodes and settings.

## Editor workflow

The **MGS Visuals** dock has five tabs. The compact workspace picker and **Open ZIP…** stay at the top:

- **Maps → Browse** lists locations by name. Expand a location for gameplay/cinematic variants, then expand a cinematic variant for its camera clips. Search also accepts stage IDs and types. The list combines prepared sources automatically and shows direct/inherited edits; **Only maps with edits** filters the active mod. Selection retains its original source identity.
- **Maps → Test** holds Preview profile, native entry profiles, Run/Stop and logs. Supported original actor declarations and their part anchors appear in the ordinary Scene tree when opening a map.
- **Assets** browses models and textures, with replacement assignment and additional tools in **Asset tools**. Selecting an original model in the Scene tree selects its asset here.
- **UI** groups HUD, conversations and menus. Select an entry and use **Open selected**, or double-click it. **Effects** uses the same workflow for materials and post-processing resources. Edited entries are marked in their own browser.
- **Mod → Workspace** holds Save/Save As, ZIP Export/Export As, version, export status and catalog reload. **Mod → Enabled mods** selects the saved mod set and priority for Profile Preview and native Run; it also shows conflicts from the preview.

The map browser owns the remaining dock height; save/export controls and global UI/effect summaries do not occupy space on the Maps tab.

The active workspace stays enabled. Add other `mod.json` files under **Mod → Enabled
mods**, toggle their checkboxes, and edit Priority to change precedence within a
scope. This stores project-local selections in `.godot/mgs_mod_profile.json`; source
manifests are unchanged. Missing enabled resources block the preview/run with a named
error. Disabled mods are omitted. Opening another workspace for the same mod ID
disables its previous workspace in the profile; other duplicate enabled IDs are rejected.

**Preview profile** saves open scenes and opens a separate combined view of the
enabled saved scenes, original references, materials, lights and camera edits. Edit
each mod in its ordinary source scene, then Preview profile again. Changes to the
enabled list immediately rebuild an open profile preview. Its content is unowned
editor context; saving that tab cannot embed the original map or other mods into a
workspace. **Run** records the same enabled set and priorities in the isolated
session's `mod-profile.json`. Changes made afterwards apply on the next launch.
Save/Export and Open ZIP continue to operate on the active workspace alone.

For an original-free example of shared/exact scope and independent additions, see
`examples/layered_maps/README.md`. Command-line runs accept `-ModProfile <file>`;
schema1 contains a `mods` array of `manifest`, `enabled` and numeric `priority`.
Paths are absolute or Godot `res://` paths. `MGS_GODOT_PROFILE` selects this profile
in a direct renderer launch and takes precedence over `MGS_GODOT_MODS`. These editor
controls are included in the current development SDK.

From the repository folder, open the project in the pinned Godot editor:

```powershell
& ".\.tools\godot-4.8-dev7\Godot_v4.8-dev7_win64.exe" --editor --path ".\renderers\godot\project"
```

This command works in a fresh PowerShell session without setting `$p`. Keep the
leading `&`: PowerShell needs it to execute a quoted executable path.

Click **Open ZIP…** in **MGS Visuals** and choose an exported ZIP.
The editor creates a workspace under `mods/<zip-name>-<content-hash>` and opens
its first map. The normal disc-backed reference geometry is restored locally.
The picker at the top selects the active workspace; all map, texture and model
edits go there. `local` remains available for new work.

Opening the same ZIP resumes its existing workspace, preserving later local edits.
A ZIP exported again by that workspace also resumes it. A ZIP changed elsewhere
opens a separate workspace. Import validates paths, archive integrity and the
referenced dependency graph before making the workspace available. Missing nested
scenes, materials, textures, script bases/preloads, shader includes and glTF buffers
are reported with their paths. Validation reads the extracted files before editor
import; a fresh PNG does not need an existing Godot import cache. A failed check
leaves no partial workspace and preserves the ZIP and existing local edits.
It uses the prepared Python environment and the currently running Godot executable.
Command-line use of `tools/import_godot_mod.py` requires `--godot <executable>` and
`--project <SDK project folder>` after the ZIP and destination-folder arguments.

**Mod → Save** saves this workspace's open scenes, edited Inspector resources and
optional version. **Export ZIP** saves, then updates its remembered ZIP destination;
the first export asks for a filename. **Export As…** chooses another destination
without changing the mod identity. Externally changed archives are protected from
ordinary Export; inspect the newer archive or explicitly choose Export As.
Failed exports leave the previous ZIP intact.

Export follows the referenced resource graph, including binary Godot scenes and
resources, shader includes and glTF/GLB buffers and images. Binary resources are
converted to portable text inside the ZIP; source files remain unchanged. The
prepared catalogs are required for export: files matching known original data
are rejected even if renamed, including matching embedded glTF image/buffer data.
The error identifies the dependency and original asset. Keep original content as
local references and package your own replacement assets. Metadata-tagged original
subresources, such as fonts and animations, are also rejected.

Original model resources are marked before custom replacements are applied, so
ordinary resource duplication and saving a mesh, skin or texture separately do
not turn it into a custom asset. The exporter also compares image pixels with
prepared originals: an extracted font atlas or a lossless PNG/WebP re-encoding
cannot bypass the check by losing its resource metadata. Newly authored resources
and edited textures remain exportable.

**Save As…** creates a separate mod ID and workspace, including custom assets and
unassigned drafts. It resets export history and relocates resource references.
Binary Godot `.res` and `.scn` files become editable `.tres` and `.tscn` files in
the copy. A conflicting text filename is reported instead of overwriting it.
The source workspace remains unchanged. The Mod tab distinguishes unsaved changes,
saved changes not yet exported, and a workspace matching its last export.

The catalog includes both models and textures. Selecting an original model in
Godot's Scene tree also selects its asset in the catalog. To edit characters:

1. Select a model and click **Assets → Edit model / view texture**. This opens a
   scene with the original rig and `mesh_NNN` parts visible in the Scene tree.
2. Edit a part's material in the normal Inspector, including albedo tint, roughness,
   metallic, normal maps and custom textures. Save the scene. The saved scene stores
   changed properties and original asset IDs; the original mesh, skeleton and
   unchanged textures stay on the recipient's disc.
3. To replace geometry, assign your own Mesh resource to a part, or use
   **Assets → Assign replacement…** for a complete rigged GLB/glTF/TSCN.
   GLB files are copied into the active mod. Put glTF/TSCN and their dependencies
   inside the active mod folder before assigning them. Preserve `part_NNN` bone
   names, parent/rest transforms, skin binds and `mesh_NNN` attachment slots;
   incompatible complete replacements are rejected before registration.

Godot's Inspector edits mesh resources and materials; detailed vertex modeling
and texture painting still use tools such as Blender or an image editor.
**Show original source file** locates the local glTF/PNG for reference.
**Show selected model's textures** lists the texture IDs used by that model.
Select a texture, then **Assets → Assign replacement…** to import your
PNG/WebP and register it without editing JSON. Reopen an existing map/model tab
to refresh its preview after assigning replacements. Put custom material maps
inside the active mod folder so export can include their dependencies.

Older local scenes containing copied original geometry are still rejected by
export. Create a reference-based edit scene or supply your own replacement instead.

### Attach replacements to a moving native object

Opening a prepared map creates supported native declaration previews in the
ordinary Scene tree; no separate actor button or running game is needed. SDK18
Loading Dock includes water (`6d44`), chains (`6d45`), submerged scenery (`6d46`)
and the conditional elevator cart (`6da3`). The underwater area is part of this
location, not a separate stage. Re-run current preparation if older metadata
lacks these declarations.

Each binding contains part anchors and original mesh previews. The Inspector's
`target` identifies the exact original declaration, including its script
revision. Renaming nodes does not change that target. Explicit
`alternate_targets` can identify corresponding declarations in inherited
scenarios. Supported providers and conditional availability are distinct from
the ability to open the map. See [water and original actor visuals](GODOT_WATER_FROST.md)
for current deformation support and replacement-mesh limits.

Add ordinary `MeshInstance3D`, light, or scene children under a part. Hide/delete
an `Original_mesh_NNN` preview to replace only that original part. The binding's
`hide_original_object` replaces the entire original elevator. Collision and
gameplay stay native. Children follow the platform automatically. Optional scripts
can connect `state_changed(state)` and `availability_changed(available)` on the
binding. `state` includes native phase, progress, duration and visibility; these
are current-state notifications, not an ordered gameplay-event stream.

Save the scene, choose a native launch profile under **Maps → Test**, then **Run**
to test without exporting. Docks and helipad offer a fresh stage entry.
Every workspace also offers **Title screen · New Game / Load**, which keeps native
story setup responsible for reaching cinematic and story-dependent scenes. A
cinematic editor set is not advertised as an independently playable scenario.
Each run uses isolated runtime files. **Stop** requests normal game
shutdown; if it stalls, the session host cleans up its own process tree after five
seconds. Closing the editor also stops its test session. Duplicate runs are
prevented, and startup failures appear in the dock. **Open test logs** opens
that run's folder under `build/godot-editor-runs`. Godot's F6 preview is separate
from native gameplay. Dedicated checkpoint/cinematic profiles remain future work.

The custom elevator example is generated with:

```powershell
& ".\.tools\godot-4.8-dev7\Godot_v4.8-dev7_win64_console.exe" --headless --path ".\renderers\godot\project" --script res://examples/native_elevator/create_example.gd
```

It creates `mods/sdk-native-elevator` and `build/mod-exports/sdk-native-elevator.zip`.
The generator preserves an existing workspace by refusing to overwrite it. Use
**Open ZIP…** to reopen the ZIP, then edit its platform, railing,
shadow-casting lamp or motion indicator in the normal Scene tree. Export includes
custom geometry and the standalone binding script; original previews stay local.
The example targets the gameplay elevator only; cinematic elevator actors are
not yet supported by this binding.

Select a scene from the searchable list and click **Open map** in MGS Visuals.
The list shows readable location names alongside stage IDs and disc numbers,
with separate **Type** and **Active mod** columns. Names come from the pinned
[FoxdieTeam stage table](https://github.com/FoxdieTeam/mgs_reversing#overlays).
Search by name, ID or type; **Only scenes with edits in this mod** filters to
direct and inherited scene, model, texture and material changes. **From s00a**,
for example, means a cinematic set inherits the gameplay map's overlay. Shared
asset edits appear separately because their scene usage can span several maps.
Switching mod workspaces refreshes these indicators.

The list includes configured campaign scenes and prepared catalog entries,
including cinematic sets such as `d00a` and `d01a`. Missing definitions, model
files or unresolved textures prevent opening; selecting the row explains why.
Campaign preparation imports all configured stages from the selected disc. The
current caches each open 82 startup map sets, including later locations and
cinematic scenery. Some sets contain only an empty background model; UI and
dynamic actors are separate authoring work. Sets without startup map declarations
remain unavailable for map assembly. These previews do not establish campaign
state or execute conditional actor scripts. New maps record their original-content
fingerprints. Editor and runtime use the same source check and reject mismatching
content, identifying the affected mod and target during runtime loading. Inherited
overlays validate their recorded authoring source, rather than the active cutscene's
different script. Older scenes without source metadata remain supported.
Preparation reads the stage's startup map declarations from its disc script and
converts the referenced models and textures. The editor assembles those models
directly from `.local/godot-content`; no gameplay session or F7 is needed. If an
older cache has no map definitions or light tables, rerun `tools/prepare-godot-content.ps1` and
click **Mod → Reload catalog**.

`tools/prepare-godot-content.ps1` prepares the configured disc-1 campaign by
default. `-Stages s00a,s01a` limits preparation when a smaller cache is wanted.
`-Disc 2` prepares a separate `.local/godot-content-disc2` cache with disc-2 asset
IDs and source fingerprints. Keep the caches separate; the SDK validates and
mounts both without rewriting them. The Maps browser combines locations and nests
variants and clips, choosing their prepared source automatically. Opening a saved
map retains its recorded source; a missing source reports a preparation error.

New map overrides use manifest targets such as `disc1/s00a` and `disc2/s00a`,
with separate scene files under `stages/disc1/` and `stages/disc2/`. A mod can
edit both independently. Older unscoped targets such as `s00a` continue applying
on either disc; an explicit disc target takes precedence for that stage. An exact
cinematic override still precedes inherited gameplay edits. The ZIP keeps these
targets and custom scene files, while original references remain local.

Native test runs select the edited map's source disc. Command-line runs can use
`tools/run-godot.ps1 -Scene3D -StartDisc 2`; the host reads that disc's validated
receipt. Native context reports the inserted disc and the renderer selects its
catalog, while resident model references keep the disc they came from. This
does not fabricate story state for arbitrary direct map launches. Physical
mid-session disc-change playthrough validation remains pending.
Null-texture (`0000`) surfaces are transparent in editor previews, matching the
runtime; genuinely missing named textures still prevent opening affected maps.

The list also includes **Cinematic clip** rows linked by the original scripts.
Open one to edit that stage against its declared cutscene scenery. Under
`LocalMapReference`, select `OriginalCameraTimeline` and scrub the `Original`
animation in Godot's Animation panel. Edit its transform/FOV keys at source
frames (30 FPS). Saving records only changed/added/removed keys and interpolation
settings; unchanged original camera keys stay local. Runtime applies edits using
the actual native clip frame. Scenery edits apply to the stage, and
scrubbing does not execute actors, audio or story events. Existing caches can
add the previews with `tools/prepare-godot-content.ps1 -CinematicsOnly` (and
`-Disc 2` for the second cache). See [cinematic authoring](GODOT_CINEMATIC_AUTHORING.md)
for source identity, supported behavior and remaining camera work.

Caches generated before the KMD normal correction need preparation again too:
native normals use the opposite lighting convention from Godot. After rebuilding
the cache, save your edits and restart the editor to reload the corrected meshes.

The original map appears in Godot's **Scene tree**, under `LocalMapReference`.
Model names include their stage and resource ID (`s00a_c661_k`, for example);
hover for the full stable asset ID. Expand a model to select its mesh parts.
`OriginalLights` contains the original stage lights as ordinary `OmniLight3D`
nodes. Select and inspect them normally. Original geometry, textures and light
tables are excluded when the overlay is saved.

Use Godot's **Add Node**, transform gizmos and Inspector for lights and meshes,
or drag your own scenes into the map. Enable **Shadow > Enabled** on lights and
assign StandardMaterial3D or ORMMaterial3D for PBR. There are no MGS-specific
light/object creation buttons. Authored children of original reference nodes
are saved as standalone nodes at the same world position, since their original
parents are supplied separately by the game.

`EventLightTemplates` contains ordinary `OmniLight3D` (`TemporaryFlash`, `AlarmFill`) and
`SpotLight3D` (`WeaponSpot`, `AlarmSpot`) nodes. Edit their native Inspector properties
to tune muzzle/impact flashes, soldiers' weapon lights and rotating alarm beacons.
All cast shadows by default.
The group is hidden so its templates do not illuminate the editor map; show it
temporarily to preview them. A child's visibility enables/disables that event.
The runtime hides the template group and spawns lights from original game events.
TemporaryFlash's range caps the original animated radius; native positions and
lifetimes are retained. WeaponSpot follows the original gun-light attachment and
barrel direction; its transform provides a local offset, with -Z pointing forward.
AlarmSpot creates two red spotlights per beacon, 180 degrees apart, following the
original activation and rotation. It replaces the legacy beam meshes and projected
glows in Godot. AlarmFill adds one soft, wide red omni at each active beacon,
with shadows enabled (default energy 0.35, range 6 m). The red glass is emissive
while the alarm is active; the opaque housing retains normal lighting and shadows.
Opening an older overlay adds missing alarm templates without changing existing
templates; older ZIPs work immediately with the default settings.
These source-defined templates contain no original game assets and ship in the ZIP.
Older ZIPs without templates use the same shadow-casting defaults.

For bounced lighting, select the map's `WorldEnvironment` and enable **SDFGI**.
SSIL is independent and can be turned off. SDFGI works without a bake or additional
mod resources. A useful starting point for these metre-scale maps is four cascades,
0.25 m minimum cell size, occlusion on and energy 1.0; quality and GPU cost still
depend on the authored scene. Original map geometry contributes, while characters
receive GI without becoming static blockers. Opaque custom geometry uses its normal
Godot GI mode. Moving lights can contribute; moving objects do not inject bounced
light with SDFGI. See [Godot's GI comparison](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html).

Godot 4.8's multi-bounce ambient occlusion is enabled project-wide under
**Rendering > Lights and Shadows > Multi Bounce Occlusion > Enabled**
(`rendering/lights_and_shadows/multi_bounce_occlusion/enabled`). It applies an
albedo-aware correction to SSAO and material AO, reducing excessive darkening.
Keep SSAO enabled on the `Environment` for screen-space occlusion; multi-bounce
AO works alongside SDFGI and does not require SSIL. Restart the editor/game after
changing this project setting. The launcher copies it into each runtime project;
it is not a setting to add to individual mod ZIPs.
See [Godot's implementation](https://github.com/godotengine/godot/pull/115426).

**Mod → Export ZIP** exports the mod containing the currently edited scene under
`mods/<your-mod>/`, using its nearest `mod.json`. This also supports opening and
editing a separate trial mod without exporting `mods/local` by mistake.

Hide originals with the Scene tree's visibility toggle or delete their nodes;
Godot's normal Undo restores them. Saving records their stable asset ID, original
position and optional part index in `mgs_removals` metadata. Matching uses a
0.25-metre position tolerance; after a match it follows
that actor lifetime, including movement and model swaps. Omit `anchor` in a
manually authored rule to target all instances of an asset. These removals affect
Godot scene geometry; compatibility-only effects are outside this editor's current
selection scope. Removal and placement are visual only: native collision,
gameplay, audio and the gameplay camera remain unchanged.

The disc importer resolves `mapdef -l` tables and the implicit `.l` resources
used by `map -d`. The docks declare 74 fixed lights; the helipad declares 96.
Their native positions, RGB colors and radius/cutoff values come from the disc.
Godot approximates the original radial falloff with shadow-casting OmniLights:
range is `min(2 * radius, extent) / 1000`, attenuation is 1, and energy is 1.5.
The native cutoff is a box, so this is not pixel-identical PS1 vertex lighting.
Both the editor and renderer use these defaults. Temporary/script-driven lights
are not part of the static disc map importer.

Edit original lights with the Inspector: position, color, energy, range,
attenuation, shadow settings and other standard light properties are stored as
deltas in `mgs_light_overrides`. Hiding/deleting a light stores a visibility
override. The recipient rebuilds the defaults from their own disc; the exported
mod contains only changed values and authored assets.

Lights, WorldEnvironment, fog and authored objects share the game's Godot world.
The disc map contains geometry declared by top-level startup `mapdef` and `map -d`
commands. Animated/script-created actors and gameplay-dependent arrangements
are not assembled by this static map importer. The map browser currently exposes
the docks and helipad; it is not a complete campaign scene simulator.

Render layer 20 is reserved for internal ordering/mask metadata. Use layers 1â€“19
for authored visual geometry.

Map editor coordinates are metres with Y up: original `(x, y, z) / 1000`.
New overlays store `mgs_coordinate_space = "native_y_up"` on their root; the
renderer converts their placement and orientation when loading them. Existing
overlays are upgraded when opened, preserving their in-game placements. Save
the scene to keep that upgrade. Use Godot's normal 3D camera and gizmos.

Prepared model geometry, visual API v1 and removal `anchor` selectors retain
the renderer's `(x, -y, -z) / 1000` convention. The editor handles that conversion
for selection/removal. Overlays without coordinate metadata retain this legacy
convention at runtime; existing exported mods do not need conversion.

## Manifest v1

```json
{
  "schema": 1,
  "id": "author.visuals",
  "priority": 100,
  "replacements": {
    "mgs/integral-j/disc1/stage/init/992d.k": {
      "path": "models/snake.tscn",
      "lighting": "lit"
    },
    "mgs/integral-j/disc1/stage/s00a/1234.p": {
      "path": "textures/replacement.png"
    }
  },
  "stages": {
    "s00a": { "scene": "stages/docks.tscn", "original_lighting": false }
  }
}
```

The texture ID above is illustrative; choose an actual catalog ID. Model paths
accept `.gltf`, `.glb` and `.tscn`; texture paths accept `.png` and `.webp`. All
paths are relative to their manifest and must remain inside its directory.
Godot scenes can contain scripts: only load mods whose code you trust.

Higher priority wins for the same category and target. Equal priority sorts by mod
ID; the later ID wins the whole entry. The shared resolver records both mod IDs and
the overlapping target; runtime logs these as `MGS_MOD_CONFLICT` with instructions
to change priority or disable an overlapping mod. Reconfiguring the enabled set
clears old definitions and diagnostics. Disc-specific and exact-stage targets
retain the precedence described above. Duplicate mod IDs and missing/invalid resources are errors. Models are
validated/preloaded before boot. Requested failures do not silently use originals.
Stage scenes compose their independent additions across enabled mods. Shared-location
scenes apply before exact-scenario scenes, with priority/ID ordering within each scope;
disc-specific targets follow their generic target. Each mod contributes its most
specific scene, so an explicit variant saved from an inherited scene is not duplicated.
Scene roots, scripts, signals and relative node paths remain intact under separate
parents. Original-light edits merge by light/property, removals combine, and camera
edits select one definition per clip. The highest-precedence authored environment,
camera attributes, compositor and event-light templates supply those shared settings.
WorldEnvironment nodes remain in their authored scenes; ordinary Godot scene order
selects the active resource. `MGS_MAP_CONFLICT` identifies competing settings and their
final mod/scope winner; `MGS_STAGE_COMPOSITION` lists contributors. Single-mod scenes
retain their existing hierarchy. The editor's Enabled mods page shows these
diagnostics after Profile Preview and supports enable/disable and priority changes.
Broader dependency/migration and actor-role conflict controls remain implementation work.

Original meshes use Godot PBR lighting and shadows by default. An explicit stage
override with `original_lighting: true` retains native vertex lighting for that mod.
Imported maps include a normal **MapEnvironment** WorldEnvironment node. Edit its
Environment resource under **Ambient Light** in the Inspector; color and energy
save/export with the scene and are used unchanged at runtime. The shared default
is neutral gray `(0.6, 0.6, 0.6)` at energy `1.0`, with sky contribution disabled.
Existing authored WorldEnvironment nodes are preserved. Unmodded runtime maps use
the same baseline from `map_environment.tres`. Editor and runtime share model reference/replacement
validation, stage/disc texture lookup and conversion of authored materials to lit
shading; native poses and active visibility remain authoritative. Model
replacements choose `unlit` or `lit`; they cannot inherit original per-face light
indices after changing topology. Custom ShaderMaterials retain their own shader.
Editor previews also apply texture-level albedo, normal, ORM and emission overrides
with the same PBR factors as runtime. Sparse material edits retain their precedence
over these base definitions; custom albedo is preserved unless the edit inherits
the original texture. Editor viewport lighting is still a preview of static content,
not execution of native animation, visibility or effect state.

The opening cutscene stages inherit their gameplay map overlays: `d00a` uses
`s00a` (docks), and `d01a` uses `s01a` (helipad). Authored lights, environment,
objects, original-light edits and visual removals follow that overlay. An explicit
cutscene stage entry takes precedence within its mod; independent additions from
other enabled mods remain. Model/texture/PBR replacements also follow
these variants when the original resource hashes match; an explicit replacement
for the cutscene asset wins. Different original resources are not aliased.
The visual API still reports the actual active stage, such as `d00a`.
Opening an inherited map for its first direct edit copies the resolved authored
overlay, including its custom nodes and environment. It creates an independent
variant, preserves the parent scene, remaps removals only for hash-matched original
models, and records the variant's source fingerprint. Subsequent changes to the
parent overlay do not overwrite that explicit variant.

Godot lighting also covers supported transparent original model surfaces,
native water surfaces/ripples, gameplay and cinematic bubbles, breath/smoke, fog and casing particles. Their animation,
UVs, fades and half/additive blending remain driven by the game. Framebuffer
effects such as stealth, subtractive packets and emissive flashes retain the
compatibility renderer. Existing ZIPs work without re-exporting.

## PBR overrides for original meshes

Add a `materials` object keyed by texture asset ID. It applies to original meshes
using that texture without copying the mesh or its original albedo into the mod:

```json
"materials": {
  "mgs/integral-j/disc1/stage/s00a/1234.p": {
    "normal": "textures/normal.png",
    "orm": "textures/orm.png",
    "roughness": 0.8,
    "metallic": 1.0,
    "normal_scale": 1.0
  }
}
```

Choose a real catalog ID in place of the illustrative `1234`. Optional `albedo`
and `emission` PNG/WebP maps are also accepted, with `emission_energy` from 0 to
16. ORM packs occlusion, roughness and metallic in R/G/B. Roughness/metallic
factors multiply the map channels; without maps the defaults are 0.8/0.0.
Normal maps use OpenGL (+Y) convention; `normal_scale` ranges from 0 to 4.
The shader derives the tangent frame from the live UVs, so converted meshes do
not need authored tangent data. Live face visibility, UVs and packet ordering
remain active. PBR overrides use Godot lighting even if the stage otherwise
retains original lighting, and bypass original five-bit color quantization.

## Native GDExtension mods

`extensions` loads a native library into the **64-bit Godot process**. It does
not inject code into the 32-bit gameplay runtime. The working C++ example is in
`renderers/godot/sdk`; its godot-cpp 4.4 source revision is pinned in
`sources.lock.json` and tested with the pinned Godot 4.8-dev7 renderer.

```powershell
& "$p\tools\build-godot-mod.ps1"
& "$p\tools\run-godot.ps1" -Scene3D -Stage s00a -Mods "$p\build\godot-sdk-x64\mod\mod.json"
```

The example creates a moving OmniLight3D with shadows and follows dock/helipad
stage changes. The build defaults to two workers. A manifest entry is:

```json
"extensions": [
  { "path": "example.gdextension", "class": "MgsExampleMod", "api_version": 1 }
]
```

The registered class derives from Node and binds
`mgs_mod_initialize(context) -> int` (return Godot `OK`) and
`mgs_mod_shutdown()`. Initialization runs before model/override scenes load, so
extension classes can be used in those scenes. The context is a Node3D in the
rendered world and provides `get_api_version()`, `get_stage()`, `get_camera()`
and `get_instances()` (`id`, `asset`, `node`, `appearance` dictionaries). Appearance
is a copy of native presentation state: `kind` 0 is normal; kind 1 includes
camouflage `amount` (0..1) and a `Vector3` tint with 1 as neutral. It emits
`stage_changed(stage)` and `snapshot_updated` after a complete native snapshot.
Use Godot's ordinary node, material and light APIs for visual behavior; these
hooks do not expose gameplay mutation. Initialization failures are errors.
Shutdown runs in reverse order; hooks must tolerate partial initialization.
Libraries stay loaded for the process lifetime. Restart to replace a native DLL.

The lifecycle uses Godot's
[GDExtensionManager](https://docs.godotengine.org/en/latest/classes/class_gdextensionmanager.html).
This is visual API version 1; platform binaries must match the recipient's Godot
architecture. The bundled build workflow currently validates Windows x64.

## Exporting without original files

Click **Mod → Export ZIP** after saving the overlay. Packages
go to `build/mod-exports`. The exporter includes the manifest and its referenced
authored scenes, textures, scripts and current-platform extension binaries. It
rewrites local resource paths for relocation, rejects dependencies outside the
mod directory, and refuses local previews or resources marked as retail-derived.
The editor replaces an existing archive only after the Save dialog's overwrite
confirmation; the export API defaults to refusing overwrites.

Use `preload()` for script dependencies that belong in the package. The exporter
relocates those paths along with scene resources and shader includes. Literal
runtime `load()` paths produce an export error because Godot resolves them
against the project root, not the relocated script's directory. For resources
selected dynamically, register named entries as described below.
References appearing only in comments or string examples are ignored. ZIP opening
uses the same static dependency rules; it does not execute custom scripts or prove
that a constructed runtime path will resolve.

### Named resources for scripts and extensions

Save your custom resource inside the active mod folder, then use **Assets → Mod
resources → Add…** to give it a name and choose its file. **Open** edits the asset
through Godot's normal scene, script or Inspector editor. **Edit entry…** changes
the name or file; **Remove entry** leaves the file untouched. Save and export from
the Mod tab as usual. No manifest editing is required.

For example, register two materials as `finish/amber` and `finish/teal`. A mod
script can choose one at runtime:

```gdscript
var api := get_tree().get_first_node_in_group("mgs_visual_api_v1")
var entry: Dictionary = api.resolve_mod_resource(self, "finish/" + selected_finish)
if entry.status != "ready":
    push_error(entry.message)
    return
material_override = load(entry.path)
```

The resolver returns `status`, `mod` and a Godot-loadable `path` on success, or
`status: unavailable` with a diagnostic `message`. Use normal `load()` or
`ResourceLoader.load_threaded_request(entry.path)` and the corresponding Godot
status/get methods; the SDK does not replace Godot's loader or resource cache.
Requester ownership comes from its resource/script/scene path, then its parents.
Native extension roots receive their package association before initialization;
pass that root or its children to the same method. Names are local to each enabled
mod, so equal names in different mods do not conflict. This association supplies
context, not a security sandbox for mod code.

The optional manifest entry is `"resources": {"finish/amber": {"path":
"amber.tres"}}`. Registered files and their dependencies enter the same export,
original-content and ZIP-import checks as scene dependencies. Binary-to-text
conversion updates these paths, and Save As preserves them in the new package.
Missing files, paths outside the mod folder and undeclared names report errors.
Arbitrary unregistered paths constructed by scripts cannot be discovered or made
portable automatically; declare those resources and resolve their names instead.

The asset-free example in `examples/named_resources` provides an Inspector-selectable
amber/teal finish on a custom sphere in the dock. Export it with:

```powershell
& "$p\.tools\godot-4.8-dev7\Godot_v4.8-dev7_win64_console.exe" --headless --path "$p\renderers\godot\project" --script res://examples/named_resources/export_example.gd
```

Open `build/mod-exports/sdk-named-resources.zip` through **Open ZIP…**, select the
Marker node and change **Finish**, edit its materials under Assets → Mod resources,
then use Maps → Test → Run. This example changes presentation only. Export refuses
to overwrite an existing ZIP; use the editor's Export controls for subsequent edits.

The package stores original asset IDs and removal/placement instructions. Each
recipient prepares the original content from their own discs. The local map
reference is never included. Model edit scenes store `mgs_model_reference` and
`mgs_part_edits` metadata. Runtime reconstructs the original rig from prepared
disc content and applies only authored material/mesh/transform changes. Original
surface visibility and animation remain native. New geometry and textures must
be your authored assets; the exporter rejects embedded original resources.

Open `build/windows-x86-godot/RE-INTEGRAL.exe`, select **Mods â†’ Add ZIPsâ€¦**,
choose one or more exported ZIPs, and click **Save and play**. Checkboxes enable
or disable installed mods; selections persist across launcher restarts. Adding
a newer ZIP with the same mod ID replaces that selection. **Remove** removes
the selection without changing the original ZIP.

The launcher installs packages and imports custom resources automatically under
`%LOCALAPPDATA%/RE-INTEGRAL`. Only enabled mods enter the private runtime project;
disabled extensions and editor-local mods are excluded. Imported resources are
cached until the selected content or renderer source changes. No manual unzip,
editor import or manifest arguments are needed. Scenes and native extensions
execute code, so the existing trusted-mod rule applies.

This launcher is built with the Godot renderer module and uses the checkout's
prepared disc content. The published native alpha does not include Godot yet.
Source builds create the launcher with:

```powershell
.\tools\build.ps1 -BuildDirectory build/windows-x86-godot -RendererModule renderers/godot/native
```

For development, `run-godot.ps1 -Mods` still accepts explicit `mod.json` paths,
including `mods/local/mod.json` for testing unsent editor changes.

An exportable map/PBR example contains a primitive sphere, lights, a removal
selector and procedurally authored normal/ORM maps. Original albedos are referenced
by asset ID and are not copied:

```powershell
& "$p\.tools\godot-4.8-dev7\Godot_v4.8-dev7_win64_console.exe" --headless --path "$p\renderers\godot\project" --script res://examples/make_map_demo.gd
& "$p\tools\run-godot.ps1" -Scene3D -Stage s00a -Mods "$p\renderers\godot\project\mods\map-overlay-demo\mod.json"
```

The generator refuses an existing mod directory so it cannot overwrite edits.

```powershell
& "$p\tools\run-godot.ps1" -Scene3D -Stage s00a -Mods @(
  "$p\renderers\godot\project\mods\local\mod.json"
)
```

Asset IDs contain edition/disc/definition-stage/resource hash and type. The
definition-stage remains `init`, `init_ve` or `init_tux` for resident assets even
after changing maps. Do not merge them based on matching 16-bit hashes. Content
SHA-256 identifies a revision, not an asset. Actor lifetime IDs are inspection
handles for one simulation run; they are not persistent mod targets.

## Local examples

The authored lighting example can be enabled directly:

```powershell
& "$p\tools\run-godot.ps1" -Scene3D -Stage s00a -Mods "$p\renderers\godot\project\examples\lighting\mod.json"
```

Generate a visibly altered mesh from your prepared resident model, without
shipping the source asset:

```powershell
& "$p\.tools\godot-4.8-dev7\Godot_v4.8-dev7_win64_console.exe" --headless --path "$p\renderers\godot\project" --script res://examples/make_local_demo.gd
& "$p\tools\run-godot.ps1" -Scene3D -Stage s00a -Mods "$p\renderers\godot\project\mods\generated-mesh-demo\mod.json"
```

The generator enlarges each part's geometry, applies a cyan material and retains
the original rig. It refuses to overwrite an existing example folder.

## Current boundaries

The runtime uses Forward+ and inherits the project's positional shadow atlas
size, precision and quadrant allocation. Camera culling does not remove active
opaque mesh shadow casters; native hidden actors and mod removals do. Configure
light range, shadow bias and optional distance fading in the normal Inspector.
OmniLight3D, SpotLight3D, DirectionalLight3D and AreaLight3D use Godot's native
lighting and shadow paths; animated character shadows are GPU-tested with all four.

The launcher selects output resolution, widescreen or original 4:3, and the
Godot presentation mode. Full scene mode combines Godot world geometry with
ported UI/effects and the remaining native command-layer visuals. The command
layer does not share the 3D scene's depth buffer, so mixed-effect occlusion still
has limits. Original texture replacements target the mesh layer; UI and effects
have their own editable resource contracts described below. Live packet UVs,
palette updates, optical camouflage and vision effects have scoped support;
those checks do not establish complete campaign fidelity.

The runtime keeps SDL input and native audio/replay formats. Recording is
available through `-RecordInput`; replaying uses `-ReplayInput`. Source-script runs use `.local/godot-runtime`; editor tests use isolated
`build/godot-editor-runs` folders. Launcher runs use the normal
`%LOCALAPPDATA%/RE-INTEGRAL` saves. Visual mod settings are not part of the native
simulation identity; retain manifests alongside visual comparison captures.

Run `tools/test-godot.ps1` for snapshot, rig/manifest, converter, map removal/export,
compiled GDExtension lifecycle, GPU PBR/shadow and protocol/composition checks.
`-SkipGpu` runs the CPU checks only; `-SkipNativeMod` skips the C++ build/lifecycle
test when a compiler is unavailable. GPU
checks require the pinned Forward+ renderer; logs are saved under `build/godot-tests`.

## Fog backgrounds

The renderer draws Godot's environment fog/sky through gaps with no geometry.
Use the normal WorldEnvironment fog settings. Integration reserves visual layers
19 (background-pass lights) and 20 (ordering metadata).

Puddles and ripple effects use their original rendering path. The experimental
reflective replacement and its material metadata controls have been removed.

### Native timing context (prototype 15.2)

The additive API-v1 methods `get_native_context()` and signal
`native_context_updated` expose the latest validated native sample. The getter
returns a copied Dictionary with `session_id`, `epoch`, `sequence`, `stage`, `actor_loop_tick`,
`pause_mask` and `passage_ticks`; it is empty until the first sample. `epoch`
changes on every native resource-stage load, even a reload with the same name.
Use this to distinguish fresh native state; do not use the private launcher token
as an authored identity.

The raw actor-loop tick can advance while gameplay actors are paused. Use current
native poses and pause state; this API does not authorize native actions or provide
cinematic time, interpolation or reconnect. The initial elevator provider below
supplies current actor poses. See
[GODOT_PROTOCOL.md](GODOT_PROTOCOL.md#native-context-samples-151-152-156-157-and-1512) for the precise
sampling boundary and current limits.

`session_id` is a public 32-digit hexadecimal connection identity, distinct from
the private launch token. Pair it with `epoch` and future actor generations; do
not persist runtime IDs as authored mod targets. A new connection gets a new ID.

### Native elevator declaration lookup (initial provider)

API v1 adds `get_native_actors()`, `resolve_native_actor(target)` and
`native_actors_updated`. The getter returns copied records containing identity,
slot/generation/epoch, native tick, pose, current elevator state and a live `body`
Node3D. The body is owned by the bridge; children follow its motion and are freed
when it retires. Record dictionaries are copies; Node references remain live.

The resolver requires all five source fields below, with no additional selectors:

```gdscript
var target := {
    "stage": "s00a",
    "script": 0x6ea54,
    "script_sha256": "40e6084b4cbf0c38660c3044238613ad2d7b24442aa2677530df49ef71ac66c8",
    "command_offset": 5981,
    "provider": 0x2abc,
}
var result: Dictionary = api.resolve_native_actor(target)
if result.status == "available":
    result.actor.body.add_child(custom_visual)
```

This example identifies the original dock elevator declaration. Stage and digest
refer to the source GCX, not the current camera or a model name. A changed script
revision needs a newly verified target. Runtime slot IDs are never saved in this
target. Children use native local metres (Y up); the renderer applies its space
conversion at the native actor root. Do not apply that conversion again to children.

The result has `status` and, on success only, `actor`. Other statuses are `invalid`
(malformed or unsupported target), `inactive` (no matching current-epoch actor),
`ambiguous` (multiple incarnations of that declaration), and `unavailable` (provider
or anchor absent). Failures include `message`; ambiguity also includes `count`.
JSON round-trips preserve integral numeric fields. No match is guessed from the
actor name, model, list order or an earlier scene. Visibility is separate from
availability: an active native actor can currently be hidden.

Resolve once for late attachment and again on `native_actors_updated` or
`native_context_updated` when its incarnation changes; do not add the same child
on every update. Context notifications occur after old-epoch anchors are hidden
and excluded from lookup. The current provider exposes elevator phases 0 at start,
1 toward end, 2 at end and 3 toward start, plus progress/duration/visibility.
Lookup restores current state; it does not replay arrival sounds or other events.

The dock binding now exposes five separately editable source-ID parts and an
original-free platform/railing/light example with ZIP roundtrip evidence. Their
poses share the verified rigid native body motion. Generated bindings preserve
ordinary authored `visible` properties while separately masking native-hidden or
unavailable mesh/light descendants, including nested bindings. `native_visible`
reports that native mask; authored hiding remains independent. New binding
workspaces include `native_actor_binding.gd` and its `native_visibility.gd` helper.
Existing mod scripts remain unchanged; update both copied SDK scripts deliberately
when adopting this behavior. General actor adapters, typed property bindings,
ordered events and reconnect/full-state resync remain open.

### Prepared content revision metadata

New asset preparation runs add `contentId`, `preparedFiles` and `preparedRevision`
to each local catalog entry. `contentId` hashes the full original asset identity,
a newline, and its original SHA-256 (UTF-8), prefixed with `sha256:`. Prepared
files map cache-relative paths to SHA-256 digests; their canonical JSON mapping
(sorted keys, compact separators, UTF-8 without ASCII escaping) is hashed for `preparedRevision`. Model glTF
files include referenced external buffers/images; texture entries include STP
masks. Embedded data is covered by its containing glTF digest. These are local
provenance records, not permission to include original-derived files in a mod.

Source identity does not change when a generated dependency changes. Runtime startup and editor catalog reload validate these fields and file digests
before exposing the catalog. Model dependencies and texture masks must be listed.
Missing or changed files produce a preparation diagnostic. Hashes are deduplicated
within each validation pass; no per-frame hashing is added. Older catalog entries
remain readable with an explicit unverified notice. Partial provenance is rejected.

This detects stale local caches at catalog load; it is not a signed provenance
chain, a sandbox or validation of files changed after loading. Native model declarations now carry the exact raw source digest, checked against
the catalog before instantiation. Disc-aware native model keys and separate
prepared catalogs prevent same-named resources on different discs from colliding.
Full resource incarnations and archive subresource provenance remain pending. Transitive mod export validation
remains separate SDK work.

### World-effect materials

Snow and registered textured world effects now accept ordinary **ShaderMaterial**
resources. Native code still supplies their positions, UV animation, colors,
blend mode, visibility and lifetime. These overrides affect the world-effect
batches, independently of model materials using the same texture.

1. Open the mod ZIP or select its existing workspace.
2. In the asset list, search for **Snow**, or select the original texture used by
   the effect. Click **Edit effect material for selected texture**. Opening the
   Snow entry also opens its material.
3. Edit **Shader Parameters > Appearance** in the normal Inspector and save the
   material. It lives under `effects/` in the active mod. Put custom PNG/WebP
   textures inside that workspace, assign **Custom Texture**, and enable
   **Use Custom Texture**. Leaving it off uses the locally prepared original
   texture; the generated snow default is white.
4. Run the workspace in the native game to see saved changes. Export and reopen
   the ZIP normally; the material, shaders, includes and custom textures travel
   together. Reopening an existing override preserves its edits.

| Appearance parameter | Effect |
| --- | --- |
| Effect Tint | Color and opacity multiplier; native fade still applies |
| Custom Texture / Use Custom Texture | Replaces the sampled artwork, using the native UVs |
| Alpha Cutoff | Matching cutout threshold in color and depth |
| Effect Roughness / Metallic / Specular | Godot light response for lit effects |
| Emissive Energy | Brightness of native emissive lamps/original-lighting effects |
| Emission Color | Additional emission, multiplied by native shade/fade |
| Beam Width | Width multiplier for native IR sensor beam strips (top-level shader parameter) |
| Beam Heat | Thermal intensity for those beams; zero disables their heat output |

The generated files contain renderer code and sparse parameters, not original
artwork. PNG/WebP dependencies are loaded with mipmaps even outside the editor's
import cache. A global snow override uses `mgs/effects/snow`; other targets use
the prepared texture's complete disc/stage identity. For example, the s12c lamps
use `mgs/integral-j/disc2/stage/s12c/0e6f.p` and the shared
`mgs/integral-j/disc2/stage/init/479f.p`. Runtime `MGS_WORLD_EFFECT` records identify
active texture targets and the winning mod. A texture's presence in the catalog
does not prove an effect using it is active in the current scene.

The infrared sensors (`ir_cens.c`) use the original `lsight` texture identity.
Select that prepared texture to edit their material. Their reveal strength,
animated texture row, endpoints and cigarette proximity fade stay native; the
material controls the visible beam. Zero native reveal remains invisible in
color, depth and thermal vision, even when a replacement texture is supplied.
Thermal beam heat shares the color/depth geometry and respects foreground walls.

Scene list status includes effect texture edits and matching cinematic
inheritance. Shared textures may affect several scenes; global snow edits have
a separate notice because the catalog does not enumerate every snow emitter.
Multiple mods use the existing priority/ID ordering for each effect identity.

The additive schema-1 manifest field is generated by the editor:

```json
"effects": {
  "mgs/effects/snow": {
    "material": "effects/mgs_effects_snow/material.tres",
    "depth_shader": "effects/mgs_effects_snow/world_effect_depth.gdshader"
  }
}
```

Shader authors can edit the copied shaders and shared includes. Both shaders
must retain the spatial geometry inputs `geometry_data`, `albedo_texture`,
`mask_texture`, `quad_count` and `screen_sized`; the renderer supplies them.
Color material parameters are also supplied to matching depth-shader uniforms.
Keep deformation, coverage and sidedness consistent between the two passes.
The supplied shared appearance include handles this for the Inspector controls.
For beam effects, the depth shader also needs the boolean `thermal_pass` uniform.
The runtime duplicates that shader for the thermal layer and supplies true there;
the normal composition-depth copy keeps it false. Keep its heat output and discard
rules consistent with the color shader. Older copied depth shaders without this
input report an error when used for beams; merge the current beam geometry and
thermal branch into the mod's copies, preserving authored changes.
Additional material passes are rejected. Custom shaders can change appearance,
but are responsible for preserving this rendering contract.

This requires the current SDK/runtime scripts; IR sensor beams require protocol 15.14.
Effect materials are loaded at session start and copied per batch. Live material
reload, per-emitter selection, arbitrary emitter/particle scene replacement and
effect simulation editing are not implemented. Effects still rendered through
the compatibility path cannot use these overrides yet. The Inspector exposes the
material; full native effect simulation is tested with **Run workspace in native
game**, not replayed in the map preview.

### Optical camouflage material

Use **Effects → Optical camouflage** in the editor dock to create or reopen
the active mod's ShaderMaterial. Edit it in the normal Inspector: distortion,
index of refraction, blur LOD, tint, tint strength and optional rim appearance. The copied shader and material
live under `appearances/camouflage/` and export/reopen with the mod ZIP; they
contain no original assets. The scene list reports this as a shared appearance edit.

```json
"appearances": {
  "camouflage": {"material": "appearances/camouflage/material.tres"}
}
```

The override applies to native optical-camouflage users, including scripted
characters using `NewKogaku2`/`NewKogaku3`. Native code owns activation, transition
progress, thermal switching and retirement. Godot renders its own scene refraction
and restores the previous material when camouflage ends. Collision, equipment,
enemy detection and cinematic timing remain native.

The default bends background detail through the model's surface normals. Snake's
native tint is green; Ninja's is neutral. Distortion controls the effective optical
thickness relative to camera distance; index of refraction controls the bend
(1.0 means no bend). Foreground depth prevents sampling a nearer opaque object
into the cloak. The default rim emission is off. Existing mods retain their copied
shaders and parameters; these defaults apply to the renderer and newly created
camouflage materials, without overwriting authored ZIPs.

Custom spatial shaders must retain float `camouflage_amount` and vec3 `native_tint`.
The adapter also supplies `albedo_texture`, `has_albedo` and `base_color` from the
current ordinary material. For arbitrary custom model shaders only the conventional
`albedo_texture` input is understood; implement their other base-shading behavior
in the camouflage shader if needed. Additional material passes are rejected.
The usual mod priority/ID ordering selects one global camouflage definition.

The default appearance is a whole-model fade into refraction, not the original
screen-space vertical wipe. It samples Godot's opaque scene buffer, so transparent
particles and other refractive characters are not included in the sampled image.
Sampled background fog is preserved without applying fog twice; the base-color
portion during the short fade has no additional fog. Opaque shadows are disabled
while the effect is active. Thermal presentation and per-character
appearance targeting remain separate work. Test native transitions using **Run
workspace in native game**; the static map preview does not simulate equipment.

### Night vision effect

Use **Effects → Night vision** to create or reopen the active mod's
CompositorEffect in the Inspector. Tint, gain, black lift, contrast, scanlines
and grain are editable. The effect follows native goggles activation; it does
not equip goggles or alter gameplay visibility. Test equipment behavior through
**Run workspace in native game**; the static map preview has no equipment state.

```json
"postprocess": {
  "night_vision": {"effect": "postprocess/night_vision/effect.tres"}
}
```

The resource and its copied GDScript live under `postprocess/night_vision/`.
Export/reopen preserves edits and includes these custom files, with no original
artwork. The scene list shows a shared night-vision edit notice. The usual mod
priority/ID ordering selects one global definition; changes load next session.

The compositor filters opaque and transparent world color plus the empty
background after transparent rendering and before postprocessing/upscaling.
It preserves depth and alpha, supports Forward+/FSR2, and clears temporal history
when vision mode changes. Grain follows the native actor-loop tick; the renderer
does not advance gameplay. Native UI is outside this world filter.

Shader authors can edit the copied compute code. Custom CompositorEffect scripts
must provide `validate() -> String` (empty on success), `set_native_state(mode,
tick)`, render-thread `prepare()` and `release()`, and a `failed(message)` signal.
The runtime creates separate resource copies for world and background views.
The supplied effect enables only mode 1 (night vision); modes 0 (normal) and 2
(thermal) disable it. The thermal compositor below handles thermal world color;
first-person sight UI remains separate migration work.

### Thermal vision effect and heat sources

Use **Effects → Thermal vision** to open the active mod's CompositorEffect.
The Vision controls set cold scenery tint, gain, lift and contrast. Heat controls
set the hot tint and heat curve; Display controls set scanlines and grain.
The native goggles select this effect. Thermal settings use the same priority
ordering and next-session loading as night vision.

```json
"postprocess": {
  "thermal_vision": {"effect": "postprocess/thermal_vision/effect.tres"}
}
```

Export includes the resource, its thermal script and its shared vision base
script, plus the manifest. Script `extends` dependencies are audited and relocated
along with other dependencies. No original model or texture is included.

Original IR-marked models automatically supply heat, including native-rig model
replacements. Mesh transforms, skinning, native visibility and visual removals
apply to the heat pass. Walls occlude heat. This classification follows the
original game rather than guessing from object names or lights. Mines and other
conditional actors still follow their native goggles/visibility logic.

Custom meshes can register heat through the visual API after entering the tree:

```gdscript
var api = get_tree().get_first_node_in_group("mgs_visual_api_v1")
var error: String = api.register_thermal_source($MeshInstance3D, 0.8)
if not error.is_empty(): push_error(error)
```

Heat is a normalized presentation value in [0,1], not degrees. A registered value
overrides native classification for that mesh; `api.unregister_thermal_source(mesh)` restores the native
classification if present. Deleted meshes retire automatically. The internal
heat pass uses Godot layer 18; layers 19/20 serve background lighting and metadata.
Ordinary authored geometry should use other layers.

Custom thermal compositors implement the night-vision methods plus
`set_heat_capture(capture)`. The supplied capture exposes a render-thread RG32F
texture: red is linear camera depth in native millimeters and green is heat.
The background compositor receives no heat capture. Heat drawing and compositing
stop when the goggles are removed. This adds a geometry pass while thermal vision
is active; full performance acceptance remains pending.

The default heat pass supports rigid, skinned and blend-shape meshes and skips
empty original surfaces. Heat follows reparenting and temporary geometry removal;
restoring geometry retains authored heat registration. It does not reproduce
arbitrary material vertex deformation or custom shader discard patterns. Native thermal laser lines and
the goggles sight now have Godot presentation paths. Custom heat deformation and
live goggles visual review remain open under M4.04c/M5.

### Editable goggles UI

Open your mod ZIP through the SDK's existing mod picker, then choose **UI → Goggles / sights**.
This opens (or creates once) `ui/goggles/goggles.tscn` inside the active mod. The
Scene tree contains NightVision and ThermalVision groups, ordinary Labels,
ColorRects and Controls referencing the prepared sight artwork. Edit their
positions, colors, visibility, materials and fonts with the normal Godot Inspector.
Select the root and change **Preview Mode** or **Preview Heading** to inspect
either sight. These preview settings do not control gameplay.

Save and export the active mod normally. Reopening that ZIP restores the same UI
scene and edits. Its manifest entry is:

```json
"ui": {"goggles": {"scene": "ui/goggles/goggles.tscn"}}
```

The editor removes transient original FontFile resources and preview state during
save, then restores the local preview. The ZIP contains the scene and its custom
scripts/assets; original atlas pixels and sight vectors stay in the local cache.
Original shapes save `source_id` and `shape_index`. Shared IDs such as
`mgs/ui/nv_ggle1` and `mgs/ui/menu_small` resolve against the running disc's verified
prepared catalog. Both discs need the UI preparation introduced in M5.02a.

Labels use `mgs_ui_font` metadata for original small/large font references. An
authored font override or Godot Theme font takes precedence. Remove the metadata
to use only your own font. Custom fonts must be inside the mod folder; exporting
an embedded original font is rejected. The menu aliases support the recovered
menu glyph set; broader localization remains part of the UI migration.

`mgs/ui/subtitle` resolves the original general-purpose `font.res` font from the
running disc. Use font size 12 for its native metrics (18-pixel line spacing).
It preserves variable ASCII widths, glyph Y offsets and the original four-level
subtitle palette; ordinary Label font color and size overrides remain available.
This is a local resource for UI scripts through `resources.font(...)`, not a font
to save into your mod. Detach it before packing a scene, as with the menu fonts.
The exporter rejects serialized original FontFile resources.

Its embedded native bank is addressed using private-use code points
`0xF0000 + glyph_index` (one-based), and the native generated dash uses `0xF4000`.
These are native glyph references, not a Unicode Japanese translation. Dynamic
radio/GCL/cinematic banks, language-pack glyphs, formatted text layout and the
subtitle Control/state bridge remain pending; preparing this font alone does not
replace in-game subtitle rendering. Incremental preparation uses
`tools/prepare_godot_assets.py --ui-only` for each configured disc.

A complete custom goggles scene needs a Control root with
`apply_native_state(state: Dictionary)`. Optional `bind_originals(resources)`
returns an error string; `detach_originals()` must remove any transient original
resources before saving. The supplied script also emits `native_state_changed`.
State contains `epoch`, `mode` (0 off, 1 night, 2 thermal), `active`, `hud`, `scan`,
`heading` (0..4095), `timer`, a three-bit `layers` mask and three `Vector2` offsets.
The runtime delivers snapshots at native FRAME boundaries and hides the root when
inactive or the native display is disabled. It scales the 320x224 layout into the
presentation rectangle, outside the 3D FSR2 viewport.

The default binding script uses `mgs_ui_role` / `mgs_ui_index` metadata for dynamic
labels, bars and layers. Wrap or replace those nodes to customize their layout;
native state remains authoritative for the eight-tick first-person entry delay,
six-tick indicator delay, SCAN blink, input offsets, visibility messages and exit.
Custom UI scripts cannot equip items or change native memory through this slot.
Other HUD/menu slots and settings actions remain in progress.

### Authored cameras

For editable Camera3D rigs and explicit gameplay/clip ownership, see
[Authored presentation cameras](GODOT_CINEMATIC_AUTHORING.md#authored-presentation-cameras)
and the asset-free `examples/presentation_camera` folder. Camera scripts update
their own nodes through the visual API; native snapshots retain world poses and
the renderer applies the selected camera afterward.

### World rendering coverage audit

Set `MGS_GODOT_WORLD_AUDIT=log` in the launching shell to print `MGS_WORLD_COVERAGE`
records from the standard and fog world sorters. Each record identifies the disc,
stage and scene epoch, with counts for Godot-owned, compatibility-rendered and
deliberately suppressed content. Records repeat when counts or the epoch change.
The audit is disabled by default and does not scan queues in that mode.

Use `MGS_GODOT_WORLD_AUDIT=detail` to add `MGS_WORLD_UNSUPPORTED` records at each
changed inventory. Mesh records include original model ID and part index; effect
records include primitive kind, face and registered texture ID (zero if absent).
FT4 records also show page, palette and UV coordinates for tracing unregistered
native producers. Mesh packet/texture fields describe the first face for context,
not necessarily the rejected face. Detailed logging is a diagnostic mode, not a
performance preset.

`meshes_*` counts active packet-owner parts, including their extended-part chains.
`effects_*` counts faces in active primitive groups. Both include off-camera content
eligible for an edited view; they are queue inventories, not pixel counts or draw
calls. `prim_types` is a bit mask of compatibility primitive kinds from `libdg.h`
(for example, bit 9 is TILE and bit 18 is textured FT4). Hidden/inactive groups are
excluded. Suppressed stock blob shadows/glows are reported separately.

Use `MGS_GODOT_WORLD_AUDIT=strict` to stop with a diagnostic when those world queues
contain compatibility content. This currently fails on scenes with unmigrated
effects; it helps identify remaining work. It does **not** certify the complete
frame: UI, Codec, movies, other draw channels, missing producers and other custom
sorters remain outside this audit. Full presentation strict mode is still pending.
Unset the variable to return to normal launching; no mod or user setting is changed.


### Editable health, oxygen and boss bars

Choose **UI → Health / oxygen** in the SDK to open the active mod's existing
bars scene or create its first one. It registers `ui.bars.scene` in `mod.json`.
Edit the ordinary `Life`, `Oxygen` and `Other` Control templates: their Label,
background, borders, damage segment and gradient texture are normal Godot nodes
and resources. Root Inspector health/oxygen values preview native fill values.
Native gameplay values and timing are unchanged.

Move a template to offset its native placement, or turn off Follow Native Position
for a fixed location. Hide a template to suppress that bar kind. Fonts can be
replaced through Label overrides or a Godot Theme. Life/Oxygen labels are editable;
Other defaults to Use Native Name and Use Native Colors for boss-specific values.
Those switches can be disabled to style or rename the generic template. Changes
to a gradient in the preview are preserved when saving. Preview values and locally
resolved original fonts are detached during save and never enter the ZIP.

Export and reopen the ZIP through the existing mod workflow. It contains the
Control scene, its scripts and authored dependencies; the original small font is
resolved locally from the selected disc. Both discs use the same `mgs/ui/menu_small`
reference. The UI browser marks Health / oxygen as edited.

A fully custom bars scene needs a Control root with
`apply_native_state(state: Dictionary)`. `state.bars` is an ordered Array of
records containing `position: Vector2`, `rest`, `value`, `maximum`, `height`,
`kind` (0 other, 1 life, 2 oxygen), `damage` (0/1), `left`/`right` packed RGB and
`name`. An empty array clears the UI. The presenter handles display visibility,
disc/epoch changes and screen fitting outside FSR2. Optional `bind_originals`,
`detach_originals` and `update_preview` methods supply local font references and
editor preview. Default templates and the root emit `native_state_changed` for
visual scripts; these signals cannot change native health or inventory.

This covers shared status bars, including their inventory/boss callers.
The rest of inventory and other menus are still separate migration work.


### Editable subtitles and modal messages

Choose **UI → Subtitles** to open or create `ui.subtitles.scene` for the active
mod. Move the `Text` Control to offset native caption placement; its Inspector
provides font color, size, outline and an optional replacement font for Latin
characters. Native symbols and other font banks retain their original glyphs.
`Pause` is a normal Label (including Theme/font overrides); `Dim` is a ColorRect.
The root's Preview Text is editor-only. A custom root Control can replace the
whole view using `apply_native_state(state)` and `native_state_changed`.

The native runtime owns subtitle expiry, caption visibility, forced text,
confirmation, pause and GCL callbacks. Its source glyph layout arrives by page
revision, including wrapping, ruby and button symbols. The layout is not a
Unicode string; see the [subtitle state contract](GODOT_PROTOCOL.md#subtitles-minor-17).
Fonts and current-page data stay transient. Saving detaches originals, and ZIP
export contains the authored scene/scripts/custom dependencies only. Open ZIP
uses the same workspace flow as other mods; each user's disc provides the
original preview font. Dynamic cinematic font banks are resolved during native
runs; arbitrary cinematic page selection in the offline preview is still open.


### Editable radar

Choose **UI → Radar** for the active mod. This creates or opens
`ui.radar.scene`; **Open ZIP…** reopens it through the same editable-workspace
flow as map changes. Move the `Radar` Control in the normal Scene tree, change the
root's map/alert/evasion/jamming palette in the Inspector, and edit the wall,
contact and noise layer styling. Header, symbol, digits and countdown warnings
are ordinary TextureRects: assigning your own texture preserves it through native
updates. Root Preview Mode shows map, jamming, evasion, alert and escape countdown.
Native radar hide/slide state is added to the authored placement.

The default scene resolves original radar artwork and digit palettes from the
locally prepared `init/5d43.r`; escape warning textures come from the prepared
`s19b` resources. Prepare both discs before using the full campaign SDK. Saving
removes transient original artwork and state, then restores the editor preview.
A default radar ZIP contains the manifest, scene and five scripts, plus any custom
assets you add; it never contains the original atlas or warning textures.

A fully custom radar view uses a Control root with
`apply_native_state(state: Dictionary)`. The dictionary follows the
[radar protocol](GODOT_PROTOCOL.md#radar-minor-18), with `contacts`, `sights` and
`walls` arrays of resolved radar coordinates. Optional `bind_originals(resources)`,
`detach_originals()` and `update_preview()` support local artwork and authoring.
The default emits `native_state_changed(state)` for visual scripts. The presenter
handles session/epoch/display visibility and UI scaling outside FSR2. Alert logic,
detection, RNG and escape expiry remain native.


### Editable inventory

Choose **UI → Inventory** in the SDK to create or reopen the active mod's
`ui.inventory.scene`. Existing exported mods use **Open ZIP…**, then the same
button. `Item` and `Weapon` are editable panel templates: move them, change their
Controls, substitute custom `Icon` textures, edit colours, or hide elements using
the Inspector. Native scrolling uses copies of these templates. The default
`Description` contains normal background/title Controls, formatted native text
and an optional PAL-key image. Root **Preview Mode** previews equipped, item and
weapon layouts. The default preserves the original appearance and held-button
input: hold L2/R2 to open, select/use through native controls, release to equip.
It has no added action footer, click areas or labels.

The default scene exposes `native_state_changed(state)` and consumes
`apply_native_state(state)`; see the [inventory payload](GODOT_PROTOCOL.md#inventory-minor-19).
Custom views can replace that implementation entirely. `use_native_name` and
`use_native_icon` on each panel allow authored alternatives, while custom textures
are preserved automatically. Original art resolves from the player's prepared
disc resources and is detached before saving/exporting. A default inventory ZIP
contains nine text files: manifest, scene and seven scripts, plus any custom assets
you add. It contains no original icon/font images or original data files.

For an explicitly custom interface, mod authors can add Buttons using the copied
`inventory_button.gd` and set these Inspector properties. That optional script is
included in the ZIP only when referenced by authored content; the standard scene
does not instantiate any of these Buttons.

| Property | Meaning |
| --- | --- |
| native_action | open, select, equip, use or close |
| native_side | Current(-1), Items(0), Weapons(1); opening needs an explicit side |
| native_target | Native entry ID; -1 is None, -2 follows the current selection; open/close use0 |

Custom roots may implement `connect_provider(provider)` to receive the inventory
action provider. Scripts can also use the visual API's `get_inventory_actions()`.
`get_snapshot()` returns native entries, selection, equipped IDs, open masks and
permissions. `request(action, side, target)` returns a positive action ID or0 with
`last_error`; await `action_finished(id, error)` before another request. The
provider emits `state_changed(state)` as native state changes. See the
[action contract](GODOT_PROTOCOL.md#direct-inventory-actions-minor-30) for exact
fields and target ranges. Render from the acknowledged state; do not decrement
counts or apply gameplay effects in the UI.

In a custom interface, script/Button opens remain open until equip or close.
Closing commits the selected
equipment just like releasing the original inventory button; choosing None
unequips it. Opening with the original held L2/R2 controls retains native input
and release-to-close until a Godot action takes ownership. Custom roots must
capture only while their active inventory view is owned, and release on close;
the reusable `inventory_controls.gd` handles this. Native rules govern consumption,
disabled equipment, frozen rations, health and player/menu restrictions.

Older exported UI scripts are preserved. To add these actions to an existing
custom inventory, merge the new provider connection and Button scripts, or
regenerate the inventory template in a separate workspace and transfer your edits.
Opening a ZIP does not silently replace its authored scripts. Physical-controller
parity, held-direction repeat and comprehensive UI review remain under validation.

### Editable Codec

Choose **UI → Codec** for the active mod, or **Open ZIP…** first to continue
an exported mod. This creates or opens `ui.codec.scene`. Console, frequency digits,
signal bars, portrait frames, dialogue, contact rows, incoming-call indicator and
fade are ordinary editable Controls. Move them in the Scene tree or Inspector,
change their styling, hide elements, or assign custom portrait textures. Native
updates preserve authored placement and replacement textures.

The root's **Preview Mode** offers conversation, tuning, contacts and incoming
call layouts. Offline selection of original animated portraits is not implemented;
native runs provide the original live portraits. Conversation timing, voice,
script choices and contact effects remain native; ordinary Godot Buttons now send
validated actions to that runtime. Save screens use the
separate editable [PC Save / Load scene](#editable-pc-save--load).

Custom Control roots consume `apply_native_state(state)`; the default also emits
`native_state_changed(state)`. See the [Codec protocol](GODOT_PROTOCOL.md#codec-minor-20).
Original frame/CALL artwork and fonts resolve from prepared local disc data and
are detached before serialization. A default Codec ZIP has eight text files:
manifest, scene and six scripts, plus any custom assets. It includes no original
portrait, artwork or font files. Reopen it through the standard ZIP workspace flow.

The default scene includes editable Buttons over tuning arrows, Call, Memory,
contacts, dialogue and the incoming-call indicator. `codec_button.gd` exposes
`native_action` and `native_target` in the Inspector. Contact targets are visible
row indices; the controller resolves the current native page. Keyboard/controller
directions navigate and confirm/cancel use the native allowed actions. Held-key
repeat and physical-controller parity remain under validation.

Custom roots can implement `connect_provider(provider)` or obtain
`visual_api.get_codec_actions()`. For example, `request("tune",14085)` sets140.85,
`request("call")` calls it, `request("confirm",0)` confirms the first native contact
or dialogue choice, and `request("back")` leaves the current page. Wait for
`action_finished(id,error)` before another action. A request returns its ID or
zero with `last_error`. `state_changed(state)` and `get_snapshot()` expose native
availability, mode, selection and revision. See the
[Codec action contract](GODOT_PROTOCOL.md#direct-codec-actions-minor-29).

Capture input only while your Codec dialog owns it. `active` can be true while
Codec is closed; use `opened` too, and yield modes12/14 to Save/Load. The default
root handles this. Native input still opens the closed Codec. Existing ZIPs retain
their copied scripts; merge the new Button/controller scripts or create a fresh
Codec template and transfer edits to adopt mouse/custom actions.

### Editable Options menu

Choose **Open ZIP…** to continue an existing mod, then **UI → Options**.
The active mod's `ui.options.scene` contains ordinary named Controls for captions,
language, sound, vibration, screen adjustment, controller layout, help and selection
highlight. Edit their positions, visibility, textures or materials in the Scene
tree and Inspector. **Preview Page** switches between the three original pages;
**Preview Selection** moves the main-page highlight. Original artwork resolves
from the prepared local disc. Native help text appears during a test run.

Mouse, keyboard and controller actions now call the native Options actor directly.
Each interactive artwork node has an ordinary **Interact** Button with editable
**Native Action**, **Native Option** and **Native Value** properties. Captions,
language, sound, vibration, both secondary pages and apply/exit preserve native
semantics and menu sounds. Settings are staged until leaving the main menu.
Unavailable hardware options remain unavailable. Errors appear inside the menu.
Display settings opens from the former Screen row through the registered Display
page; Back returns to Options with that row selected.

A custom root can implement `connect_provider(provider)`, or obtain the same
provider with `visual_api.get_options_actions()`. Use `request("set",3,1)` for
monaural, `request("activate",8)` for the Controller page, and `request("back")`
to leave the current page. Request returns an ID or zero plus `last_error`;
`action_finished(id,error)` confirms native acceptance after the updated snapshot
is visible. `get_snapshot()` returns a copy. Capture input while the custom menu
owns focus; the default root handles capture, controller navigation and Display
panel suspension. Existing authored UI scripts are not overwritten automatically.

The default root receives `apply_native_state(state)` and emits
`native_state_changed(state)`. See the [Options protocol](GODOT_PROTOCOL.md#options-minor-21).
Its named TextureRects have `use_native_position`, `use_native_color` and
`use_native_texture` switches for custom presentation. A normal export contains
eight text files: manifest, scene and six scripts, plus any custom assets you add.
Original textures and help glyph resources are detached for save/export and rebound
from local data when reopening. Both discs use the same authoring workflow.

### Editable PC Save / Load

Choose **Open ZIP…**, then **UI → Save / Load**. The active mod's
`ui.save_load.scene` exposes its title, save-list rows, New Save action, confirmation
and result dialog as ordinary Controls. **Preview Loading** switches the preview
between saving and loading. The default uses original MGS fonts, green-on-black
colors and framing with a flat PC list instead of memory-card/block selection.

Save rows and New Save are ordinary Godot Buttons. Mouse, keyboard and controller
focus activate them through the existing native storage worker. Up/down or the
mouse wheel scrolls the list; Escape/Back cancels when the worker permits it.
Overwrite defaults to Cancel; loading offers no New Save. Play time, difficulty
and location names come from native metadata. Storage format and capacity remain
unchanged. Input is captured while this dialog is active. Display settings is
entered through Options.

The root receives `apply_native_state(state)` and emits `native_state_changed(state)`.
See the [save/load view contract](GODOT_PROTOCOL.md#pc-saveload-minor-22).
An optional `connect_provider(provider)` method receives
`visual_api.get_save_actions()`. Custom buttons can call
`provider.request("activate", save_id)`, `request("new_save")`, `request("confirm")`,
`request("back")` or `request("continue")`; listen to `action_finished(id,error)`
for acceptance and to `state_changed(state)` for actual native I/O results.
Use `capture_input(true)` only while your native save dialog is active, and release
it on close. Honor `captures_input()` before handling controls, since another menu
may own focus. See [action validation and signals](GODOT_PROTOCOL.md#direct-saveload-actions-minor-26).
Older ZIPs retain their authored scripts/layouts and native controller behavior;
they are not silently rewritten to add buttons.
Original bitmap fonts resolve locally and are detached for export; custom fonts
remain authored assets. A default ZIP has three text files (manifest, scene, script)
and can be reopened in another prepared SDK workspace without original files inside.

The default Codec console also retains separate dim background and active foreground
Controls for its frequency, signal and action indicators. The Foreground CanvasGroup
applies the original small additive glow; these nodes and its shader remain editable.

### Editable title and new-game menu

Choose **Open ZIP…** to continue an exported mod, then **UI → Title / New Game**.
The active mod's `ui.title.scene` contains named Controls for backgrounds, logos,
portrait parts, menu entries, difficulty labels, highlights, storage warnings and
native help text. **Preview Page** offers Press Start, Main menu, Difficulty and
Special; **Preview Difficulty** selects the highlighted difficulty.

Edit nodes through the Scene tree and Inspector. Custom positions, sizes,
visibility, textures and materials survive native animation updates. Artwork
nodes expose `use_native_position`, `use_native_color`, `use_native_texture` and
`use_native_crop` when custom presentation should replace those native properties.
The root receives `apply_native_state(state)` and emits `native_state_changed(state)`;
see the [title view contract](GODOT_PROTOCOL.md#title-and-new-game-minor-23).

Original artwork and fonts resolve from prepared disc data. Native help layouts
appear during a test run. Local originals are detached before saving or exporting
and restored on reopening. A default title ZIP contains nine text files: the
manifest, scene and seven scripts. Custom assets add their own dependencies.

The **Interact** children are ordinary Buttons with editable **Native Action**,
**Native Target** and **Native Page** properties. Mouse, keyboard and controller
input invokes native selection, transitions, sounds, difficulty, storage checks
and New Game. The original cancel input returns to the previous menu page; no
extra Back button is added. The transparent branding
Button uses the original logo-skip behavior. Unavailable actions are disabled.

Custom roots can implement `connect_provider(provider)` or call
`visual_api.get_title_actions()`. `request("select",2)` selects Options on the
main menu; `request("activate",2)` opens it. On the difficulty page, target2 is
Normal. `request("back")` cancels the current page. Requests return an ID or zero
with `last_error`; `action_finished(id,error)` runs after the resulting snapshot
is presented. `get_snapshot()` returns a copy including mode, selection, difficulty,
unlock status and revision. Capture input while the custom menu owns focus;
the default root handles capture, focus and transition guards. See the
[title action contract](GODOT_PROTOCOL.md#direct-title-actions-minor-28) for targets.

Existing authored scripts remain unchanged when the SDK updates. Merge the new
Button/provider scripts into an existing custom UI, or create a fresh title UI
template and transfer your edits. Native input remains available to old title UIs.
The separate animated Metal Gear logo, briefing, movies and other front-end actors
are not migrated by this title scene. Special-page actions still use native input.

### Shared settings API

The visual API now exposes `get_settings_provider()`. Godot scripts can read typed
display settings, validate a proposed change and explicitly save it through the
same profile used by the launcher. Original asset files are not involved. Launcher
sessions and editor/command-line native tests use the same provider implementation.
See [the settings contract](SETTINGS_CONTRACT.md) for request IDs, signals, stale
write handling, persistence and launch overrides.

For live changes, use `provider.display.preview(changes)`, then `confirm()` or
`revert()` once the phase reaches `preview`. The 15-second timeout restores the
previous native projection, GPU buffers and window; only confirmation persists.
`provider.get_snapshot()` reports actual applied state and the negotiated policy.
Raw `request("save", changes)` changes persistence only. The editable in-game
settings panel and input ownership remain under implementation.

### Editing the PC display settings menu

Choose **UI → Display settings** to create or reopen `ui.display_settings.scene`
in the active mod. It is an ordinary Control scene with editable fields, buttons,
labels and Theme. Export and reopen it through the normal mod ZIP workflow; original
fonts are local references and are excluded from the ZIP.

Players open **Options → Display** (the former Screen row). Back appears only inside
the Display page and returns focus to that Options row. There is no global Display
button or F10/R3 opener. Apply Preview uses the
shared live display provider; Keep saves the change, while Revert or the countdown
restores it. Controls are captured while the panel is open; the native game keeps
running. The API and current limitations are in [Settings contract](SETTINGS_CONTRACT.md#editable-display-panel).

The display presenter registers its page with the Options scene through
`register_page(6, "DISPLAY", display_ui)`. Registration uses an ordinary authored
`Options/Screen/Interact` Button (`native_action="activate"`, `native_option=6`).
The Options provider first selects row 6, then opens the page after the native
acknowledgement. The page implements `allow_options(bool)` as well as the display
panel contract; while it captures input, Options is suspended. Custom Options UI
scripts need this registration method to expose built-in settings. Regenerate the
UI template or merge the method into older authored copies; scripts in existing
user ZIPs are not rewritten automatically.
