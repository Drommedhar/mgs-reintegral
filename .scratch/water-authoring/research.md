# Water and actor authoring research

Inspected14October2026. Read-only source and primary-source research; no shader integration or runtime validation performed in this slice.

## Shader sources

| Source and verified MIT license | Revision inspected | Techniques worth adapting |
| --- | --- | --- |
| [GodotSSRWater](https://github.com/marcelb/GodotSSRWater), [license](https://github.com/marcelb/GodotSSRWater/blob/391b2f9f9fc289c8ef0ccc2889cf53b5d3cfdaec/LICENSE.md) | `391b2f9f9fc289c8ef0ccc2889cf53b5d3cfdaec` | Custom SSR, refracted screen color, depth reconstruction and edge fade. Targets4.3+, upstream tested4.4.1. Needs underwater/caustics and reflection fallback integration. |
| [Godot realistic-water branch4](https://github.com/godot-extended-libraries/godot-realistic-water/tree/4), [license](https://github.com/godot-extended-libraries/godot-realistic-water/blob/fa0fc4785a009e99db96015cb8512d232565aae1/LICENSE.md) | `fa0fc4785a009e99db96015cb8512d232565aae1` | Gerstner waves, normal layers, absorption, foam and caustics. Its surface shader applies caustics to transmitted screen color with back-face culling; this does not establish underwater-camera receiving-surface caustics. |
| [Boujie Water Shader](https://github.com/Chrisknyfe/boujie_water_shader), [addon license](https://github.com/Chrisknyfe/boujie_water_shader/blob/25f3c2da458e0a4f65bdb5903dc068b050930c06/addons/boujie_water_shader/LICENSE.md) | `25f3c2da458e0a4f65bdb5903dc068b050930c06` | Camera-following snapped ocean meshes, horizon geometry, world-position waves, distance fading and two-sided treatment. Upstream4.1.1 validation is not proof for this project's4.8dev7. |

Recommendation: one maintained addon with shared water parameters and compatible passes, rather than stacking full third-party shaders. No external source has yet been vendored. Pin adopted revisions/assets in the reproducible source inventory and retain notices before distribution.

## Additional references requested by the user

[Building the pond: waves, light, and the waterline](https://atsaturn-dev.github.io/blog_posts/index.html), Eduardo,9October2026: useful techniques include filtering wave detail into roughness, shared animation time, guarded refraction, shadow-aware receiver caustics and bounded water optics. It explicitly omits SSR and a full underwater-camera mode. Its receiver/volume captures and ripple processing have no published benchmark. Treat these as prototype references, not an integrated solution. The article identifies an HPWater port at `1253e5b10801db791fc0768a95214228870332bd`; preserve the separate [MPL-2.0 license](https://github.com/AshenOneArt/HPWater/blob/1253e5b10801db791fc0768a95214228870332bd/LICENSE) for adapted code. This is a different pipeline from Saturn's FFT addon. Local article evidence: `build/godot-sdk-m0/water-research/saturn-blog.html`, SHA256 `889925580b5d88dbd6d0a36cf7c30f482b5ea1e3a7ceafff4d0bd8e50cc220e8`.

[Saturn Water](https://oddpotatodev.itch.io/godot-water) is the current name of the second reference. Its page describes a Forward+ prototype developed on4.8.dev6, shared water resources and FFT waves; caustics and distant horizon are Pro features. It discloses fog/foam issues and expensive close-water views. Only the publicly available Free0.1.0 source was downloaded; Pro was not purchased or inspected.

The Free archive's61 manifest hashes verify. ZIP SHA256: `a6c3a74393b108b14d568c94e44ac4f6a46a93fc693314d98c598f8067ed2f28`. Its LICENSE dedicates author-owned material to CC0; this does not cover the separate blog/HPWater code. Source paths below are relative to the ignored extraction `build/godot-sdk-m0/water-research/saturn-water-free0.1.0/addons/saturn_water/`.

| Verified Free source behavior | Integration consequence |
| --- | --- |
| `rendering/water_trace.gdshaderinc:266` / `water_optics.gdshaderinc:84`: panorama/fallback reflection, no reflected scene-depth trace | SSR still needs implementation. |
| `rendering/surface.gdshader:70` / `volume.gdshader:46`: directional lights only | Native dock Omni/Spot lamps do not directly light this water. |
| `rendering/water_trace.gdshaderinc:257`: zero caustics; Pro generator absent | No Free caustic implementation to integrate. |
| `rendering/shaft_shadow.gd:5` / `water_body_3d.gd:169,636`: layer1<<19 | Collides with this project's metadata layer, excluded by the gameplay camera. |
| `simulation/gpu_fft_wave_field.gd:54,68`: six compute passes, sync/readback; `water_body_3d.gd:381`: mip generation/upload | Share any adopted wave simulation across surfaces and measure total cost. |
| `rendering/water_trace.gdshaderinc:108`:20–96 height samples/pixel; `shaft_shadow.gd`:512x512 scene capture per shadowed-sun body | FFT resolution alone does not predict rendering cost. |

The complete local source audit is `build/godot-sdk-m0/water-research/saturn-free-source-audit.md`. Recommendation: borrow volume bounds, resource sharing, mesh LOD and filtering ideas selectively. Do not adopt either whole pipeline as the SDK foundation. No visual/performance acceptance is inferred from source inspection.

## Rendering constraints and design inferences

Godot captures screen color after opaque rendering and before transparent rendering. Refraction therefore omits transparent objects and other screen-reading surfaces. A second water layer cannot rely on that copy containing the first. [Godot screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)

SSR cannot recover off-screen or hidden geometry. Trace misses need another reflection source, and higher ray budgets cost more. Proposal: bounded near-water SSR with a local probe/environment fallback, faded down for distant water. [Godot SSR](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#screen-space-reflections-ssr)

Reconstruct positions with inverse projection/view matrices and compare linear depth. Old shader formulas must be audited for reverse-Z, introduced in4.3. [Godot reverse-Z explanation](https://godotengine.org/article/introducing-reverse-z/), [depth reconstruction](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html#depth-texture)

Underwater receiver caustics are a separate implementation problem from surface refraction. Proposed candidates are a bounded depth/receiver pass or selected animated light projectors. Godot light projectors require shadows enabled, so adding them to every dock light would be costly. Prototype occlusion, masks, lighting and GPU cost before choosing. [Light3D projector](https://docs.godotengine.org/en/stable/classes/class_light3d.html#class-light3d-property-light-projector)

For the receiver candidate, reconstruct opaque position/normal, clip outside-water/dry pixels, and test a spatial shader using LIGHT_VERTEX with per-light ATTENUATION. The API exposes shadow-aware attenuation, but correct local-light selection at reconstructed positions remains a prototype requirement. This could avoid replacing arbitrary imported GLB materials; it is an inference, not a validated implementation. [Godot spatial shader API](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)

Specular crystal detail needs filtering at the pixel footprint. Proposal: sparse light-responsive glints that blend into roughness when too small, rather than random bright pixels. Preserve existing temporal AA and use motion captures as acceptance evidence. [Godot antialiasing and roughness filtering](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html), [Zirr and Kaplanyan, Procedural Multiscale Materials](https://research.nvidia.com/publication/2016-02_real-time-rendering-procedural-multiscale-materials)

## Repository evidence

- `tools/prepare_godot_assets.py:94` / `tools/godot_assets/maps.py`: startup map/mapdef assembly only. s00a static models are c661 and6da4.
- `renderers/godot/project/addons/mgs_editor/disc_map.gd:36`: editor instantiates only layout.models. Converted actor assets are consequently missing from the contextual scene.
- `addons/mgs_editor/native_authoring.gd`: hard-coded elevator asset/hash, target and five preview parts; plugin exposes a special elevator button. `native_actor_target.gd` and `src/mgs_godot_actors.c` accept only provider2abc.
- `native_actor_binding.gd:54`: one body pose drives the binding. `scene_view.gd:403` already receives native final part matrices, but authored part nodes do not consume them.
- `src/mgs_godot_scene.c:359`: matrices, visibility, material palettes; no mutated model vertices. `vendor/mgs/source/takabe/shakemdl.c:252` changes vertices in place.
- `model_edits.gd` / `reference_materials.gd`: original-reference model material overrides can already carry ShaderMaterial. The missing contextual actor authoring must reuse this capability.
- `map_coordinates.gd`: authoring Y-up becomes renderer `(x,-y,-z)`. Hardcoded world+Y water/frost calculations would disagree between editor and runtime. Use the authored surface basis.
- `scene_view.gd`: FSR2 at scale1.0 and camera far250m. Project mip bias0.5/sharpness0.8 are inherited user-facing rendering work; preserve them. Ocean range needs explicit configuration.
- `runtime.gd`: world/metadata/background viewports and existing depth/vision compositor effects require deliberate pass ordering. Water-only native distortion must be suppressed selectively, leaving UI/vision/other effects intact.

## Disc-backed docks ownership

Source: local `s00a/ea54.g`, SHA256 `40e6084b4cbf0c38660c3044238613ad2d7b24442aa2677530df49ef71ac66c8`. Original files remain local; no retail data is embedded here.

| Model | Provider / message name / byte offset | Evidence |
| --- | --- | --- |
|6d44|ec77 / d14a /16768|Water plane, renderer Y1.5, two extended parts, zero placement/rotation.|
|6d45|ec77 / c056 /16811|Chains: chain-link texture0a38 and narrow vertical geometry; zero placement/rotation.|
|6d46|ec77 / c056 /16854|Five extended parts of submerged walls/props/lamps, renderer Y≈1.499–4.5. Not uniformly water.|
|6da3|2abc / b15b /5981, conditional procedure053d|Elevator cart, five parts; known endpoints and shared railing motion. No optional secondary model in this declaration.|

Two distinct declarations share message namec056, so names cannot identify targets alone. Constructor semantics establish provider ec77 as NewWallGcl; the elevator's existing declaration evidence is in `docs/GODOT_NATIVE_BINDING_NOTES.md`.

Separate ShakeModel declarations at16897/16928/16959 deform6d44/6d45/6d46 along Y/X/Y, with amplitudes100/70/50 native units. Camera-water callback1592 stops/restores the two water-related shakes but leaves the chain shake running. This proves a deformation-data gap, not a diagnosis of the earlier screenshot or crash. Exact submerged-part optical roles still need visual classification before replacement.

## Missing underwater map clarification

The user confirmed the missing list entry means the underwater area of the docks. `scene_catalog.gd` groups Loading Dock gameplay s00a and cinematic d00a; there is no separate underwater-stage declaration. Model6d46 is actor-owned geometry in the same location, omitted from the static editor assembly. M3.13 must expose it in the normal Loading Dock Scene tree with its original identity. Do not create a fictional standalone map row.

Existing individual-model workflow, confirmed in `addons/mgs_editor/plugin.gd:126`: Assets → Original assets → Models → search6d46 → select the s00a entry → Edit model / view texture. This edits an original-reference model scene; it does not provide the missing contextual map preview. No user asset was opened or changed during this audit.

The user explicitly deferred rebuilding/repairing submerged scenery while retaining caustics and underwater support. Exposing that geometry for modders remains in scope. The prior screenshot defect is not declared fixed.
