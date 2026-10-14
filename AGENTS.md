# Project instructions

Direction approved on 2026-10-12: deliver the complete Godot presentation renderer and modding SDK described in `docs/GODOT_SDK_MASTER_PLAN.html`. Keep the recovered C runtime authoritative for gameplay, collision, animation, audio, saves and timing. Godot must own all visuals, including editable original-layout UI, effects, cinematic-only maps and camera tracks. Dynamic native actors expose independently moving anchors and state/events for ordinary Godot parenting and scripting. The launcher selects Legacy 0.2, Godot or compatible community renderers. Preserve Remix Plus as a separate experiment, with further integration work deferred.

The user explicitly authorized an active goal and persistent session handoff. Read `docs/GODOT_SDK_PROGRESS.md` before continuing; it is the granular execution ledger. After the initial actor bridge, the user rejected spending further sessions on elevator events. Prioritize the usable M2/M3 editor, native-run and ZIP workflow now. Ordered events and generalized lifecycle/resync remain required later work, but must not gate this workflow. Do not repeat native elevator timer probes unless a new implementation change requires them. Update task IDs, validation evidence, blockers and the exact next action there before ending a session or compacting context. `PROGRESS.md` and `docs/GODOT_RENDERER_PLAN.md` retain historical evidence; their old version/readiness statements are not current acceptance claims. Preserve inherited FSR2 changes and user settings; do not reset unrelated work.

Continuity correction from the user: before compaction, update the ledger's top status, Current work table and Current handoff, not only historical entries. Record unfinished edits separately from validated work, the next executable action and any owned processes. On resume, use that current handoff; historical user reports and older "Next" paragraphs are not new assignments. Do not repeat completed Codec, elevator or display checks without a relevant change or new evidence. A user status question or clarification does not restart the implementation plan.

Local output policy, approved 2026-10-14: put current deliverables in `build/releases/current/`, rollback archives in `build/releases/archive/`, and temporary test evidence in `build/evidence/<task>/`. Keep canonical CMake build directories and the editable Godot project in place. Remove redundant staging/extracted test copies after verification; preserve logs and unique authored assets. Do not write outputs to Downloads; the user maintains that folder. Keep the editor's remembered mod export destination inside the release folder.

Real gameplay and performance runs must have diagnostic screenshot/frame/scene capture disabled. Capture requires explicit diagnostic opt-in, and its timings are visual evidence only. Preserve the FPS/debug overlay. Do not launch competing background game/GPU probes while the user tests.

The user subsequently requested GDExtension modding, dynamic lights/shadows, PBR materials and Godot map authoring. Maps use local original-content previews; exported mods contain edits and custom assets, never the original files. Object removals are visual only for this milestone, as explicitly confirmed by the user. Preserve native collision and gameplay.

The user rejected requiring F7 or a running game to view/edit maps. Load map geometry and textures directly from prepared disc data using the original map declarations. Keep gameplay-dependent actor state distinct from static map assembly; do not make runtime snapshots a prerequisite for authoring.

Use Godot's normal Scene tree, node creation, Inspector, materials, animation tracks, signals and visibility tools. Show original model/part IDs and declared map lights in that tree; do not replace these workflows with MGS-specific lists or light/PBR creation buttons. Keep integration UI focused on content loading, original-asset references, native bindings/test sessions, diagnostics and mod packages. Original lights must come from the game's light data, not invented starter lamps.

Display settings belongs inside Options, registered on the existing Screen row as Display. Do not add a floating top-right entry or global F10/R3 opener. Back appears only inside the Display page, returns to Options and restores its selected row/focus. Keep the page editable through normal Controls and the mod UI registration contract.

Default UI fidelity is mandatory: reproduce the original UI 1:1. The only approved presentation changes are settings and the previously requested PC Save/Load list. Do not add inventory action footers, new Back buttons, extra labels, diagnostic overlays, tooltips or replacement wording elsewhere. Native inventory keeps held-button opening and release-to-equip. An SDK API for custom interfaces does not authorize redesigning the default interface; keep custom UI examples and validation fixtures separate.

