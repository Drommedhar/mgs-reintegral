# Mod creator guide

Make and test visual mods using the Godot SDK's **MGS Visuals** dock and Godot's
normal Scene tree, Inspector, materials and animation tools. This guide covers
the 0.3.0-alpha.1 SDK workflow. You do not need a running game, F7 capture or a compiler
to preview original maps and create your first mod.

For playing and installing a finished ZIP, use the [player guide](PLAYER_GUIDE.md).
For scripting, manifests and extension APIs, use the
[technical reference](GODOT_MODDING.md).

The SDK supplies higher-resolution original-style menu lettering and scalable
dialogue by default. Native text positions, wrapping and timing still drive the
default interfaces. Players can choose the original pixel fonts in the launcher.
An authored text control's `font_override` takes precedence; injected SDK fonts
are detached before saving, so an ordinary UI mod does not need to redistribute
the SDK font files. Bitmap location cards and credits retain their original
artwork with smooth scaling. Lettering baked into scene textures and unsupported
glyphs keep their original artwork.

## What a visual mod changes

You can replace models and textures, edit materials and original lights, add
custom geometry and lights, hide original visuals, attach content to supported
moving actors, and edit supported UI, effects and cinematic camera tracks.

The native game still controls gameplay, collision, animation state, audio,
saves and timing. **Hiding a wall does not remove its collision. Adding a floor
does not make it walkable.** Water appearance does not change swimming or oxygen.
Native extensions are an advanced presentation API, not permission to replace
the gameplay simulation.

Original previews are rebuilt locally from the user's discs. Your exported
ZIP contains edits, original-asset references and your custom assets. It must
not contain the original meshes, textures, fonts or extracted disc data.

## Set up the editor

1. Extract the complete SDK into a writable folder. Its commands download the
   pinned tools on first use; keep that Godot version for renderer/SDK compatibility.
