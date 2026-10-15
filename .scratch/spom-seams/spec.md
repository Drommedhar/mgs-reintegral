# SPOM joined-surface gaps

Status: shared-profile wall example accepted as good enough; container regression corrected in SDK32, human retest pending
Ledger: M4.05k (rejected), M4.05l, M4.05m

## Corrected visual contract

The user rejected both flattening and retaining border pixels to conceal gaps.
An exposed hard edge must retain its actual relief silhouette. Connected edges
must retain the shaped cut too: their displaced boundary shapes meet along a
shared relief profile. Equal material height settings or some retained depth
elsewhere do not establish this requirement.

Confirmed answers from the grill-with-docs session:

- When neighboring edge heights disagree, adjust both locally to a shared
  profile, preserving its variation and each surface away from the join.
- At a 90-degree corner, retain the sharp angle while its visible outline
  follows the shared relief profile. Do not introduce a bevel to conceal a gap.

Continue to preserve Height5, source textures/height maps and native collision.
Physical matching must cover only the neighboring segment; the remaining part
of a partially connected edge remains exposed. The implementation uses a derived
visual mesh; its validation and authoring constraints are recorded below.

Acceptance must exercise different height profiles/materials and texture scales,
with an exposed edge, a partial join, a coplanar join and sharp convex/concave
corners. Verify varying cut outlines and coincident displaced boundary positions
from multiple views; also check that the unaffected interiors retain their
detail. A blank strip, an unchanged straight outline, suppressed clipping,
zero background pixels alone, or a nonzero depth probe alone cannot pass.

Audit of the rejected SDK29/30 implementation: the baker discards neighbor identity after finding
overlap; its atlas stores binary connection flags. The shader samples only its
own clamped height and bypasses UV/curvature discard near connected borders.
It cannot enforce a shared relief profile. The prior fixtures primarily count
background pixels and use identical materials in their synthetic joins.

The design tree is in `map.md`. The user confirmed this contract with `+`
under the explicitly invoked grilling workflow. The subsequent prototype and
profile/position regressions established the implementation described below.

## SDK31 implementation and validation

SDK32 follow-up: the user accepted the wall example, then identified a stretched
return on mesh_057 + mesh_060. Nearly collapsed UVs inflated the physical height;
treating the thin return as an independent relief face compounded the distortion.
The baker and shader now bound pathological UV scale. Thin returns continue the
direction and scale of a nearby well-mapped face on the same connected surface.
The source and installed container renders no longer show the stretched band.
Mesh065's geometry is exactly unchanged; Height5, shared/exposed profiles, all
authored inputs, UVs and shading normals are preserved. Five additional CPU
regressions and a GPU depth check cover the failure, including rotated UVs and
disconnected-neighbor exclusion. The earlier shared-profile/wall checks still
pass. SDK32 and the corrected docks mod are installed; human retest is pending.
Evidence: `build/evidence/spom-container-profile/delivery-verified.json`.

Derived boundary geometry now carries the actual shared/exposed relief curves.
Both sides sample one physical profile, with local transition bands and unchanged
interiors; residual SPOM supplies the remaining relief. Hard normal creases remain
sharp. Partial joins, T-junctions, duplicated vertices and differing texture scales
are covered. Binary connection masks are removed. Baked materials use geometric
outlines instead of the interior-perforating curvature heuristic; unbaked materials
retain ordinary SPOM. Height5 and the authored inputs/native collision are preserved.

The source mod uses dock_remastered_relief.glb and205baked materials. Bake metadata
disables mesh compression and independent automatic LODs during import. Changing
height, UVs or layout requires rebaking. The compact derived mesh has1,327,881vertices
and1,677,416triangles; this adds geometry/loading cost.

