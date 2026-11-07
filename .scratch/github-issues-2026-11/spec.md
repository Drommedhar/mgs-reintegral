# November GitHub issues and Godot update

User request: analyze, validate and fix the latest GitHub issues, then update Godot. User selected **4.8-beta2** on 7 November 2026. Work in the existing checkout and preserve user settings, authored content, FSR2 and the separate Legacy 0.2 binary.

## Scope and evidence

- Open [#4](https://github.com/Drommedhar/mgs-reintegral/issues/4): exit after opening cinematic/Codec. Attached native log downloaded to `build/evidence/github-issues-2026-11/issue-4.log`; native exits on `Godot renderer: connection closed or timed out`. This is evidence of transport failure, not yet evidence of its cause. Reproduce before claiming a crash fix. Keep capture disabled during disc runs. Improve actionable diagnostics where a proven reporting gap prevents diagnosis.
- Open [#2](https://github.com/Drommedhar/mgs-reintegral/issues/2): expose dithering and fractional pattern size (including 0.5, 1.0, 1.3, 1.4). Existing default rendering must remain unchanged. Use existing settings/Graphics workflows; do not redesign original UI. Preserve standalone Legacy 0.2; explicitly scope renderer support.
- Closed #1 is a contribution discussion and requires no action.
- Pin and install official Godot 4.8-beta2, update executable consumers, notices and package metadata, verify GDExtension compatibility and relevant renderer/SDK checks. Official release archive and GitHub release confirm beta2 is latest on the 4.8 line.

## Approach

Fix only reproduced defects. Use existing presentation/settings boundaries for the requested dithering control; preserve defaults. Upgrade the existing pinned binary and verify hashes, rather than introducing automatic unpinned updates. No issue comments/closures, publishing, push or release replacement is requested.

## Validation

Targeted red/green regressions, native/launcher compilation where changed, scoped Godot CPU/GPU tests and capture-free real-disc boot where relevant. Scoped Aislop scans; report unavailable engines honestly. Record exact results and unresolved evidence in the execution ledger.
