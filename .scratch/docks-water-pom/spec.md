# Docks water follow-up and POM

Status: SDK25 fixes and clean-height mod revision delivered; human appearance retest pending
Date: 2026-10-15
Base checkpoint: 0bee28e
Ledger tasks: M4.05e, M4.05f

User requests removal of original ripple sprites over the upgraded water in the
docks intro, POM for docks materials, rejection of black screen-space water
samples where geometry is missing, and a soft fade at geometry intersections.

Preserve original gameplay and Legacy rendering. Replace native ripples only
where authored water owns their presentation; unrelated splashes and bubbles
remain. Keep water controls editable in the normal Inspector. Preserve the
user's saved scene values, custom textures, settings and unsaved editor work.
Back up any affected docks mod files before updating them.

The docks GLB has358materials and263images. Its external families contain
color, normal, ORM and some emission textures, with no height/depth maps found.
User selected generation through their running ComfyUI at192.168.178.93:8188
and authorized installation of needed models. Initial heights used existing
material normals through CHORD; the color-derived revision below supersedes them.
Verify normal-Y/height convention. Use ordinary editable StandardMaterial3D
deep parallax, restrained depth/layer counts, and preserve alpha cutouts and
emissive surfaces. Validate saved scene and export/reopen dependency handling.

Build focused failing tests for ripple ownership and GPU water sampling/fades,
then verify the production paths. Actual runtime/performance runs must have
capture disabled; separate small GPU fixtures may read their own images.
Evidence belongs in build/evidence/docks-water-pom/. Do not launch competing
probes while the user tests. No native/gameplay change is currently planned.

Reference: https://docs.godotengine.org/en/4.6/classes/class_basematerial3d.html
(heightmap_enabled, heightmap_deep_parallax, heightmap_texture).

Initial SDK25 delivery: build/releases/current/RE-Integral-SDK-dev-25.zip and docks.zip.
The mod is installed and selected. Regression/GPU tests, both exported scene
save/reopens, geometry/material equivalence and a2500-frame capture-free
installed intro pass. CHORD1.1.1 generated48active height families, used on216
opaque surfaces. Source colors/normals/ORM and saved water values are preserved.
A separate shared-texture GLB avoids duplicate texture payloads; originalGLB
remains intact. Full evidence and validation limits: M4.05e current handoff.

## User revision: clean structural heights (M4.05f)

The user rejects the normal-derived heights as too noisy and suggests color
textures as references. Replace them with clean structural height maps: flat
faces, broad relief, panel recesses and seams. Exclude grain, scratches, stains,
paint markings and illumination. Preserve basecolor/normal/ORM and material
controls; validate structure alignment and reduced interior noise before
updating the installed mod. Evidence: build/evidence/docks-clean-heights/.

Physical bolted sign plates remain raised and flat; only their printed markings
are excluded from height. Generative cleanup is checked against the source
layout, with separate masks where a single pass loses joints or plates.

Revision delivered15October:46clean structural height maps from ComfyUI color
references serve205POM surfaces. Eleven featureless surfaces have POM disabled;
their constant-white maps matched blank original pixels in the export guard, so
they are excluded without weakening that guard. All other material properties,
color/normal/ORM maps and saved scene settings are preserved.48generated maps
were reviewed; sampled flat-face noise is99.36–99.74% lower. Fresh installed
imports, both205-surface scene save/reopens, six-material Vulkan rendering and
ZIP/hash audits pass. Updated docks.zip is installed/selected; prior ZIP and
materials are backed up. SDK25 code needs no rebuild. Human appearance remains
a separate retest; no new gameplay/performance run was needed for this asset edit.
