# Water, frost and original actor visuals

Development resources live in `renderers/godot/project/addons/mgs_water`. Copy that folder into your mod before referencing its scenes or materials; its internal dependencies use relative paths. Export ZIP rejects dependencies outside the mod and excludes locally regenerated original previews.

Open `examples/water_frost/preview.tscn` and run that scene for a pool, a separate raised pool, a shallow puddle and a distant ocean. Hold right mouse to look, WASD to move, Q/E to descend/ascend and Shift to move faster. Click left mouse on the pool or puddle to create a surface ripple. These controls belong only to the standalone example.

## Authoring water

Instance `water_region.tscn`, `pool.tscn` or `ocean.tscn` through Godot's normal Scene tree. The region origin is the waterline, local Y points up, and `volume_size` extends downward. Rotate the region with the scene; calculations use its local basis. Visual water never changes native collision, swimming, oxygen or audio.

Select the **water region root** for grouped Inspector controls. Waves exposes height, size (wavelength) and speed; Surface exposes roughness and refraction amount; Reflections exposes steps, distances, thickness and fallback color. Caustics exposes strength, size, speed and color. Coverage and Virtual Bottom expose puddle masking and refracted-floor settings. The Surface and Caustics children remain ordinary meshes with ShaderMaterials. Root settings override the corresponding child material values; leave a setting untouched to retain its existing preset or authored value.

Wave and caustic speed are independent multipliers: 0 freezes that motion, 1 uses the preset's normal rate, and 2 doubles it. Caustic size is a spatial scale in metres: increasing it makes the pattern larger. It is the inverse of the advanced material's `pattern_scale` frequency. Root edits are per region and survive scene save, reopen and ZIP export. Native pause freezes both motions regardless of their speed multipliers.

The general surface starts at 0.08m wave height and 3.2m wavelength; the puddle preset uses smaller waves. Disable `size_plane_from_volume` to author another mesh. Raising root wave height expands its culling bounds automatically; increase `displacement_bounds` further for unusually strong scripted ripples. Volume dimensions, absorption and water color are shared with fog. Disable caustics for distant water.

The pool preset has bounded underwater fog and caustics. The distant ocean preset reduces reflection work, disables these near-water passes and explicitly requests an1800m presentation view distance through its ViewDistance node. Removing that node restores the ordinary250m limit when no other mod requests a longer range. This expands presentation range only; it does not stream native gameplay or invent distant scenery. The broad ocean mesh is intended for the horizon; use smaller adjoining regions for close views.

Reflections ray-march the opaque depth buffer and fade into Godot environment/probe reflections and an authored fallback color at screen edges or missed hits. Refraction rejects foreground samples. Absorption clips the ray to the authored water bounds. Underwater fog uses the same bounds and two transmission/scattering passes. Caustics reconstruct opaque receiving surfaces, so they remain visible when a submerged camera looks away from the water surface. They use actual directional/Omni/Spot light attenuation and shadows. This approximates focused light; it is not a photon simulation.

Screen copies exclude transparent objects. One screen-refracting water layer per view ray is supported; overlapping or stacked bounds produce an editor warning. Keep separate heights spatially separated. Puddles with a virtual bottom do not sample deeper water for their bottom and are exempt from this warning. Accurate off-screen moving reflections require a separate planar capture and are outside this version. Water color/absorption should remain modest when another scene Environment already supplies heavy fog.

Caustics require an opaque receiver inside the volume and a light whose range reaches it. Shadows still block the light. Raising caustic strength cannot illuminate a floor outside every lamp's range. The updated docks mod extends nine existing basin lamps, adds a stone floor at Y=-4.45m and increases caustic strength; it adds no new light sources. The floor is visual only and uses the mod's existing stone texture.

## Surface ripples and shallow puddles

SDK19 routes the native water actor's expanding rings into upgraded water surfaces. Their position, radius, fade and lifetime come from the native actor; the matching original sprite rings are suppressed only when a visible region accepts them. Other splashes and bubbles remain. Ripples displace the surface and change its normals, reflection and refraction. Regions without the new helper retain the original effect.

Scripts can call `water.add_ripple(world_position, strength, width, speed)`, for example `water.add_ripple(hit_position, 0.08, 0.3, 2.2)`. The point must be within the region and near its waterline. The method returns whether it accepted the disturbance. Distances are in region-local metres; native motion is converted into the region basis. Up to16 disturbances are rendered per region. Authored disturbances expire after four seconds; native pause freezes the water clock, and a native scene/session reset clears disturbances. This is a bounded visual wave model, not a fluid or collision simulation.

Instance `puddle.tscn` for shallow water that does not need geometry below it. Its Surface material enables `virtual_bottom_enabled`: assign `bottom_texture`, `bottom_color`, `bottom_depth` and `bottom_tile_size`. The shader refracts a textured local plane below the water and lights that bottom with the scene. Underwater fog and caustics are disabled for this preset.

