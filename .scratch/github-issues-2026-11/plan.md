# GitHub issues and Godot update implementation plan

> Execute with systematic debugging, test-driven development where a meaningful regression seam exists, and verification-before-completion. Independent ownership follows the dispatching-parallel-agents skill; final integration and GPU/native runs are serialized by the root agent.

**Goal:** Address open issues #4 and #2 and migrate the existing SDK/runtime to Godot 4.8-beta2.

**Architecture:** Native gameplay remains authoritative. Presentation controls use launcher/settings and Godot rendering boundaries. Tool distribution stays pinned in sources.lock.json.

**Spec:** `.scratch/github-issues-2026-11/spec.md`

## Tasks

- [x] #4: inspect reported log and attempt actual NewGame reproduction on dev7/beta2; fix the established reporting gap with regression coverage. Missing renderer logs explicitly recorded.
- [ ] #4 root cause: obtain matching reporter renderer logs and reproduce the indicated failure. Current evidence does not establish a crash fix.
- [x] #2: trace existing dithering, add supported persisted controls and fractional scale without changing defaults, verify settings round trips and actual rendering behavior.
- [x] Godot: verify official archive, install beta2 alongside dev7, update runtime/tool/package paths and pinned notices, validate version plus import/extension compatibility.
- [x] Integrate: build serially, run relevant CTests and Godot tests, run scoped Aislop, inspect diff and obtain final review.
- [x] Update ledger top status, Current work and Current handoff with validated work, unresolved reports, next action and process ownership.

## Review focus

Preserve old settings defaults; fractional/invalid scales; renderer-specific unsupported controls; renderer exits versus transport timeouts; engine upgrade invalidates stale resource caches; no generated retail assets in tracked output.
