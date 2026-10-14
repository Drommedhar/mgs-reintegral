# Shared settings provider, schema 1

The launcher and Godot share the existing profile's `settings.xml`. The provider
currently exposes `display.resolution` (string), `display.widescreen` (boolean)
and `display.fullscreen` (boolean). The launcher uses the same display validator
and resolution choices as the provider. Current Godot sessions support live
display previews with confirmation/revert; older peers use next-launch settings.

`SettingsRegistry` reads and merges only known settings. Save uses the launcher's
atomic temporary-file replacement. Disc paths, languages, gameplay preferences
and mod selections are preserved. A SHA-256 revision of the profile rejects
requests based on an older read; a stale client must reload before retrying.
`validate` never writes. Invalid types, unknown setting IDs, incompatible aspect
and resolution combinations, and storage errors return explicit errors.

`GodotSession` owns the service in launcher sessions. `tools/run-godot.ps1` owns
`settings-host.exe` for command-line and editor native-test sessions, using
`settings.xml` inside the chosen runtime directory. Omitted display parameters
use saved settings; explicit `-Resolution`, `-Widescreen:$false`/`$true` and
`-Fullscreen:$false`/`$true` override this launch without replacing saved values.
A new command-line profile retains the previous 1280x960/original-aspect default.
Launcher profiles retain their existing default. Both paths use the same code.

## Godot API

The visual API's `get_settings_provider()` returns the settings client Node.
Obtain the visual API through the `mgs_visual_api_v1` group, as with actor and
camera bindings. The provider exposes:

- `snapshot`: latest successfully read state; empty until the first read.
- `get_snapshot()`: storage plus actual applied/runtime policy when connected.
- `display`: live transaction controller; see its API below.
- `unavailable_reason`: nonempty when no settings host is configured.
- `request(action, values = {})`: returns a positive request ID, or zero with
  `last_error` explaining rejection. Only one request can be pending.
- `settings_updated(snapshot)`: emits a detached copy after a valid response.
- `request_finished(id, error)`: empty error means success. Always wait for this
  result before treating a save as committed.

Actions are `read`, `validate` and `save`. For the latter two, `values` contains
only changed IDs. The client adds its last revision automatically. For example:

```gdscript
var api = get_tree().get_first_node_in_group("mgs_visual_api_v1")
var provider = api.get_settings_provider()
var request_id = provider.request("validate", {
    "display.resolution": "1920x1080",
    "display.widescreen": true
})
if request_id == 0:
    show_error(provider.last_error)
```

On successful validation, `snapshot.candidate` contains the complete proposed
display values. A raw `save` request only persists changes. Live settings UI must
use the display transaction below instead of saving an unconfirmed preview.

Snapshots contain schema, revision, definitions, launch, saved, restart_required
and live_apply. Definitions describe each ID's type, label, owner, bounds/choices
and application policy. `launch` records the configuration requested for this
session, not a claim about measured GPU viewport state or advanced native argument
overrides. `saved` records the profile. `restart_required` lists their differences.
The storage service reports `live_apply: false`: it cannot change the native/GPU
session itself. `provider.get_snapshot()` adds negotiated runtime state and marks
supported definitions `application: "live_confirm"`. It includes `applied`,
`display` (phase, confirmation time remaining, error), and `unapplied_saved`.
The latter lists stored values different from the actual running configuration;
live-capable fields do not require a restart. `settings_updated` emits this
effective snapshot. The raw `provider.snapshot` retains the host response.

## Live display transaction

`provider.display` exposes `preview(changes)`, `confirm()` and `revert()`; each
returns an empty string when accepted or a reason for rejection. Subscribe to
`changed(state)` and `finished(result, error)` before requesting a preview.
`result` is `confirmed`, `reverted`, `rejected`, or `failed`. Read `snapshot()`
for applied values, negotiated support, phase, remaining seconds and last error.

```gdscript
var provider = api.get_settings_provider()
var error = provider.display.preview({
    "display.resolution": "1920x1080",
    "display.widescreen": true
})
if not error.is_empty():
    show_error(error)
# Enable Keep / Revert only when changed(state).phase == "preview".
# Keep calls provider.display.confirm(); Revert calls provider.display.revert().
```

Changes merge into actual applied values, then pass through the shared host
validator. At the pre-actor DISPLAY barrier, Godot prepares replacement buffers;
native code acknowledges projection/culling changes before the next actor update.
Godot then switches textures, world/metadata extents and window mode/size, resets
temporal history and checks the window system's result. Only then does the
15-second confirmation timer begin. Codec/movie/menu canvases retain 4:3.

The old GPU buffers remain allocated until confirmation or rollback. Cancel,
timeout and rejected changes do not save. Rollback reuses the old buffers and
seeds them with current native VRAM, preserving texture uploads made while the
preview was active. Allocation or native rejection leaves the previous display
active. Window rejection restores native projection and the original window.
An unexpected wire identity or failed restoration terminates with an explicit
error rather than continuing with mismatched projection and buffers.

Confirm uses the existing revision-checked save request. A lost save response is
ambiguous: the controller reads the profile back. Matching values confirm the
preview; otherwise it restores the running display. If readback also fails, the
error explicitly says that saved settings could not be verified. No compensating
write silently overwrites another session's changes. Closing an unconfirmed
session never saves its preview. Fullscreen uses the desktop size; resolution
still selects the internal rendering scale.