For a floor with alpha-cutout holes, enable `use_coverage_mask`, assign its texture to `coverage_mask` and enable `invert_coverage_mask`. Opaque floor pixels exclude water; transparent pixels show it. Match the water mesh's UVs to that floor. The optional `puddle_mesh.gd` script on Surface copies the footprint and UVs of a horizontal source MeshInstance3D surface: set `source_mesh` and `surface_index`, place the puddle just below the floor and size its bounds to enclose the footprint. It rebuilds local preview geometry instead of saving a duplicate mesh. The source must be available when the scene opens; the docks example references the mod's custom GLB. This helper is for flat cutouts, not skinned or sloping surfaces. Edit its source path/index in the Inspector to rebuild after replacing a source.

Runtime waves/caustics use native actor-loop ticks and `passage_ticks` at60000/1001 ticks per second. Duplicate snapshots do not advance time; native pause freezes it; session/scene epoch changes reset it. Offline previews use a separate clock. Enable `animate_preview` to animate an editor scene. Native timing remains authoritative.

Protocol15.32 annotates the original WaterView distortion/tint draws. The renderer suppresses only those draws when the current camera is inside a visible, available upgraded region with underwater appearance enabled. HUD, oxygen, other effects and the FPS overlay remain. Legacy and Legacy through Godot retain original water draws.

## Frost

Add `frost.tres` as a material's Next Pass, or attach `frost_layer.gd` to an ordinary Node3D and fill its explicit target NodePaths. The helper layers only those environmental meshes and their descendants; it does not search the whole scene or coat characters. Original resources are duplicated locally and restored when the helper leaves the tree.

Coverage combines a UV coverage mask, coarse breakup and surface exposure. A black mask excludes frost. Set the submerged height in the exposure basis to keep liquid-water surfaces clear. For original model materials, `exposure_in_model_space` and an up vector of `(0,-1,0)` follow the prepared model's basis through editor/runtime conversion. For custom scenes the helper uses its own global Y basis. Small facets respond to lighting, and subpixel facets fade into broader roughness. The helper carries StandardMaterial normal maps into the thin frost layer; the underlying albedo, normal, roughness and metal remain on the original pass.

## Original objects and native motion

Open Loading Dock to see Water6d44, Chains6d45, Submerged scenery6d46 and the conditional Elevator cart6da3. The submerged area belongs to this location; it is not a separately selectable stage. These previews come from prepared disc declarations without requiring a running game.

Use normal visibility/material controls and parent custom content under the part anchors. Saving retains declaration targets and sparse edits; original meshes/textures regenerate locally. A conditional preview does not imply the native actor is currently active. Targets include script digest, command offset and provider. `alternate_targets` explicitly lists declarations for an inherited scene running in another stage; matching a model or message name alone is insufficient.

Protocol15.32 includes changed native vertex deltas for original ShakeModel deformation. Chains retain this motion in addition to part transforms. Arbitrary replacement meshes do not inherit guessed vertex correspondence. A replacement can opt in using `mgs_native_deformation=true` and UV2 coordinates mapping each replacement vertex to its original face corner, as documented in [the protocol](GODOT_PROTOCOL.md).

## Sources and validation scope

These shaders are original implementations; no third-party shader source is bundled. Research included [marcelb's MIT SSR water](https://github.com/marcelb/GodotSSRWater), [realistic-water](https://github.com/godot-extended-libraries/godot-realistic-water), [Boujie water](https://github.com/Chrisknyfe/boujie_water_shader), [Saturn's pond articles](https://atsaturn-dev.github.io/blog_posts/index.html) and [Saturn Water](https://oddpotatodev.itch.io/godot-water). Pinned source revisions, license boundaries and the public Free0.1.0 archive audit are recorded in `.scratch/water-authoring/research.md`. Saturn Free has no SSR/caustics and its layer/light assumptions differ from this renderer; its entire pipeline was not imported. HPWater-derived code has a separate MPL2.0 license.

Focused GPU fixtures cover SSR contribution, underwater fog, native-clock pause/reset, caustic light/shadow/bounds behavior, frost masks/exclusion, water-only draw ownership and virtual-bottom ripple refraction. Native ripple routing and puddle footprint/UV/save behavior have separate checks. These establish specific behavior, not full campaign performance or human visual acceptance. SDK19 also guards the native indirect-shading path reproduced from the elevator crash dump; human elevator retesting remains pending.

Audited revisions: GodotSSRWater `391b2f9f9fc289c8ef0ccc2889cf53b5d3cfdaec`, realistic-water branch4 `fa0fc4785a009e99db96015cb8512d232565aae1`, Boujie `25f3c2da458e0a4f65bdb5903dc068b050930c06`. The public Saturn Free0.1.0 archive SHA256 is `a6c3a74393b108b14d568c94e44ac4f6a46a93fc693314d98c598f8067ed2f28`; the pond article was audited as published9October2026. No Pro package was purchased or redistributed.

Native and scripted surface ripples ease in over 0.12 seconds of water time.
Pausing freezes the onset along with wave motion. A newly emitted concentric
ring gets its own onset; an expired ring does not leave a persistent disturbance.
