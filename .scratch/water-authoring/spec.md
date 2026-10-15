# Water, frost and actor visual authoring

Status: ready-for-agent

The user confirmed this scope on14October2026 with "+" after the final shared-understanding question. Both additional water references have been reviewed. Implementation is in progress; acceptance remains subject to the checks below.

Ledger tasks: M4.05b (water/underwater), M3.13 (declaration authoring), M2.12 (part anchors/deformation), M4.14 (frost). The earlier crash investigation M2.10a remains open separately.

## Confirmed direction

Follow-up after SDK18 testing,14October: elevator-wait crash recurred with native
access violation. User requests larger visible surface-normal waves, visible
underwater caustics, actual surface ripple disturbances replacing the image
ripple effect, alpha-masked floor puddles with a refracted virtual bottom, and
a visual floor roughly below the dock entrance block at the stairs using the
same texture. The last item explicitly adds that floor to the authored scene;
the rest of the submerged scenery remains deferred. Keep native gameplay and
collision unchanged. Update player/creator documentation with validated behavior.

- Deliver reusable SDK resources and enable them first in the user's docks mod.
- Dark liquid dock water, restrained ripples, patchy frost and tiny light-responsive ice crystals on exposed stone, metal, wood and chains. Preserve the underlying materials; allow coverage masks and per-material adjustment.
- One water system owns both the surface and underwater appearance: depth color, fog, surface refraction and caustics on submerged objects. Suppress the original water-only screen distortion where the upgraded water owns presentation.
- Skip rebuilding or repairing the existing submerged scenery; modders will replace it. Keep underwater features in the reusable water system and expose the original submerged geometry for authoring. The missing underwater area is part of Loading Dock, not a separate map.
- Keep the earlier approximately60FPS/1440p target, native gameplay/collision/swimming/oxygen/audio/timing, ordinary Godot authoring, and original-content-free exports. Legacy and Legacy through Godot retain their fidelity contract.
- Preserve the user's model/textures and open editor work. Inspect and checkpoint saved mod files before applying changes; do not close the editor or overwrite unsaved work. Do not repeat fullscreen debugger probes.

## Proposed deliverable

One reusable water addon with an ordinary scene resource, editable mesh, material, bounded underwater region and presets for sheltered docks, pools and distant ocean. Several cooperating shaders/passes may implement it; the author works with one coherent water setup. Parameters include color/absorption, roughness, wave scale/speed, refraction, reflection quality, caustic strength, volume bounds and depth. Resources can be copied into and exported with a mod.

Use selected techniques from the sources listed in [research.md](research.md): custom SSR and refraction, depth absorption, filtered Gerstner/detail waves, distance-based ocean geometry, and caustic projection. The user-supplied pond article contributes contact rejection, receiver lighting and filtering ideas; Saturn Free contributes volume, wave-resource and mesh-LOD references. Neither supplies the requested SSR. Saturn Free also lacks caustics, ignores local-light illumination and conflicts with this project's metadata layer, so it is not a drop-in foundation. An FFT ocean option requires measured benefit over simpler waves and shared simulation across adjoining surfaces. Pin any adopted code/assets and retain their respective MIT, CC0 or MPL-2.0 notices; the blog's HPWater-derived code is not covered by Saturn's CC0 license. Do not combine entire competing rendering pipelines.

Reflection hits blend into probe/environment reflection when screen data is unavailable. The bounded SSR trace, refraction rejection and edge fade must avoid black holes and foreground smearing. The default emphasizes stable motion. Reflection of off-screen moving objects is outside SSR's capabilities; accurate planar captures are a possible later quality option, not a promised default.

Nearby surfaces use detailed shading. Distant ocean reduces geometry density and fades expensive features. Ocean support must account for the current250m camera range through an explicit scene configuration, never a global silent camera change. Separate water regions can have different heights and materials. Intersecting or stacked transparent layers need an explicit supported composition path or an editor diagnostic; a single screen copy does not establish correct layered refraction.

Underwater caustics must illuminate visible submerged receiving surfaces even when the camera faces away from the water plane. A surface-only caustic trick fails this requirement. Prototype a bounded spatial receiver pass against a small number of shadowed light projectors and retain the approach that meets occlusion and performance requirements with the actual dock lights. The receiver candidate reconstructs opaque position/normal and uses LIGHT_VERTEX plus light() attenuation; local-light selection and shadow correctness are unvalidated until the prototype passes. Caustics must not glow on dry surfaces, through opaque barriers, across unrelated water regions or without an illuminating source. This is an approximation of refracted light, not a photon simulation. Fog and surface transmission share the same water bounds and color parameters. Native water physics and oxygen remain unchanged.

