# Startup presentation, font fidelity and current docks performance

Status: implemented and delivered in SDK22; human acceptance pending
Date: 2026-10-14

## Requested scope

- Show RE:INTEGRAL branding and overall progress during initial startup asset checks.
- Repair flickering black squares on submarine screens in the pre-menu cinematic.
- Improve font quality while retaining original lettering, wording and layout; investigate relevant fork fixes.
- Reduce shimmering from texture/material detail inside surfaces.
- Diagnose and fix frame drops with the exact current Downloads/docks.zip.
- Correct original UI alignment, particularly CALL/PUSH SELECT and Codec MEMORY.

## Decisions confirmed

Q1: Startup presentation ends before the opening cinematic. Later in-game transitions remain free of loading UI. Existing game/debug overlays are unchanged.

Later steering, 14 October: the loading-emblem decision in `../transparency-loading-audio/spec.md` supersedes Q1's restriction for the game window. The user approved a delayed lower-right pulse of the integral emblem during black startup and subsequent loading screens, with no text/progress bar. This is a new planned change, not part of SDK22/23 acceptance.

Q2: High-quality fonts become the full Godot renderer default with the original pixel font available. Both faithful Legacy modes retain their appearance. Preserve original typography, wording and layout.

Q3: User approved the complete scope, including the fork's smoothed MGS-style block lettering and closely matching dialogue font with original spacing.

Q4: Verify and integrate applicable smoke-script crash fixes and audio-decoding correction with focused tests. Larger gameplay changes stay separate.

## Investigation, not acceptance

The latest ZIP is558865508bytes, SHA256650e369183a9b915e8834b5ebcd01bb39642dbe7fb7bfcb0d9e71a4b5cb672ec. Installed files match. Both authored docks scenes now contain a default1000-flake snow volume. Existing SDK20 temporary-snow warm-window results do not establish performance for this exact package.

Latest user run ended normally at15245frames. Startup logs show923ms project preparation,73557ms import and10308ms renderer startup. These are timings, not established causes of gameplay drops.

Investigate fork ImperishableNEET/mgs1-reintegrated for sharp text and relevant fixes; verify code, license, applicability and test evidence before integration. Do not bulk merge unrelated gameplay changes.

## Validation required

- Startup captures show branding/progress before expensive work and removal before cinematic presentation, with no later loading UI.
- Native/reference comparisons for original text coordinates and advances; high-resolution rendering and original-font option, including scaled windows.
- Actual submarine-screen reproduction and targeted alpha/blend regression.
- Moving-camera comparisons for texture/specular shimmer without changing authored material parameters indiscriminately.
- Exact-ZIP1440p baseline and changed run, reporting warm-frame percentiles separately from startup/import/capture stalls.
- Relevant regression suites, scoped Aislop, updated documentation and an audited test build.

## Current next action

Delivered SDK22 and separately named docks-performance-fixed.zip. Startup, submarine live textures, sharper fonts/pixel option, native label alignment, material filtering and verified fork smoke/XA fixes pass scoped checks. Exact1000flake cinematic improves56.64/57.84→59.07/59.40FPS; frames over20ms45/50→2/2. Output2560x1421, with occasional hitches, so this does not establish strict fullscreen1440p/locked60 or campaign acceptance.

See docs/GODOT_SDK_PROGRESS.md Current handoff for complete artifacts, hashes, test evidence and limitations. Fresh packaged launcher install/import/reimport/600frame real-disc boot and1325file audit pass. Original ZIP/settings/scenes/assets preserved; source snow helpers backed up. No owned process or unfinished production edit remains. Next: user tests the new build/mod; investigate any new feedback with matching logs.
