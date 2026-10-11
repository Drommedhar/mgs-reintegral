# Visual mod prototype

Godot is the primary renderer and modding editor direction. The matched protocol
v9 implementation supports the focused workflow below; campaign-wide renderer
coverage and a stable public SDK remain follow-up work.

This is the first renderer-facing API, not a finished campaign SDK. The C runtime
still owns gameplay, collision, animation, audio, saves and input timing. Godot
owns all GPU rendering. Use the editor project at `renderers/godot/project`.

## Prepare from your discs

```powershell
$p = 'D:\git\mgs-integral-native'
& "$p\tools\prepare-godot-content.ps1" -DiscDirectory 'C:\Users\domin\Downloads\mgs'
& "$p\tools\run-godot.ps1" -Build -Scene3D
```

The existing Integral importer reads BIN/CUE files without modifying them. The
converter verifies the extraction receipt and writes deterministic glTF 2.0/PNG
files to `.local/godot-content`. The current content profile supports Integral
Japan disc 1, including English resources and normal/Very Easy/tuxedo resident
assets. It prepares the opening, docks and helipad. Different editions require
explicit identity mappings and are not currently accepted.

No original models, textures or sounds are included in source. `mods/`,
`.generated/`, `.godot/` and `.local/` are ignored. Generated examples and editor
captures may contain your disc's content; keep them local. The tracked example
lighting scene contains only authored Godot nodes and settings.

## Editor workflow

From the repository folder, open the project in the pinned Godot editor:

```powershell
& ".\.tools\godot-4.8-dev7\Godot_v4.8-dev7_win64.exe" --editor --path ".\renderers\godot\project"
```

This command works in a fresh PowerShell session without setting `$p`. Keep the
leading `&`: PowerShell needs it to execute a quoted executable path.

Click **Open mod ZIP for editing…** in **MGS Visuals** and choose an exported ZIP.
The editor creates a workspace under `mods/<zip-name>-<content-hash>` and opens
its first map. The normal disc-backed reference geometry is restored locally.
The picker at the top selects the active workspace; all map, texture and model
edits go there. `local` remains available for new work.

Opening the same ZIP resumes its existing workspace, preserving later local edits.
A ZIP whose contents changed opens a separate workspace. Import validates paths,
archive integrity and manifest references before making the workspace available.
It uses the Python environment already created by `tools/bootstrap.ps1`.

**Export mod ZIP (custom assets only)** saves the scenes and opens a Save dialog.
Choose the output filename; selecting an existing ZIP asks Godot's normal overwrite
question. Imported workspaces initially suggest their source ZIP; subsequent
exports remember your selected path. Failed exports leave the previous ZIP intact.

The catalog includes both models and textures. Selecting an original model in
Godot's Scene tree also selects its asset in the catalog. To edit characters:

1. Select a model and click **Edit selected model / view texture**. This opens a
   scene with the original rig and `mesh_NNN` parts visible in the Scene tree.
2. Edit a part's material in the normal Inspector, including albedo tint, roughness,
   metallic, normal maps and custom textures. Save the scene. The saved scene stores
   changed properties and original asset IDs; the original mesh, skeleton and
   unchanged textures stay on the recipient's disc.
3. To replace geometry, assign your own Mesh resource to a part, or use
   **Assign replacement texture / model…** for a complete rigged GLB/glTF/TSCN.
   GLB files are copied into the active mod. Put glTF/TSCN and their dependencies
   inside the active mod folder before assigning them. Preserve `part_NNN` bone
   names, parent/rest transforms, skin binds and `mesh_NNN` attachment slots;
   incompatible complete replacements are rejected before registration.

Godot's Inspector edits mesh resources and materials; detailed vertex modeling
and texture painting still use tools such as Blender or an image editor.
**Show original source file** locates the local glTF/PNG for reference.
**Show selected model's textures** lists the texture IDs used by that model.
Select a texture, then **Assign replacement texture / model…** to import your
PNG/WebP and register it without editing JSON. Reopen an existing map/model tab
to refresh its preview after assigning replacements. Put custom material maps
inside the active mod folder so export can include their dependencies.

