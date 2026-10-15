# Local 0.3.0-alpha.1 release preparation

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
