# Project instructions

The first priority is a complete, faithful native Windows rebuild. Keep recovered gameplay C readable and preserve useful boundaries for custom graphics, resource mods, and a later map editor. Do not replace unrecovered behavior with silent success stubs or describe a stage development build as a completed game.

The active goal is full stage code recreation, including missing vendor behavior. Reuse existing recovered implementations and reconstruct missing functions from original-game evidence. Keep the renderer replaceable and models, textures, sounds, scripts and stage data modifiable; do not embed retail data in generated source. Record evidence and intentional compatibility differences.

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