2. Run **Prepare.cmd** and select both Integral campaign CUE files. Let the
   preparation finish. See the [player requirements](PLAYER_GUIDE.md#what-you-need)
   for the supported disc format.
3. Run **Editor.cmd**. The project is
   `renderers/godot/project/project.godot`. Wait for the initial asset import
   and catalog loading to finish.
4. Find the **MGS Visuals** dock. The workspace picker and **Open ZIP…** are
   at the top; the tabs below organize the work.

| Tab | Use it for |
| --- | --- |
| Maps → Browse | Search locations, expand gameplay/cinematic variants and camera clips, open a map |
| Maps → Test | Preview enabled mods together, choose a native entry profile, Run, Stop and Open test logs |
| Assets → Original assets | Find original model/texture IDs, edit models and assign replacements |
| Assets → Mod resources | Work with the active mod's named resources |
| UI / Effects | Browse grouped entries and use **Open selected** |
| Mod → Workspace | Save, Save As, version, Export ZIP, Export As and export status |
| Mod → Enabled mods | Choose other mods for combined preview/testing and set their priorities |

Large custom assets can make the first Godot import slow. Check the editor's
import progress and Output errors before assuming it has frozen. Preparation,
editor import and launcher import are separate steps with separate caches.

## Your first mod: change the Loading Dock

### 1. Create an independent workspace

Choose `local` in the workspace picker, then **Mod → Workspace → Save As…**.
Enter a name such as `My Dock` and a unique ID such as `yourname.my-dock`.
Click **Create mod**. The new workspace becomes active; edits go into its
folder under `res://mods/`.

Use **Open ZIP…** instead if you want to continue an existing mod. Opening the
same ZIP resumes its existing workspace, including later local edits. A ZIP
changed elsewhere opens a separate workspace. Use **Save As…** to create an
independent copy with a new ID.

### 2. Open a map and make a visible edit

1. Go to **Maps → Browse**, clear **Only maps with edits**, and search for
   `Loading Dock` or `s00a`.
2. Expand the location, select its gameplay variant and click **Open map**.
   You can also double-click a row. Original geometry and declared lights load
   directly from prepared content.
3. Select an original mesh in the ordinary **Scene** tree. Its model/part IDs
   identify the source. Change a material's albedo tint in the **Inspector**,
   or use the node's visibility control to hide that visual.
4. To add a simple custom object, add a **MeshInstance3D** under your mod scene
   root, assign a **BoxMesh**, move it into view and give it a material. It is
   a visual prop; it does not gain native collision.
5. Use **Mod → Workspace → Save**. This saves open scenes and edited resources
   belonging to the active workspace, plus its version field.

The original preview nodes are editable references. The SDK records their
supported changes when saving and restores their source geometry locally when
reopening. Do not copy generated original geometry into a separate custom mesh
file to package it.

### 3. Test with the real game

1. Open **Maps → Test**, choose a native entry profile and click **Run**.
2. Check the edit in the game. Use **Stop** to close this editor-owned test.
3. Use **Open test logs** if startup or a resource fails.

A fresh-stage profile is useful for a quick visual check. It does not establish
the story state needed for every actor or cinematic. Use **Title screen · New
Game / Load** to reach story-dependent content through normal gameplay.

Godot's **F6** runs the current scene as a Godot preview; it does not run the
native game. Editor native tests use isolated folders under
`build/godot-editor-runs`, separate from the player's normal saves. Changes made
after a native test starts apply on the next launch.

### 4. Export and test the actual ZIP

1. Set an optional version under **Mod → Workspace**.
2. Click **Export ZIP**. On first export, choose a filename and destination.
   Subsequent exports update that remembered destination. **Export As…**
   chooses another ZIP destination while keeping the same mod ID.
3. Check the workspace status: **Workspace matches exported ZIP** confirms
   the saved source files match their last export. This check runs in the
   background while you edit. Older workspaces ask for one export to establish
   this comparison. Full dependency and original-content validation runs when
   exporting, rather than every time you open or save a resource. If it says **Export
   needs attention**, read the dependency/error path; a save dialog alone does
   not mean a ZIP was written.
4. Follow the [player installation steps](PLAYER_GUIDE.md#install-update-or-disable-a-mod)
   to install your exported ZIP in the launcher. Verify it with **Godot scene
   rendering** and only the intended mods enabled.

Export saves first, then shows a progress dialog while checking custom resources
and writing the ZIP. Validation shows the current activity and elapsed time;
compression shows its percentage by bytes written. **Cancel** keeps the previous
ZIP and export history. Cancellation becomes unavailable while finalizing the ZIP.
The editor continues drawing throughout the export. It preserves the
previous ZIP if export fails. If another program changed that ZIP, ordinary
export refuses to overwrite it; inspect the change or choose **Export As…**.

For a portability check, open the exported ZIP in a separate prepared SDK
folder. Reopening it in the same editor can resume your existing workspace,
which is useful for editing but does not prove a fresh import works.

## Custom models, textures and materials

Keep custom dependencies **inside the active mod folder**, for example:

```text
res://mods/yourname.my-dock/
  mod.json
  assets/
    dock.glb
    wood_normal.png
  materials/
    wet_wood.tres
  stages/
  sdk/
```

Use Godot's FileSystem dock to move resources within the project so references
can be updated. If you move a file using Explorer, reassign any stale references
in scenes and materials, then save. A copy now existing inside the mod does
not fix a scene that still references the old file outside it.

- **Add a custom prop:** place its GLB and textures in the workspace, wait for
  import, then instance it under your map scene using normal Godot tools.
- **Replace an original texture:** select it in **Assets → Original assets**
  and use **Assign replacement…** with your PNG/WebP.
- **Edit an original model's materials:** select the model and use **Edit
  model / view texture**. Edit its mesh parts in the Inspector and save.
- **Replace a complete model:** use **Assign replacement…**. GLBs are copied
  into the workspace; glTF/TSCN files and their dependencies must already be
  inside it. Rigged replacements must preserve the expected part bones, rest
  transforms, skin binds and attachment slots. See the technical reference.

Reopen an existing map/model tab after assigning replacements to refresh its
preview. Use **Make Unique** when you intend to change only one instance of a
shared custom material. Keep texture mipmaps enabled for detailed surfaces;
very sharp normal maps, roughness maps and tiny bright details can shimmer in
motion. Evaluate them in a native run at the intended output resolution.

The SDK prepares mipmaps for textures used by mipmapped 3D materials, including
enabled POM height maps. It also
enables normal-map mip filtering and pairs roughness textures with their normal
maps where that relationship is unambiguous. ORM materials use the green
roughness channel. This runs when a mod scene/model is opened, saved or imported
in the editor, and during the launcher's first import. Texture source files and
base-level colors stay unchanged. Valid explicit roughness import settings,
including **Disabled**, are preserved; stale normal paths are repaired.

For custom shaders, configure texture mipmaps and roughness filtering yourself
in Godot's Import dock: the SDK cannot infer arbitrary shader parameter usage.
Filtering reduces distant detail flicker; very smooth surfaces and tiny bright
features may still need material tuning. It does not add geometry or remove
your normal-map detail at close range.

For relief on opaque custom surfaces, assign a grayscale texture under a
StandardMaterial3D's **Height → Texture**, enable Height and **Deep Parallax**,
then tune Scale and the layer counts. White represents raised areas. Keep
height textures inside the mod so scene/material dependencies include them in
the exported ZIP. POM changes surface shading; native collision and the mesh
silhouette remain unchanged. Avoid large depth values on thin or cutout surfaces.

The docks POM variant uses editable surface overrides in
`docks_test/dock_remastered_pom.tscn`, with materials and height maps under
`docks_test/pom/`. Open that inherited scene to edit a shared surface material.
Its revised ComfyUI-generated maps use the color textures to identify structural
relief: flat faces, mortar joints, panel recesses, braces and bolts. Surface
grain, stains and painted markings stay out of the height maps; the original
normal maps retain their fine detail. The generation record is included as
`height-generation.json`. Both docks variants use the same
materials, with 8–24 parallax layers and Scale values of0.3–1.0 on most surfaces.
Featureless surfaces keep Height disabled; a flat surface needs no parallax
texture or ray-marching work.

Original files remain reference material only. Export checks known original
content and dependencies, including embedded GLB/glTF data. Renaming an extracted
asset or duplicating its Godot resource does not turn it into a custom asset.

## Maps, variants and moving objects

The map browser combines prepared sources; there is no disc dropdown. Expand
a human-readable location to see gameplay/cinematic variants and camera clips.
Rows show direct or inherited edits. A previewable cinematic is not necessarily
a playable standalone stage. Unprepared rows show why they cannot be opened;
run preparation and use **Mod → Reload catalog** to refresh the browser.

**The underwater part of the docks is inside Loading Dock**, not a separate
map entry. With SDK18 declaration metadata, its Scene tree includes water
(`6d44`), chains (`6d45`), submerged scenery (`6d46`) and the conditional
elevator cart (`6da3`). If an older preparation lacks them, close the editor,
run the current SDK's **Prepare.cmd**, then reopen the map.

These objects have native binding nodes and part anchors. Parent custom meshes,
lights or scenes under the appropriate part to follow its native motion. Hide
an original mesh preview to replace that part's appearance. Keep the binding
and anchors when you need their motion; preserve the binding's `target` fields.
Conditional objects can be visible as authoring context before their actor
exists in the running game.

Copying a whole binding also copies its local preview in the editor. The SDK
recognizes that preview during save, retains your material changes and custom
children, and excludes original meshes and unchanged original textures from
the ZIP. SDK21 also repairs saved copies when you reopen and save the map;
the binding must still match a declaration or an explicit alternate target.

Support depends on the declaration/provider; not every dynamic actor has an
editable preview yet. Original chains retain their native deformation. An
arbitrary replacement chain mesh needs explicit vertex correspondence to inherit
that deformation; ordinary parenting supplies part motion, not guessed bending.

When an edit is inherited into a cinematic variant, check that variant too.
Bindings identify exact native declarations, including source revision. The
advanced `alternate_targets` field supplies explicit counterparts for other
scenarios; identical model names alone do not establish a match.

## Water and freezing surfaces

The SDK includes reusable water, puddles and frost under `addons/mgs_water`:

1. Copy the **whole folder** into your workspace, for example
   `res://mods/yourname.my-dock/sdk/water/`, before using its resources.
2. Instance **pool.tscn** for close water, **puddle.tscn** for shallow cutouts or **ocean.tscn** for distant water.
   Put the region origin at the waterline; local Y points up and `volume_size`
   extends downwards. Hide the original water visuals you are replacing.
3. Select the water region root and use its grouped Inspector controls for wave
   height/size/speed, refraction, reflections and caustic strength/size/speed.
   Existing preset values are preserved until you override them. The Surface
   child's material exposes further shading controls such as absorption.
   Near-water presets include bounded underwater fog and caustics. Enable
   `animate_preview` for offline editor motion.
4. For frost, add **frost.tres** as a material's **Next Pass**, or attach
   **frost_layer.gd** to a Node3D and set its explicit target paths. Use a mask,
   exposure and submerged exclusion to keep coverage patchy.

Screen-space reflections (SSR) can only reflect visible opaque screen content;
misses fade to environment/probe reflections and a fallback color. Avoid
overlapping or stacked water regions along the same view: this version supports
one screen-refracting water layer per view ray. Virtual-bottom puddles can cover deeper water. Caustics need an opaque surface inside the volume and actual scene lights whose range reaches it. The ocean
preset increases presentation view distance; it does not create or stream
gameplay terrain.

Try `examples/water_frost/preview.tscn` with F6 for an asset-free demonstration.
Its right-mouse/WASD/Q/E controls belong only to that demo. See the
[water and frost guide](GODOT_WATER_FROST.md) for volume setup, filtering,
performance choices and limitations. Existing submerged scenery is not rebuilt
by the water system.

## Falling snow

Copy `addons/mgs_snow` into your mod and instance **snow_volume.tscn**. GPU weather simulation is the default; select Exact surfaces (CPU) when triangle collision and moving-surface attachment are required. Size and
position the volume, then use its Inspector for flake amount, size, fall speed,
wind and contact fading. Enable **Animate Preview** to watch it in the editor.
Both sides of scene geometry block flakes, including one-sided roofs. This is
a reusable resource; it does not add snow to the docks automatically.

See the [snow volume guide](GODOT_SNOW.md) for collision sources, original-snow
replacement, performance and the standalone example.

## UI, effects, cameras and multiple mods

Original wet footprints now follow the native player, actor and cinematic
footprint lifetimes in full Godot. Select the original `asiato` / `dc55` texture
in Assets, then use **Asset tools → Edit texture's effect material** to edit
its subtractive material or supply a replacement texture. Keep its subtractive
shader when changing appearance. The original
quad stays at the native floor height; moving a mod floor significantly away
from that height requires corresponding presentation placement work.

Open UI and effect entries from their grouped browsers, then edit ordinary
Controls, materials and resources. Open cinematic clips from the expanded map
browser and edit their tracks using the
[cinematic authoring guide](GODOT_CINEMATIC_AUTHORING.md). Supported bindings
follow native state and timing; an offline preview is not a full gameplay test.

In **Mod → Enabled mods**, add other `mod.json` files, check the desired mods
and set their priorities. The active workspace remains enabled. Use **Maps →
Test → Preview profile** to inspect the combined saved result and conflicts;
**Run** uses that same enabled set. Edit each mod in its own source scene, then
preview again. The combined preview is context, not a new editable merged mod.

**Save and Export ZIP affect only the active workspace.** Other enabled mods
are not bundled with it. Launcher selections and editor profiles are separate;
list any required companion mods in your release instructions.

## Troubleshooting and release checklist

| Problem | Action |
| --- | --- |
| Export says a dependency is outside the mod | Read the exact path. Move/copy the custom file into the workspace, update every reference to the old location, save, and export again. Check nested materials, textures, scripts and shader includes as well as the scene. |
| Export says original content was found | Keep that content as an SDK original reference. Remove the copied original resource from your custom dependency graph; use your own authored replacement if needed. |
| Map is absent | Clear the search and **Only maps with edits** filter, expand its location, then check preparation status. The submerged docks area is part of Loading Dock. |
| Preview is correct but game is unchanged | Check the active workspace, Save, restart the native test, and check the enabled profile and the exact gameplay/cinematic variant. In the launcher, install the latest ZIP and select Godot scene mode. |
| Attachment does not move or appear | Check the binding's availability and target, the native entry profile, and whether your children are under the correct part. Conditional actors need the appropriate gameplay state. |
| Imported model looks stale after a file move | Reassign the new resource path, save the scene/material, allow import to finish and reopen the scene. Inspect the error's old path rather than merely repeating Export. |

Before sharing a release:

- Export successfully and test that ZIP in a separate prepared SDK workspace
  and in the launcher. Include normal gameplay and affected cinematic variants.
- Check with intended companion mods and with optional ones disabled. Document
  dependencies, overlaps and the SDK version you actually tested.
- Include mod name, ID, version, installation steps, changed locations, known
  limits, asset credits and redistribution terms.
- Share the exported mod ZIP. Keep disc data, `.local`, `.godot`, prepared
  previews, saves and your populated SDK private.
- Back up the editable workspace as well as release ZIPs. Unreferenced drafts
  are not guaranteed to be included in an exported dependency graph.

For code-driven resources, GDExtension builds and manifest details, continue
with the [technical reference](GODOT_MODDING.md). C++ extensions require a
separate compiler and the pinned godot-cpp source; ordinary editor mods do not.
Full campaign fidelity and universal actor coverage remain in development.