Six profile CPU tests and six topology tests pass. Seven multi-view GPU contour/join
measurements stay within0.55–1.54pixels of independently computed profiles. Generic
SPOM regression, actual mesh065/corridor joins, source/installed stage reopens, import
flags, source-input hashes, exports and SDK archive audits pass. The2500-frame
capture-free intro exits0; steady1280x720windows average59.90–59.95FPS, with isolated
spikes and no additional audio starvation in those windows. Human appearance and
full-resolution acceptance remain open. Evidence: build/evidence/spom-shared-profile/.

Current docks.zip is623109258bytes, SHA256
fc48bfb0743fed6cbf8fabbd1080899853de75e0dc6f62d4878cfd3abcca5c51.
SDK31 is217731178bytes, SHA256
f9ca42d8356319f937d6975346bfb043aba5f53a0db8ca137fa247b1077c2f7a.
Previous packages are archived; settings changed only the selected docks hash.
Automatic approval review blocked verified temporary SDK31 cleanup with only
“blocked by policy”; files remain and deletion must not be retried.

## Rejected SDK29/30 implementation and limited evidence

The records below describe the rejected implementation. Its passing checks
establish coverage closure only; they do not establish the requested silhouettes.

User identified mesh_065 in the failing corridor screenshot. Its actual UV
borders are inset (.0078125–.9765625, .00390625–.98828125); SDK29 matched all
physical edges but discarded side connections that were not within .005 of0/1.
The baker now classifies sides against each island's actual UV bounds. Actual
source GPU regression: panel joins1472→0, six corridor joins3674→0. Six CPU
tests include the inset layout and preserve unmatched sides. Generated GLB,
shader,205materials and heights are unchanged; only the connection atlas changes
inside the mod ZIP. Depth/exposed/partial-edge GPU checks remain passing.
Evidence: build/evidence/spom-wall-panels/.
Fresh installed imports, both stage reopens and actual panel/corridor GPU checks
pass. SDK30 archive and the single-file mod change are audited; prior SDK/mod
archives and settings are preserved. Distant interior curvature-clipping pinholes
remain separate from the repaired panel joins. Temporary cleanup was rejected
by automatic approval review; files remain under task evidence.

SDK29 validation: five topology tests cover partial/distant/crossing edges, UV
reuse, internal diagonals and same-island wraparound. Source/installed/packaged
GPU checks close straight351→0 and corner780→0join pixels, retain630exposed cut
pixels and276depth-probe pixels. SDK28 fails7new assertions. Source/installed
docks views retain open cuts while reducing backdrop gaps. Both scene reopens,
lossless data-atlas import and exact geometry/material/archive audits pass.
Updated docks is installed/selected and SDK29 published; backups/settings and
export history are recorded in the ledger. No game/performance acceptance claim.

## Rejected SDK28 approach and historical evidence

The user's height5/silhouette preview opens bright gaps between dock surfaces.
Keep Height Scale5 and both material silhouette flags. Protect shared clamped UV
borders by blending the height field to its reference plane near the border,
including the light trace. Preserve coverage when coarse refinement overshoots
that border and keep curved clipping out of the protected band. Expose width;
zero restores unrestricted silhouette clipping, repeating UV behavior unchanged.

This closes clipping gaps; it does not make independently authored textures or
displacement continuous across arbitrary UV seams. Borders become flat, while
interior relief keeps the requested scale. Test the actual production shader on
touching surfaces and the authored docks scene. Preserve all material values,
textures, scene geometry and settings; back up the package before updating it.

Evidence: build/evidence/spom-seams/. Minimal joined-quads test is red with351
background pixels; UV clipping off gives0, depth/curvature toggles retain351.
Shader fix gives0 and the existing SPOM suite passes. Authored docks scene
fixture986→0background gap pixels; source/installed/packaged seam tests pass.
Only2mod shader files changed; all205Height5/both-silhouette materials preserved.
Fresh imports, both scene save/reopens, source/ZIP audits and SDK28 package checks
pass. Updated docks installed/selected, prior package and SDK27 archived. No
gameplay/performance capture or new performance acceptance claim. Verified SDK28
staging deletion was blocked by automatic approval review and retained.
