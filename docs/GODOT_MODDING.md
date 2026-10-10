# Visual mod prototype

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

Open the project in the pinned Godot editor:

```powershell
& "$p\.tools\godot-4.8-dev7\Godot_v4.8-dev7_win64.exe" --editor --path "$p\renderers\godot\project"
```

The **MGS Visuals** dock lists stable model IDs. Select one and click **Create /
open model override**. The plugin saves an editable local scene and updates
`mods/local/mod.json`. Edit meshes/materials while preserving `part_NNN` bones,
their parent/rest transforms and `mesh_NNN` attachment slots. Runtime validation
rejects incompatible rigs before the native game starts.

During gameplay, **F7** captures the current camera, geometry and poses to
`.generated/previews/<stage>.tscn`. The plugin can open that reference. Creating a
stage lighting scene after capture includes it as an editor-only preview: it is
removed when the override is loaded in the game. Lights, WorldEnvironment, fog
and other visual nodes in the override run in the same Godot world as the meshes.
They do not change collision or the original gameplay camera.

Coordinates are metres: original `(x, y, z)` becomes `(x, -y, -z) / 1000`.
Use the captured camera to inspect placement. The preview is a moment in time,
not a reconstruction of hidden rooms or a complete level editor.

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
with `original_lighting: false` switches them to Godot material lighting. Model
replacements choose `unlit` or `lit`; they cannot inherit original per-face light
indices after changing topology. Custom ShaderMaterials retain their own shader.

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

The game view is 4:3 with native command-buffer resolution. Godot world geometry
has perspective-correct textures and a depth buffer, then is composed with the
original HUD, menus, Codec and effects. Runtime-textured/transparent KMD parts and
procedural spotlight geometry still use the Godot command layer. That layer has
no shared depth with the 3D scene. Texture overrides currently affect the mesh
layer, not original UI/VRAM uploads. Palette animation and thermal/stealth effects
need further material migration. Higher internal resolution, widescreen,
campaign-wide coverage and seamless mixed-effect depth are follow-up work.

The prototype keeps SDL input and native audio/replay formats. Recording is
available through `-RecordInput`; replaying uses `-ReplayInput`. Save cards are
separate in `.local/godot-runtime`. Visual mod settings are not part of the native
simulation identity; retain manifests alongside visual comparison captures.