Older local scenes containing copied original geometry are still rejected by
export. Create a reference-based edit scene or supply your own replacement instead.

Select **s00a — docks** or **s01a — helipad** and click **Open map** in MGS Visuals.
Preparation reads the stage's startup map declarations from its disc script and
converts the referenced models and textures. The editor assembles those models
directly from `.local/godot-content`; no gameplay session or F7 is needed. If an
older cache has no map definitions or light tables, rerun `tools/prepare-godot-content.ps1` and
click **Reload prepared catalog**.

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

**Export mod ZIP** exports the mod containing the currently edited scene under
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

Render layer 20 is reserved for internal ordering/mask metadata. Use layers 1–19
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

Higher priority wins. Equal priority sorts by mod ID; the later ID wins a
conflict. Duplicate mod IDs and missing/invalid resources are errors. Models are
validated/preloaded before boot. Requested failures do not silently use originals.

Original meshes use the game's live vertex lighting by default. A stage override
with `original_lighting: false` switches them to Godot PBR lighting and shadows. Model
replacements choose `unlit` or `lit`; they cannot inherit original per-face light
indices after changing topology. Custom ShaderMaterials retain their own shader.

The opening cutscene stages inherit their gameplay map overlays: `d00a` uses
`s00a` (docks), and `d01a` uses `s01a` (helipad). Authored lights, environment,
objects, original-light edits and visual removals follow that overlay. An explicit
cutscene stage entry takes precedence. Model/texture/PBR replacements also follow
these variants when the original resource hashes match; an explicit replacement
for the cutscene asset wins. Different original resources are not aliased.
The visual API still reports the actual active stage, such as `d00a`.

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
and `get_instances()` (`id`, `asset`, `node` dictionaries). It emits
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

Click **Export mod ZIP (custom assets only)** after saving the overlay. Packages
go to `build/mod-exports`. The exporter includes the manifest and its referenced
authored scenes, textures, scripts and current-platform extension binaries. It
rewrites local resource paths for relocation, rejects dependencies outside the
mod directory, and refuses local previews or resources marked as retail-derived.
The editor replaces an existing archive only after the Save dialog's overwrite
confirmation; the export API defaults to refusing overwrites.

Use `preload()` for script dependencies that belong in the package. The exporter
relocates those paths along with scene resources and shader includes. Literal
runtime `load()` paths produce an export error because Godot resolves them
against the project root, not the relocated script's directory. Dynamically
constructed resource paths are outside this exporter's dependency discovery.

The package stores original asset IDs and removal/placement instructions. Each
recipient prepares the original content from their own discs. The local map
reference is never included. Model edit scenes store `mgs_model_reference` and
`mgs_part_edits` metadata. Runtime reconstructs the original rig from prepared
disc content and applies only authored material/mesh/transform changes. Original
surface visibility and animation remain native. New geometry and textures must
be your authored assets; the exporter rejects embedded original resources.

Open `build/windows-x86-godot/RE-INTEGRAL.exe`, select **Mods → Add ZIPs…**,
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

The game view is 4:3. The launcher's output resolution also scales the world
viewport and composition framebuffer; the native command buffer and readback
retain their original dimensions. Godot world geometry has perspective-correct
textures and a depth buffer, then is composed at the higher resolution with the
original HUD, menus, Codec and effects. Visible runtime-textured or subtractive KMD parts and
procedural spotlight geometry still use the Godot command layer. That layer has
no shared depth with the 3D scene. Texture overrides currently affect the mesh
layer, not original UI/VRAM uploads. Palette animation and thermal/stealth effects
need further material migration. Live packet UVs reach original-color and Godot-lit
meshes. Lit faces use Godot culling and prepared UVs when the original low-resolution
projection culls their packets, preserving small distant faces. Widescreen, campaign-wide coverage and
seamless mixed-effect depth are follow-up work. Permanently collapsed textureless
faces are discarded separately, so they do not prevent textured character parts
from receiving Godot lighting.

The prototype keeps SDL input and native audio/replay formats. Recording is
available through `-RecordInput`; replaying uses `-ReplayInput`. Save cards are
separate in `.local/godot-runtime`. Visual mod settings are not part of the native
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
