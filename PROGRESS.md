## 2026-10-13: Godot editor ZIP dependency validation

M3.03a complete; full SDK goal remains active. Opening a ZIP now validates its static nested scene/script/material/shader/texture/glTF graph before publishing or resuming an editable workspace. Failures preserve the archive and later local edits. Source scanning ignores comments/string examples while retaining actual preloads, bases and shader includes. New dependency-only inspection accepts fresh textures without an import cache; regular export provenance checks remain intact.

Validation: dependency-python-final.log25/25 (five real Godot integration tests), dependency-{source-final,binary-regression,overlay-regression,workspace-final,provenance-regression}.log each0 failures. Scoped Aislop100/four Python files/no diagnostics; GDScript unscored. User ZIP unchanged; no native/protocol/build changes. M3.02a task tabs/location tree remains completed. Next: explicit package-relative dynamic script resource loading; constructed/threaded paths still outside static discovery. See docs/GODOT_SDK_PROGRESS.md Current work/handoff. No owned processes.

## 2026-10-13 — Godot SDK M3.11b resource provenance

Original model imports now mark mesh/skin/texture/image/font/animation resources before custom replacements are applied. Standard resource duplication and text/binary save/reopen retain export exclusion. Pixel checks catch extracted font images and lossless PNG/WebP copies after metadata loss, including embedded images in otherwise untagged resources. Custom replacements and changed textures remain supported.

Eight focused Godot suites passed, recorded in docs/GODOT_SDK_PROGRESS.md. The new original_resource_export_test covers duplicated/saved resources, original font images, untagged wrappers and custom map/model edits; export_provenance_test includes actual textures from both discs re-encoded as WebP. No native, protocol or launcher change. User ZIP unchanged. Full goal active; next audit dynamic script dependencies and ZIP reopening. Aislop has no diagnostics on these selected paths, but they remain unsupported/unscored.

## 2026-10-13 — Godot SDK M3.11a export integrity

Binary Godot resources now export as portable text dependency graphs with stable IDs, shader includes and collision-safe filenames. Export checks source/prepared hashes from both available local catalogs and rejects renamed original copies, including matching glTF/GLB embedded buffers/images. Invalid or missing provenance catalogs fail explicitly; failed exports preserve the previous ZIP. Custom external/embedded/GLB models remain supported.

Eight focused Godot suites passed: export-provenance-test-final.log and export-integrity-{binary,workspace,overlay,model,ui,codec,camera}.log under build/godot-sdk-m0. Scoped Aislop reported no diagnostics but these GDScript/docs/PowerShell paths are unsupported/unscored. User ZIP unchanged. No native/protocol/launcher changes. Full goal remains active; docs/GODOT_SDK_PROGRESS.md records the next detached/duplicated resource-provenance audit and all remaining gates.

## 2026-10-13 — Godot workspace Save / Export / Save As

- Completed M3.04 workflow and actual editor round-trip validation. Repeat Export retains destination/identity; reopening it resumes the workspace; Save As creates an independent mod and relocates custom resources. External ZIP revisions and failed provenance checks preserve the existing archive.
- Binary .res/.scn Save As uses a separate headless Godot conversion to editable .tres/.tscn resources, without changing the source. Fixed imported-directory normalization so Save sees the workspace's open scenes.
- 17 Python tests, Godot workspace roundtrip, existing map-overlay/model-authoring tests and real editor fixture pass. Aislop100 for supported Python/PowerShell; GDScript unscored. No native build or user ZIP changes.
- Full goal active. Next: M3.11 binary export dependencies/provenance; unchanged source binary resources still need recursive export inspection. Current evidence and exact handoff: docs/GODOT_SDK_PROGRESS.md.

## 2026-10-13 — Godot editor dock restructuring

- Replaced the full-height button stack with Maps, Assets, UI, Effects and Mod tabs; Maps has Browse/Test/Actors subtabs and the list expands to fill the dock.
- Maps group readable locations, then native gameplay/cinematic variants and source clips. Both prepared catalogs feed the list without a disc selector; exact source identity and direct/inherited mod status remain. UI/effects use grouped browsers with one Open action. Save/export controls moved to Mod.
- Focused scene_browser_test passes. Actual editor fixture passes with map list1029px in dock1327px; screenshots inspected. Inherited tests/fixtures template imports still report missing generated base scripts; this is not a clean whole-project import claim. Scoped Aislop has no diagnostics; GDScript unsupported/unscored.
- No native build, user ZIP change or live process remains. Full goal tool is paused; M3.04 workspace round-trip validation remains unfinished. Current handoff: docs/GODOT_SDK_PROGRESS.md.

## 2026-10-13 - Godot SDK renderer selection and inventory proof

- Completed native held-inventory repeat/release and name-alignment validation; broader UI fidelity remains open.
- Added saved launcher renderer selection and installed package descriptors, matched Legacy/Godot startup, explicit unavailable states and preserved shared settings/mod selections. Actual Legacy0.2 and Godot opening runs passed from one isolated profile; Godot loaded the user ZIP and presented990 world composites.
- Fixed fresh copied-runtime startup by moving the shared cinematic helper out of the editor addon. Launcher4/4 tests and cinematic preview pass; scoped Aislop100/no diagnostics (GDScript unsupported). No native C/protocol change, no stable60/campaign/distribution acceptance claim.
- Authoritative handoff: docs/GODOT_SDK_PROGRESS.md; package contract: docs/RENDERER_PACKAGES.md. Next: M3.04 Save/Export/Save As workspace flow. Goal active.

## 2026-10-13: requested stealth refraction correction

Default Godot camouflage now uses projected refracted rays, stronger native Snake green tint and neutral Ninja tint, with rim emission off. Foreground depth protects the filtered sample footprint. GPU checks now prove nonzero background displacement and edge occlusion at native resolution and FSR2; appearance/ZIP tests pass. Scoped disc2 s13a frozen comparison confirms floor detail is refracted through Snake. No native or UI changes. Detailed evidence and exact follow-up state are in docs/GODOT_SDK_PROGRESS.md; broader goal tool reports paused.

## 2026-10-13 - Original UI correction; custom inventory API

Removed the unapproved inventory action footer/click areas, title Back button,
Codec diagnostics/tooltips and rewritten title storage warning. Default UI must
be 1:1 except settings and the approved PC Save/Load list. SDK APIs remain for
explicit custom mods. Godot checks pass; corrected inventory/title native runs
pass at576/1025 frames with inspected screenshots. No native rebuild was needed
for this script correction. Protocol15.30 custom inventory actions are documented.
See docs/GODOT_SDK_PROGRESS.md Current handoff for evidence and remaining fidelity
work. Full renderer/SDK goal remains active.

## 2026-10-13 - Godot direct Codec actions

M5.11d completed: editable Codec Buttons invoke validated native tuning, calls,
contacts, dialogue advance/skip and Back. Native/client/wire/ZIP checks pass;
the relocated UI completes manual and contact calls, then returns to gameplay
with zero failures in the final native run. Protocol15.29,121 MGS patches verified.
Display remains inside Options; no repeat of completed Display/artwork work.
Old helipad checkpoint actor-identity failure remains an explicit M4/M7 issue.
Exact evidence, limits and next M5.04a inventory actions: docs/GODOT_SDK_PROGRESS.md.
Full goal active; no owned process remains.

## 2026-10-13 - Godot direct title actions

M5.11c completed: editable title Buttons use validated native actions for branding
skip, main selection, difficulty and Back/New Game. Build/native/client/wire/ZIP
checks pass; relocated custom UI proves title->Options->title->rendered docks.
Display remains inside Options with Back only inside its page. Current protocol
15.28,120 MGS patches verified; full goal active. Exact evidence, current build
hash and next M5.11d Codec action work: docs/GODOT_SDK_PROGRESS.md.

## 2026-10-13 — Display navigation correction

Display now registers inside Options (former Screen row). The floating shortcut and
F10/R3 opener are removed; Back appears only inside and returns selection/focus.
Focused UI/ZIP checks and live native mouse/controller proof pass. Details and
interrupted title-actions handoff: docs/GODOT_SDK_PROGRESS.md. Current built protocol
15.28;120 MGS patches verified. Title live new-game acceptance remains open.

Godot SDK M5.11b completed (2026-10-13): direct Options actions, editable Buttons,
native apply/audio/vibration semantics, original-free UI ZIP and both-disc live
mouse/synthetic-controller checks pass. Protocol 15.27, 119 MGS patches. Current
handoff and remaining full scope: docs/GODOT_SDK_PROGRESS.md. Next: M5.11c direct
title/new-game actions. Full goal remains active.

## 2026-10-13 - Godot direct Save/Load actions

M5.11a implemented: editable Buttons, validated native actions, safe overwrite confirmation, input capture, original-free UI ZIP. Native copied-save overwrite/New Save/load and synthetic controller checks pass. Protocol 15.26. See docs/GODOT_SDK_PROGRESS.md current handoff for evidence and next M5.11b Options actions. Full SDK goal remains active.

## 2026-10-13 - Editable Godot display settings

M5.06b implemented: DISPLAY/F10/R3 panel, live Apply/Keep/Revert and countdown,
editable Controls and original-free ZIP reopening. Protocol 15.25 adds native
two-port input capture with release guards. Matching native build and scoped
native/CPU/GPU/editor/ZIP/real dock checks pass. Simulation continues while open.
Full goal active; next: direct PC Save/Load actions for custom Godot Controls.
See docs/GODOT_SDK_PROGRESS.md.

## 2026-10-13: live Godot display settings provider

M5.05a.2 implements negotiated native projection/culling and GPU/window previews, 15-second confirmation/revert, retained-buffer rollback and confirm-only profile persistence. Protocol 15.24 / 0x3ffffff; 118 pinned patches. Native/CPU/GPU checks pass. Final isolated dock run: 1871 frames, 2760 world composites, zero display-probe failures and empty Godot/settings stderr. Current build SHA-256 1745B464249ECB8F03405560D967BADBDCE090203586BBE4BB0804F3E7E33FD7. Next: M5.06b editable settings Controls and native input ownership. See docs/GODOT_SDK_PROGRESS.md and docs/SETTINGS_CONTRACT.md for exact evidence and limits. Full goal remains active; campaign, distribution and 60-at-1440p acceptance remain open.

# Full native stage recreation — progress ledger

## 2026-10-13 - Shared display settings backend (M5.05a.1)

Launcher and Godot now share typed display settings through the existing XML
profile. The authenticated local provider supports read/validate/save, stale-write
rejection, preservation of mod selections and explicit next-launch requirements.
Editor/command-line runs use the same settings-host.exe backend and load saved
values unless display arguments explicitly override them. Godot exposes the
provider through its visual API. No original assets enter the settings flow.

Production host/Godot round trip, next-launch reload, 3/3 launcher/native-argument
checks and a real 480-VSync title boot pass. A startup timeout during shader warmup
was found and corrected; the final run has empty renderer/service stderr. Details,
build hashes and commands: docs/GODOT_SDK_PROGRESS.md and docs/SETTINGS_CONTRACT.md.
Production C# Aislop scan: eight files, score 100. One test warning flags intentional
PASS output; C# formatter/linter unavailable. User mod ZIP remains untouched.

M5.05a remains open. Next: coordinated live native/GPU display application,
confirmation/revert and rollback, then editable settings Controls and input
ownership. Saved settings are not yet applied to the running rendering session.
The full Godot/SDK/campaign/performance goal remains active.


## 2026-10-13 - Editable title/new-game UI (M5.07a)

Original title, difficulty and Special menu presentation now uses named Godot
Controls, locally resolved art/fonts and native input/game-start behavior.
Edit Title / New Game UI supports preview, custom assets and original-free ZIP
reopening on both discs (eight text files in the default export). Protocol 15.23,
scene capability mask 0x1ffffff; all 117 pinned patches verified. Native build,
3/3 focused C tests, both-disc editor/ZIP tests, Vulkan crop/gradient/blend checks
and a real title -> d00a -> s00a new-game probe passed. Existing Options tests pass.
The current build hash, logs, source/reference screenshots and precise remaining
scope are recorded in docs/GODOT_SDK_PROGRESS.md. The Codec foreground correction
remains verified against original rendering; older authored overrides retain
copied scripts/layouts. No user ZIP was rewritten.

Aislop: nine native files clean; 22 inherited nonfixable vendor complexity warnings.
C formatter/cppcheck/clang-tidy unavailable. Capture-run audio queue warnings mean
this is not a frame-pacing pass. M5 and the full goal stay active: remaining menus,
shared settings/actions, final rendering ownership and campaign/performance gates
are still required. Next slice: M5.05a shared display settings provider. No owned
process remains.


## 2026-10-13 — PC Save/Load and Codec foreground

Godot now shows an editable flat PC save list/New Save using original MGS fonts,
green-on-black colors and framing; native storage remains unchanged. Real isolated
save/load probes pass. Codec frequency/signal now retain dim backgrounds and the
original additive foreground glow. Protocol 15.22; 116 patches verified. Details,
validation limits and next work are in docs/GODOT_SDK_PROGRESS.md (M5.09a/M5.08a).

## 2026-10-13 — Godot original Options UI

Added editable Options/main, screen-adjustment and controller Controls with native
setting actions, local original-art references and original-free ZIP reopening.
Both-disc authoring, GPU highlight/help checks, paired Legacy/Godot actions and a
live Options run pass. Protocol 15.21; 115 vendor patches match. Shared modern
settings, save/load and remaining presentation work stay open. The full SDK goal
and stable-60 performance acceptance remain incomplete.

Production executable SHA-256:
`B2EBDA9D3F130DC614734342FE2754133F0DBE9D07FFA7742ABE9D98DD85438B`.
Evidence and next action: `docs/GODOT_SDK_PROGRESS.md`, M5.06a handoff.

## 2026-10-13 — Godot Codec UI milestone

Added negotiated Codec portraits/dialogue/contact/incoming-call Controls and editor
ZIP authoring. Native conversation/audio/input/save actions remain authoritative;
save screens still use legacy drawing. Native, both-disc ZIP and GPU checks pass;
live disc-2 save-call completion observed. Full renderer/SDK goal remains active.
Protocol 15.20, 114 pinned patches. Current native executable SHA-256:
9F2F7F197FE8B41E54C63D68510B9DD5F8A2C68C861BCF716BC14B321775A07B.
See docs/GODOT_SDK_PROGRESS.md M5.03g for evidence, limits and next menu/settings work.

## 2026-10-13 — Godot inventory UI milestone

Added negotiated inventory panel/description ownership, local icon preparation,
editable item/weapon/description Controls and original-free ZIP reopening.
Protocol 15.19 / 0x1fffff; patch 113 pinned. Native build, 7 focused CTests,
9 Python checks, both-disc ZIP tests, Vulkan/FSR2 rendering and an inspected
660-frame disc-2 saved-game load pass. Full UI/campaign interaction and stable-60
acceptance remain pending. Codec, menus/settings and the remaining renderer/SDK
scope are still open. See docs/GODOT_SDK_PROGRESS.md M5.03f for exact evidence,
limitations, final build hash and next actions. Full goal remains active.

## 2026-10-13: Godot radar ownership and editable UI

Radar now renders through editable Godot Controls: map/contact/cone layers, alert/evasion/jamming, recovery and escape countdown. Native detection, RNG, timers, sounds and callbacks remain authoritative; privately constructed radar packets never reach the rendered ordering table. Protocol 15.18 / 0xfffff, pinned patch 112. Native rebuild and seven CTests pass; both-disc original-free ZIP round trips, Vulkan/FSR2 UI checks and protocol validation pass. A 1020-frame native run reached the opening Codec without renderer errors; active gameplay radar and human campaign/60-class acceptance remain pending. Inventory UI is next. Detailed evidence, CPU-adapter limitation and handoff: docs/GODOT_SDK_PROGRESS.md (M5.03e).


## 2026-10-13: native radar presentation view

Added frame-local radar walls/contacts/cones, alert/recovery state and escape countdown observations. Native runtime rebuild and five focused CTests pass, including 100-frame draw/RNG/timer parity. Pinned patch 111; protocol remains 15.17. Godot radar Controls, original artwork and ownership are next; legacy radar is still rendering. See docs/GODOT_SDK_PROGRESS.md (M5.03d) and docs/PRESENTATION_CONTRACT.md section 10. Full SDK goal remains active.

## 2026-10-13: Godot formatted subtitles and editable UI

Implemented protocol 15.17 subtitle ownership and an editable `ui.subtitles.scene`
slot. Native font/layout and subtitle timing remain authoritative; Godot draws
transient source-glyph FontFiles through Controls, with native outlines and no
subtitle raster/VRAM image dependency. Legacy retains its original draw path.
The SDK opens/edits/exports/reopens subtitle Controls without original font data.
Both-disc ZIP checks, 22 native/Godot formatting pixel cases (also FSR2), four
native CTests and an unskipped 5400-VSync intro run pass. Human campaign visuals
and 1440p cadence are not established. Seven inherited nonfixable vendor size/
complexity warnings remain; project/test Aislop scopes have no findings.

Patch 110 is pinned and verified. Native executable SHA-256:
`7966C11F1518495C7F24D5F3E9805586EE9DAF4A4C0F4966FA90CB8391084A06`.
Detailed evidence, limitations and next radar task are in
`docs/GODOT_SDK_PROGRESS.md` (M5.03c). Full goal remains active.

## 2026-10-13 — Native subtitle state (Godot SDK M5.03b)

Added a native presentation snapshot with retained encoded text, captured before expiry/confirmation. Native timing, modal pause, multi-page continuation and the current draw path are preserved. Four focused native/font/bar checks, full 109-patch verification and a real-disc title startup with the user's mod pass. This is the state-provider prerequisite; formatted glyph layout, dynamic font banks, Godot subtitle Controls and ownership negotiation remain open. Native SHA FF01524AF28EA849491EB590087418B32A7BE20D4D1020831D71CA96B4D2C0DD; protocol remains 15.16 / 0x3ffff. One inherited vendor long-function warning remains. Full goal active; exact next action and evidence in [Godot SDK execution ledger](docs/GODOT_SDK_PROGRESS.md).

## 2026-10-13 — Original subtitle font (Godot SDK M5.02c)

Imported both discs' base KCB font into local Godot resources. All 538 glyphs match compiled native font.c pixels/metrics; ordinary Label rendering, font styling, FSR2, export rejection and existing UI/ZIP regressions pass. Original artwork stays local. This completes the base font prerequisite, not the subtitle state/Control migration or dynamic glyph banks. Native runtime/protocol unchanged (15.16 / 0x3ffff); user ZIP preserved. Full goal active. Next: native subtitle timing/formatted text, dynamic bank references and editable Controls. Detailed evidence and exact handoff: [Godot SDK execution ledger](docs/GODOT_SDK_PROGRESS.md).

## 2026-10-13 — Editable native status bars (Godot SDK M5.03a)

Implemented semantic health, oxygen and shared boss/inventory bars with unchanged native state/timers. SDK **Edit health / oxygen UI** authors ordinary Control templates, keeps original fonts local and supports ZIP reopening. Protocol 15.16 / 0x3ffff; 108 pinned vendor patches. Paired native, both-disc authoring/ZIP and GPU/FSR2 checks pass; native pair rebuilt. Real-disc startup with the user's existing mod passes, but active HUD visual and cadence acceptance remain pending. Four inherited vendor complexity warnings remain; scoped project scan has no findings. Full goal active. Next: semantic subtitles/notifications and original KCB font/text preparation. Detailed evidence and exact handoff: [Godot SDK execution ledger](docs/GODOT_SDK_PROGRESS.md).

## Godot editable goggles UI - 13 October 2026