Wave animation and effects use a documented native-time source in-game, with pause and scene/camera-reset handling. Offline editor previews have their own preview clock. Water-plane and frost-exposure calculations use the authored local basis, respecting the existing editor/runtime coordinate conversion.

## Missing editor objects and native motion

Prepared content currently lists only static map declarations. Add source-backed actor declarations alongside them, including provider, source identity, model roles, original part indices, resolvable preview pose and activation/placement status. Parse known constructor semantics; do not guess that every constructor's `-m` means a model.

Open Map automatically includes these previews in the normal Scene tree. Water, chains, submerged scenery and cart must be visible without a running game or a special elevator button. Loading Dock retains its gameplay/cinematic map rows; its submerged scenery appears inside the opened scene with a readable name and original model ID6d46. Do not invent a separate underwater stage. Conditional objects remain clearly identified as conditional previews, not claims that every script branch runs at once. Unsupported placement remains visible with a reason. Asset presence alone is insufficient to invent placement.

The user can hide originals, assign materials, replace meshes, and parent custom visuals/lights beneath part anchors. Preserve authored visibility separately from native availability. Regenerate original previews locally; save sparse edits, source references, binding data and custom assets only. Existing mod work must survive reopening and reimport when provenance still matches.

Runtime bindings resolve declarations and explicit model roles, not matching model names or nearest geometry. Preserve session/epoch/generation and explicit ambiguity handling. Populate part anchors from the same final native part poses already used to render original meshes. A hidden original must not disable its anchor or gameplay. The dock cart's railing shares its verified body movement; no invented railing animation or elevator events.

Native vertex deformation is a separate requirement. The chains are modified by ShakeModel in the original shared model definition; transforms alone cannot convey this. Publish versioned changed vertex data, or a source-backed deformation provider, without recopying every unchanged model each frame. Original and replacement geometry need explicit handling: preserve native original deformation, and expose/document a deformation mapping for replacements rather than guessing vertex correspondence. Custom water can intentionally replace native water deformation within the upgraded mod.

Verified docks declarations include6d44 water,6d45 chains,6d46 submerged geometry and6da3 elevator cart. Do not apply water to all6d46 or remove it wholesale: inspect its actual part/material roles first. Include gameplay and the opening cinematic through their distinct verified source identities so the upgrade does not disappear or reveal the map early across the transition.

## Frost

Provide a reusable PBR frost layer preserving albedo, normal, roughness and metal identity underneath. Coverage combines an author mask, exposure/slope and coarse breakup; masked materials can opt out. Crystals respond to light and view direction. Filter or fade crystals smaller than a pixel into broader roughness so camera movement does not bring back the reported shimmer. Support native reference materials and ordinary custom GLB materials. Environmental frost must not automatically coat characters, UI or underwater surfaces.

## Delivery sequence and acceptance

1. **Authoring and motion:** expose verified declarations; prove open/edit/save/reopen/export with original previews excluded; prove conditional availability, duplicate message names, part offsets and actual native chain deformation. Use focused fixtures and a bounded real-disc check after native changes. No automated elevator encounter completion.
2. **Water prototype:** capture a small pool above/below water, opaque occluders, nearby moving objects, screen edges, separate water heights and distant ocean. Compare caustic receiver options and measure GPU cost before choosing the final implementation.
3. **Docks integration:** preserve the user's remastered content, target water geometry precisely, integrate native splashes/ripples and water-only screen-effect suppression, validate the opening cinematic and underwater first-person water effects. Do not rebuild or repair submerged scenery. Preserve HUD/O2/FPS overlay and keep loading progress outside the game.
4. **Frost:** inspect still and moving-camera views on stone/metal/wood/chains. Compare glint stability and material readability with frost disabled.
5. **Package and prove reuse:** deliver pool/ocean examples, editable docks resources, documentation, attribution/pins and a new launcher/SDK artifact. Reopen an exported mod outside the source workspace. Measure warm steady-state frame times and startup separately at1440p on the existing reference machine; report editor-open contention separately. Human visual acceptance remains distinct from automated validation.

No performance or appearance acceptance is claimed by this design document. The original crash remains unproven; keep the validated crash-dump instrumentation active and retain matching symbols.


## SDK19 follow-up delivery

The later request explicitly adds a visual basin floor below the entrance stairs to the previously deferred scenery scope. SDK19 and docks-water-frost-2.zip implement the broader waves, native/authored surface rings, lit underwater caustics, four masked shallow puddles with a virtual refracted stone bottom, and matching basin floor. Native collision remains unchanged. Player and creator guides are included. Focused tests, native boot and fresh ZIP reopen/captures pass; final appearance and the human elevator wait remain pending. See the current handoff in docs/GODOT_SDK_PROGRESS.md for hashes, evidence, limitations and next action.