The native capability can operate without a settings host, but preview validation
and persistence require that host. The effective snapshot only advertises live
application when both are available. Legacy/older peers retain restart policy.

Godot initiates its first read only after renderer/shader initialization; starting
the connection before warmup can leave the host waiting while the main thread is
unable to send. The client performs no synchronous filesystem/network calls in
the frame presentation path. Request deadlines are five seconds.

## Local transport

This service is separate from native rendering protocol 15.30. The host listens
on an ephemeral loopback TCP port in `MGS_SETTINGS_PORT`. Every request must carry
the launcher-owned session token (`MGS_GODOT_SESSION_TOKEN` for Godot or
`MGS_PRESENTATION_TOKEN` for launch API 2 companions); the token never appears in public
snapshots or readiness files. It is local session authentication, not a sandbox
against installed mod code or other code running with the user's privileges.

One connection carries one request/response. Each begins with a little-endian
uint32 byte length, followed by UTF-8 JSON. Requests are limited to 4096 bytes and
responses to 65536. Request fields:

```json
{"schema":1,"id":1,"token":"<session token>","action":"read","revision":"","values":{}}
```

Successful responses contain `schema`, matching `id`, empty `error`, and
`snapshot`. Rejections contain a nonempty `error` without a snapshot. An
unauthenticated request gets ID zero and no settings. Truncated/oversized framing
closes that connection; errors are logged and the service remains available.
Stopping the owning session closes the listener and active client before joining
its worker. No profile is written merely because a configured service starts;
the standalone host initializes a profile only when none exists.

## Verification and remaining work

`launcher_settings_registry` exercises validation, preservation of other settings,
revision conflicts, restoration, next-launch arguments, authentication and disposal
with a partial request. `tools/test-settings-bridge.ps1` starts the production
host, runs the actual Godot client against an isolated profile, saves and restores
values, then starts a second host and checks that it reads the saved selection.
The main Godot test runner includes this check and requires `settings-host.exe`
from the matching native build.

`display_settings_test.gd` covers transaction sequencing, identity rejection,
allocation/native/window failures, timeout and ambiguous save reconciliation.
`display_buffers_test.gd` checks real GPU transitions, retained-buffer rollback
and current VRAM preservation. `resolution_test.gd` includes world viewport
resize/binding invalidation. Native tests cover projection/canvas restoration and
wire acknowledgement. The opt-in `tests/fixtures/display_settings/mod.json` dock
fixture exercises cancel, timeout, fullscreen confirmation and profile restoration;
run it only with an isolated profile and `-Probe dock`.

Still required: audio, controller, renderer-quality and mod-defined providers,
plus native pause/system-menu integration. These APIs do not complete
the full shared settings or editable settings milestones.

## Editable display panel

Display settings register in **Options → Display**, using the existing Screen
row. There is no floating entry or F10/R3 shortcut. Back is visible only inside
the page and restores the Options selection/focus. The panel uses normal OptionButton, CheckButton,
Button and Label nodes with locally bound original menu typography. Select a
resolution, widescreen/original aspect and fullscreen, then Apply Preview.
Keep Changes confirms and saves; Revert, Escape during preview, or the 15-second
timer restores the previous configuration. Revert receives initial confirmation
focus. Back/Escape closes the idle panel. Pending transactions retain input
ownership until settled. Validation and persistence errors appear in the panel.

The panel captures keyboard, controller and mouse interaction. Native digital
and analog host input is neutralized on both ports while open, and held controls
must be released before returning to gameplay. **Simulation continues**; the
native pause/audio/timing behavior is unchanged by this slice.
Original Options still owns its existing gameplay actions.

In the editor, choose **Edit Display Settings UI**. The mod slot is
`ui.display_settings.scene`; its default export contains the manifest, TSCN and
`display_menu_ui.gd` only. Fonts rebind from verified local content. Normal node
placement, Theme editing and ZIP reopen/export work. The root contract is a
Control with `connect_provider(provider)`, `allow_capture(bool)`, `allow_options(bool)`, `open_menu()`,
`close_menu()` and `capture_changed(active)`. Optional `bind_originals`,
`detach_originals` and `update_preview` support the existing editor sessions.
Custom scripts can use the same public display transaction provider.

`display_menu_test.gd` checks authored layout, editor save, original-free ZIP
relocation, keyboard/R3 navigation, preview/cancel/timeout/confirmation, countdown,
focus and release gating. Its GPU mode renders the actual Controls. Native
`mgs_godot_input_capture_test` covers both ports, digital and analog modes,
connection preservation and release latching. The isolated opt-in
`tests/fixtures/display_menu/mod.json` opens the menu with Godot input events,
clicks Preview/Revert/Keep/Back, verifies applied and persisted values, and reopens
with R3 during a real dock run. Synthetic controller events and native buffer
tests are not a physical-controller usability review.

Current navigation correction (13 October): `display_menu.register_options()`
calls `options_ui.register_page(6,"DISPLAY",display_ui)`. The selected native row
is acknowledged before opening; capture suspends Options and Back restores its
focus. The page has its own drawing priority above Options. Default page and
Options templates remain ordinary editable Controls. `display_menu_test.gd` now
checks registration, absence of an external entry/hotkeys, native row selection,
controller entry, Back/focus return and original-free ZIP reopening. The earlier
R3 evidence above describes the superseded global-overlay implementation.
