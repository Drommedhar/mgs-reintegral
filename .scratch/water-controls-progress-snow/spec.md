# Water controls, launcher progress and snow volume

Status: resolved

Execution ledger: docs/GODOT_SDK_PROGRESS.md, tasks M3.06c, M4.05c and M4.03e. Implemented and delivered in SDK20 on14October2026; human visual acceptance remains separate.

## Settled requirements

- Water regions expose ordinary Inspector controls for wave height/size, refraction, caustic strength/size and independent water/caustic speeds. Preserve existing material overrides and pool/ocean/puddle appearances, with independent per-region settings that survive save/reopen and export.
- Launcher moves status into the top banner below a raised logo and adds a progress bar. Show measured fractions where available; do not invent percentages for opaque work. Keep elapsed time/current work visible. No loading UI in game; retain the FPS/debug overlay.
- Provide a reusable placeable snow volume only. Do not add snow to the docks automatically (explicit user answer, 14 October 2026).
- Snow controls include amount, flake size and variation, fall speed and variation, wind direction, gusts and turbulence. Scene surfaces must block flakes from both sides even when their visual material is one-sided.
- Flakes settle/fade on impact without accumulating a persistent snow layer (explicit user answer, 14 October 2026).
- Visual changes must preserve native gameplay, collision and timing.

## Completed validation

- Import replay failed on misleading0%; the corrected launcher uses animated activity plus elapsed time for opaque GLB import, measured fractions elsewhere. Five CTests and real banner captures pass, including stale-callback cleanup.
- Two-sided swept ray collision handles reversed winding, roofs, wind into walls, moving/skinned and native-deformed geometry. Snow controls, pause/reset, contact following and original-snow replacement pass focused tests.
- Water GPU tests verify independent regions, preset preservation, save/reopen and independent wave/caustic speeds. Both final docks variants reopen successfully.
- Snow copy/export/import/reopen preserves321flakes,0.02–0.04m size and1.7m/s speed, with no generated collision geometry in the ZIP.
- Full-map profiling caught repeated unused-bone work; final collision synchronization p95 fell from5.352ms to0.445ms. A1200-frame1440p real-disc run with1000temporary flakes exits0; warm windows59.55–59.75FPS. No snow was saved into the docks mod.
- Final SDK archive provenance/hash audit passes;29 relevant runtime files match source and the tested SDK. Aislop100 on8supported C#/Python files; GDScript/shaders are unscored. See ledger for evidence paths, limitations and artifact hashes.

## Confirmed scope

User confirmed the combined scope on 14 October 2026, including an enabled-by-default switch to replace original snow within a placed volume. Production implementation is authorized. Two-sided swept particle collision uses locally derived geometry; the source meshes' skin poses must be respected. Native gameplay physics stays separate. Collision costs and GPU appearance require measured validation.
