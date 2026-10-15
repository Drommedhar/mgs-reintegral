# Stable 0.3.0 release workflow

Task: M8.03i. Status: committing, merging to main and publishing0.3.0.

## Publication authorization - 15 October

The user now explicitly requests committing, merging into main, pushing and building the new release. This supersedes the earlier no-push hold. Commit the reviewed source/docs/tests, preserve excluded local material files, merge latest main without rewriting remote history, push main and dispatch godot.yml with version0.3.0/publish=true. Verify the workflow and normal Latest release with game/SDK/symbols/checksums. Record the exact main/tag/run identities and results in the execution ledger and build/evidence/release-0.3-publication.

## Current approved contract - 15 October

- Prepare the workflow to run manually on main after merge and publish stable v0.3.0 as a normal release marked Latest. No alpha or prerelease flag.
- Build the launcher and Godot native host, include the preserved Legacy0.2 renderer, and package the modding SDK. Upload game, SDK, matching symbols and checksums only after validation.
- Publication defaults on for the manual release workflow and is restricted to main. Unchecking publish retains a build-only option. Existing versions are never overwritten.
- DONT PUSH YET: make and validate local edits only. No push, workflow dispatch, tag or release creation during preparation.
- Preserve on-demand pinned tools, user assets/settings and current delivered ZIPs. Local test candidates/evidence stay under build/evidence/stable-release.

The earlier alpha/default-off contract below is historical and is superseded by the stable release request above.

## Stable workflow validation

Optimized0.3.0 build,218CPU CTests,32offline workflow/package tests, actionlint, PowerShell parsing, Ruff and supported Aislop scans pass. Actual game556files/SDK677files pass archive/inventory/original-content/native-identity audits. Cold relocated SDK bootstrap, Open ZIP, lazy Python, Save As, Python repair and both headless imports pass; existing dummy-thumbnail diagnostic remains explicitly scoped. Evidence: build/evidence/stable-release/verified.json. Current ZIPs/mods/settings and26local-only files preserved. No push, dispatch, tag, publication or owned process. Automatic approval review blocked temporary staging/smoke deletion; copies remain and must not be deleted through another mechanism. Next: user reviews local changes before authorizing push/merge/run.

## Previous local candidate task (M8.03g)

Task: M8.03g. Status: complete within local candidate scope.

## Approved contract

- Commit the accumulated SDK33 source locally, then audit documentation and prepare release files. No GitHub commits, pushes, tags, workflow dispatches or releases.
- Separate game and SDK Windows ZIPs, version0.3.0-alpha.1. Publishing is an explicit default-off workflow option.
- Bundle no Godot, PowerShell or Python installation. Editor.cmd fetches pinned tools on demand, checks SHA256 and reuses installed tools offline. Preparation and editor Python operations fetch Python when needed.
- Preserve built-in Godot POM, user's mod assets and settings. Current deliverables go in build/releases/current; prior SDK goes in archive.

## Validation and delivery

Local checkpoint:8bcdd27. Subsequent release-preparation edits remain uncommitted. Optimized native/launcher build and214/214 CPU CTests pass. Fifteen bootstrap/package tests pass. Actual cold/offline downloads, CMD forwarding/exit status and exact tool versions pass. Fresh final SDK opens a ZIP, installs Python, repairs it during Save As and preserves the authored scene. CI uses a synthetic provenance catalog; retail preparation remains required for normal provenance checks. Both packages import headlessly. The known dummy-renderer thumbnail diagnostic is explicitly recorded/permitted; other errors fail the test. Archive hashes, inventories, no-retail checks, documentation links, source/patch verification and actionlint pass. Supported scoped Aislop scans have zero findings; cppcheck and unsupported PowerShell/GDScript engines are recorded in the ledger.

Game14,977,618bytes and SDK15,094,801bytes, symbols and checksums delivered in build/releases/current. SDK33 archived; docks/settings preserved. No GitHub action performed. Public loading-art permission and broad human/GPU/campaign acceptance remain open. Automatic approval review blocked temporary staging cleanup with “blocked by policy”; files remain, no retry. No owned process or unfinished implementation.

Authoritative evidence: docs/GODOT_SDK_PROGRESS.md and build/evidence/sdk-release/delivery-verified.json. Next: user reviews candidates and release edits. Publication is not authorized.