Map selection must use a searchable list, not a dropdown. The user refined the editor layout on 2026-10-13: use focused Maps, Assets, UI, Effects and Mod tabs, not one scrolling stack of buttons. Give the map list the remaining dock height. Top-level rows are human-readable locations; expand them for gameplay/cinematic variants and camera clips. Combine prepared sources without a disc selector in the map browser; retain exact source identity internally. Show whether the active mod changes a scene directly or through inherited edits, and keep unprepared scenes visible with actionable reasons. UI/effects use grouped browsers and one Open action, not one button per resource. Readable names come from the pinned FoxdieTeam reversing README; preparation and native playability remain separate facts.

Save/Load is a deliberate PC presentation adjustment: show a flat list of saved games and New Save, without memory-card or block selection. Preserve the original MGS typography, green-on-black colors and framing. Keep native memory-card storage and save compatibility underneath; the user requested a visual change, not a new save format.

The faithful native Windows rebuild remains the gameplay foundation. Keep recovered gameplay C readable and preserve useful boundaries for custom graphics, resource mods, and a later map editor. Do not replace unrecovered behavior with silent success stubs or describe a stage development build as a completed game.

Preserve the recovered stage code and address missing vendor behavior when found. Reuse existing recovered implementations and reconstruct missing functions from original-game evidence. Keep the renderer replaceable and models, textures, sounds, scripts and stage data modifiable; do not embed retail data in generated source. Record evidence and intentional compatibility differences.

The user clarified on 2026-10-09: implement all scene code and compile it; the user will perform the playthrough after the code handoff. Do not continue tuning automated players, attempting automated encounter completion, or expanding into unrelated work. Keep any necessary verification scoped to the implementation being changed. Unverified gameplay is a handoff note, not a reason to postpone the scene-code handoff or invent more implementation work.

Keep input operating-system independent through SDL. Windows is the initial target, not a permanent engine requirement. Confine Windows scheduler, filesystem and process behavior to host adapters; do not introduce Windows input APIs into game actors. Native startup should select the original English text resources.

Validation labels must remain precise: source present, source recovered, native compilation, automated runtime checks, and human playability are different milestones. An input/coordinate probe is not a manual dock playthrough and must never be reported as one. Keep a persistent progress ledger with completed work, current blockers and next tasks.

Work in this project; preserve the original MGSR project and the user's disc images. Retail assets, extraction results, tool downloads, and build outputs stay in the ignored local directories. Source revisions and changes to downloaded code must be reproducible through `sources.lock.json` and `patches/`. Export affected patches after vendor edits and verify bootstrap application.

Only one agent may run CMake/Ninja against a given build directory at a time. Keep independent test compilations in distinct paths. Run the relevant CTest suites and a real disc boot when changing platform behavior; a VSync limit alone does not establish loaded or playable gameplay.

## Aislop

Treat aislop findings as blocking according to the user's severity ladder:

- `error`: fix in the same turn.
- `warning` with `fixable: true`: fix in the same turn.
- `warning` with `fixable: false`: fix if mechanically simple; otherwise report it.

Act on hook feedback, `suggestedActions`, and `nextSteps`. If the environment does not invoke the edit hook, run a scoped scan manually. `.aislop/config.yaml` is authoritative if present; do not alter configuration or disable rules without user consent. Open `.aislop/rules.yaml` when an architecture finding cites it. Explain false positives rather than deleting their rules. Report unavailable scan engines and inherited nonfixable findings honestly.

## Agent skills

### Issue tracker

Issues and specs use local Markdown under `.scratch/<feature>/`. Before issue or spec operations, read `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage roles. Before triaging, read `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: root `GLOSSARY.md` and `docs/adr/`. Before exploring domain concepts or decisions, read `docs/agents/domain.md`.
