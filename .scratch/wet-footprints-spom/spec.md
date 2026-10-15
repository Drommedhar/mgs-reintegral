# Wet footprints and SPOM assessment

Status: SDK26 implementation delivered; human footprint appearance retest pending
Date: 2026-10-15
Ledger tasks: M4.03i (footprints), M4.05g (SPOM assessment)

Restore the original wet-footprint presentation in full Godot. Keep native
eligibility, wetness, placement, handedness, fade, expiry and guard behavior
authoritative. Include player, other-actor and cinematic footprint constructors.
Preserve Legacy and unrelated subtractive/framebuffer effects. Footprint
materials remain editable/exportable through the existing Effects workflow.

Evidence: build/evidence/wet-footprints-spom/. The production-constructor CTest
fails for all three actors before registration, and still fails with generic
registration because subtractive effects are excluded. The GPU fixture fails
three appearance checks with the original effect material. Validate scoped
registration, subtractive rendering, coplanar depth, transparency, occlusion,
native fade/lifetime, authoring ZIP reopening and a capture-free real-disc boot.

Assess the user-linked SPOM shader against docks materials. Preserve the
delivered StandardMaterial3D setup while evaluating suitability; the user has
expressed interest, not requested a wholesale material replacement.

Source: https://godotshaders.com/shader/improved-spom-with-outline-detection-and-self-shadowing/

The CC0 shader adds contact refinement, self-shadowing, depth writes and
silhouette clipping. The author flags instability on mixed surfaces. Our
assessment: refinement and self-shadowing merit a separately measured material
option. UV clipping must be disabled for repeating textures. Direct adoption
would misread packed ORM (its metallic/roughness samples both use red), replace
Godot's default lighting with a custom BRDF, and equate UV displacement scale
with view-space depth. The latter needs physical texture scale validation.
Curved silhouette clipping should remain opt-in until grazing-angle and
FSR2 stability tests pass. Its shadow march also runs when the toggle is off,
and only diffuse receives its shadow factor. No production SPOM conversion
or performance benefit is claimed by this assessment.

Delivered in build/releases/current/RE-Integral-SDK-dev-26.zip. Six native
tests, source/installed Vulkan footprint checks, world-effects regression,
editable-material ZIP/reopen, fresh import and package audits pass. Native
vendor changes are pinned in mgs-godot-footprints.patch;131patches check cleanly.
Capture-free disc boots exit0 but did not emit footprints, so actual in-game
footprint visibility remains a human retest item. Current docks assets/settings
are unchanged. Full receipt and the precise validation limits are in the ledger.
