# GitHub #4: opening cinematic / Codec disconnect

Status: needs-info
Type: task
Ledger: M8.03k
Source: https://github.com/Drommedhar/mgs-reintegral/issues/4

The attached 0.3.0 native log records `Godot renderer: connection closed or timed out` followed by exit1 during d00a. This is the host's deliberate transport-failure exit, not a native access-violation trace. The corresponding `godot-*.log` and `godot-*.err` files were not attached. They are needed to identify whether Godot rejected a command, failed in its renderer/driver, or stopped for another reason.

## Work

Launcher failure reports now append bounded renderer stdout/stderr tails, their full log paths, and the renderer exit code observed before cleanup. A process intentionally stopped by the launcher is distinguished from a renderer that had already exited. This repairs the demonstrated diagnostic gap; it does not establish a fix for the reported crash.

Regression covers error/phase inclusion, exit-code formatting, bounded history and cleanup/not-started labels. Optimized launcher compilation and relevant CTests pass. Real-disc reproduction and final evidence are recorded in `docs/GODOT_SDK_PROGRESS.md` and `build/evidence/github-issues-2026-11/`.

## Next action

Obtain the reporter's matching renderer stdout/stderr (or a new combined failure log from this build) and reproduce the indicated failure. Do not close the GitHub report based only on a successful run on different hardware.