Delivered typed native goggles state and editable original-layout Godot Controls, both-mode editor preview, local original font/vector references and original-free UI ZIP export/reopening. Native gameplay/input/timing remain authoritative. Protocol 15.15 / 0x1ffff and 107 pinned patches; native build SHA 1184307B1FBDABCDC39B8DAF9AD338293811AB746C9AC9E82A254135B60F9EA9. Five paired native/scene checks, 16 Python tests, both-disc authoring/ZIP, GPU/FSR2 and real-disc startup checks pass. Live active-goggles visual review and the rest of the goal remain open. Project Aislop 100; five inherited nonfixable vendor complexity warnings remain, with unavailable C/C++ scan engines recorded. Next: native life/oxygen state and editable HUD Controls. See docs/GODOT_SDK_PROGRESS.md for the granular handoff. All owned processes exited; user ZIP/discs/settings preserved.

## Godot original UI preparation - 13 October 2026

Both discs now prepare the six goggles vector layouts and two original menu fonts as local references with source/dependency hashes. Godot Labels and reference Controls pass 27 Python tests, both-disc asset checks and GPU/FSR2 pixel tests. Serialized original fonts are rejected by the mod exporter. Native sight rendering and protocol 15.14 are unchanged; typed UI state, complete editor Control scenes and UI ZIP reopening remain next. Full goal remains active. See docs/GODOT_SDK_PROGRESS.md for evidence and exact handoff.

## Godot native IR sensor beams - 13 October 2026

Protocol 15.14 renders native IR sensor endpoints/reveal as editable Godot beam strips, with thermal heat and matching depth/occlusion. Paired native sensor tests, GPU/FSR2 camera/reveal/heat checks and original-free material ZIP reopening pass. All 106 vendor patches reproduce; rebuilt pair passes loaded s02c startup. That run had no active beam batch or goggles, and five other world compatibility faces remain. Live visual acceptance and M4.04c stay open. Next: typed UI state and editable original-layout Godot Controls, starting with first-person goggles sight. Exact evidence, limitations and handoff are in docs/GODOT_SDK_PROGRESS.md.

## Godot thermal model heat and editor controls - 13 October 2026

Protocol 15.13 / 0xffff adds negotiated thermal model/compositor ownership. Native IR-marked originals and replacements supply heat; custom meshes can register heat through the visual API. Editable thermal resources export/reopen without original assets. Native ownership tests, rigid/skinned GPU occlusion/motion/background tests, FSR2 and night/depth regressions pass; rebuilt pair passes a loaded dock smoke. All 105 vendor patches reproduce. M4.04c remains open for thermal-only laser beams and live goggles review; first-person UI, custom shader/blend-shape heat matching, campaign ownership and cadence acceptance remain pending. See docs/GODOT_SDK_PROGRESS.md for exact evidence and next work.

## Godot native vision and editable night vision - 13 October 2026

M4.04b now publishes normal/night/thermal mode and supports an editable Godot night-vision compositor with original-free ZIP reopening. Native ownership/context, GPU/FSR2, authoring/import and depth-composition tests pass. Protocol 15.12 / 0x7fff; all 104 vendor patches reproduce. Rebuilt pair passes a loaded 1800-VSync dock movement smoke; that run did not equip goggles. Thermal heat/visibility, first-person sight UI, live special-vision review and full campaign/cadence acceptance remain open. Exact evidence, build hash and next task M4.04c are in docs/GODOT_SDK_PROGRESS.md.

## Godot semantic camouflage - 13 October 2026

M4.04a is implemented with protocol 15.11 / 0x3fff, an editable Godot refraction material, original-free ZIP reopening and preserved native equipment/thermal transitions. Paired Legacy/Godot producer tests, scene serialization/reuse checks, GPU/FSR2 checks and a 2600-VSync equipment-menu run pass. All 103 vendor patches reproduce. This is not full special-vision, campaign or stable-60/1440p acceptance. See docs/GODOT_SDK_PROGRESS.md for exact evidence, limits and next task M4.04b (night/thermal vision).

## 2026-10-13 - Editable Godot world-effect materials

- Snow and registered textured effects accept mod ShaderMaterials with tint, custom PNG/WebP textures, alpha cutoff, PBR factors and emission. The editor creates/reopens ordinary resource files; native positions, UVs and particle lifetime remain authoritative.
- Export/import follows material, shader/include and texture dependencies. Headless authoring/ZIP checks, seven Python importer tests, editor import and GPU color/depth/lifetime regressions pass. Real exported/reopened s12c mod changes snow and two lamp targets with no original assets in its 21 files.
- Native protocol/build unchanged. Per-emitter authoring, compatibility-only effects, UI and full campaign/1440p pacing remain open. Exact evidence and next M4.04 optical-camouflage task: docs/GODOT_SDK_PROGRESS.md.

## 2026-10-13 - Authored Godot cameras and fog-stage proof

- Added explicit ownership for ordinary Camera3D rigs: gameplay, exact cinematic clip or stage-wide scope, lifecycle/conflict validation and cut history resets. Native world/effect poses stay authoritative; release restores the native camera. Asset-free example and SDK documentation included.
- Headless lifecycle/ZIP/coordinate/snapshot tests, editor import and GPU history/world-effects/depth checks pass. Real exported/reopened three-file mod ran a shifted/wider disc-2 s12c fog view with retained scenery, lamps and snow. Final run exited cleanly; native code/protocol unchanged.
- Full native-time custom camera tracks, campaign-wide viewpoint coverage, editable effect resources and 1440p cadence remain open. Aislop cannot score these GDScript/PowerShell files. Detailed evidence and the next M4.03d authorable-effects task are in docs/GODOT_SDK_PROGRESS.md.

## 2026-10-13 - Godot world lamps and null surfaces

Scripted texture lamps now render as emissive Godot surfaces with native animation and one-sided visibility. KMD null-texture faces follow the importer's empty-surface contract instead of rejecting whole mesh parts. A loaded s12c audit now reports zero compatibility mesh/effect content in its world queue; UI and other channels remain outside that audit. Sampled copy work falls from 33.3 to 5.9 MiB, not a stable-60 acceptance claim. Sixteen native checks, negotiation and GPU effects/composition tests pass. Protocol 15.10 / 0x1fff; all 102 vendor patches verify. One inherited lamp-source size warning and unavailable C lint engines remain. Exact evidence/hash and the next edited fog-camera validation are in docs/GODOT_SDK_PROGRESS.md. Goal active; no owned processes remain.

## 2026-10-13 - Godot world snow

Registered snow now renders as Godot billboards with native positions, sizes and colors; simulation/RNG remain untouched. The live s12c queue moves all 96 TILE faces out of compatibility rendering, leaving one mesh group and 8-10 FT4 faces. Sampled world composition copies drop from 132.9 to 33.3 MiB; stable-60/1440p acceptance remains open. Sixteen native tests, session negotiation and GPU effects/composition checks pass. Protocol 15.9 / 0xfff; rebuild/deploy the native and Godot pair together. All 101 vendor patches reproduce. Three inherited snow-source complexity warnings and unavailable C lint engines remain. Exact build hashes, live images, remaining effect-authoring limits and the next attribution task are in docs/GODOT_SDK_PROGRESS.md. Goal active; no owned processes remain.

## 2026-10-13 - Godot fog world composition and ownership audit

Fog sorting now inserts Godot world markers and skips only owned effect faces and replaced shadow/glow packets. Added opt-in queued-world ownership logging and strict compatibility rejection. Sixteen focused native tests and two GPU tests pass. Disc-2 s12c reaches 900 VSyncs with 12,422 world composites and an inspected snowy-world image; remaining audit content includes one compatibility mesh group and TILE/FT4 effects. Full image ownership, edited fog-camera validation and 1440p pacing remain open. All 99 source patches reproduce; latest native SHA-256 A23178126F212D1FA26FF1377BF97E3B9E6970E10051CF0413C053B7108D92B8. Aislop reports no new blocking findings; four inherited vendor size warnings and unavailable C lint tools remain. See docs/GODOT_SDK_PROGRESS.md for exact evidence and the next producer-migration task. Goal active; no owned processes remain.

## 2026-10-13 - Godot fog packets and connected-part shading

M4.02b retains fog material packets and thermal palettes outside native bounds, with safe fog-table indexing. Both standard and fog transform paths now refresh connected-part color links before retained shading. This fixes a native access violation reproduced in disc-2 s12c; original gameplay visibility is preserved.

Eleven focused CTests pass. Rebuilt native executable and isolated s12c/docks boots reach 900 VSyncs with empty Godot error logs. These are native smoke checks, not full Godot fog rendering or frame-pacing acceptance. The fog sorter still lacks Godot world-marker composition; that is the next M4.01/M4.03 slice. Actor visibility checks affecting AI, combat, pickups or RNG were audited and left intact.

All 98 vendor patches verify. Test-file Aislop score 100, zero findings; separate vendor scan retains four nonfixable recovered-code size warnings and lacks C lint/format tooling. Detailed failure/fix evidence and next action: docs/GODOT_SDK_PROGRESS.md. Goal active; inherited work preserved; no owned processes remain.

## 2026-10-12 - Godot authored camera cuts and temporal history

Animation markers now define hard cuts; sparse camera edits retain marker names/colors/frames and hold-key easing through save, ZIP export and reopen. Runtime handles skipped source frames, paused samples, clip generations and camera ownership changes without changing native timing.

Pinned Godot 4.8.dev7 has no direct FSR2 reset API. The renderer recreates temporal buffers once before a cut and renders world/background fog with zero history weight for that frame, restoring the authored environment afterward. GPU checks match a fresh view and remain clean on the following frame. Buffer recreation cost at full resolution remains an open performance gate.

Headless camera/ZIP/lifecycle tests, related scene/mod tests, GPU history test, editor import and runtime syntax checks pass. An exported-and-reopened camera-only ZIP completes the unskipped opening through dock Codec with cuts at source frames 450/900 and native camera return at 1981. Logs: build/godot-sdk-m0/cuts-*. Native audio refill warnings remain; no full-resolution cadence or campaign acceptance claimed. Scoped Aislop reports no findings but cannot score GDScript/PowerShell.

M6.04a / M6.08b checked. Next: M4.02 actor-level visual/emitter updates gated by native camera visibility, preserving gameplay decisions. See docs/GODOT_SDK_PROGRESS.md for evidence and remaining camera gates. Goal active; inherited work preserved; no owned processes remain.

## 2026-10-12 - Godot off-axis models and world effects

Protocol 15.8 keeps active owned meshes and live material packets available outside the native camera bounds while preserving native gameplay visibility. Registered spatial effects survive native projection rejection; billboards face the authored camera using their world centre and dimensions. Existing hidden/group/lifetime behavior remains active.

Native build, four focused CTests, Godot negotiation/snapshot/camera tests, GPU off-axis model/billboard/shadow checks and editor import pass. A camera shifted three metres, rotated 0.45 radians and widened to 100 degrees completes the unskipped opening to dock Codec; inspected images and logs are under build/godot-sdk-m0/offaxis-*. All 97 vendor patches verify. Aislop: 100, zero diagnostics in seven files; C lint tools unavailable, GDScript/shaders unscored. No campaign or frame-pacing acceptance claimed.

M4.02a / M6.08a completed; broader actor/emitter gates and unsupported primitive paths remain open. Next: authored hard cuts and temporal-history reset. Full evidence and continuation instructions are in docs/GODOT_SDK_PROGRESS.md. Goal active; no owned processes remain.

## 2026-10-12 - Sparse Godot camera edits and native playback

M6.03b / M6.06a now save sparse original-camera transform/FOV edits, reconstruct them on reopen, exclude original tracks from mod ZIPs and sample at the actual applied native cinematic frame. Protocol 15.7 carries stream identity and lifecycle. An edited, unskipped opening reaches dock gameplay/Codec and releases camera ownership at clip completion.

Native build, four focused CTests, launcher tests, Godot save/ZIP/reopen/frame tests and headless editor import pass. Scoped Aislop: 100, zero findings in seven supported files; C lint tools unavailable and GDScript/PowerShell unscored. Both-disc validation took 87 seconds; startup limits increased, startup cost remains open. Off-axis geometry/effects, custom camera rigs, cut/history handling and broader lifecycle/ZIP-native acceptance remain open. See docs/GODOT_SDK_PROGRESS.md for exact evidence and the next M4.02 / M6.08 action. Goal active; no owned processes remain.

## 2026-10-12 - Source-linked Godot cinematic previews

The searchable scene list now exposes verified GCX/DMO cinematic scenery and original camera tracks without running gameplay. Both local caches include 119 distinct camera tracks; the editor uses normal Camera3D and AnimationPlayer nodes. Scene save/ZIP tests strip original tracks and retain custom edits. Scenery edits still apply stage-wide; authored camera export/native playback and actor animation preview remain open.

Python checks pass 21 tests; Godot builds all 119 camera libraries and loads 250 disc-1 / 147 disc-2 available scene entries. Focused browser/session/ZIP checks and headless editor import pass. Aislop: 100, zero diagnostics in four Python files; GDScript/PowerShell unscored. No native or performance acceptance is claimed. M6.01 read-only reuse review and granular next actions are recorded in docs/GODOT_CINEMATIC_AUTHORING.md and docs/GODOT_SDK_PROGRESS.md. Goal active; no owned processes remain.

## 2026-10-12 - Godot SDK disc-aware editor and runtime

M3.01d implemented: original Disc 1/2 selection above the searchable map list, separate disc-scoped scene edits in one mod, and protocol 15.6 current/source disc identity. Both validated caches are mounted without rewriting originals. Runtime models retain their source disc; scene, texture and effect settings select the active disc. Native tests pass the edited scene's source disc to the host.

Native build and three relevant CTests pass. Godot catalog/ZIP/identity/browser checks, editor import, managed disc-2 start/stop/failure checks and disc-2 water/particle GPU regression pass. Short native boots from both discs complete normally. Aislop reports 100 with zero findings in five C files; cppcheck/clang-tidy unavailable, GDScript/PowerShell unscored. This does not establish actual mid-session disc swapping, campaign playability or stable frame pacing. Evidence and exact next M3.01e/M6.01 action are in docs/GODOT_SDK_PROGRESS.md. Goal active; no owned processes remain.

## 2026-10-12: campaign-wide Godot map preparation

Both campaign discs now prepare 22,727 assets each. Godot opens and validates all
82 startup map sets per disc; null-texture surfaces no longer reject whole maps.
The expanded disc-1 cache is installed and its predecessor retained locally.
Native startup now instantiates stage models as needed instead of all 2,015
campaign models. Focused tests and a 600-VSync native dock run pass. Disc-aware
editor/runtime switching, conditional assembly and full presentation acceptance
remain open. See docs/GODOT_SDK_PROGRESS.md for exact evidence and next actions.

## 2026-10-12: searchable Godot map browser and native tests

The editor now lists readable location names with stage IDs, gameplay/cinematic
classifications, disc labels and direct/inherited active-mod edits. Search and
modified-only filters replace the map dropdown. Unprepared scenes remain visible
with explicit reasons; four current gameplay/cinematic sets open successfully.
Managed workspace test sessions provide launch profiles, stop, startup errors
and isolated logs without a ZIP export. Native startup/normal stop and invalid-mod
reporting pass. Campaign preparation and broader SDK acceptance remain open.
See docs/GODOT_SDK_PROGRESS.md for checks, evidence and the next implementation.

## 2026-10-12: usable Godot actor mod workflow

The dock elevator now supports ordinary editable replacement parts, parented lights,
per-part visual removal and a portable mod ZIP. The imported custom example passed
native descent/bottom-stop checks (1,158 observed attachment samples). Editor/map
save and ZIP round-trip tests pass. This is a bounded workflow proof, not full SDK
or playthrough acceptance. See docs/GODOT_SDK_PROGRESS.md for exact evidence.

User priority correction: move on to M3 scene selection and native test sessions;
ordered elevator events/generalized resync must not hold up usable editor work.

Godot SDK elevator proof (12 October): the native timer creates the real dock
body; 1,177 samples verify ordinary child motion through descent/bottom stop.
Exact declaration lookup now reports inactive/ambiguous targets explicitly, and
context signals exclude old-epoch actors. Named parts, events and lifecycle
acceptance remain next; see docs/GODOT_SDK_PROGRESS.md.

Godot SDK actor bridge (12 October): initial elevator lifecycle/world-anchor
provider and declaration identity are implemented in protocol 15.5; focused
tests pass. Ordinary dock probe still passes but spawns no elevator, so live
elevator acceptance remains open. See docs/GODOT_SDK_PROGRESS.md next action.

Godot SDK source matching (12 October): protocol 15.4 sends bounded raw model
source digests before scene use. Dock probe passes with 41 declarations / 15
verified models. Vendor patch stack reproduces all 94 patches. M1.02 resource
incarnations and M1.03 actor anchors remain next; see the SDK progress ledger.

Godot SDK catalog validation (12 October): runtime startup and editor reload now
share source/prepared revision checks before exposing stamped assets. All 2,018
local assets / 3,861 files pass; older catalogs receive an unverified notice.
Native resource identity/lifetime integration remains next in the SDK ledger.

Godot SDK prepared provenance (12 October): asset preparation now stamps source
content IDs and generated dependency revisions. Eleven focused tests pass;
in-memory validation resolved all 2,018 local assets / 3,861 prepared files.
Runtime revision enforcement remains next in docs/GODOT_SDK_PROGRESS.md.

Godot SDK retained palettes (12 October): protocol 15.3 adds bounded, session-bound
create/update/retire and revision references. Focused native dock probe passes;
600 snapshots avoided 68.7% of raw face-palette payload (not total traffic or
60-FPS acceptance). M1.02 general resources/content IDs remain open; see
docs/GODOT_SDK_PROGRESS.md for evidence and the next action.

Godot SDK session contract (12 October): protocol 15.2 now carries a public
session ID distinct from the launch token, plus sequenced native clock/resource
generations. M1.01 minimum contract checks pass, including real wrong-session
rejection and dock boot. Continue M1.02 retained resources in the SDK ledger.

Godot SDK authentication (12 October): current prototype pair is protocol 15.0.
Launcher/CLI create a per-session token passed privately to both children.
Wrong tokens fail before command dispatch. Gate tests, launcher tests, GPU
protocol fixture and real launcher boot with the testing ZIP pass. Resume the
public session/clock/scene envelope in docs/GODOT_SDK_PROGRESS.md.

Godot SDK protocol update (12 October): native/Godot now negotiate prototype
14.0 command, scene and debug capabilities. Rebuild the pair together. Headless
checks, GPU protocol integration and a 360-VSync isolated dock boot pass. This
is partial M1.01; clock/epoch/authentication/reconnect remain open. See the
SDK execution ledger for current work and evidence.

Godot SDK continuation (12 October): the user clarified that dock bars mean the
attached platform railing. The HTML plan and SDK ledger now distinguish separate
editing targets from shared native body motion. Added the proposed presentation
contract and both-disc cinematic inventory tooling (79/40 clips; eight tests
pass). These are design/source evidence, not runtime SDK acceptance. Continue
from `docs/GODOT_SDK_PROGRESS.md`; the implementation goal remains active.

Scene-code handoff: Integral's main campaign is present in the native Windows
build, with modifiable resources and a replaceable renderer. Gameplay acceptance
is assigned to the user's playthrough. Original project files and disc images
remain preserved.

The user completed the campaign through the credits on 10 October. The final
recording is `.local/replays/run-20261010-014859-670.mgsinput`: 89,751 input
samples / 89,755 VSyncs, ending normally at the title. This is human completion
of that campaign route, not validation of every branch or optional mode.

The [campaign completion snapshot](test-data/campaign-completion-20261010/README.md)
preserves all 30 native recordings, their initial saves and session metadata,
retry checkpoints and timing/log data in the original local repository history.
The archive and its personal-path manifest are excluded from the release
repository. Its local manifest records per-file hashes and restore instructions.

