# Project instructions

Direction confirmed on 2026-10-11: Godot is the primary renderer and modding SDK/editor path. Keep the recovered C runtime authoritative for gameplay, collision, animation, audio, saves and timing. Build on the matched v4 renderer and visual mod workflow; resolve the remaining visual/transition acceptance work in `docs/GODOT_RENDERER_PLAN.md` before expanding the SDK. Preserve Remix Plus as a separate experiment, with further integration work deferred. The existing native alpha remains the playable baseline while Godot is brought up to that standard.

The user subsequently requested GDExtension modding, dynamic lights/shadows, PBR materials and Godot map authoring. Maps use local original-content previews; exported mods contain edits and custom assets, never the original files. Object removals are visual only for this milestone, as explicitly confirmed by the user. Preserve native collision and gameplay.

The user rejected requiring F7 or a running game to view/edit maps. Load map geometry and textures directly from prepared disc data using the original map declarations. Keep gameplay-dependent actor state distinct from static map assembly; do not make runtime snapshots a prerequisite for authoring.

Use Godot's normal Scene tree, node creation, Inspector, materials and visibility tools. Show original model/part IDs and declared map lights in that tree; do not replace these workflows with MGS-specific lists or light/PBR creation buttons. Keep integration UI focused on disc loading, original-asset references and mod export. Original lights must come from the game's light data, not invented starter lamps.

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
