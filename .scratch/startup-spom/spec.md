# Startup status and docks SPOM

Status: delivered in SDK27; human appearance retest pending
Date: 2026-10-15
Ledger tasks: M4.05h, M8.03f

Restore the startup asset-check status to the left of the existing loading
animation. Show current phase and supplied progress, reject stale phase updates,
scale/wrap at small resolutions. Later scene transitions remain icon-only.

Adapt Amose05's improved SPOM for the existing docks textures. Preserve basecolor,
normal, AO/roughness/metallic channels and generated clean heights; convert only
the205currently enabled POM surfaces. Keep11featureless surfaces and other
materials unchanged. Preserve mod scenes, source geometry, water and settings.
Back up the current ZIP and affected materials before conversion.

Include bounded contact refinement, self-shadowing and optional silhouette
clipping/depth correction, with editable parameters. Validate channel mapping,
flat/disabled parity, shadow toggle, grazing angles, tiling/clamping, depth
scale, FSR2 stability, imports and ZIP reopening. Document any feature disabled
by default on the existing mesh. Credit the source and retain required licenses.

Source: https://godotshaders.com/shader/improved-spom-with-outline-detection-and-self-shadowing/
Evidence: build/evidence/startup-spom/.

Completed: startup text/layout regression;205SPOM material conversions preserving
all texture inputs and11flat surfaces; source and packaged Vulkan tests; fresh
installed imports and both stage save/reopens; ZIP/source preservation checks;
2500-frame capture-free intro (59.85–59.94FPS warm720pwindows); SDK27 audit and
local installation/selection. Full evidence: delivery-verified.json and ledger.
UV/curved silhouette controls are opt-in and disabled on existing docks meshes.
Human/full-resolution and moving-camera temporal acceptance remain open.