Latest preserved retry checkpoint:
`.local/checkpoints/pal-hot-20261010/room-entry.mgssave`, on the stairs outside
the PAL room before detection, with the hot PAL key equipped and reheated.
The first two PAL steps remain complete; the final insertion remains pending.
[Launch and record](docs/INPUT_RECORDING.md#hot-pal-key-retry-disc-2).
The cargo-elevator crash is fixed; its earlier retry checkpoint remains at
`.local/checkpoints/cargo-20261010/ambush-entry.mgssave`.
The earlier cargo `recorded-restart.mgssave` is unsuitable for an encounter
retry: it captured post-fight story 207 and skips the guards. It remains only
as provenance for existing recordings; use the corrected checkpoint above.
The earlier Disc 2 entry checkpoint remains preserved at
`.local/checkpoints/disc2-20261009/recorded-entry.mgssave` (`s13a`, map `0x4986`).
Its export matched all 26,559 inputs / 26,563 VSyncs of the previous recording,
and its 600-VSync reload reached the Disc 2 entry corridor. Checkpoints restore
map entries, not exact process snapshots. Original recordings and cards remain
preserved; each checkpoint has adjacent provenance and validation JSON.

## 2026-10-12 - Godot SDK M0 baseline and source inventory

Active goal: [granular SDK ledger](docs/GODOT_SDK_PROGRESS.md). M0.01/M0.02 and M0.04a are complete; M0 as a whole remains in progress.

- Recorded inherited source/build/content hashes and verified the published Legacy 0.2 binary plus a rebuilt current Godot native executable in isolated real-disc runs. Existing FSR2 renderer files and the input mod ZIP were preserved.
- Added a provenance-checked both-disc inventory and synthetic tests: 92 configured names, 190 disc-stage entries, ten prepared catalog entries. Scenario/conditional variants remain unclassified; no full Godot stage acceptance is inferred.
- Fixed the performance harness's accidental 4:3 setting. Widescreen dock timing still fails: 59.844 average FPS, 13 over-budget frames / 2,500. The unskipped intro completes but its active demo averages 48.088 FPS. Requested 2560x1440 produced a 2560x1421 window client; effective preset and UI-transition timing remain open.
- The actual dock elevator declaration has no optional secondary bar model. Its body, callback/state evidence and UI draw side effects are recorded in [native binding notes](docs/GODOT_NATIVE_BINDING_NOTES.md). Next: verify the visible bars' actual actor/DMO ownership before defining anchors.
- Selected CTests passed (4/4): inventory, list_assets, launcher_mods, launcher_settings. [Baseline and evidence](docs/GODOT_SDK_BASELINE.md); [coverage inventory](docs/GODOT_PRESENTATION_COVERAGE.md). These are scoped automated checks, not a manual playthrough or a cadence pass.


## Active Godot SDK goal - 12 October 2026

The user approved the full presentation/SDK plan and requested a reachable active
goal with a granular handoff for later sessions and context compaction. The goal
is now active. Start with [GODOT_SDK_PROGRESS.md](docs/GODOT_SDK_PROGRESS.md): it
records milestone tasks, dependencies, acceptance gates, the inherited baseline,
known failures, evidence paths and the exact next action. AGENTS.md directs
future sessions to this ledger and the approved implementation sequence.

First delivery path: M0 baseline/contracts, the minimum M1 actor/session bridge,
M2 dock elevator and independent bars, then M3 open/edit/native-run/export/reopen.
The remaining milestones cover complete Godot visuals and UI, camera/cinematic
editing, community renderers, campaign coverage, cadence and relocatable SDK
packages. Native gameplay stays authoritative; exported mods exclude originals.

This handoff changes documentation only. Expanded implementation tasks remain
pending; existing FSR2 and user settings are preserved. Next task: M0.01.

## Complete Godot presentation and SDK plan - 12 October 2026

The user expanded the target to a fully Godot-rendered, editable presentation
layer: all world effects and UI, cinematic-only maps, camera tracks, dynamic
actor attachments/state/events, editor-launched native testing, and launcher
selection of Legacy 0.2, Godot or community renderers. Native gameplay remains
authoritative for now. The default UI will preserve the original layout as
editable Godot Controls. Original-content exclusion remains required for mods.

The [HTML implementation plan](docs/GODOT_SDK_MASTER_PLAN.html) records the current
source baseline, proposed contracts, an elevator/bar binding example, migration
sequence, acceptance gates and reuse candidates from the earlier MGSR archive.
It replaces the earlier limited visual-SDK target as the approved delivery scope.
This is a planning deliverable; the proposed actor/UI/renderer APIs are not yet
implemented. The prior FSR2 working changes remain separate and uncommitted.

Plan validation: Chromium checks passed at 1440x1080 and 390x844, including
all 28 local source links, section anchors, nine milestone controls, both
binding sliders and print output. No browser errors or page-width overflow.
Evidence: build/sdk-plan-review/report.json. Aislop found no findings but did
not score these document formats (zero supported files). No game code changed.

## FSR 2.2 native-resolution antialiasing - 12 October 2026

Enabled FSR 2.2 at 100% 3D resolution for the editor and runtime world viewport,
with sharpening 0.8 and no additional TAA/SMAA pass. The native HUD and menus
remain outside the temporal resolve. Existing user shadow/GI settings remain.
Metadata uses unfiltered rendering; the small fog-background viewport disables
temporal scaling. Shader warm-up now includes the FSR motion-vector variants.

Godot's FSR output overwrites alpha and uses pre-resolve scene alpha as a reactive
mask. Added opaque coverage capture before transparents and preserved final
coverage alongside linear depth, so native composition retains water/particle
transparency over both native pixels and opaque geometry. No protocol or native
binary change is needed; the launcher fingerprints the updated renderer scripts.

Validation: full Godot CPU/GPU/protocol suite passed, including both ordinary and
FSR depth/composition and high-resolution/HUD tests. Added transparent-over-native
and transparent-over-opaque coverage regressions. Lighting serialization/shadow
fixtures explicitly disable temporal AA for their exact before/after comparisons.
Aislop score 100, no findings. Real-disc 1,800-frame docks probe with the existing
local-780062320 mod passed movement and completion; renderer errors were empty.
Requested 2560x1440 widescreen (window client area 2560x1421), RX 9070 XT.
The short pre-screenshot steady sample averaged 59.23 FPS with p99 23.43 ms;
this is not a locked-60 claim or a manual visual acceptance test. Pixel shimmer
from original texture sampling or geometry overlap may still need separate work.
Evidence: build/fsr2-check/ and build/godot-runs/e23435374ea243c198e0ebd6ff00103c/.

## Puddle replacement removed - 12 October 2026

The user rejected the reflective puddles in the running game. Removed the water
snapshots, replacement planes/shader, reflection probes and custom ripple system.
Restored the native RippleSurface actor and its original ripple effects. Fog in
empty space and the repeated WORLD sorting fix remain. Protocol v13 rejects older
renderer/runtime pairs. The user's mod ZIP is unchanged.

Validation: rebuilt the native Godot executable; 22 targeted CTests and the
Godot CPU/GPU suite pass, including original world effects and fog composition.
The 1,800-frame real-disc dock probe loaded local-780062320.zip and completed
normally on protocol v13. This is automated boot validation, not human acceptance.
Logs: build/puddle-removal-build.log, build/puddle-removal-ctest.log,
build/puddle-removal-godot-tests.log and build/godot-puddle-removal-boot/.
Bootstrap verifies 93 MGS and 28 Psyz patches. The selected ZIP retains SHA256
BF0DBC8F98FC3F14B19BCEEBF4CF0F416357AF1985856C37BBA882ECBB30B81D.
Aislop score 100, no findings; cppcheck and clang-tidy are unavailable.

## Fog in empty space and reflective shallow puddles � 12 October 2026

**Superseded:** the puddle experiment below failed user acceptance and has been
removed. The fog and ordering changes remain.

Implemented protocol v12 and rebuilt `build/windows-x86-godot/RE-INTEGRAL.exe`:

- A separate quarter-resolution background viewport renders the same camera's
  environment fog/sky, including light-lit volumetric fog, without requiring geometry.
  It is composed before native world packets. The main transparent viewport and HUD
  ordering remain intact. Repeated sorting now removes previous WORLD markers before
  insertion; regression tests cover empty/populated tables, both buffers and pause.
- RippleSurface actors publish shallow regions and stable character contacts. A hazard
  floor check distinguishes the five dock puddles from the deep pool. Native geometry,
  collision, movement and trap behavior stay authoritative. Water bounds and texture
  cutouts remain local original content; no retail files or coordinates were embedded
  into distributed source or the user's mod.
- Puddle planes use dielectric PBR reflections and outward normal ripples on entry and
  every 0.28 metres of movement. Waves fade over 2.5 simulation seconds and pause with
  the actor. Nearby puddles share local box-projected probes; movement/exit refreshes
  are capped at 2 Hz. SSR cannot run on the transparent world viewport and is not
  enabled. Reflections are approximate and can lag movement; off-camera geometry not
  submitted by the native renderer can be absent. Planar reflections remain future work.
- `patches/mgs-godot-puddles.patch` records the native actor hook. Bootstrap confirms
  all 94 MGS and 28 Psyz patches. The selected ZIP's SHA256 remains
  `BF0DBC8F98FC3F14B19BCEEBF4CF0F416357AF1985856C37BBA882ECBB30B81D`.

Validation: 23 targeted CTests pass. The full Godot CPU/GPU suite, 19 Python asset/mod
checks and GPU transport check pass in `build/godot-tests/2f8a7eb8c5b44873947ebaf92033b2a1`.
The puddle fixture also verifies reflected-content refresh and expiry; the fog fixture
checks empty-space fog, volumetric scene lights and native foreground preservation.
Godot 4.8-dev7 emits a seven-texture reflection-atlas shutdown warning even in an empty
stock-probe reproducer. The test runner reports this exact version-specific warning;
other errors/leaks fail. Details are in `docs/GODOT_RENDERER_PLAN.md`.

A real disc boot with the unchanged selected ZIP completed its dock movement probe
and composed the modded world. At 2560x1440, 700 frames after warmup averaged 59.909 FPS,
with p95/p99 16.6835 ms and one 21.4378 ms outlier. Therefore the strict no-hitch cadence
check **failed**; this is not a claim of perfectly stable 60 FPS. Data:
`build/godot-performance/fb4f66c74a7740b091be565ea873e95f/summary.json` and `timing.csv`.
A local dock-scene render additionally exercised a real puddle cutout and its underside
geometry. These are automated renderer checks, not a manual playthrough.

Scoped Aislop score 100 with no findings. cppcheck and clang-tidy are unavailable.
Human acceptance of fog boundaries, puddle appearance and motion remains open.

## Emissive beacon glass, soft alarm spill and missing ripples — 11 October 2026

The user confirmed the paired rotating red spots, requested emissive red glass and
a gentle wide omni, and reported that ripples had disappeared. Native beacon
activation now marks its glass assembly; only the transparent glass receives
emission while active. Its opaque housing keeps ordinary lighting and shadows.
The glass no longer casts opaque shadows across the beacon's lights. Each beacon
adds one shadow-casting red omni (energy 0.35, range 6 m), sharing the first beam's
lifetime and centered at the pivot. `EventLightTemplates/AlarmFill` is editable in
the normal Inspector; existing ZIPs receive the default without changing authored
templates. Protocol v11 carries the new fill-light kind and glass/activation flags.
`mgs-godot-beacon-glow.patch` reproduces the native actor hooks.

The ripple regression had three contributors. Godot already flips two-sided
normals, so our second flip inverted back-facing ring lighting. Gamma conversion
also crushed the native fade multiplier. Both are corrected. An actual dock scene
replay then exposed transparent water writing depth before the rings, hiding most
of them. Original transparent model color now blends without writing depth; a
late colorless next pass retains the depth needed by world composition. Solid
foreground meshes still occlude ripples. The prior fog-coverage fix remains.

Validation: rebuilt `build/windows-x86-godot`, 21 relevant native CTests pass, and
the complete CPU/GPU Godot suite plus 19 Python tests and the transport test pass
(`build/godot-tests/854d4dce55bb4a579e6b3a76da6ff2f2`). GPU checks cover active/off
glass emission with dark housing, all four event-light kinds and shadows,
opposing spots with exactly one fill, legacy-template migration, both sides of
ripples, linear fading, water overlap, foreground occlusion and fog. The real
`local-780062320.zip` boot passed; its SHA256 remains
`BF0DBC8F98FC3F14B19BCEEBF4CF0F416357AF1985856C37BBA882ECBB30B81D`.
Local diagnostics render the actual dock ripple geometry and beacon glass; they
are ignored development files, not an editor workflow or exported content.
Human alarm/ripple acceptance and the previously deferred cutscene pacing remain
unverified. Bootstrap verifies all 93 MGS and 28 Psyz patches. Aislop reports no
findings; C/C++ engines `cppcheck` and `clang-tidy` are unavailable.

## Godot side visibility, ripple fog and paired alarm spots — 11 October 2026

The user's widescreen screenshots exposed a missed native/Godot ordering issue:
`DG_SortChanlSystem` restored classic 4:3 gameplay bounds before publishing the
Godot scene. The scene now receives render bounds before that restore, while
gameplay still receives the classic bounds. A new Godot variant of the production
visibility test failed before this fix and passes afterward, covering both edges
at half-widths 214, 280 and 480 plus hidden/inactive groups. The earlier aspect
tests established projection and framing, but did not cover this handoff order.

The ripple rectangles have a reproducible fog failure: a completely faded
additive quad still contributed fog color across its whole polygon. Four GPU
checks failed with ordinary/volumetric fog and additive/quarter-additive blending.
Factoring texture color and native fade into premultiplied coverage keeps the
unfogged color and makes fog follow the ripple instead of the polygon. Invisible
additive texels no longer write depth. These checks now pass alongside existing
particle overlap, water depth, lighting and shadow tests. The existing 1 mm ripple
depth bias is unchanged.

Patrol beacons now register both native `pat_spt1` beam objects as red SpotLight3D
instances, 180 degrees apart, with shadows. Rotation, activation, map membership
and destruction follow the native objects. The Godot path suppresses beam meshes,
wall-glow primitives and fullscreen alarm tint, preserving lamp housings, audio
and actor state. `EventLightTemplates/AlarmSpot` exposes ordinary Godot properties;
older ZIPs get its defaults without changing authored lights. Protocol v10 adds
the alarm kind. Native patches are exported and pinned in `sources.lock.json`.

Validation: the complete Godot development build succeeds; 21 scoped native,
visibility, light and launcher CTests pass (`build/godot-visibility-alarm-ctest.log`);
the Godot CPU/GPU suite, 19 asset/workspace Python tests and TCP readback pass
(`build/godot-tests/5541d475163f48849e8ad83386fd8049`). The 1280x720 widescreen
launcher check installs and boots the unchanged `local-780062320.zip`, confirms
its overlay and world composition, and exits without renderer errors
(`build/godot-visibility-alarm-boot`). A separate 3,600-VSync unskipped intro run
followed animated cameras through d00a; it ended before the later dock Codec and
therefore did not complete the intro probe. Active dock-alarm appearance and the
user's exact moving ripple shot still need human confirmation; synthetic lighting
tests are not a dock playthrough. Cutscene pacing remains deferred as requested.

Bootstrap verifies all 92 MGS and 28 Psyz patches. Aislop reports score 100 with
zero findings; cppcheck and clang-tidy are unavailable in this environment.
The original selected ZIP still has SHA-256
`bf0dbc8f98fc3f14b19bceebf4cf0f416357af1985856c37bba882ecbb30b81d`.

## Godot widescreen selection — 11 October 2026

The launcher disabled Widescreen for Godot and replaced the native resolution
with 320x240, so selecting a wider output only changed the window. It now passes
the selected resolution and Widescreen flag to the native video code. The Godot
transport retains 1x packet coordinates while the renderer handles output
resolution. The normal launcher checkbox is enabled; the command-line wrapper
also supports `-Resolution 2560x1440 -Widescreen`.

Protocol v9 adds horizontal projection scale to each scene snapshot. Godot
expands the color and metadata cameras' horizontal field of view and viewport
width together, preserving vertical framing and matching native culling,
compatibility geometry and HUD transforms. Original-aspect mode remains 4:3;
menus, Codec and movies retain native 4:3 presentation in widescreen mode.
Rebuild the native executable together with the renderer. Existing mod ZIPs
require no conversion, and the user's ZIP was used without modification.

The game and launcher are rebuilt (`build/godot-aspect-build.log`,
`build/godot-aspect-final-build.log`). Fifteen selected video, clipping and
launcher CTests pass (`build/godot-aspect-ctest.log`). The Godot CPU/GPU suite,
19 Python tests and protocol readback pass (`build/godot-aspect-tests.log`, run
`495560d735754ac1a81c961003813c08`). Projection tests cover 4:3, 16:9, 21:9,
4:1, returning to 4:3, extra horizontal visibility, unchanged vertical framing,
metadata alignment and invalid scale rejection.

Two 1,800-frame real launcher/disc boots with `local-780062320.zip` at
1280x720 pass. Widescreen displays a 1280x720 game rectangle, horizontal scale
0.75; original mode displays 960x720, scale 1.0. Both renderer logs are error-free,
and the images were inspected (`build/godot-aspect-wide/render.png`,
`build/godot-aspect-original/render.png`). Assertions against these real logs
also reject an incorrect aspect selection (`build/godot-aspect-display-check.log`).
This is scoped dock validation, not campaign-wide widescreen acceptance or a new
performance benchmark. Cutscene pacing work remains deferred. Aislop reports
zero findings (`build/godot-aspect-aislop.json`); cppcheck and clang-tidy remain
unavailable. Repository whitespace and normal headless editor import checks pass.

## Godot color precision and editable mod ZIPs — 11 October 2026

Native fullscreen blend/framebuffer effects were rounding the composed Godot
image back to 5-bit RGB. The Godot composition path now preserves floating-point
color through those operations; native texture decoding and the standalone PS1
renderer retain their original behavior. The locally supplied shader flag does
not change protocol v8. `patches/psyz-godot-color-precision.patch` is in the lock
file; bootstrap verifies all 90 MGS and 28 PsyZ patches
(`build/godot-editing-bootstrap.log`). GPU regressions cover all four blend modes
and framebuffer copies at native and scaled resolutions. The exact helicopter
shot reported by the user has not been replayed for visual acceptance.

The editor now offers **Open mod ZIP for editing…** and an active workspace
picker. Imports restore the normal local disc references; reopening identical ZIP
contents resumes the workspace without discarding edits. Changed archives get
separate workspaces. Import validates paths, integrity and manifest references,
and publishes the workspace only after extraction succeeds. Export uses a Save
dialog with explicit overwrite confirmation and replaces the output only after
success. The user's `local-780062320.zip` remains unchanged, SHA256
`BF0DBC8F98FC3F14B19BCEEBF4CF0F416357AF1985856C37BBA882ECBB30B81D`.

Model edit scenes expose original character rigs and parts in the normal Scene
tree. Inspector material/transform changes are saved as sparse edits; original
geometry, rigs and unchanged textures remain disc-backed and are excluded from
export. Custom Mesh resources and compatible complete rigged models are supported.
The catalog now includes textures, can list a selected model's texture IDs, and
can assign PNG/WebP replacements in the active workspace. Original resources are
marked to reject accidental export. Bone-contract changes and missing original
mesh slots are rejected. Detailed vertex modeling and painting still use external
tools. See `docs/GODOT_MODDING.md` for the workflow. Saving inactive map tabs also
now preserves visibility and authored-child transforms without requiring those
tabs to be inside the live editor tree.

Validation: the Godot CPU/GPU suite, 19 Python tests and TCP readback pass
(`build/godot-editing-tests.log`, run `859c5a206e7744cabe12b7f273049dfd`). Seven
standalone SDL GPU CTests pass (`build/godot-color-native-ctest.log`); those tests
require SDL rather than the Godot transport without a server. The final Godot
game/launcher build and four geometry/light/launcher CTests pass
(`build/godot-editing-final-build.log`, `build/godot-editing-final-ctest.log`).
The final sparse-asset test and normal headless editor import pass
(`build/godot-editing-final-authoring.log`, `build/godot-editing-final-editor.log`).

An actual disc-backed guard with 16 parts and 23 texture IDs round-trips through
the editor, and its exported material edit loads in a 900-frame launcher boot
including the opening cinematic alias (`build/godot-editor-zip-boot.log`). The
scripted editor workflow assertions pass, but its custom editor main loop emits
Godot progress-dialog errors and requires terminating the owned test process;
this is not a clean manual UI acceptance run. The ordinary editor import has no
such errors. The separate SDFGI trial's short steady 1440p dock check measures
59.940 FPS, P99 16.6835 ms, maximum 16.693 ms and zero frames more than 2 ms over
budget (`build/godot-editing-performance.log`). This does not establish campaign
performance; cutscene pacing work remains deferred. Aislop reports no findings;
cppcheck and clang-tidy are unavailable, and its GLSL scan has no supported files.

## Godot event lights and SDFGI trial — 11 October 2026

Current-build handoff: the full `build/windows-x86-godot` build succeeds
(`build/godot-current-build.log`); the native game and launcher were already
current. The x64 GDExtension build also reports no pending work. Seven selected
native/launcher CTests pass (`build/godot-current-ctest.log`), and the complete
Godot CPU/GPU suite including the native extension, 13 Python tests and TCP
readback passes (`build/godot-tests/2c65f32a8ba44331895f49cfa0b40b8e`).
Start `build/windows-x86-godot/RE-INTEGRAL.exe`; it uses the current renderer
project and its MBAO setting. Select the SDFGI trial ZIP below for SSIL-off
bounced lighting. This is the local development build, configured as Debug.

Protocol v8 now transfers the native temporary-light pool and weapon attachments.
The original FAMAS flash animation and wall-impact spark actor already call
`DG_SetTmpLight`; their positions, animated radii and lifetimes now drive
shadow-casting Godot omni lights. Original soldier/DMO weapon glows were sprites;
the corresponding `glight` and `famaslit` attachments now also drive shadow-casting
spotlights down the barrel. Invisible/uninitialized attachments are omitted, and
retired primitive addresses receive new light identities when reused. Native
gameplay, animation and collision remain authoritative.

Map scenes expose ordinary `TemporaryFlash` and `WeaponSpot` light nodes under
the hidden `EventLightTemplates` group. Their Godot Inspector properties configure
the spawned lights. Old packages use the same default templates. ZIP export now
uses the manifest of the currently edited mod scene, including separate trial
mods, instead of always exporting `mods/local`. Export still excludes original
geometry, materials and local disc references.

The requested SDFGI/SSIL-off trial is
`build/mod-exports/local-780062320-sdfgi.zip`, authored in
`renderers/godot/project/mods/sdfgi-trial/stages/s00a.tscn`. It derives from the
user's `local-780062320.zip`; the original ZIP's SHA256 remains
`BF0DBC8F98FC3F14B19BCEEBF4CF0F416357AF1985856C37BBA882ECBB30B81D`.
The user's newer `mods/local` scene is preserved. The trial keeps the original
lights/fog and enables SDFGI with four cascades, 0.25 m cells, occlusion, no sky
input, energy 1 and bounce feedback 0.5. SSIL is off; SSAO stays on. Only opaque
declared map geometry contributes static GI; animated actors receive GI without
being voxelized, as do transparent effects. Custom mod geometry keeps its authored
GI mode. There is no original-asset bake to package.

Godot 4.8-dev7's project-wide
`rendering/lights_and_shadows/multi_bounce_occlusion/enabled` is now true.
Multi-bounce AO corrects the shading of SSAO/material AO; it still needs an AO
source and works alongside SDFGI. Both editor and launcher-prepared projects use
this setting. The pinned engine recognizes it; the trial reports SDFGI=true,
SSIL=false and SSAO=true (`build/godot-mbao-settings.log`).

Verification:

- Native build and six selected CTests pass, including attachment transforms,
  light lifetime/visibility, temporary-light encoding, zero-pose rejection and
  launcher ZIP selection (`build/godot-event-ctest.log`). Bootstrap verifies all
  90 MGS / 27 PsyZ patches; the new hooks are in
  `patches/mgs-godot-event-lights.patch`.
- Godot CPU/GPU, 13 Python conversion tests and fragmented TCP upload/readback
  pass with MBAO enabled (`build/godot-tests/8133f4ec2ec24d3ab0a0e27c227dda84`).
  Rendered event-light tests verify both omni and spot shadows. The actual
  reference shader produces 10860 green bounce pixels in the SDFGI fixture and
  illuminates the dynamic receiver with SSIL disabled. Scene save/export tests
  preserve authored spotlight settings without shipping original geometry.
- The real launcher/ZIP dock run at 2560×1440 averages 59.922 FPS across 700
  measured frames after 1100 warm-up frames: P99 16.684 ms, maximum 18.539 ms,
  zero frames exceeding native 59.94 Hz budget + 2 ms. Evidence:
  `build/godot-performance/17443d139f374c9aa60aa48003b5244a`.
  This is a short steady-dock check, not whole-game stable-60 acceptance.
- A separate dock visual run reports two live native weapon lights and no
  renderer errors (`build/godot-effects-s00a-4ac5f2e648fa4fa4991c94237a3285b3`).
  A human gunfight/weapon-beam placement review is still pending. Screenshot
  readback stalls are excluded from performance evidence.
- Changed-project Aislop scores 100 with zero findings
  (`build/godot-mbao-aislop.json`); cppcheck and clang-tidy are unavailable.
  The four touched vendor files retain two nonfixable findings: the inherited
  seven-parameter `SetParam`, and a false positive for `chanl.c`'s label after
  `return`, which is reached by `goto` (`build/godot-event-vendor-aislop.json`).
  No rules were disabled. The non-patch working diff passes whitespace checks.

Remaining cutscene shadow-preparation hitches stay deferred at the user's
request. Next acceptance is the user's lighting/mod workflow review with the
trial ZIP; native muzzle/impact light placement also needs a live combat review.

## Godot cinematic overrides and physical effects — 11 October 2026

The requested `build/mod-exports/local-780062320.zip` is now the verification mod.
Its archive and authored environment/lights remain unchanged. `d00a` inherits the
`s00a` overlay and `d01a` inherits `s01a` unless an exact cinematic override exists.
Model, texture, PBR and removal rules are remapped only when original resource
hashes match. The live stage and native actors remain cinematic; visual overrides
do not change gameplay, collision or cutscene timing.

Protocol v7 transfers live water, ripples, bubble actors (including the three-texture
opening DMO bubbles), breath/smoke, fog and casing quads to Godot. Original animation,
UVs, fades and blend modes are retained. Supported transparent KMD surfaces also
receive Godot lighting. Effects reuse meshes and geometry textures, blend without
writing depth, then write depth in a colorless pass for native command composition.
Ripples use a 1 mm depth bias above coplanar water; small ring normals no longer
switch abruptly to a camera-facing fallback. GPU regressions cover overlapping
particles, coplanar ripples from different camera angles, foreground occlusion,
dynamic lighting/shadows, alpha/additive composition and animated fades.

The guard's glowing waist was a separate ownership bug: `96b6.k` part 0 has two
textureless, permanently collapsed faces. They sent the entire otherwise textured
waist through the original baked-lighting renderer. Repeated-corner classification
now keeps that part in Godot and discards only its empty surfaces. Indirect vertices
with different bone references remain distinct; visible runtime-textured parts
still use the command renderer. Native geometry and Godot mixed-surface tests pass.
The elevator shot at frame 3300 confirms that the bright waist band is gone.

Lit models now use Godot's face culling instead of discarding faces rejected by
the original low-resolution projection. Such faces use prepared UVs rather than
stale packet coordinates. Native actor/part visibility and visual removals still
apply. The GPU regression renders a lit imported mesh with all native face flags
culled; it remains visible and responds to a moving light. The subsequent animated
intro and elevator wide shots are in
`build/godot-effects-title-60f2dea1a0d1498099c8246d631499de` (frames 3000/3300).

Stage textures and initial model materials prepare during loading. Effect batches
reserve 1024 quads so growing bubble bursts reuse their mesh and geometry texture.
Representative shader/skin formats warm up before native startup. The temporary
viewport covers cube/dual-paraboloid omni, spot, directional and area lights;
it is removed before play and does not change the mod's environment or lights.
The actual dock ripple sequence at frames 1200–1212 expands and fades without
partial-ring loss (`build/godot-effects-s00a-9a2b95fc523d4f0f95d1c0a8382c8f09`).

Verification so far:

- Native build and seven selected geometry/visibility/timing/video/launcher CTests
  pass. The complete Godot CPU/GPU suite, 13 Python conversion tests and fragmented
  TCP upload/readback check pass (`build/godot-all-light-tests.log`). Added GPU
  checks verify moving skinned shadows under spot, directional and area lights,
  in addition to the existing omni coverage; all pass.
- Full title → New Game → `d00a` → `s00a` introduction runs to the dock Codec with
  no post-title input. Visual evidence is in
  `build/godot-effects-title-e69ab2af8507494c824b750b7937066b`.
  Direct `--stage d00a` is only a static map diagnostic and does not start the DMO.
- Bootstrap verifies all 89 MGS and 27 PsyZ patches. The effect hooks are reproduced
  by `patches/mgs-godot-world-effects.patch`.
- Changed-project Aislop: 100, zero findings. The nine-file vendor scan retains five
  inherited nonfixable function-length/parameter-count warnings and one false
  positive: `chanl.c`'s label after `return` is reached by a valid `goto`.
  Applicable scans lack clang-format/cppcheck/clang-tidy. Rules remain enabled.

The latest 1440p dock test through the real ZIP-selection/launcher path passes:
59.940 FPS, P99 16.684 ms, maximum 16.701 ms, zero frames over budget + 2 ms in
2500 measured samples (`build/godot-performance/d8062233f7344814bbc7489ecdffcfc5`).
The latest full intro without screenshot readbacks averages 59.830 FPS, P99 16.706 ms,
with 11 frames over budget + 2 ms and a 55.243 ms maximum across 3948 active DMO
samples (`build/godot-effects-title-ab7b6a08147f4e54b0eaec49950ac940`).
The cutscene still does not meet the requested stable-cadence acceptance.

RenderingDevice timestamps locate the repeatable first camera-change hitch in
Godot's omni shadow preparation: 35.531 ms CPU versus 1.135 ms GPU in that section
(`build/godot-effects-title-9acc98a3fcb14d599a0143392b3b8a50`). This is outside the
GDScript scene update and native command submission. Larger artificial shadow
warm-ups reduced that first stall but worsened subsequent cadence, so they were
discarded. Explicit drawing, a separate render thread and a D3D12 comparison did
not improve pacing either; production keeps the existing Vulkan/Forward+ path.
Resolving shadow preparation without changing authored lights remains open and is
deferred at the user's request. Work continues on the Godot editor/mod workflow,
including native muzzle/impact lights and weapon-mounted soldier spotlights.

## Godot steady gameplay performance — 11 October 2026

The user's minimum target is stable 60 FPS. The native NTSC clock remains 59.94 Hz;
gameplay, authored lighting/shadows, PBR materials and output resolution are unchanged.
Frame-by-frame measurements separated loading from steady gameplay. The initial
1440p dock run still averaged 59.222 FPS after frame 1100, with P99 25.307 ms,
maximum 40.789 ms and 31 frames over budget + 2 ms in 1301 samples
(`build/godot-perf-baseline`).

Fixed three sources of stalls:

- Windows loopback sometimes delivered the first 196485 scene bytes immediately,
  then waited 25–32 ms to deliver the remainder. Native writes now use 16 KiB chunks;
  Godot drains available bytes in the same iteration. Protocol v6 and ordering remain
  intact. The cadence CSV now measures bridge exchange time in `submit_us`.
- Removed forced unbuffered native stdout. Redirected diagnostic/probe lines caused
  repeatable 15–19 ms stalls on the game thread. Default buffered output is retained
  and flushed by normal process exit.
- Reused identical surface materials within each character, keyed by texture,
  culling and lighting mode. Materials remain separate between actor palettes.
  First model swaps no longer build duplicate materials for every mesh part.
  Shadow visibility now sets the final casting mode directly instead of toggling
  it off and back on for every snapshot.

The real launcher/mod path with `build/mod-exports/local-474555866.zip`, Forward+
and 2560×1440 measured **59.937 FPS, P99 16.685 ms, maximum 17.017 ms**, with zero
frames over budget + 2 ms across 2500 measured VSyncs after the 1100-frame warmup.
Evidence: `build/godot-performance/663878e8d98943c0bcad79e77b02622d/summary.json`,
`timing.csv` and logs. Measurements use the existing dock probe, not a manual
playthrough or a whole-campaign performance claim. Loading remains excluded.

A longer confirmation run measured **59.938 FPS, P99 16.6835 ms, maximum
16.9681 ms**, again with zero frames over budget + 2 ms, across 4900 measured
VSyncs after the same warmup. It submitted 59,489 world composites, with the
selected ZIP verified active. Evidence:
`build/godot-performance/7d0477e44d754a7cb1e775a23c3e363c/summary.json` and adjacent
logs/timing CSV. This is the rebuilt Debug native runtime with the pinned
Godot 4.8-dev7 Forward+ Vulkan renderer on the local RX 9070 XT.

`tools/test-godot-performance.ps1` installs a chosen ZIP into a private test project,
uses the launcher path and records every VSync without screenshot readbacks. It
reports percentiles and fails on slow frames or an average outside the native
cadence tolerance. `MGS_CADENCE_ALL_FRAMES=1` enables buffered complete timing CSVs;
normal slow-frame diagnostics remain available.

Validation: native, launcher and mod test harness build targets pass; six selected
frame-timing/video/visibility/launcher CTests pass. Godot CPU/GPU suite and 13 Python
conversion tests pass, including a new fragmented 256 KiB upload/readback check,
PBR lighting, imported-map lighting, characters casting shadows, 2D sampling and
depth/order composition. Project Aislop scores 100 with no findings. The scoped
PsyZ scan retains five inherited nonfixable file/function-size warnings;
clang-format, cppcheck and clang-tidy are unavailable to the applicable scans.
`git diff --check` passes. Bootstrap verifies all 88 MGS and 27 PsyZ patches,
including `psyz-godot-exchange-timing.patch`.

## Godot overlay, tiled images, legacy effects and pacing — 11 October 2026

Rebuilt the Godot native executable with protocol v6. Native debug text (including
FPS/frame/MAX and controller prompts) now reaches a Godot overlay. The launcher
checkbox works, and `run-godot.ps1` accepts `-DebugOverlay`. Renderer counters
report draw/world commands, copied MiB, CPU submission and scene-update time;
these are not GPU timings.

Scaled polygons now divide their pixel-center offsets by the render scale. The
tiled-image GPU regression checks every scaled sample, and the real Konami logo
has no central split (`build/godot-logo-fixed-000300.png`). Legacy shadow-textured
models/FT4 shadow packets and static emitter halos are suppressed only in Godot
3D mode. Actor behavior and other transparency/effects remain active. The user's
existing `local.visuals` ZIP loads unchanged; authored lighting was not altered.

DRAW now carries clipped batch bounds and texture/destination dependencies.
Dirty-region snapshots avoid copies for opaque draws and ordinary WORLD passes;
destination blends copy their bounds, while framebuffer feedback retains all
required source writes. Dock copy samples fell from about 126 MiB to 6–14 MiB per
rendered frame. Tests cover tiled rasterization, mask preservation, blending after
skipped copies, uploads/moves, native readback and world detail.

The 240 Hz Godot loop also delayed synchronous native requests. Buffered commands
resume after completion, and the loop cap is now 1000 Hz; native VSync remains
authoritative and the 3D viewports update only for new scenes. Matched 1800-VSync
dock checks with the same ZIP/settings measured 50.56 versus 58.32 average FPS,
584 versus 34 frames over budget + 2 ms. Evidence is under
`build/godot-pace-s00a-{240,1000}`. Each includes startup, one screenshot readback,
and eight empty audio refills; this is scoped timing evidence, not steady-state
performance acceptance under an otherwise idle GPU. Loading stalls remain.

Validation: CPU/GPU Godot suite and 13 Python conversion tests pass; five selected
visibility/video/launcher CTests pass; real modded dock and startup-logo boots pass.
Project Aislop has no errors/warnings. Scoped vendor scans retain six nonfixable
file/function complexity warnings; optional C lint/format tools were unavailable.
Bootstrap verifies 88 MGS and 26 Psyz patches. Pre-existing unexported presentation
and Remix input hooks were preserved in separate `*-existing-*.patch` files so
the pinned source stack reproduces the working tree; no new Remix behavior was added.

## Runtime character and omni-light shadows — 11 October 2026

Confirmed the user's game uses Vulkan / Forward+ at 2560x1440. Removed the
runtime-only 2048 shadow atlas override; the world viewport now inherits the
project's atlas size (4096), depth precision and quadrant subdivisions.

Protocol v5 separates camera-visible parts from active shadow casters. Native
camera bounds no longer hide geometry needed by omni shadow maps; inactive map
groups, game-hidden actors, unused parts and mod removals still suppress it.
Animated bone transforms continue to update offscreen. Original-color and PBR
shadow passes ignore camera face visibility and retain prepared UVs when native
face packets are absent. Replacement meshes retain authored Cast Shadow settings.
The native backend is rebuilt; existing ZIPs need no re-export.

Validation: GPU regression renders a skinned caster with no camera-submitted
faces and absent live UVs, measures 1,365 shadow pixels in both material modes,
checks animated shadow movement/removal, and checks two camera distances with
13 competing omni lights. A guard from the real dock runtime (`96b6.k`) casts a
1,071-pixel shadow in an isolated receiver check. The full Godot CPU/GPU suite,
five targeted visibility/video/launcher CTests, and a 1,800-VSync modded disc boot
pass. Evidence: `build/godot-shadows-suite.log`, `build/godot-shadows-boot/`,
`build/godot-character-shadow-real.png` and its log. Aislop reports zero findings;
cppcheck/clang-tidy are unavailable. Camera-route and performance acceptance
remain with the user; the native build retains its existing getenv deprecation
warning. No original assets were added to source or mod archives.

## Godot launcher rendering and resolution — 11 October 2026

Fixed the launcher starting Godot with scene rendering enabled while omitting
that setting from the native process. The native runtime consequently kept
drawing its original packets even though Godot reported the selected mod as
loaded. Both processes now enable scene composition. The previous short ZIP
boot checks stopped during Codec and did not establish visible mod application.

The output resolution now also scales Godot's world and composition targets.
Previously it only resized the window and enlarged the native image. A separate
scaled VRAM target preserves mesh detail through HUD/effect composition, masks,
uploads and moves; native texture/CLUT lookup and readback retain their original
dimensions. `run-godot.ps1 -Resolution` uses the same path. The view remains 4:3.

Rebuilt `build/windows-x86-godot/RE-INTEGRAL.exe`. Existing installed ZIPs and
saved selections are preserved; restart the launcher to use the updated code.
The user's actual selected package, `local-474555866.zip`, runs unchanged in a
1,800-VSync dock check at selected resolution 2560x1440. The composed image at
frame 1,200 shows its blue lights and fog; this is beyond the earlier Codec-only
check. A second run with that installed ZIP disabled restores the original
lighting, verifying the saved enable/disable selection reaches the renderer.
Evidence: `build/godot-visible-mod-1440p/render.png`,
`build/godot-disabled-mod-1440p/render.png` and adjacent logs.

Validation: all three launcher CTests and the Godot CPU/GPU suite pass. The new
GPU test distinguishes high-resolution detail inside 2,304 native pixel blocks
and checks masks, composition, uploads/moves and unchanged native readback.
The lighting test also covers assigning the runtime PBR shader after its texture
parameters, matching production. Aislop reports zero findings; cppcheck and
clang-tidy are unavailable. No gameplay or performance acceptance is claimed.

## Godot mod ZIP launcher — 11 October 2026

Added the missing user-facing installation flow: the Godot build's launcher
has a Mods tab with a multi-select ZIP picker, enabled checkboxes and removal.
Selections persist in settings; selecting another ZIP with the same mod ID
updates that selection. Packages install privately without changing source ZIPs.
The launcher prepares and imports a private runtime project containing only
enabled packages, then starts the matched Godot/native pair. Unchecked native
extensions and editor-local mods cannot leak into that project. Imports are
cached by source/content hash. User saves stay in the existing launcher directory.

ZIP validation rejects traversal, absolute/reserved paths, duplicate paths,
symlinks, missing manifest resources and oversized archives. Failed installations
use isolated staging; existing installations remain intact. This is available
in the source Godot build with prepared disc content, not the published native
alpha package. No new distribution of original assets is involved.

Validation: launcher settings/import/mod CTests pass, including ZIP updates,
invalid packages, persisted selections, disabling mods and import-cache
invalidation. UI smoke renders confirm the Mods tab. The user's exported
`local-476755079.zip` installs and loads its `s00a` overlay during a 900-VSync
native/Godot disc boot. A second ZIP verifies automatic custom-PNG import and
stage loading. The actual launcher checkboxes persist their state and its Save
and play button completes a modded boot and clean shutdown. Evidence:
`build/godot-zip-boot/logs`, `build/godot-zip-texture-boot/logs`,
`build/godot-zip-ui-check.log`, `build/godot-zip-ui/launcher-4.png`.
Aislop reports no findings; cppcheck/clang-tidy are unavailable. These are boot
and UI checks, not gameplay or performance acceptance.

## Direct disc maps in the Godot editor — 11 October 2026

Fixed imported geometry ignoring authored lights: native KMD normals point
inward because `libdg/pshade.c` lights them with vertex-minus-light vectors.
The glTF converter now reverses those normals for Godot without changing face
winding, positions, rigs or native vertex-color ordering. Rebuilt the local
prepared cache; existing editor sessions must reopen their maps to load it.

Validation: a synthetic KMD floor goes through the production converter and
disc-map loader, then GPU tests exercise ordinary OmniLight3D lighting/movement,
editor StandardMaterial3D, runtime PBR and shadow reception. Before the fix both
materials produced zero illuminated pixels; afterward both produce 9,738, and an
inverted-normal control still reproduces the failure. The CPU/GPU renderer suite
passes (native GDExtension rebuild skipped; no native changes). Actual docks and
helipad renders use the rebuilt geometry and original lights. Evidence:
`build/godot-normals-suite.log`, `build/godot-normals-real.*`,
`build/godot-original-lights-*.png`. No gameplay or performance acceptance claimed.

Follow-up: map models/parts and original lights now appear in the native Godot
Scene tree. Names carry model IDs; full IDs appear in tooltips. Removed the
duplicate originals list and light/PBR/removal wrappers. Ordinary visibility or
Delete/Undo records visual removals. Standard original-light Inspector edits are
saved as property deltas. Editor save hooks exclude reference geometry and light
defaults while preserving authored nodes, including nodes placed under originals.
Duplicated original mesh parts retain provenance and are rejected by mod export.

The prepared catalog now decodes the original `DG_LITS`/`DG_LIT` `.l` layout,
selected through the recovered `GM_CreateMap`/`GM_SetMap` declarations. Docks has
74 declared lights; helipad has 96. Both editor and renderer instantiate these
as ordinary OmniLight3D nodes with shadows. Positions/RGB/range data are native;
Godot radial attenuation approximates the original vertex-light function and
box cutoff. Temporary actor lights are outside the static importer. New overlays
no longer insert an invented starter lamp/fog environment; existing edits remain.

Validation: actual editor Scene-tree items contain model/light IDs for both
maps, selection works, ordinary edits save/reopen, and ZIP export excludes
originals. Regression tests cover visibility/deletion/restoration, light deltas,
runtime placement, nested authored nodes and rejection of copied retail meshes.
CPU/GPU renderer checks pass. Evidence: `build/godot-native-editor-ui.*`,
`build/godot-native-editor-tests.log`, `build/godot-original-lights-*.png`.

The user rejected the F7-dependent map authoring workflow. MGS Visuals now has an
**Open map** action that opens the local mod overlay and assembles its original
reference directly from prepared disc assets. No running game is required.
Preparation decodes top-level GCX startup `mapdef` and `map -d` declarations using
the recovered loader's structure, rather than treating every model in a stage as
map geometry. Docks uses two declared models (204 mesh parts); helipad uses one
(122 base parts). Script-created/animated actors remain outside this static map
importer's scope. The browser still exposes docks/helipad only.

Editor references use textured, lit StandardMaterial3D materials with the
model's face culling for inspection and authored light preview. Original geometry
is excluded from saved mod scenes. The old screenshot's checkerboard
error was reproduced: an embedded generated shader retained a raw `#include`
that failed when the saved scene reopened. Generated shader variants now expand
their shared source before assignment; the new map workflow does not use those
live-frame shaders.

The user's upside-down map report exposed a world/camera axis mix-up: native
world Y points up (for example, `game/item.c` applies negative-Y gravity), while
prepared renderer models use `(x,-y,-z)`. Map references now rotate into native
Y-up editor space. New authored scenes identify their coordinate convention;
the runtime converts their transforms on load. Opening older overlays migrates
their authored transforms once without moving them in game or changing removal
selectors. Existing exported overlays remain compatible. Coordinate regressions
cover native placement, save/reload, nested lights, old-scene migration and
unknown coordinate spaces. Docks/helipad renders and real editor save/export
checks pass, as does the CPU/GPU renderer suite. Evidence:
`build/godot-disc-map-upright-*.png`, `build/godot-upright-*.log`.

Disc-backed renders and map parsing/assembly/export checks pass. The existing
CPU/GPU renderer suite passes with the new map checks. A separate editor instance
also exercised Open map for both stages, selection, part removal, light/object
addition, saving and ZIP export; its saved overlays contain no original geometry.
The glTF loader explicitly converts editor importer meshes into renderable nodes
and loads local textures in memory, avoiding editor reimport attempts outside the
project. Evidence is under ignored
`build/godot-disc-map-*`. Original discs, existing local edits and old scenes are
preserved. Performance has not been assessed.

## Godot GDExtension, PBR and map overlays — 11 October 2026

Implemented the user's follow-up requirements in the Godot process:

- Native visual mod API v1 loads declared GDExtensions, checks their lifecycle
  hooks and initialization result, exposes stage/camera/instance inspection and
  emits stage/snapshot signals. A Windows x64 C++ example animates a shadow light.
  `tools/build-godot-mod.ps1` builds it against godot-cpp pinned in the source lock;
  the 32-bit gameplay executable is unchanged.
- Original meshes can use albedo, normal, ORM and emission maps with metallic,
  roughness and normal/emission factors. Godot-lit materials use specular GGX,
  receive/cast dynamic shadows and retain native UV/visibility data. Normal
  mapping derives tangents from the live UVs. Authored Standard/ORM/ShaderMaterial
  overrides are preserved on replacement meshes.
- MGS Visuals opens captured maps as unsaved local references, adds shadow lights
  and PBR objects, and records object/part removals as stable asset/position rules.
  Matched removals survive actor motion and model swaps. The user explicitly chose
  visual removal only; collision/gameplay are unchanged. Compatibility-only
  effects are outside the current scene-editing scope.
- ZIP export follows custom-resource dependencies, makes resource paths portable,
  excludes the local preview, and rejects embedded retail-derived scenes and
  dependencies outside the mod folder. The generated map example contains only
  IDs/edit instructions, one authored scene and two procedural PBR maps; its
  exported ZIP is approximately 2.4 KB. Original models/albedos stay in the local
  disc cache. Native extension binaries can be packaged separately.

Validation: the pinned editor loads the plugin; the C++ DLL builds and loads;
extension lifecycle, map packing/removal/export, manifest/rig and scene snapshot
tests pass, including an exported/relocated native DLL and nested authored
scene/script/material dependencies. Literal script `load()` paths are rejected
with guidance to use `preload()`; dynamic dependency discovery remains unsupported.
GPU tests prove moving lights/shadows, metallic and roughness response,
normal/ORM/emission maps, while the existing protocol/composition and six asset
conversion tests pass. Tests also reject retail-preview export and outside-folder
dependencies. The scoped Aislop scan reports no findings on its supported files;
GDScript/shaders are checked with Godot, and optional C++ lint engines are unavailable.

The combined native extension + PBR map overlay passes all 1,446 recorded dock
inputs / 1,450 VSyncs. A separately extracted package at a different path passes
the same replay; logs confirm the native extension, stage override and removal.
Screenshots show the added sphere and changed lighting/materials. Godot logs are
error-free. Evidence: `build/godot-sdk-*`, `build/godot-tests/` and
`build/mod-exports/map-overlay-demo-final.zip`. Performance remains unassessed
while another game is running. Human authoring/playthrough and broader stage
coverage remain distinct from these scoped automated checks.

## Godot v4 renderer and visual mod workflow — 11 October 2026

The user selected Godot as the primary renderer and modding SDK/editor direction.
The roadmap and project instructions now reflect that choice. Remix Plus is
preserved as a separate experiment with further integration work deferred.
The recovered C runtime remains authoritative for gameplay and the native alpha
remains the playable baseline.

Completed the matched v4 consumer: live packet UV/ordering and face visibility,
metadata camera and depth capture, original color quantization/dithering and
STP masks, synchronized scene composition, and Godot-lit original materials.
Custom foreground geometry uses its own depth rather than metadata belonging
to background geometry. Material resolution follows native ownership, and
missing textures on visible Godot parts are explicit errors. Retired models
detach immediately; editor exports omit runtime metadata and compositors.

The native Godot executable rebuilt in `build/windows-x86-godot`. Four native
video/visibility CTests pass. The new `tools/test-godot.ps1` passes scene decoding,
mod/rig contract, six asset conversion, GPU protocol and composition tests.
The pinned headless editor imports the project without errors. Scoped Aislop
reports no findings but scores no files: its installed engines do not cover
the changed GDScript, shaders, PowerShell or documentation. Godot validates the
scripts/shaders; this is not a 100/100 static-analysis claim.

Real local-disc evidence:

- No-input startup reaches the opening at 1,800 VSyncs without renderer errors.
- The unskipped opening passes all 4,496 inputs / 4,500 VSyncs in scene and
  command modes. Captures show aligned scenery/cameras with expected geometric
  differences; particle/effect equivalence remains subject to visual review.
- The dock mod replay passes 1,446 inputs / 1,450 VSyncs with replacement model,
  checker textures and stage lighting active together, with no Godot errors.
  Captures visibly confirm the replacements and stage preview export works.
- Local asset preparation reproduces all 2,018 stable identities / 175 models.
  Synthetic tests check resident IDs across stage changes and preview reloads.
- A separate heliport checkpoint replay passes 2,996 inputs / 3,000 VSyncs,
  including Codec and movement, in scene and command modes with no Godot errors.
  Matched Codec captures and scene-mode gameplay were inspected. This does not
  validate the dock-to-helipad transition.

The historical Xbox route fails at inventory sample 3,606 / VSync 3,610 in both
scene and command modes (expected `-178662692`, actual `1877702569`). No replay
checks were weakened; this run cannot supply current transition acceptance.
Performance remains unassessed because the user was running another game.
Evidence is retained under `build/godot-v4-*` and `build/godot-tests/`.

Next: current transition evidence, human visual review, effects migration and
isolated frame-pacing measurements. Full campaign rendering and a stable public
gameplay/audio/script SDK remain future work. See the
[active integration milestone](docs/GODOT_RENDERER_PLAN.md#active-direction-11-october-2026).

## Launcher 240p comparison preset — 11 October 2026

The display dropdown now includes `320x240`, with a hint to disable widescreen
for original 4:3 output and 1× internal rendering. The alpha instructions explain
the comparison settings and distinguish the developer frame count from an FPS
cap. The existing renderer already supports this mode; rendering and timing
code are unchanged.

The modern launcher compiled and its UI smoke check passed. All four scoped
CTest suites passed: launcher settings, video CLI, resolution parsing and original
aspect. Aislop reports 100/100 with no findings; formatting and lint engines have
no support for the changed languages. The rebuilt launcher is under
`build/windows-x86-modern/RE-INTEGRAL.exe`; the published download is unchanged.
Next: record and assess the user's comparison footage.

## Alpha 0.2 published — 10 October 2026

Published [0.2.0-alpha.1](https://github.com/Drommedhar/mgs-reintegral/releases/tag/v0.2.0-alpha.1)
from `a6cf2278b1d54e1d71ebfd286b3098a07cc066fe` after
[release run 38079640612](https://github.com/Drommedhar/mgs-reintegral/actions/runs/38079640612)
passed all 147 hosted tests and the unpacked download checks. The local build of
the same commit passed all 170 tests, including GPU readback and joint geometry.
Downloaded all four release assets; the three ZIPs match their published SHA-256
sums. The downloaded player package passes version/source identity, Unicode
paths, read-only disc checks, importer startup without Python on PATH, UI smoke
checks, and accompanying modern-renderer source checks. The published importer
bundles x64 Python 3.12.10; the game remains x86.

The downloaded executable booted real Integral discs into the briefing with all
three graphics options, faster loading and the local German text/speech pack.
It selected Disc 1 VOX sector 7 and exited normally after 1,500 VSyncs. Evidence
is under ignored `build/alpha-0.2-published/`; this is a boot/stream-selection
check, not a localized playthrough. No retail packs were uploaded. Release scans
have no errors or fixable warnings; the inherited long `main` warning remains,
and cppcheck/clang-tidy are unavailable locally.

Version `0.2.0-alpha.1` builds the modern renderer with enhancements disabled by
default, the joint/subdivision seam fixes, optional faster map loading, and the
local regional-language importer. Release automation tests the asset-free suites
and unpacked download before publishing. Tests requiring GPU readback run locally;
the hosted runner excludes them. The accompanying source ZIP includes the modern
renderer and its shader sources. Generated language packs remain excluded.

## Optional regional localization — 10 October 2026

The launcher now provides **Languages → Import from discs…** with regional
release selection, four disc pickers (Integral paths prefilled), progress, logs
and cancellation. Import runs from a bundled x64 Python executable; players need
no Python installation or network connection. Temporary extraction stays inside
a unique profile-local staging folder. The native validator checks the completed
pack before the folder is renamed and the text/speech settings are selected.
Failure/cancellation removes unfinished output and leaves existing packs intact.
Release packaging includes the importer and its runtime notices, rejects retail
asset extensions, and excludes all generated packs. `.mgslang` is ignored globally.

Launcher import validation: both launcher builds compile; all five relevant CTest
suites pass in each build (settings, import workflow, bundled importer, language
packs and content import). Synthetic workflow tests cover repeat imports,
nonzero exit, corrupt output, missing receipt, cancellation, Unicode paths,
source preservation and staging cleanup. The unpacked player ZIP passes checks
with Python absent from PATH, including importer startup, invalid-disc rejection,
notices and UI smoke captures. The scoped Aislop scan reports zero findings.
A real German import through the launcher service produced 2,667 records with
the same SHA-256 as the existing CLI pack, then passed native validation. A
1,500-VSync Integral briefing boot with that pack selected VOX sector 7 and
rendered German captions. Evidence stays in ignored `build/language-launcher-check/`.
This is scoped import/playback verification, not a full localized playthrough.

Implemented local English/German packs with an importer that validates the donor
and Integral executable revisions, records source hashes, and reports disc-specific
coverage. Launcher and CLI selections are optional. Inventory descriptions,
German glyphs, matched text, speech and cinematic audio/captions use donor assets;
Integral scripts, stages and animation stay in use. Codec segment mismatches and
unmatched references retain Integral. Movie/XA localization and complete German
coverage remain outstanding. See [usage and limits](docs/LANGUAGES.md).

Pack checksums/framing, malformed-input handling, animation preservation, ambiguous
mapping rejection and recording identity have asset-free regression coverage.
Record/replay/resume identity includes selected pack hashes. Retail data and local
coverage receipts stay under ignored `.local/languages/`.

Validation before the launcher importer: reference Debug 164/164 and modern RelWithDebInfo 168/168 CTest
cases pass; the registered vendor patch passes bootstrap verification. Real-disc
boots selected the German opening, briefing and initial dock Codec streams.
Inspected captures show German Codec text and German briefing glyphs. German
coverage is 449/1,108 and 311/754 VOX entries, plus 119/119 DEMO entries; excluded
dialogue and movies remain Integral. Full playthrough and perceptual audio sync
remain for human testing. Aislop reports no errors or fixable warnings; the
existing long native startup function is still flagged, and cppcheck/clang-tidy
are unavailable in this environment.

## Regional language source audit — 10 October 2026

Inspected the newly supplied US English (`SLUS_005.94` / `SLUS_007.76`) and
German (`SLES_015.07` / `SLES_115.07`) campaign pairs alongside Integral.
Both donor pairs contain full campaign resource banks, including Disc 2.
Recorded image/executable/resource hashes and parsed all twelve VOX/DEMO banks.
Original images and the MGSR project were preserved; extracted content and
detailed reports remain ignored under `build/language-audit/`.

The [language resource audit](docs/REGIONAL_LANGUAGE_RESOURCES.md) records
identical Codec portrait assets, verified opening English payload matches,
different Codec addressing, German font encoding and PAL timing, dynamic UI
text offsets, and Integral-only content requiring explicit mapping/fallback.
Recommended first implementation: selectable English UI resources, retaining
Integral speech/gameplay, followed by German text/Codec and cinematic support.
This is asset/source analysis; no pack importer or runtime localization has
been implemented or playtested.

## Map loading pacing — 10 October 2026

Added opt-in **Faster map loading (experimental)** on the launcher's Gameplay
tab, `-FastLoading` in the run wrapper and `--fast-loading 0|1` in the engine.
It defaults off. The previous failed sector-batching loader remains removed.
The new host adapter removes presentation waits during the original stage-load
lifetime while retaining every loader/CD frame, texture allocation and cleanup.
The deterministic clock is selected before startup; normal pacing resumes at
load completion. A separate audio-output suppression flag preserves all SPU
samples/interrupts and independent caller pause state, then primes fresh output.
BGM behavior is unchanged. Replay records this as presentation metadata.

PAL `s16d` load: **3720.3 → 32.7 ms**; Ninja `s08b`: **2836.1 → 27.0 ms** at
2560x1440 with all modern geometry options. Both matched every recorded state
and produced byte-identical final captures. A PAL launch without recording
also matches the image. The existing New Game-to-dock and unattended opening
replays pass (4996 / 2496 inputs); the opening capture also remains identical.
One older `s11e` recording diverges at the same VSync 648 with the option off
and on, so it does not validate the later transitions in that recording.

Both x86 game/launcher builds compile; all **167 modern / 163 reference** CTests
pass, including loading-mode restoration, audio timing/pause, settings,
recording metadata and CLI checks. Bootstrap verifies **85 MGS / 24 PsyZ**
patches, including `mgs-loading-pacing.patch` and
`psyz-audio-output-suppression.patch`. Scoped first-party/audio scans score 100.
The original 142-line `SetupNextFile` retains one nonfixable complexity warning;
cppcheck/clang-tidy remain unavailable. Source files and the archive loader's
resource dispatch are preserved. Details and limits are in
[performance diagnostics](docs/PERFORMANCE_DIAGNOSTICS.md#map-loading), with
local evidence in `build/map-loading/`. Whole-campaign testing remains pending.

## Character joint seams and PBR removal — 10 October 2026

Removed the experimental PBR material/light/shadow implementation, its launcher
controls, F9 toggle, authoring tools and vendor hooks at the user's request.
The local dock launch script now uses original lighting with the three geometry
options. The removed experiment is archived in ignored
`build/pbr-removed-backup.zip`; existing local assets, recordings and saves remain
preserved.

The joint regression exercises the real `libdg` transform and packet writer:
integer face culling drops a subpixel-wide face that the precise renderer can
draw. Precision mode now evaluates face area from the same projected positions
used by the renderer. Nonzero areas retain their sign when converted for the
original ordering/subdivision metadata. Disabled precision and incomplete
projection data keep the original decision. Exact parent-vertex copying remains
unchanged. The integration is exported as `mgs-precise-face-culling.patch`.

The user's intro screenshot reproduced a second cause on the character's back
and arm in `opening`: subdivision projected rounded integer model midpoints,
moving split vertices away from shared edges. It now copies precise endpoints
through the subdivision scratchpad and computes depth-weighted fractional
midpoints, including recursive splits. Invalid source metadata propagates as
invalid. Original integer packets and subdivision decisions remain intact.
This integration is exported as `mgs-precise-subdivision.patch`.

Validation: both x86 builds compile. The culling/PBR changes passed all **166
modern** and **162 reference** CTests; after the subdivision fix, all **166 modern**
tests and the two relevant reference adapter/CLI tests pass. The 1x/4x pixel
tests cover thin faces, winding, double-sided faces, stale metadata, parent-joint
coordinates and identical coverage before/after recursive subdivision. Both
pixel regressions failed before their respective fixes. Adapter tests cover
unequal-depth midpoints, reversed edges and invalid metadata propagation.
The 1500-VSync real-disc dock probe retains matching player movement counters.
A 2500-VSync real-disc intro recording replays all 2496 inputs successfully;
the reproduced back/arm slits are closed in the matching updated frame with
all three geometry options enabled at 2560x1440. Captures are
`build/intro-seams/baseline.bmp` and `build/intro-seams/after.bmp`; earlier dock
evidence is `build/geometry-seams-*`. Bootstrap verifies **84 MGS / 23 PsyZ**
patches. Scoped source/vendor aislop scans score 100 with no findings;
`cppcheck` and `clang-tidy` remain unavailable. This confirms the reported intro
shot, not whole-campaign visual acceptance of the modern renderer.

## Modern renderer — 10 October 2026

The user requested correction of affine texture warping, then expanded the
scope to stable geometry and per-pixel depth as the foundation of our renderer.
The [experimental modern module](renderers/modern/README.md) builds in
`build/windows-x86-modern`; its launcher has independent, persisted switches
for perspective-correct textures, subpixel geometry and depth testing.
The normal build keeps the original renderer and rejects unsupported enhanced
rendering requests explicitly. All three enhancements default off.

Model vertices, including attached parent vertices and subdivided surfaces,
carry float projected geometry alongside unchanged PS1 packets. Opaque models
write reversed D32 depth; semitransparent models test without writing. HUD,
framebuffer effects and untracked primitives retain their original drawing.
This is an experimental model path, not a floating-point gameplay rewrite or
a completed modern material/mesh engine. Whole-campaign visual acceptance of
this new renderer remains outstanding.

Validation: the modern build passes all 164 CTests; the reference build passes
all 162. New tests check actual pixels at 1x and 4x for occlusion, depth reset,
transparent depth reads, perspective UVs, missing metadata and subpixel edges.
The metadata tests cover copied vertices, changed XY words, frame isolation,
table growth and invalid projection inputs. CLI and launcher tests cover all
three switches. The original 32-bit build guard is unchanged.

With all three options enabled at 1280x720, real-disc checks reached the dock
Codec and loaded the hot-PAL checkpoint after 600 VSyncs each. Captures show
the frequency and PAL-room surfaces intact. The unskipped 5000-VSync New Game
probe passed all three stage transitions and reached the dock Codec. Strict
replay passed `native-clock-boot01` (596 samples / 600 VSyncs) and the recorded
campaign segment `run-20261010-005349-602` (2804 samples / 2808 VSyncs, ending
in `s14e`). An older `native-dock-01` recording fails at its first sample on
both renderers (recorded VSync 5 versus current VSync 4); it is not evidence of
a new renderer divergence. Local artifacts: `build/modern-validation/`.

The vendor integration is exported as `mgs-projected-geometry.patch` and
`psyz-projected-geometry.patch`; bootstrap verifies all 82 MGS and 23 PsyZ
patches. Scoped aislop finds no errors or fixable warnings. It retains inherited
renderer size/complexity warnings, the inherited `SetParam` parameter-count
warning, a false positive for reachable `goto found` code in `chanl.c`, and a
generated shader-array size warning. `cppcheck` and `clang-tidy` are unavailable.

The user deferred x64 work. The audit script, detailed findings and compiler
report remain local and excluded from Git. Production pointer guards remain
active; no x64 executable has been linked or validated.

## Agreed prerelease scope — 10 October 2026

The native project's release name is **Metal Gear Solid Re:Integral**, with
[`Drommedhar/mgs-reintegral`](https://github.com/Drommedhar/mgs-reintegral)
as its private GitHub repository. Its
visual identity is **RE:INTEGRAL**, with an original symbol based on an integral
sign inside code brackets, `[ ∫ ]`, suggesting code, reconstruction and stealth.
The user-supplied generated [logo](assets/branding/re-integral-logo.png) is stored
under `assets/branding/` for the setup UI and project presentation, and appears
in the README. Its original PNG bytes are preserved. Branding should present an independent technical
project: do not trace or modify the official wordmark,
use extracted character art or faction emblems, add console branding, or
recreate an exact in-game interface around the title. Include a visible notice:
"Unofficial project; not affiliated with or endorsed by Konami" in the setup UI
and public project/release presentation. Original artwork and this notice do
not establish trademark permission or resolve code, binary or asset rights.

The user accepted the following release requirements:

- Simple clone/prerequisite setup with pinned dependencies downloaded from
  official upstream sources. Required runtime libraries may accompany releases.
- A documented Debug build path using the same build chain as CI.
- GitHub Actions build/test/package workflow and a versioned runnable Windows
  release ZIP, with checksums and matching debug symbols retained separately.
- One small setup/settings UI shared by developer and release builds: validate
  supported Integral BIN/CUE discs, remember their paths, select resolution,
  fullscreen/windowed and aspect ratio, launch the game, and open logs.
- Stable writable save/settings storage that survives application replacement;
  players need no development tools or Python installation.
- Fresh-clone and clean-machine acceptance checks; public CI tests use no
  retail content. Document requirements, controls, known limits and bug reports.
- Main-campaign setup should request Discs 1 and 2; requiring Disc 3 depends on
  actual VR support. Existing importer assumptions must not define the UI scope.

Completed: [upstream license check](docs/THIRD_PARTY.md#prerelease-license-check--10-october-2026).
The user selected MIT for original project contributions, credited to
Drommedhar and RE:INTEGRAL contributors. The scoped [project license](LICENSE),
README licensing summary, and a licensing/attribution issue template are now
present. Documentation invites authors and rights holders to provide
corrections while retaining the known upstream license facts and uncertainties.
FoxdieTeam's missing grant and uncovered PsyZ scopes remain unresolved for
public distribution. The repository and first alpha remain private.

## First native alpha preparation — 10 October 2026

- Added official-source prerequisite setup, pinned Python requirements, and
  Debug/RelWithDebInfo builds with a statically linked C/C++ runtime.
  Both configurations compile successfully with the shared launcher.
- Added the shared Windows launcher with both-disc validation, display and
  gameplay settings, developer switches, additional command-line arguments,
  versioned logs, restart handling, and persistent per-user settings/cards.
- Added manual-only GitHub Actions: one Windows job builds and tests, verifies
  the unpacked ZIP, uploads a draft, then publishes the complete prerelease.
  Pushes consume no Actions minutes. Dependencies are cached; failure/test
  artifacts expire after three days.
- Added player instructions, license notices and source access, SHA-256 sums,
  separate debugging symbols, issue templates, and the [roadmap](docs/ROADMAP.md).
- Optimized local build: all 161 CTests pass, including local GPU checks.
  The package passes synthetic-disc identity/rejection checks, Unicode paths,
  read-only input checks, version/commit checks, and launcher startup.
- A real-disc packaged boot at 1280x720 reached the dock's opening English
  Codec and exited normally after 600 VSyncs. This is a boot check, not a new
  campaign playthrough. Local evidence: `build/alpha-boot/boot.log` and `boot.bmp`.
- An isolated launcher integration check validated both real discs, saved
  settings, launched the game, captured its output, and returned to the ready
  state after 600 VSyncs. Evidence: `build/alpha-launcher-profile/logs/`.
- Bootstrap verifies every pinned source and patch; workflow syntax passes
  actionlint. Scoped aislop reports 100 with no findings; `cppcheck` and
  `clang-tidy` are unavailable to that scan.

The first hosted build compiled successfully and passed 141 of 142 hosted
tests. The remaining audit test exposed Windows short-path normalization in
`compile_evidence`; the helper now resolves its source root. The regression
passes with long and short temp paths under Python 3.11 and 3.12. Python 3.12
also passes the unpacked ZIP and UI checks using the shortened temp path.
The workflow now saves verified dependencies before tests and uses pinned
Node 24 Actions. Release/tag reuse is rejected before a publishing build.
The corrected [hosted run](https://github.com/Drommedhar/mgs-reintegral/actions/runs/38058089785)
passed all **142 hosted CTests**, unpacked-package checks and UI startup, then
published [**v0.1.0-alpha.1**](https://github.com/Drommedhar/mgs-reintegral/releases/tag/v0.1.0-alpha.1)
from `0219c04da14c6e98b928ca736a08ea66ec851378`. The tag, package metadata and
executable version agree. All four downloaded asset digests and all three ZIP
checksums match. Dependency and Python caches are present for subsequent runs.

The downloaded player ZIP also passed local Python 3.12 package/UI checks.
Its executable reached the dock's English Codec and exited normally after
600 VSyncs at 1280x720. Its import table contains only Windows system DLLs.
Local download/boot evidence is under `build/github-alpha-1/`; no retail data,
personal saves or replay archive was uploaded. Existing local history remains
on `godot`, `native-main-before-alpha` and the other preserved branches; `main`
tracks the new private repository's source-only history.

Broader hardware and clean Windows installation acceptance remain user testing.

## Current handoff scope

On 9 October the user assigned playthrough testing to themselves and requested
scene implementation and compilation only. Automated encounter tuning is stopped.
The fresh source audit selects all **92 main-game stage identities**, **738 C
translation units** and **1,715 constructor entries**. All **184 disc overlay
class-ID lists** match; no main-stage table, nonterminal constructor binding,
selected source file or active assembly implementation is missing. The Windows
x86 Debug executable builds. This establishes source/build coverage; campaign
completion is now confirmed by the user's playthrough above. VR uses a separate executable
and is outside this main-campaign source audit.

## Verified in this work session (8–10 October 2026)

- Removed the experimental fast stage loader at the user's request after it
  caused missing surfaces at the PAL checkpoint. The CD reader, stage loader,
  texture staging and BGM reset are restored to their previously pinned code;
  `-FastLoading` / `--fast-loading` are removed. BGM continuation is cancelled.
  A rebuilt 600-VSync PAL checkpoint load at 2560x1440 shows the stairs,
  railings and surrounding textures again. The checkpoint itself is unchanged.
  Evidence: `build/post-credits-20261010/rollback-pal.bmp` and adjacent log/movie.
  The unbuilt perspective-rendering prototype is saved only in that evidence
  directory's `baseline/` diffs and `vertex_depth.c.prototype`; the active
  renderer remains unchanged. That prototype was not shipped; the new opt-in
  modern renderer described above now supplies the geometry enhancements.

- Added opt-in `-AutoCard` (`--auto-card 1`) with record/replay identity support.
  Original card comparisons can use an owned access card without equipping it;
  the original card-level checks still apply. Other equipment and PAL-key
  checks retain their original behavior. Tests exercise the actual GCL
  expression evaluator and session inheritance/rejection rules.

- Added an initial host audio buffer and bounded device-clock correction for
  deterministic recording/replay. Emulated SPU timing is unchanged. Seven
  focused tests pass: auto-card, input sessions, CD, audio, SPU IRQ/sweep and
  replay clock. The PAL load still reports one empty audio refill; occasional
  cutscene/video crackles are not established as resolved. Aislop reports no
  findings across the six changed C/header files, including vendor files copied
  outside ignored directories; cppcheck and a C formatter are unavailable.

- Recovered the PAL room entry before the user's detection lockout from
  `run-20261010-010306-651.mgsinput`: all 122,441 prefix inputs / 122,445 VSyncs
  match. The original Continue bank has stage `s16d`, story 246, selector
  `0x2aa8`, and spawn `(-6800,1900,7900)`. Only PAL temperature changes from
  7560 to 9000, plus the save checksum; the key was already hot. A separate
  600-VSync reload confirms story 246, hot key equipped, temperature 8970,
  alert zero, game status zero, and Snake on the entry stairs outside the room.
  Original recordings and saves are preserved. No game code or executable
  changed. Evidence and exporter: `build/pal-reset-20261010/`.

- Corrected the cargo retry checkpoint after the user reported a skipped
  encounter. The previous crash-time snapshot already contained story 207;
  the original script uses that value to bypass the ambush. Recovered story
  206 and entry selector `0x2e90` from the original recording's transition,
  after 12,001 verified inputs / 12,005 VSyncs, without editing gameplay flags.
  A separate 600-VSync reload now shows all three guards fighting: three live
  actor pointers, health 768 each, retired count zero and the original end
  procedure still registered. The original save bank instead retains selector
  `0x2190`, which returns to the upper landing. The corrected direct checkpoint
  is `ambush-entry.mgssave`; old files and source recordings remain preserved.
  No game code or executable changed. Exporter Aislop scan has no findings.
  Evidence: `build/cargo-checkpoint-20261010/`, including the active-combat
  capture and debugger inspection. [Corrected command](docs/INPUT_RECORDING.md#cargo-elevator-restart-disc-2).

- Fixed the Disc 2 cargo-elevator crash in `run-20261010-004229-177.mgsinput`.
  `zako14com.c::ChangePrio` dereferenced a retired guard after all three ambush
  actors were removed (`n_watchers=3`, retired count 3, game flag 15). Empty
  slots now sort last and receive no writes, matching the earlier elevator's
  fix. Configured slot counts and the completion state machine are unchanged.
  Both builds match all 13,989 complete inputs / 13,993 VSyncs; the old build
  then faults at address `0xC2C`, while the fixed build survives a bounded
  600-VSync held-input continuation. The diagnostic limit intentionally reports
  failure rather than successful movie completion. Three focused commander
  CTests pass, including all cargo-ambush retirement combinations and empty
  registries. The first checkpoint reload only verified arrival in `s14e` and
  missed the post-fight flags; the corrected ambush check is recorded above.
  The 79 MGS / 20 PSYZ patch stack verifies. Aislop reports no new findings,
  errors or fixable warnings; the existing 175-line `UpdateGameFlag` warning
  remains and `cppcheck` is unavailable. Evidence: `build/cargo-crash-20261010/`;
  executable SHA-256
  `57b7926c263bd276193d9923c74eebfc3d271a7217975a43897c6146e1c19d08`.

- Fixed the elevator ambush crash from `run-20261009-191445-721.mgsinput`.
  The commander dereferenced guard slots that had been cleared by actor
  retirement. Empty slots now sort last and receive no writes, preserving the
  encounter's slot counts and completion logic. The old build reproduces the
  access violation after all 123,202 recorded inputs / 123,206 VSyncs match;
  the fixed build matches the same prefix at 2560×1440, survives a bounded
  600-VSync diagnostic continuation and begins loading `s11c`. The continuation
  deliberately returns failure at its limit; it is not recording completion.
  A direct elevator restart loads active combat in a 600-VSync native check:
  [retry command](docs/INPUT_RECORDING.md#elevator-ambush-restart).
- Removed the sky's visible texture grid. Both panorama actors now use a
  scoped background drawing mode with 2D texel alignment and the wider scene
  transform. World sampling is restored afterwards. Before/after captures from
  the same recorded rooftop frame at 2560×1440 show the repair; opaque floor
  and HUD control regions are pixel-identical. [Details](docs/WIDESCREEN.md#sky-texture-seams).
  All 23 focused CTests pass, including 256 guard-retirement masks and GPU
  atlas-edge checks at 1×/2×/8×. The 78 MGS / 20 PSYZ patch stack verifies.
  Scoped Aislop has no new findings, errors or fixable warnings. Four inherited
  long-function warnings and one existing `goto`-label false positive remain;
  `cppcheck` is unavailable. Evidence: ignored `build/tower-report-20261009/`;
  executable SHA-256
  `df38a0a024db4e56632f4c8649d50ed33dd1dd7d86e520e53eeb8c8cc86e9658`.

- Fixed the torture-area crash from `run-20261009-183217-163.mgsinput`:
  the persistent item box dereferenced `GM_PlayerControl` after the player
  actor retired while the cutscene camera remained in first person. Its label
  and proximity pickup now require a live player. Both builds reproduce all
  74,909 complete input samples / 74,913 VSyncs; the old build then crashes,
  while the fixed build survives a bounded 600-VSync diagnostic tail. This tail
  deliberately ends with failure status and is not recording completion.
  A direct torture-area restart is available at
  `.local/checkpoints/torture-20261009/recorded-restart.mgssave`; a 1,200-VSync
  native load check reaches the torture introduction without earlier bosses.
  Original movies/cards remain intact. [Retry command](docs/INPUT_RECORDING.md#torture-area-restart).
- Extended both tiled sky actors to cover the requested widescreen viewport
  without rescaling tiles. The vignette keeps its original gradient and fills
  beyond the outer ring using the same animated edge color/blend mode.
  Coverage checks exercise both buffers, yaw/wrapping and multiple aspect ratios.
  [Rendering details](docs/WIDESCREEN.md#sky-and-vignette-coverage).
- Fixed ignored live SPU ADSR writes: the game's sound-effect stop path changes
  the release rate after key-off, but the mixer retained the key-on value.
  Active voices now receive both envelope registers without restarting playback.
  Tests verify release to silence on looping samples in voices 0/13/23 and live
  attack/sustain changes. This fixes a shared cause of lingering detection/alert
  sounds; listening acceptance for the reported artifact remains with the user.
  Debug builds and 17 focused CTests pass. The 76 MGS / 20 PSYZ patch stack
  verifies. Scoped Aislop has no errors/fixable warnings or new diagnostics;
  three inherited long-function warnings remain and `cppcheck` is unavailable.
  Evidence: ignored `build/wolf-report-20261009/`; executable SHA-256
  `3f702155f99ac45d6ad116f82dd1936f4bd6c566cf81378c6c074fa78afef314`.

- Fixed Mantis's misplaced HIDEO blackout by restoring the original overlay
  channel. Widescreen captures confirm the full black screen and large/small
  lettering. Added SDL port exchange on F2 or L3 + R3, with a visible prompt,
  analog/keyboard/rumble routing and replay support. SDK checks pass; a direct
  Mantis checkpoint test records/replays 1,596 inputs across 1,600 VSyncs and
  moves Snake using the original second-controller flag. User's full encounter
  playthrough remains outstanding. [Evidence](docs/MANTIS_RECOVERY.md#hideo-and-controller-ports-9-october).
- Added opt-in `-MantisMemory random` / numeric seed. Mantis receives a temporary
  synthetic list drawn from Integral's original recognized titles, honoring the
  English dialogue masks. Real cards and play statistics are unchanged; the
  seed is part of recording identity and inherited by replay/resume. Matcher and
  session tests pass. Voiced intro acceptance remains for the user's playthrough.
- Recovered a direct Mantis battle restart from the latest user's recording:
  `.local/checkpoints/mantis-20261009/recorded-entry.mgssave`. Original story 129,
  map, spawn, saved encounter health and bonus items are retained. This avoids
  repeating earlier bosses; it starts after the memory-reading introduction.
  Vendor changes are reproducible through 74 MGS and 19 PSYZ patches.

- Recovered a direct Ninja retry checkpoint from the recorded live encounter
  entry, after the original script assigns story 77 and its spawn. The existing
  Integral save loader accepts it and a 1,400-VSync check visibly reaches active
  Ninja combat; stealth/bandana inventory is preserved. Use
  `.local/checkpoints/ninja-20261009/recorded-entry.mgssave` with `-LoadCheckpoint`.
  This is separate from the older Continue save bank that blocked the earlier
  export, and does not require replaying the earlier bosses. No gameplay code,
  original recording or existing checkpoint was changed. The local exporter
  passes Aislop without findings. [Evidence](docs/NINJA_RECOVERY.md#direct-ninja-retry-checkpoint).
- Fixed the Ninja phase stall reported in `run-20261009-171125-195.mgsinput`.
  A strict replay reproduces all 47,087 inputs and reaches phase 3 with zero
  boss health. Three recovered hit dispatchers were missing their original
  switch bodies, preventing phase/counter updates independently of invulnerability.
  Restored the original MIPS behavior; 960 new reference cases pass, and the
  old code fails the regression test. Ninja now has 3,478 reference comparisons.
  Debug builds, five focused CTests pass, and the 72-patch MGS stack verifies.
  Full boss completion remains for the user's playthrough. Aislop retains one
  inherited vendor size warning; no errors/fixable findings, `cppcheck` absent.
  The fixed build strictly replays the 39,701-input pre-combat prefix. Ninja
  checkpoint export is unavailable because the original stored save still names
  another stage; no new checkpoint was created and existing ones are preserved.
  [Evidence](docs/NINJA_RECOVERY.md#hit-driven-phase-transitions--9-october-2026).
- Fixed the user's Tank victory crash in `run-20261009-165718-122.mgsinput`.
  The main camera ran before the retiring Tank camera and called an already
  removed director. Tank destruction now unregisters its camera callbacks
  before resource/script cleanup, preserving foreign callbacks and deferred
  actor freeing. All 5,823 recorded inputs match; a bounded 600-VSync tail
  enters the post-fight cinematic without a crash. Five focused CTests pass,
  including actual scheduler ordering and the existing 1,260 cleanup traces.
  Debug builds; the change is exported in the 71-patch MGS stack. The old
  snowfield checkpoint is unchanged. The remaining cinematic/next stage are
  for the user's playthrough. Aislop retains nine inherited vendor complexity
  warnings, with no errors/fixable warnings; `cppcheck` remains unavailable.
  [Evidence](docs/TANK_COMPLETION_AUDIT.md#camera-teardown-crash-9-october-2026).
- Fixed the next Tank crash: the dying gunner retains an actor but has already
  released its target. Aim and blast hooks now handle that retirement window.
  All 10,487 recorded inputs match with cheats disabled; a further bounded
  600-VSync continuation passes the crash. This does not establish victory.
  Added opt-in `-Invulnerable` health protection with recorded session identity,
  replay inheritance and original-setting checkpoint recovery. A real-disc
  checkpoint start strictly records/replays 596 inputs / 600 VSyncs. The old
  snowfield entry remains available. Twelve focused CTests pass, Debug builds,
  and both vendor changes are exported in the 70-patch MGS stack.
  Scoped Aislop reports no errors/fixable warnings; 33 existing vendor size/
  complexity warnings remain. `cppcheck` is unavailable; PowerShell is not a
  supported Aislop language and is covered by the session tests instead.
  [Tank evidence](docs/TANK_COMPLETION_AUDIT.md#gunner-retirement-crash-9-october-2026),
  [invulnerability behavior and limits](docs/INPUT_RECORDING.md#invulnerability).
- Fixed the user's next crash in `s05a`: claymore trajectory initialization
  wrote two vectors into a one-vector local, corrupting the native stack.
  An explicit two-element array restores the original stack-buffer contract.
  All 55,657 recorded input checks match and 600 further VSyncs pass the mine
  explosion without a crash. Four focused CTests pass, and the old helper
  fails the new capacity regression. The Debug build and 68-patch MGS stack
  verify. The authentic snowfield entry is cached after a separate strict
  54,470-input recovery replay, ready for immediate resume.
  [Evidence](docs/STAGE_RECOVERY.md#snowfield-claymore-crash).
- Clarified Integral's English setting: dialogue/subtitles switch language,
  while item/weapon descriptions use Japanese tables. The user approved
  future US/EU disc language-resource imports, including German, with
  independently modifiable language packs. This remains future work;
  [scope and plan](docs/ENGLISH_TEXT.md#scope-of-the-original-language-setting).
- Fixed the user's prison encounter crash after the final guards are removed.
  The commander sorted cleared actor pointers; native sorting now places empty
  slots last and updates only surviving actors. All 45,533 recorded input
  checkpoints match, and a bounded 1,800-VSync continuation completes cleanup
  and reaches `s03b` without an access violation. Five focused CTests pass;
  the 67-patch MGS stack verifies. The original recording is preserved and its
  `s03d` entry checkpoint is cached for immediate resume. This verifies the
  reported failure, not the remainder of the campaign.
  [Crash evidence and limits](docs/STAGE_RECOVERY.md#prison-encounter-cleanup-crash).
- Follow-up: overlay MAX now arms at the title actor's ready/menu states,
  excluding startup and the transition frame, then retains later peaks. Direct
  campaign/checkpoint starts arm it after loading. The corrected full-run
  command includes `-BonusItems` for Stealth and Bandana. The 415-input / 419-VSync
  title replay passes and observes the readiness hook; all four relevant timing,
  analysis, input-session and bonus-item suites pass. Diagnostic startup rows
  remain available for replay investigation.
- The user's dock puddle report reproduced 40 ms GPU submission stalls with
  audio queue depletion at 2560×1440. Deferred native framebuffer resolves
  reduce slow intro frames from 191 to two in the same 5,000-VSync replay;
  the puddle burst drops from 77 slow frames to zero. The user confirmed the
  running fix works. Two isolated later intro spikes remain logged. The limiter
  resumes nominal 16.683 ms intervals after stalls without accelerated catch-up.
  The top-right overlay shows FPS, frame time and MAX since menu readiness; recording and
  replay automatically retain only slow-frame timing rows next to input data.
  Strict replay passes all 4,996 input samples; all 148 CTest suites pass.
  [Diagnostics, command and remaining limits](docs/PERFORMANCE_DIAGNOSTICS.md).
- The authentic post-REX checkpoint now follows the original rooftop scenes
  into Liquid's first Normal encounter, with attempt count zero and the original
  768/768 versus 255 health contract. The initial failed fight strictly replays
  all 59,996 samples / 60,000 VSyncs and exports a CRC-valid story 277 map-entry
  checkpoint. A controller-only get-up-kick avoidance change reaches Liquid
  at 4 HP before Snake dies; the first encounter is still incomplete. The new
  checkpoint removes the need to repeat the incoming cinematics while testing.
  [First-encounter evidence](docs/LIQUID_RECOVERY.md#first-encounter-reached-from-completed-rex).
- The full Normal REX encounter now completes from its finite, declared entry
  fixture: both 1,800-HP weakpoints destroyed, 24 Stinger rounds and eight Chaff
  consumed, Snake alive at 640/768, then original `d18a` → `s18a` rooftop
  cinematics. Strict replay passes **17,996 samples / 18,000 VSyncs** with an
  identical final screenshot. The original serializer exports a CRC-valid
  story259 rooftop entry for the next connected check. The controller now
  respects the Stinger pitch limit and uses Chaff against missile tracking in
  both phases; no REX gameplay source was changed. This proves a supplied
  encounter, not a complete New Game campaign or the following Liquid fight.
  [REX completion evidence](docs/REX_ENCOUNTER_CONTRACT.md#completed-normal-encounter-and-strict-replay).
- The dock lamp flash exposed a world-channel 2D screen-fill gap. The shared
  renderer classifier now expands full-width `TILE` overlays in both world and
  HUD channels. New 1×/2×/8× pixel checks reproduce the old failure and verify
  blending, clipping, both buffers and transform restoration, while projected
  world polygons and smaller rectangles retain their existing behavior.
  Matching 2560×1440 dock captures show the flash covering both outer strips
  with every central 4:3 pixel unchanged. Before/after unskipped intro runs
  both reach the dock Codec at 5,000 VSyncs.
  [Shared 2D policy](docs/WIDESCREEN.md#shared-rules-for-original-43-elements).
- The authentic Normal escape checkpoint now completes its full outgoing
  cinematics, Codec, ending, credits, ranking, original Bandana award/save and
  return to title. A separate strict replay passes **79,996 samples / 80,000
  VSyncs**. All three earned-save payload CRCs pass. Loading a copy through the
  original menu starts the next round and reaches the dock with the Bandana and
  completion count preserved; ordinary input moves Snake 453 units over 24
  ticks. No new gameplay fixture or code repair was needed. This extends the
  supplied Normal Liquid retry lineage, not a New Game campaign playthrough.
  [Normal ending evidence](docs/ESCAPE_RECOVERY.md#normal-ending-strict-replay-and-earned-save-reload).
- Optional native widescreen and output resolution now support
  `-Widescreen -Resolution 2560x1440 -Fullscreen`. The 3D view expands while
  logos, menus and Codec retain their 4:3 canvas. Corrected high-resolution 2D
  texel alignment removes the reproduced Konami logo seam. Water/blur/focus
  copies preserve scaled framebuffer detail; translucent lights and mask tests
  now also preserve fine destination detail. Original textures and actor
  effect shapes remain unchanged. Cold startup captures and strict menu/Codec
  recording prefixes were inspected. The unskipped intro completes 5,000
  VSyncs to the dock Codec. These checks do not establish every scene's visual
  fidelity or performance. [Widescreen evidence](docs/WIDESCREEN.md),
  [light diagnosis](docs/WIDESCREEN_LIGHTS.md).
- Wider rendering initially changed a guard's gameplay visibility. Normal and
  fog bounds now retain the original actor-visible values after rendering.
  The previously failing strict garage prefix passes 1,997 samples / 2,001
  VSyncs in 2560×1440 widescreen fullscreen. The full recording then passes all
  **6,496 samples / 6,500 VSyncs** and loads `s19b`. Original-aspect and
  resolution-only playback of that prefix also pass.
  [Visibility evidence](docs/WIDESCREEN_VISIBILITY.md).
- The rebuilt default passes **146 CTest suites**, including 1×/2×/8× atlas,
  framebuffer and world-blending tests. Bootstrap verifies **65 MGS / 17 PsyZ
  patches**. First-party scans have no findings; touched vendor scopes retain
  inherited nonfixable size/complexity findings and a `goto`-label false positive,
  with no errors or fixable warnings. cppcheck and clang-tidy remain unavailable.
- The reported mesh-edge/transparent-border artifacts prompted a renderer repair:
  polygon pixel-centre alignment, vertex-order-independent UV sampling, sprite
  UV wrapping and VRAM texture/palette wrapping. Negative controls reproduce the
  old defects; the new tests pass 70,656 native coverage comparisons and 124,980
  texture comparisons at each tested resolution. The same authentic garage
  recording passes all 6,496 samples / 6,500 VSyncs before and after the change;
  matching scene captures were inspected. Mod-resource and renderer boundaries
  are preserved. This verifies specific renderer contracts, not every reported
  scene or a complete campaign. [Renderer evidence](docs/GPU_RASTER_EDGES.md).
- Garage completion exposed an incorrect recovered gun rotation call. Restoring
  the original `RotMatrixZYX` order now lets normal gunfire explode the drums,
  break the gate and follow the authored jeep exit into `s19b`, alive at 408/768.
  The authentic garage checkpoint route and all 6,496 recorded samples replay
  successfully. Tests cover 520 original-MIPS matrices and 1,560 independently
  composed bullet paths; the old call fails. The original exit deliberately
  retains the garage retry snapshot, so no standalone escape checkpoint was
  fabricated. [Garage evidence](docs/GARAGE_ROUTE.md).
- The completed Liquid retry encounter now continues through the original
  post-fight movies and Codec into the garage, with no post-fight inputs or new
  gameplay fixture. A 25,165-sample prefix replays and exports a CRC-valid
  Normal/story283 garage checkpoint. [Connected handoff](docs/LIQUID_RECOVERY.md#connected-garage-handoff).
- From that authentic checkpoint, the combined `garage-escape` controller run
  now completes garage → both escape checkpoints → five Liquid damage releases
  → `s20a` on Normal. Snake survives with **30/768** health, no rations used and
  no Stealth/Bandana. All **17,996 samples / 18,000 VSyncs** replay with matching
  state, and the original serializer exports a CRC-valid Normal/story286 ending
  entry. This connects supplied late-game scenarios; it is not a New Game campaign.
  [Connected Normal escape](docs/ESCAPE_RECOVERY.md).
- The reused torture actor passes **2,432 original-MIPS comparisons** for round
  handoff, controller recovery and surrender. These checks found no discrepancy;
  a complete live torture session remains unverified.
  [Torture evidence](docs/BOSS_TERMINAL_VALIDATION.md#torture-round-recovery-and-surrender).
- Earlier encounter completion audits add **2,135 Ninja** and **1,260 Tank**
  original-MIPS comparisons. Victory callback conditions, arguments and ordered
  side effects match; no additional gameplay repair was justified. Complete
  live fights remain open. [Ninja evidence](docs/NINJA_RECOVERY.md#terminal-callback-verification),
  [Tank evidence](docs/TANK_COMPLETION_AUDIT.md).
- Both full escape variants now clear the two checkpoints, five guards and five
  Liquid damage thresholds, then load their authored `s20a`/`s20ar` destinations.
  Rival-jeep wall contact exposed an undersized hazard-output buffer; the native
  caller now supplies both original vectors. Its 256 new original-MIPS cases
  reject the old buffer. The base route replays all 14,996 inputs with matching
  state and supplies an authentic next-map checkpoint.
  [Escape evidence](docs/ESCAPE_RECOVERY.md).
- That real escape checkpoint now completes `s20a` cinematics and Codec,
  ending, all credits phases, ranking, Bandana award, original completed-game
  save, and title. The inherited difficulty is Easy. No input is sent before
  ranking; no new gameplay fixture is supplied. All three save payload copies
  pass their original CRC checks. [Connected finale](docs/ESCAPE_RECOVERY.md#connected-ending-from-the-escape-checkpoint).
- The full Normal Liquid fight exposed and repaired lost primary/secondary
  action-timer arguments. Original MIPS confirms both callbacks receive their
  pre-increment tick. The supplied retry encounter now completes 54 damage events,
  reduces Liquid 255→0, and follows the original victory into `d18a`; Snake
  survives with 14/768 health. No combat state is forced after the incoming
  fixture. [Liquid evidence](docs/LIQUID_RECOVERY.md).
- A follow-up [hazard-output audit](docs/HZD_OUTPUT_AUDIT.md) corrected the same
  two-vector allocation in Liquid's climb action. All six selected callers now
  provide sufficient output storage. The dispatcher and climb tests add 864 and
  840 original-MIPS cases, respectively. With both repairs, the full retry fight
  records and replays 7,196 inputs with matching state and final pixels.
- Before the widescreen changes, the default build passed all **119 CTest suites**. The source stack had
  **64 MGS / 16 PsyZ patches**. New first-party checks have no Aislop findings;
  nine inherited nonfixable size/length warnings remain in Liquid's recovered
  action file, two in the garage actor and five in the touched renderer scope.
  The C/C++ scan lacks cppcheck and clang-tidy.
- Both original completed-mission saves now load through title → `abst` →
  `d00a` → dock, preserve the respective earned Bandana/Stealth, and allow
  453 units of movement over 24 moving ticks. Both source and copied saves remain
  byte-identical. [Completed-save load evidence](docs/COMPLETED_SAVE_LOAD.md).

- Work has returned to systematic stage-behavior completion at the user's request.
  The new human crash report is deferred. A fresh audit found no omitted active
  main-stage body: all 92 selected stages still resolve to the existing 738 C
  units. Reused constructor layouts and inspected variant data agree with the
  supplied overlays; this does not establish complete campaign playability.
- REX phase-completion and Liquid victory now have **964 additional original-MIPS
  state/callback comparisons**. The escape finale adds **614 comparisons**,
  including a continuous 74-step sequence, bringing its road suite to 3,174.
  These checks found no recovered-behavior discrepancy and do not claim completed
  live boss fights or a completed chase. [Boss evidence](docs/BOSS_TERMINAL_VALIDATION.md),
  [escape evidence](docs/ESCAPE_RECOVERY.md).
- The full ending checks exposed an unused PS1 low-memory read in the footprint
  actor. Native C now checks movement eligibility before looking up the player's
  map; **3,446 cases** verify inactive cinematic players and active footprints.
  Restoring the old ordering reproduces the fault. Both companion scenarios now
  complete story 293/294, all five credits phases, ranking, original completed-
  mission saves and return to title through the PocketStation decline option.
  Both saves pass original CRC checks and contain the appropriate earned item:
  Bandana for Meryl's branch, Stealth for Otacon's. These are supplied late-game
  scenarios, not completed campaign playthroughs. [Ending evidence](docs/CINEMATIC_STAGES.md#complete-ending-scenarios).
  The rebuilt default passes **108 CTest suites**; **60 MGS / 15 PsyZ** patches
  verify. [Native compatibility](docs/NATIVE_COMPATIBILITY.md#cinematic-footprint-eligibility).

- The next human recording, `xbox-02`, reproduces a Chaff Grenade explosion crash:
  its 64-particle effect passes a null drawing rectangle into the native renderer.
  The native actor now provides an explicit zero-offset rectangle; exact original
  PS1 low-memory offsets remain unverified. All 3,752 retained inputs match;
  a 720-VSync diagnostic tail observes the burst, normal effect expiry/primitive
  release and health 256 afterward. The original recording is unchanged and its
  heliport entry is cached for resume. The actor/packet regression passes 6,953
  checks and rejects the old null argument. All **106 CTest suites** pass and
  **59 MGS / 15 PsyZ** patches verify. One inherited Chaff `Act` length warning
  remains; the new tests have no Aislop findings.
  [Chaff repair and evidence](docs/NATIVE_COMPATIBILITY.md#chaff-particle-drawing-offset).

- `-ResumeInput` recovers the last loaded campaign map's original entry snapshot
  once and caches it for direct future boots. The user's crash recording yields
  heliport `s01a`: a fresh process loads `init_ve` → `s01a`, preserving the recorded
  entry position, health, equipped Stealth and inventory checksum. New recordings
  snapshot this checkpoint and replay independently. A 3,000-VSync SDL probe skips
  the original entry dialogue, verifies 63 units of movement over 13 moving ticks
  with collision contact, and replays with matching checkpoints and final pixels.
  This establishes checkpoint restart and limited input movement, not a full
  heliport playthrough. All **105 CTest suites** pass and **58 MGS / 15 PsyZ**
  patches verify. Source recording remains unchanged. Scoped first-party Aislop
  scans report no findings; four inherited vendor complexity warnings remain.
  [Resume usage](docs/INPUT_RECORDING.md#resume-at-the-last-map-entry).

- The user's Xbox recording reaches the authored dock → `d00a` → `d01a` → heliport
  transition with Stealth on Very Easy. All 15,675 complete samples replay with
  matching checkpoints. A heliport Chaff pickup then exposed an unported PS1
  address-sign test in the item destructor. The old dispatch crashes; the fixed
  build executes the inline pickup script and survives a separately labeled
  diagnostic tail. The original recording is preserved. The 104-case destructor
  regression rejects the old implementation. The rebuilt default passes all
  **103 CTest suites**; **57 MGS / 15 PsyZ** patches verify through bootstrap.
  [Crash evidence](docs/HELIPORT_PICKUP_CRASH.md).

- Optional Stealth/Bandana ownership and original save/continue behavior have
  passing tests. A 2,400-VSync live inventory check equips and removes both through
  normal SDL input, verifies their actual actors and Stealth model flags, and
  finishes unequipped. A separate 6,000-VSync New Game route grants exactly two
  items and reaches dock movement. Guard detection and ammunition consumption
  remain untested in these fixtures. [Bonus evidence](docs/BONUS_ITEMS.md).
- Both gamepad ports now initialize in analog mode. Two virtual SDL controllers
  pass stick endpoint/center/quantization, keyboard and rumble checks. SDL detects
  the user's Xbox One Elite 2 Controller; human controller play remains pending.
- Native input recording captures both ports and game checkpoints, with initial
  card snapshots and isolated replay saves. A deterministic movie clock fixes
  host timing differences while retaining strict checkpoints. A 2,400-VSync
  bonus-menu recording replays with matching state and identical final pixels;
  an unbounded recording closed normally replays to its saved endpoint. The
  default build also replays 3,000 VSyncs through title/New Game/`d00a`/dock with
  the probe's normal skip controls, 431 movement units and identical final pixels.
  An intentionally wrong health checkpoint is rejected with failure status. The
  default Debug build passes **103 CTest suites**. All **57 MGS / 15 PsyZ** patches
  verify through bootstrap. This is not yet a full campaign replay.
  [Recording details](docs/INPUT_RECORDING.md).

- User-reported intro stalls were reproduced and traced to lost SPU interrupts
  and per-batch GPU buffer allocation. The corrected optimized run plays the
  complete 1,981-frame New Game cinematic in 66.10 seconds and reaches the dock
  Codec with no input after the title. Maximum measured draw time drops from
  701.73 ms to 5.59 ms, with no animation-update gaps above 250 ms or audio queue
  starvation. Underwater packet-layout, scratchpad and lifetime defects are
  corrected against original MIPS traces. GPU extent limits are covered by
  native, scaled and software pixel tests. The default Debug build also completes
  the unskipped intro: about 66 seconds, maximum measured draw 7.23 ms, no long
  animation gaps and no audio starvation. All 94 CTest suites pass in Debug and
  the optimized external-renderer build; the 55/13 vendor patch stacks validate.
  [Intro evidence](docs/INTRO_TIMING.md), [renderer fix](docs/GPU_UPLOAD_ARENA.md).
- Fresh default startup completes all three submarine-opening parts and returns
  to the original title without input. The maximum animation-update gap is
  **33.603 ms**, with no gaps above 250 ms. New Game starts the separate underwater
  infiltration cinematic. This verifies the native startup route, not retail
  audiovisual fidelity. [Startup evidence](docs/NORMAL_STARTUP.md).

- Auxiliary theater, selector and sound stages now reuse complete vendor C; the
  vibration editor has tested native host file I/O. Theater/select1/sound startup
  checks completed 900/600/600 VSyncs. `s03dr` shares 468 instruction-identical
  functions with `s03d`; its original story=27 fixture completed 1,800 VSyncs
  and observed 2,589 units of SDL-input movement over 25 movement ticks.
  [Auxiliary evidence](docs/NATIVE_AUXILIARY_STAGES.md).

- The stage registry selects recovered constructor tables without callable PS1
  addresses. Shared sources compile once. The selected stages are authoritative
  in [config/stages.json](config/stages.json); selection alone is not runtime evidence.
- The current optimized build compiles **738 game translation units** across all
  **92 configured campaign and menu stages**, including one native disc-safety
  replacement. The full Debug build passes **94 CTest suites**. These are source/build counts,
  not a claim of complete campaign playability.
- A 6,000-VSync run followed **title → New Game → `d00a` → `s00a`** using an SDL
  virtual controller. Normal difficulty, opening Codec advancement, 431 horizontal
  movement units, 21 movement ticks and 21 collision-contact ticks were observed.
  That older probe deliberately skipped cinematics and did not validate intro playback.
  The external renderer-module build repeated this route successfully after the
  overlay-lifetime changes. A separate 393-unit build completed the New Game
  regression with the new GPU mask implementation. [Log](build/renderer-contract-new-game.log),
  [capture](build/renderer-contract-new-game.bmp).
- A 7,200-VSync Debug run entered `s01a`, completed the authored `d01a` cinematic
  camera stream and reached Mei Ling's Codec conversation at 140.85.
  [Log](build/intro-audit/heliport-7200.log),
  [capture](build/heliport-complete-frame.bmp).
- Thirteen early-stage direct-entry smoke checks ran for 900 VSyncs. Their visual
  results and missing scenario prerequisites are recorded in
  [early-stage validation](docs/EARLY_STAGE_VALIDATION.md). These are entry checks,
  not boss or stage completion.
- Forty-five constructor bindings for `s05a` and `s11a` were checked against the
  original overlays. Both stages compile and finish bounded entry checks.
  `s11a` requires its original incoming map `a9d5`. A separate `s05a` story=65
  debugger fixture ran the original intro callback, which initialized the boss
  state and called the tank constructor. Virtual input moved Snake 3,658 units
  and the run completed 2,400 VSyncs. The tank was outside the final camera view;
  this establishes scenario/constructor execution, not combat completion.
- `s03d` now has 28 verified constructor bindings and 32 functions recovered from
  21 missing assembly blocks. A debugger scenario fixture supplied only original
  story value 27, after which the original script advanced to 28 and instantiated
  Meryl, the commander and three guards. Virtual input moved Snake 1,690 units;
  the run survived 2,400 VSyncs and later displayed Game Over after guard attacks.
  This fixture does not establish the normal campaign route into that encounter.
  [Recovery evidence](docs/data/s03d_recovery.json).
- The original Mei Ling save UI, entered from development stage `s02a`, displayed
  completion and wrote an 8,192-byte save. Its original header, `s02a` stage name
  and CRC were independently verified. A separate, explicitly documented story=1
  debugger fixture then completed **save → fresh process → title Load Game →
  `abst` → restored `s02a`**. Original menu callbacks accepted the save, and normal
  controller input moved the restored player 1,651 units over 24 movement ticks.
  This is a scenario-fixture round trip, not normal campaign progression.
  [Save evidence](docs/NATIVE_SAVES.md).
- Overlay initialized data and BSS now reset on actual `.b` loads, including cached
  loads, while resident state and restarts that skip the overlay remain intact.
  EUC-JP string bytes used for original identifiers are preserved in generated C.
- The missing Codec frequency is fixed by correcting GPU texture/palette ordering.
  A pixel regression reproduces the old failure and passes with the fix.
- Disc 2's furnace (`s13a`) now loads with the original incoming map and position
  from `s12c`'s `sub_DECC`. An explicit debugger fixture ran 900 VSyncs and moved
  Snake 3,112 units down the stairway. The default development spawn had dropped
  him into the furnace and reached Game Over. This corrected fixture is not yet
  evidence of the campaign disc-change route.
- A separate run now executes **`change` → Disc 2 → `s13a`** through the original
  disc UI and script, using virtual Start and no debugger changes to game state.
  The game identifies Disc 2, sets the incoming position and loads the furnace;
  input again moves Snake 3,112 units. The run completes 2,400 VSyncs. It starts
  at `change`, so the full route into that screen remains unverified.
  [Disc-change evidence](docs/DISC_CHANGE.md).

- Mantis (`s07b`/`s07br`) now compiles from recovered native Meryl/Mantis code.
  Original story fixtures instantiate both actors, execute HIDEO and return,
  projectiles, chairs and pots. The 3,600-frame fight check passes movement after
  blackout; this is not boss completion. [Evidence](docs/MANTIS_RECOVERY.md).
- First Sniper Wolf stages (`s10a`/`s10ar`) complete their original introduction
  and pass controller movement. A separate story149 fixture observes the original
  script constructing both Wolf and wounded Meryl. Guard actions/AI/commander have
  133 original-MIPS comparisons. [Evidence](docs/NATIVE_S10_RECOVERY.md).
- The recovered Ninja and effects compile in `s08b`/`s08br`, with 383 original-MIPS
  spatial/route comparisons passing. The original `s08b` introduction releases
  control, Ninja attacks and throws Snake, and virtual input passes 1,049 units
  over 26 movement ticks in an 1,800-VSync check. This is not fight completion.
  [Evidence and native clone-lighting correction](docs/NINJA_RECOVERY.md).
- Container geometry and behavior pass eight and 133 original-MIPS fixtures;
  Raven navigation/damage adds 352 comparisons. `s15c` story242 runs 900 VSyncs,
  renders the warehouse and moves Snake 2,996 units. Story219 paired with this
  revisit resource set requests an absent model and fails; that failed fixture
  is retained separately. [Recovery and limits](docs/CONTAINER_RECOVERY.md).
- A second `s15c` fixture restores maximum serialized container damage and passes
  the same 900-VSync movement check. `s15a` story211 creates Raven and intact
  containers through the original script and completes 1,800 VSyncs with movement.
  The fixture does not establish a completed Raven fight. [Evidence](docs/S15A_RECOVERY.md).
- Original Options and Previous Operations render their menus. The opening runs
  7,200 VSyncs into the submarine scene; tower, underground-base and ending
  fixtures render their original cinematics. Credits run 6,000 VSyncs with
  scrolling text over decoded video. [Evidence](docs/CINEMATIC_STAGES.md).
- The tower helicopter stage `s11g` has 1,008 original-MIPS comparisons. Its
  story177 fixture executes the Hind actor and aiming code, returns control and
  passes 665 movement units over 19 movement ticks in 1,800 VSyncs. The fight is
  not completed. [Evidence](docs/HIND_RECOVERY.md).
- The elevator encounter `s14e` now selects native guard, commander, and elevator
  code. Its original arrival and ambush scripts run in separate story fixtures;
  the ambush spawns three guards and can kill the fixture's low-health Snake.
  The guard implementation passes 586 original-MIPS comparisons.
  [Evidence](docs/NATIVE_S14_RECOVERY.md).
- Hind variants now have 1,456 original-MIPS helper comparisons. `s11h` enters
  its original boss branch and returns control with 2,888 movement units.
  `s11b` adds 833 comparisons for its distinct cinematic and smoke actor. A
  documented trigger-volume fixture follows the authored cinematic and restart
  into `s11g`, returns control, and later reaches normal Game Over under idle input.
  [Variants](docs/HIND_VARIANTS.md), [tower transition](docs/S11B_RECOVERY.md).
- The shared countdown matches 252 original-MIPS timer, callback, digit-call,
  and GPU-packet cases. Liquid's 227 recovered routines now link with Snake18
  and LensFlare. The original story277 introduction completes and releases
  control; a retry fixture moves Snake and reaches rooftop climbing. The hazard
  query now receives its required two-vector output buffer, fixing the climb
  stack overwrite. The 1,800-frame retry run is exception-free but ends hanging,
  so its generic movement probe reports incomplete. Liquid has 7,680 state
  comparisons and Snake18 has 1,134 movement/input comparisons. The later
  dedicated Liquid scenario above completes the fight.
  [Countdown](docs/COUNTDOWN_RECOVERY.md),
  [Liquid](docs/LIQUID_RECOVERY.md), [Snake18](docs/NATIVE_SNAKE18_RECOVERY.md).
- Both REX stage variants now compile with 40 named constructor bindings and
  13 recovered actor/effect units. The helpers pass 1,823 original-MIPS cases;
  the original story255 first-phase script now runs for 1,800 frames, creates
  REX and its drums, accepts movement, and shows laser attacks and damage
  reactions. Neither REX fight completion nor the alternate variant is validated.
- Rappel (`s11d`) runs its authored story178 arrival and Codec, then accepts
  normal lateral input on the rope. Its 2,816 MIPS comparisons pass; the complete
  descent remains unvalidated. [Evidence](docs/RAPPEL_RECOVERY.md).
- A 7,200-frame no-input fixture follows the original `d18a` story275 cinematic
  callback into `s18a` and constructs Liquid, Snake18 and the countdown.
  [Evidence](docs/D18_CINEMATIC_VALIDATION.md).
- Garage (`s19a`) now compiles its guard, commander, timer, drums, gate, jeep,
  Snake and companion code. It has 666 original-MIPS guard/timer comparisons,
  16 footprint-interface cases and 4,453 original-MIPS passenger/controller
  comparisons. The authored story284 entry runs for 1,800 frames and normal
  input moves Snake 1,286 units. Driving and encounter completion remain untested.
  [Evidence](docs/GARAGE_PROPS_RECOVERY.md).
- Escape (`s19b`/`s19br`) now links all recovered road, vehicle and character
  code. The original four helper suites passed 7,449 original-MIPS cases. Both variants run
  their authored introduction; a normal SDL input probe changes mounted aim in
  both directions and creates 15 player bullets. The 3,600-frame run reaches
  original Game Over after input stops. A newer full chase now completes the
  original outgoing transition. [Evidence](docs/ESCAPE_RECOVERY.md).
- Ranking and its PocketStation menus now compile from native C, replacing all
  97 missing game assembly blocks. The suites cover 39,970 original-instruction
  comparisons and explicitly identified repair cases. A live 1,800-VSync run
  renders the score screen, counters and award. Later supplied ending scenarios
  complete ranking, save and title; both saves also reload into a new round.
  Reaching them from full campaign play remains open. [Evidence](docs/RANKING_RECOVERY.md).
- Briefing now has all 43 missing assembly blocks replaced by C and passes
  109,348 original-instruction comparisons. An SDL input run follows intro
  cancellation into the original selector and starts another topic, which
  advances 383 actor ticks. [Briefing evidence](docs/NATIVE_BRIEFING.md).
- The photo album has all 16 missing blocks recovered and passes 11,404 original
  comparisons. A native drawing-order fix restores its missing menu labels.
  Initial UI rendering is verified; a full photo editing/save/reload session is
  still open. [Album evidence](docs/CAMERA_ALBUM_RECOVERY.md).
- Equipped-camera compression now uses native packet memory; four complete
  synthetic images produce the same encoded streams and retry behavior as the
  original instructions. [Capture evidence](docs/EQUIPPED_CAMERA_CAPTURE.md).
- Native startup now selects original English text. The dock Codec displays
  English dialogue and the corrected 140.85 frequency.
- The earlier frozen stack contained 57 MGS patches and fifteen PsyZ patches.
  Full bootstrap verification passes for both stacks. The renderer module contract and resource
  override boundaries are preserved through these additions.

These are **automated runtime checks**, not a human dock playthrough or campaign
completion. Direct stage entry does not supply missing story initialization.
Debugger scenario fixtures are recorded separately from normal game flow.

## Work in progress

The user-supplied Integral all-bosses TAS input movie (BizHawk 1.11.4) is now
downloaded and inspected. A reusable inspector validates all 313,202 input frames
and exports attributed CSV segments with both controllers and disc commands;
14 parser tests pass. A 415-frame initial dock/pipe segment is exported for the
next playback integration. The native game has not replayed this movie, and its
Extreme-difficulty save-RAM setup needs an explicit compatible starting state.
[Replay research and tooling](docs/TAS_REPLAY_RESEARCH.md).

The hand-authored automated dock navigator remains incomplete. Analog SDL steering now
keeps the pipe/crossing route clear of static collision, but guard avoidance
still fails. The latest normal-New-Game run waits safely at the spawn, observes
the original elevator descending and its guard leaving, then dies after the
central crossing. The log is `build/dock-route/arrival18000.log`; it was stopped
after the recorded player death. This verifies elevator arrival behavior, not
boarding, ascent, or a connected heliport transition by that navigator. The user's
later Xbox recording does establish the authored transition with Stealth on Very
Easy, and its complete prefix replays with matching state. It now provides a
recorded route independent of the navigator's guessed patrol timing.

All configured main-stage source selections are now present in the native build.
The current priority is stage behavior: boss completion, revisits and authored
campaign transitions. Individual new human crash recordings are deferred at the
user's request. A clean source-coverage audit does not establish that every actor
and campaign transition behaves correctly.

The encounter and acceptance items below are retained as test history and future
user-playthrough coverage, not an autonomous work queue. Do not resume automated
fight tuning or hold the source handoff for a passing automated campaign run.
Implementation work should address demonstrated missing scene code or user-reported
defects within the requested scope.

1. User playthrough: connected REX/Liquid and garage/escape through the original
   damage, input and script systems. The supplied Liquid retry fight and full
   escape chase now complete their authored handoffs. Liquid also reaches the
   garage through the original post-fight script. The authentic garage checkpoint
   route now completes the garage and full Normal escape continuously, reaching
   a verified original `s20a` entry. Complete endings have separate validation;
   the Normal checkpoint now also completes credits, save, title and a verified
   next-round save load. REX now completes both damage phases, strictly replays,
   and exports the original story259 rooftop handoff. The first Liquid encounter
   remains unverified from that checkpoint. No REX gameplay defect was demonstrated by these
   runs. See the [REX contract](docs/REX_ENCOUNTER_CONTRACT.md) and
   [campaign code audit](docs/CAMPAIGN_CODE_AUDIT.md).
2. User playthrough: save/load after normal progression, overwrite and error UI.
   Both completed-mission saves already reload through the original menus.
3. User playthrough: remaining authored movie transitions and audiovisual timing. The bounded native
   VLC/MDEC/STR/XA implementation now completes an original 414-frame clip in a
   diagnostic scenario. [Movie evidence](docs/MOVIE_VALIDATION.md).
4. Make SDK, graphics, sound or resource-lifetime corrections when a concrete
   scene implementation defect requires them. GPU masking and 5-bit blending pass native/scaled pixel checks
   and software transfer tests. [Graphics evidence](docs/GPU_MASKING.md).

## Modding and remaining limits

The loose-resource interface supports exact-length original-format assets under
`mods/stages/<stage>/<hash>.<extension>`, excluding executable PS1 `.b` overlays.
A verified replacement selected original texture bytes; custom artwork and
resized assets have not yet been demonstrated. Models, textures, sounds and
scripts remain external resources with explicit loading boundaries.

A working [renderer module interface](docs/RENDERER_MODULES.md) can replace the
current renderer at build time. Its present contract receives PS1 primitives and
VRAM operations. A modern mesh/material interface and standard-format asset
imports need further work; the current boundary is not a stable binary plugin API.

Remaining work includes runtime defects, connected campaign progression,
revisits, bosses, save/load acceptance, movies and sound fidelity, disc switching,
reaching the verified endings from connected campaign play. VR missions need separate recovery and validation. See the
[stage inventory](docs/STAGE_RECOVERY.md) and [backend gaps](docs/BACKEND_GAPS.md).

## Optional Codec fast advance

Holding Triangle can interrupt skippable dialogue and advance waiting dialogue
through native radio states. Unskippable blocks keep their guard; normal release
inputs remain. Held advances use a six-frame cadence and clear the debounce mask
before the state reuses it as a countdown. No game-clock acceleration is applied.
The GUI defaults on with a persisted Gameplay opt-out; direct native launches
require REI_CODEC_TURBO=1. A source-extracted CPU fixture checks off/unset/invalid
modes, hold/release, skip flags, cadence, stream-stop calls and debounce clearing.
Live Codec playability was reviewed in Reintegrated candidates; this upstream
branch has not received a separate full-game playthrough.
