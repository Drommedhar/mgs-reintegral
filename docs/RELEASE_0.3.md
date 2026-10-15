# RE:INTEGRAL 0.3.0-alpha.1

Local release candidate for the Godot presentation renderer and modding SDK.
Publication is a separate, explicit step. Campaign-wide Godot appearance,
playability and performance acceptance are still in progress.

## Downloads

- **Game:** `reintegral-0.3.0-alpha.1-windows-x86.zip`. Includes the launcher,
  native gameplay host, Godot presentation project and preserved Legacy 0.2.
- **SDK:** `reintegral-sdk-0.3.0-alpha.1-windows-x86.zip`. Includes everything
  needed to play plus the editor plugin, authoring examples and GDExtension sources.
- **Symbols:** matching native debugging symbols. Not needed to play.
- **SHA256SUMS:** hashes of the release downloads. Both game and SDK also contain
  per-file inventories and the modified MPL-covered source/notices.

Both packages require 64-bit Windows despite the x86 gameplay host. Extract the
whole ZIP, run **Prepare.cmd** with your Integral campaign discs, then **Play.cmd**.
Use **Editor.cmd** in the SDK to create mods. See the [player guide](PLAYER_GUIDE.md)
and [SDK quickstart](SDK_QUICKSTART.md).

Godot, PowerShell and Python are downloaded only when needed, verified against
pinned SHA-256 hashes and reused offline. They are not bundled in `.tools`.
No original game assets, prepared disc content, saves or user mods are distributed.
The docks remaster is a separate mod, not part of these downloads.

## Included changes

- Godot scene rendering and Legacy through Godot, with original gameplay,
  collision, animation, audio, saves and timing remaining native.
- Editable maps, materials, lights, supported actor anchors, UI and cinematic
  camera tracks; native test sessions and mod ZIP export/import.
- Original-layout UI, Display settings, flat PC save/load lists and font options.
- Water, frost, snow, native wet footprints and improved transparent-layer ordering.
- Startup status beside the loading animation; scene loading animation and
  audio continuity during renderer waits, while respecting native stop commands.
- Built-in Godot POM support. The experimental SPOM and generated relief mesh
  tools were removed after full-resolution performance regressions.

## Limits and release checks

Bounded 2560×1440 docks checks after restoring built-in POM held59.94 FPS while
entering first person and turning. Checked opening windows measured59.55–59.97 FPS,
with one76.12ms hitch. These are scenario-specific measurements, not a guarantee
for every GPU, map or mod. First import/loading delays and eight shutdown ObjectDB
warnings in the checked modded runs remain documented. Wet-footprint integration
is tested; human in-game appearance acceptance remains open.

Ordered actor events, generalized lifecycle/reconnect recovery, campaign-wide
fidelity and broader controller/hardware acceptance remain unfinished. The
earlier native campaign playthrough does not establish Godot playability.

The loading animation credits Irbif. Its [notice](../licenses/loading-animation/NOTICE.txt)
records that public redistribution permission has not been verified. This remains
an open publication item; attribution alone does not resolve it. The current
task prepares local candidates and does not publish or create a remote tag.

See [third-party notices](THIRD_PARTY.md) for all component scopes.
