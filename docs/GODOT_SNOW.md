# Snow volumes

Copy `addons/mgs_snow` into your mod, then instance its **snow_volume.tscn** through Godot's normal Scene tree. Internal resources use relative paths. The volume creates visual flakes and local collision data; it never changes native gameplay physics. No snow is added to any map automatically.

The root's **Volume Size** is a box centered on the node, in metres. Snow falls from local +Y toward local -Y. Move or rotate the node with ordinary transforms. Select **Animate Preview** to see it in the editor. **Prewarm** fills the volume immediately while checking for roofs above each flake, so covered areas do not start full of snow.

## Inspector controls

| Group | Controls |
| --- | --- |
| Volume | Dimensions, enabled state, replace original snow, editor preview, prewarm and random seed |
| Flakes | Amount, minimum/maximum size in metres, color/opacity, fall speed in metres per second and speed variation |
| Wind | Local wind velocity, gust strength/speed, flutter strength/speed |
| Contact | Settle/fade time, contact offset, collision roots/exclusions and Rebuild collision |

Amount is the maximum active flake count, not a density per square metre. Increase it deliberately when enlarging a volume. Size and speed ranges vary deterministically between flakes. Rebuild collision resets the preview and applies a changed random seed or collision-source selection.

Flakes briefly rest and fade on contact. They follow a moving surface while fading and then return to the falling population. They do **not** accumulate a snow layer. Native pause freezes falling, flutter and fading; a native scene/session reset clears previous flakes. Offline previews use their own clock.

**Replace Original Snow** defaults on. Original snow within an enabled, ready volume is hidden; snow outside it remains. Turn the switch off to combine the two deliberately. Disabling or hiding the volume restores original snow. Existing effect-material overrides are separate from this volume.

## Geometry collision

Flakes test the segment from their old position to their next position against scene triangles. Both faces count, including the reverse side of a one-sided roof or wall. Collision is independent of camera visibility and material face culling, and supports layered floors and wind into side walls.

With no Collision Roots selected, the volume uses the active scene. Use explicit node paths to limit its sources; Collision Exclusions omit selected subtrees. Hidden meshes do not block snow. An intentionally hidden custom collision mesh can be placed in the ordinary Godot group **mgs_snow_collision_proxy** to keep it active. Water passes, native effects, thermal metadata and snow itself are excluded automatically.

Rigid meshes and original skinned models follow their current transforms and bone poses. Mixed-bone triangles and native vertex deformation are supported. Collision data is generated locally in a separate physics space and is never saved into the mod; exported ZIPs do not acquire copies of original scenery.

Boundaries to account for when authoring:

- Blend shapes need an explicit mesh proxy; the Inspector reports this. Shader-only displacement is not available to the collision system.
- Alpha-cutout textures do not cut holes into collision triangles. Use an appropriately shaped proxy or an exclusion for those surfaces.
- Collision tracks flake centers, with a small contact offset. It is not a swept sphere. Very fast geometry can cross a flake between simulation samples.
- Regenerate collision after editing source topology or changing its selected roots. Runtime mesh replacement and original native deformation update automatically.
- Large or heavily deforming meshes increase preparation and simulation cost. Collision preparation is batched, although a single very large mesh can still take time to build. Snow starts when its collision sources are ready.

## Preview and performance

Run `examples/snow/preview.tscn` with F6 for a standalone scene with a reversed-facing roof, a wall and raised geometry. Right mouse/WASD/Q/E move its camera. This example contains no original game assets and does not modify the docks.

The initial default is 1,000 flakes. A local synthetic fixture with 20,402 floor triangles measured approximately 1.5ms, 3.7ms and 7.4ms at the 95th percentile for 1,000, 2,500 and 5,000 flakes respectively. These are CPU simulation measurements, **not** complete game frame times or a guarantee on other hardware. Start with the default, measure your actual scene, and use fewer flakes or simpler collision sources before increasing the count.

A full docks probe found that recomputing every skin bind for every mesh was too expensive. Collision now evaluates only the bones used by its triangles. With 1,000 temporary test flakes, a bounded 2560×1440 native run measured about 59.5–59.8 FPS in its warm windows; startup and screenshot readback are excluded. This is scoped evidence, not campaign-wide performance acceptance or an automatic snow addition to that mod.

The implementation uses [two-sided concave collision](https://docs.godotengine.org/en/stable/classes/class_concavepolygonshape3d.html), [back-face ray queries](https://docs.godotengine.org/en/stable/classes/class_physicsrayqueryparameters3d.html) and a single [MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html) per volume. A top-down heightfield alone would not represent the required walls and stacked surfaces.
