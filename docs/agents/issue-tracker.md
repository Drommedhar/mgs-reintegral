# Issue tracker: Local Markdown

Issues and specs live in `.scratch/`. Paths below are relative to the repo root.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`.
- Spec: `.scratch/<feature-slug>/spec.md`.
- Tickets: `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, one file per ticket.
- Triage state: a `Status:` line near the top, using the role strings in `triage-labels.md`.
- Comments and conversation history: append under `## Comments`.

For Godot renderer/SDK work, `docs/GODOT_SDK_PROGRESS.md` remains the authoritative execution ledger. Reference its task IDs in related tickets and keep its current handoff up to date.

## Publishing and fetching

When a skill says “publish to the issue tracker”, create the appropriate spec or ticket file using these conventions.

When a skill says “fetch the relevant ticket”, read the supplied path. Resolve a bare ticket number within the current feature; ask for the feature if ambiguous.

## Wayfinding operations

- Map: `.scratch/<effort>/map.md`, containing Notes, Decisions-so-far and Fog.
- Child ticket: `.scratch/<effort>/issues/<NN>-<slug>.md`, with the question in its body.
- Type: `research`, `prototype`, `grilling` or `task` in a `Type:` line.
- Blocking: a `Blocked by: NN, NN` line. A ticket is unblocked when every listed ticket is resolved.
- Frontier: choose the lowest-numbered open, unblocked, unclaimed ticket.
- Claim: set `Status: claimed` and save before work.
- Resolve: append the answer under `## Answer`, set `Status: resolved`, then add a gist and ticket link to the map's Decisions-so-far.

`claimed` and `resolved` are wayfinding lifecycle states, separate from the triage role vocabulary.
