# GitHub #2: native Godot dithering controls

Status: ready-for-human
Type: task
Ledger: M8.03k
Source: https://github.com/Drommedhar/mgs-reintegral/issues/2
Resolution: implemented with automated validation; human appearance acceptance pending

The existing renderer honored native dithering flags but provided no user control. Graphics now exposes Native dithering (Godot) and fractional pattern scale0.25–4.0. Old settings default to enabled/1.0, preserving their output. Both Godot modes support the controls; standalone Legacy0.2 and community renderers do not. Custom/PBR material colors remain unchanged.

Validation includes XML persistence/old profiles, invalid scales, invariant environment formatting under German locale, actual WinForms controls and ReadSettings, strict shader adaptation, default output, native eligibility, fractional primitive/WORLD pixels, depth composition and Legacy-through-Godot behavior. Evidence: `build/evidence/github-issues-2026-11/dithering/`; final integrated results are in the execution ledger.

GitHub has not been modified. Source changes are not yet in published0.3.0 packages.
