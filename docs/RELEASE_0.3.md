# RE:INTEGRAL 0.3.0

Stable-channel release of the Godot presentation renderer and modding SDK.
Campaign-wide Godot appearance, playability and performance acceptance are
still in progress; the known limitations below remain applicable.

## Downloads

- **Game:** `reintegral-0.3.0-windows-x86.zip`. Includes the launcher,
  native gameplay host, Godot presentation project and preserved Legacy 0.2.
- **SDK:** `reintegral-sdk-0.3.0-windows-x86.zip`. Includes everything
  needed to play plus the editor plugin, authoring examples and GDExtension sources.
- **Symbols:** `reintegral-0.3.0-symbols.zip`, matching native debugging symbols.
  Not needed to play.
- **Checksums:** `reintegral-0.3.0-SHA256SUMS.txt`. Both game and SDK also contain
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
- Preserved standalone Legacy 0.2, selectable through the same launcher.
- Editable maps, materials, lights, supported actor anchors, UI and cinematic
  camera tracks; native test sessions and mod ZIP export/import.
- Original-layout UI, Display settings, flat PC save/load lists and font options.
- Water, frost, snow, native wet footprints and improved transparent-layer ordering.
- GPU snow with weather collision, plus the optional exact CPU collision mode.
- Background editor status checks and responsive ZIP export with progress and
  cancellation, including the fix for the empty native export window.
- Reduced renderer scheduling waits and optional Triangle-held Codec fast advance.
- Startup status beside the loading animation; scene loading animation and
  audio continuity during renderer waits, while respecting native stop commands.
- Built-in Godot POM support. The experimental SPOM and generated relief mesh
  tools were removed after full-resolution performance regressions.

## Limits and release checks

Locked 60 FPS is not yet achieved for every scene or mod. The latest capture-free
2560×1440 docks mod checks with GPU snow measured 55.81 and 54.34 FPS in the later
sampled windows. These are scenario-specific measurements, not a guarantee for
every GPU, map or mod. First import/loading delays, individual frame spikes and
ObjectDB shutdown warnings remain documented. GPU weather collision does not
preserve exact triangle collisions or flakes attached to moving surfaces; the
CPU mode retains those behaviors. Wet-footprint integration is tested; human
in-game appearance acceptance remains open.

Ordered actor events, generalized lifecycle/reconnect recovery, campaign-wide
fidelity and broader controller/hardware acceptance remain unfinished. The
earlier native campaign playthrough does not establish Godot playability.

The loading animation credits Irbif. Its [notice](../licenses/loading-animation/NOTICE.txt)
records that public redistribution permission has not been verified. This remains
an open publication item; attribution alone does not resolve it.

See [third-party notices](THIRD_PARTY.md) for all component scopes.
