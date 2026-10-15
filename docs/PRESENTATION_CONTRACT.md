# Presentation contract v1 — design specification

Status: **target design, partly implemented**; see the execution ledger for tested coverage. This design closes M0.07–M0.10 and guides the minimum M1 bridge. It does not change the existing [prototype v15.5 wire protocol](GODOT_PROTOCOL.md). Public class names in the HTML remain examples until implemented and versioned.

Native owns simulation, animation evaluation, collision, scripts, audio, saves and timing. A presentation provider publishes what happened and the current state. Godot owns appearance and submits validated actions. No mod binding may transfer gameplay authority by hiding or replacing a visual.

## 1. Identities and content revisions

Do not use memory addresses, Godot node names, model hashes alone or array positions as persistent actor identities.

| Identity | Fields and purpose |
| --- | --- |
| Original asset | Edition, disc, stage/resource namespace, resource name/type and source digest; exact local content reference |
| Scene | Edition, disc, native stage, scenario/entry profile and content revision; resource stage and native gameplay stage are separate fields |
| Declaration | Scene source reference, script resource digest, procedure ID, statement location and constructor ID; distinguishes two declarations of the same model/name |
| Runtime actor | Session ID, scene epoch, actor slot and generation; identifies one live incarnation |
| Spawn origin | Declaration reference plus parent actor/spawn role when generated in native code; clip/track source for cinematic objects |
| Anchor | Provider schema ID, actor identity and stable role/part ID; independent of artist node names |
| Resource incarnation | Session resource ID plus revision; retained create/update/retire ownership |

Authored bindings select declaration/role and an explicit cardinality: one expected instance, all matching instances, or a documented provider slot. A “one” binding with multiple matches is an ambiguity error. An absent conditional actor is inactive, not a missing asset. A known resource whose declaration cannot be resolved is an error, not an invitation to choose the closest model.

Actor slots may be reused only with a new generation. Session IDs change on a new native process. Scene epoch increments on every scene reset/reload, including loading the same stage name; runtime objects from an older epoch cannot satisfy bindings in a newer one. Counter exhaustion is an explicit session failure, never wraparound.

Asset references retain original import provenance through derived meshes, textures, subresources and previews. A digest change produces a new revision. Renaming an artist node does not change its stored target. Reimport preserves references only when provenance and topology still match. A changed script offset or part layout requires an explicit migration mapping or user retargeting; do not infer equivalence from matching names or geometry. Save As duplicates the mod identity deliberately, not the original-content identity.

For stage transitions where resident resources survive, scene identity still changes while eligible retained asset resources may be reused. Live actors must be explicitly carried into the new epoch or respawned there; incidental pointer survival is not authority.

## 2. Transform and pose spaces

Public authoring uses native world axes scaled by **1/1000**, with Y up. Matrix basis values are dimensionless; positions, ranges and linear velocities use metres and metres/second. Native angles/quaternions must be converted by the provider rather than interpreted as radians by the consumer.

The current prepared-mesh renderer uses `R = diag(1,-1,-1)`, a proper 180-degree X rotation. This is an internal compatibility conversion, not a public handedness change. Original mesh local coordinates and their actor transforms must use the same basis. Converting a local-to-world transform between two fully converted spaces uses `R * T * R^-1`; inserting a native-space world under a renderer-space root uses `R * T`. Do not combine both operations for the same boundary. [map_coordinates.gd](../renderers/godot/project/map_coordinates.gd) contains the current map-root conversion.

Every anchor payload identifies its space. The first bridge sends actor and anchor **native-world transforms** from the same native sample. It does not make a child apply its parent's movement again. Relative anchors may be added as a negotiated representation later, with explicit parent identity and acyclic hierarchy validation.

An artist-owned child retains its local transform. Let `W` be the native-world presentation root, `N` an anchor's native-world pose in metres, `B` its actual Godot parent's global transform, and `A` a custom child's authored local offset:

```text
anchor.local = inverse(B) * W * N
child.global = B * anchor.local * A = W * N * A
```

Use the affine inverse for a scaled parent. Reject a singular parent with a binding diagnostic. Do not silently reset its scale or detach the child.

**Nontrivial example:** `W = R`, native anchor translation `(1,2,3)`, child offset `(0,0.5,0)`, and a Godot parent translated by `(10,0,0)` and rotated 90 degrees about Y. The child's final world position must be `(1,-2.5,-3)`, independent of the structural parent's transform. Multiplying by `B` a second time fails this example. If the artist wants a visual displacement, it belongs on the child or a documented authored offset node below the driven anchor.

Points use full affine transforms; directions omit translation; normals use the inverse transpose when scale is present. Model parts carry stable source indices and extended-part ownership. Suppressing a mesh part leaves its anchor and native actor alive.

Pose packets contain native sample tick, simulation time and interpolation policy. A complete pose is atomic: all joints, actor motion, anchors and visibility belong to one sample. Renderer interpolation cannot advance native state or synthesize gameplay events. Camera cuts, teleports, scene resets and provider discontinuities reset interpolation and FSR motion history; ordinary actor motion retains history. Alpha/particles and UI require their own temporal policy rather than inheriting it accidentally from the world viewport.

## 3. Native time, cameras and lifecycle

The envelope distinguishes presentation sequence, simulation tick, native elapsed time, pause flags and active cinematic clip time. Rendering at approximately 59.94 Hz does not imply that every actor/animation updates at that rate. Never derive clip progress from Godot wall time, number of rendered frames, network arrival time or a nominal FPS multiplier.

Scene lifecycle is `begin → resources/baseline → active → end`. A baseline has a commit sequence; the consumer exposes it only when all required resources and actors are ready. Scene end retires its bindings, effects, events and camera ownership. Reload follows the same lifecycle, even with identical content.

Camera ownership is explicit: native default, an authored track for an identified native clip, or editor inspection. Native declares the active clip, source frame/time and cut markers. Godot samples the selected track at that time. Track duration, story events and audio remain native. Skip, abort and finish release ownership and reset history. Offline editor scrubbing never executes native story callbacks and is not gameplay rewind.

Geometry publication must be independent of the original camera frustum before off-axis camera authoring is accepted. Native visibility due to gameplay/map membership is separate from render-camera visibility. The provider must not reclassify an object as absent merely because the legacy draw pass culled it.

## 4. Snapshots, deltas and events

The next transport revision carries a negotiated semantic envelope. Exact operation numbers and byte layouts are frozen with implementation/tests in M1.01, not inferred from these names.

Required envelope fields are protocol major/minor, session ID, scene epoch, message sequence, simulation tick/time and payload length. Use explicit little-endian integers and IEEE float fields with finite-value validation. Pointers, native C struct padding and filesystem paths are not wire identities.

Resources have `create`, revisioned `update` and `retire` records. Unchanged resources are retained. A resource cannot retire while a committed visible frame still references it; consumer acknowledgement establishes the safe release point. Dynamic updates identify the exact prior/new revision, supported format and bounded extent. Measure uploaded bytes, allocations and resource counts.

Actors have spawn/update/despawn records. Spawn includes origin, current properties, anchors and visibility. Updates identify their baseline sequence and changed fields. Unknown generation, revision or baseline causes a resync request and a visible diagnostic; the consumer must not apply the delta to a different incarnation.

Events are typed, ordered and carry session/epoch, monotonic event sequence, sample time and actor generation. Native state and one-shot events are separate: “currently moving” belongs in state, while departure is an event. A late attachment receives current state and an event high-water mark. It does not replay old muzzle flashes or departure sounds. Duplicate event sequences are ignored only within the same session/epoch; gaps are errors that request recovery.

Full resync sends retained resource revisions, live actors/anchors, UI/settings state, camera/clip ownership, clocks and the event high-water mark as one committed baseline. Updates arriving during resync are bounded and applied after the baseline commit in order. An overflow or unsupported state cannot silently drop records; report the category and require another baseline or fail the session.

The implementation must define byte/count limits before allocation, test malformed packets and cap queued frames/resources/events. State updates may be coalesced only when intermediate state has no observable event/camera/lifetime semantics. Never coalesce spawn/despawn, events, camera cuts, actions or resource dependencies. Backpressure must be visible in diagnostics and timing; do not build an unbounded memory queue to hide a slow renderer.

On disconnect, stop accepting input/actions from the old renderer, invalidate its generation and expose a host-level paused/disconnected state without changing actor logic. A replacement renderer negotiates and requests full resync from the surviving native process. If that native build cannot resume safely, report the limitation and require session restart. Reconnect support is not complete until it resumes a live native session; a restart alone does not pass M1.07.

## 5. Actions and input

Actions address a named native/renderer/settings provider, typed action and target generation. Include an action ID, originating session/epoch and expected state revision when relevant. Providers validate availability, argument types/ranges, gameplay restrictions and authority. Replies acknowledge the action ID with accepted/rejected/failed, resulting revision and actionable reason. Accepted asynchronous operations later report completion/failure.

Within a session, a retry of an acknowledged action ID returns the recorded result without applying it again. After reconnect, unresolved non-idempotent actions require an authoritative result query or explicit failure; never replay blindly. An expired actor, stale scene or invalid inventory action is rejected, not silently redirected.

Exactly one input route owns each device/action context. SDL remains the native controller/input boundary. Godot UI focus selects UI versus gameplay routing and releases held inputs on focus loss or disconnect. Original menu callbacks continue updating native state after their primitive output is retired. Native input and Godot button actions must not trigger the same item use twice.

Settings providers declare type, bounds/options, scope, persistence, current/effective value and application policy: immediate, scene reload or session restart. Launcher and Godot Controls share these providers. Display changes have confirmation/timeout rollback and report failures. Renderer selection is persisted by renderer ID and applied on the next session; it does not hot-swap a native binary mid-game.

## 6. Compatibility, ownership and distribution

Semantic protocol major changes break compatibility; minor versions add negotiated optional capabilities. Each side declares required and offered capabilities with schema versions and limits. Missing required capabilities fail before gameplay starts with an actionable mismatch list. Optional capabilities remain explicitly unavailable in the SDK. The current v15 compatibility draw path can coexist during migration but cannot satisfy the final Godot complete-image capability.

The core project owns session/resource/identity/time/lifecycle schemas. Actor, UI, settings and effect providers own versioned domain schemas and documented semantics. Renderer packages own their rendering options and backend implementation. Community renderers consume the same presentation boundary through a descriptor and supported transport/host ABI; they do not need to link undocumented `DG_OBJS` memory layouts.

Descriptors identify renderer ID/version, supported host/protocol versions, native/renderer architecture, executable entry points and capabilities. Discovery reports missing/incompatible packages without substituting another renderer. The first release may ship matched native binaries per backend. Shared saves and native settings remain common; renderer-specific settings/mod compatibility remain namespaced.

The implemented first launcher slice is [renderer package schema1 / launch API1](RENDERER_PACKAGES.md): persisted selection, executable discovery, availability checks and matched native/Godot startup. The complete semantic host/ABI and capability-based community renderer contract above remain M1.11/M1.12 work; the launch descriptor does not advertise them as implemented.

The bridge is local IPC and must authenticate the intended launcher-owned session before accepting actions; listening on loopback alone is not a session identity. Parse and bounds-check peer messages. A custom native GDExtension or script package is executable code with the host user's privileges, not a sandbox. The SDK must not label it safe merely because the ZIP passes provenance checks.

Mods contain custom resources, sparse overrides and original-asset references. Local resolved previews are disposable caches outside distributable dependencies. Export follows dependency graphs through embedded subresources, scripts' declared resources, imported source assets, fonts/UI atlases and animation libraries. Undeclared dynamic external dependencies require an explicit manifest entry and validation; an unresolved dependency prevents a clean export claim. Renaming or copying a known original-derived file does not remove its provenance. Unknown custom files are not automatically proven original-free; importer provenance and package diagnostics are part of the workflow.

Open ZIP preserves the mod's identity and creates an editable workspace. Save changes that workspace; Export updates a selected destination/version; Save As creates a new identity intentionally. Preview and runtime use the same resolver and deterministic priority/conflict rules. Exact content revisions and missing originals are reported before launch/export rather than silently using a different asset.

### Resource reads and final-image capture

A resource read names a resource incarnation, revision, pixel format and bounded region. It returns the original resource representation needed by native palette/Codec operations. It must never substitute pixels from the final viewport.

A photo capture names a native sample and explicit crop/output format. Freeze one completed Godot scene image for that request. Convert it once to the native photo representation and serve all tile reads and JPEG quantization retries from the same immutable buffer. Associate the reply with its request/sample ID; enforce bounded size, timeout and explicit failure. Native retains compression and card/save ownership. The provider must verify the original capture point and HUD policy before implementation; these are not inferred from screen coordinates alone.

See the [readback audit](GODOT_PRESENTATION_COVERAGE.md#readback-and-resource-copy-audit). Compatibility VRAM READ is not a sufficient final-image API, and removing legacy raster presentation must not remove texture/palette state used by native logic.

## 7. First provider: dock platform and railing

The user clarified on 12 October that “bars” means the **railing attached to the platform**. It is an independently editable visual target, not evidence of a second native gate motor. [Binding notes](GODOT_NATIVE_BINDING_NOTES.md) record the actual source/declaration and cinematic tracks.

The gameplay target uses class `0x2abc`, actor name `0xb15b`, declaration provenance in `s00a/ea54.g`, and body model `0x6da3`. It publishes its body pose and per-part poses/visibility. The railing shares the body motion; its replacement remains a separate authored child/part override. Independent anchors still support actors which actually have independent native motion. Do not synthesize bar opening from platform height or publish `door_open` for this dock declaration.

A proposed elevator provider state contains native endpoint/travel phase, progress, current pose and availability. Transition events map to the source's four callback hashes: departure toward end `0x361e`, arrival at end `0xadbf`, departure toward start `0xf624`, arrival at start `0xedb8`. They are observations of native transitions; visual subscribers cannot rerun the script callback. Reconnecting during travel initializes state without replaying departure. Collision, passengers and native messages remain unchanged.

Cinematic instances of the same model use clip/model-track identity, not the gameplay declaration's runtime ID. An explicit authored override may target the common asset appearance across both; binding to a gameplay event does not implicitly bind to a cinematic track. At scene transition the resolver retires the old actor binding and activates the matching cinematic/native binding under the new epoch.

## 8. Required contract checks before claiming implementation

| Case | Required result |
| --- | --- |
| Duplicate models/declarations and reused actor slot | No ambiguous or stale binding; generation and origin decide identity |
| Parent rotated/scaled, child with an offset | The transform equation above holds; no double motion/conversion |
| Elevator mid-travel attach/reconnect | Correct current pose/state; no historical departure event replay |
| Railing-only replacement | Railing remains editable and follows native body; suppression keeps actor/anchor alive |
| Cinematic model versus gameplay elevator | Explicit clip/declaration identity; no event/transform carryover |
| UI inventory open and damage update with draws disabled | Native pause/equipment/damage transitions still execute exactly once |
| Settings apply/fail/timeout/restart | Effective value and persistence match the real result; display rollback works |
| Edited off-axis camera | Active geometry remains available outside the old frustum; native timing is unchanged |
| Missing capability/content/revision, truncated/oversized message | Early diagnostic; no hidden renderer/asset fallback or partial baseline |
| Queue overflow, event gap, disconnect and stale action retry | Bounded recovery, ordered state and no duplicated action |
| Export/reopen with indirectly referenced original resources | Original-free package and locally resolved, editable references |

These are acceptance requirements, not passing tests. M0.11 still requires the remaining presentation/variant audit and reconciliation; M1 implements and exercises this design. The initial implementation should cover negotiation, retained resources, actor/state/events, native clock, actions and resync before expanding into every UI/effect schema.

## 9. Native subtitle presentation (implemented)

`include/mgs_subtitles.h` observes the current `menu/jimaku.c` presentation before
timer and confirmation processing. The frame carries active/visible flags,
caption/modal/forced kind, pre-update timer, original rectangle, text width and
spacing. Native code owns caption settings, confirmation, pause, continuation
and procedure execution. Preparing a new page preserves the current frame's
text and layout; `MENU_ResetSystem()` clears the frame to prevent stale captions.

Retained `text` is language-resolved native encoding, not UTF-8. The accompanying
`MgsTextLayout` captures native formatting, button substitution, punctuation
spacing, ruby, emphasis and Kinsoku erasure. Records copy source glyph bytes from
the font bank at layout time. Reusing a stream/script font bank does not change
the current page. Text and layout pointers last until BeginFrame/Reset; revisions
remain distinct across Reset. This data is local original artwork and is never
mod payload.

Protocol 15.17 negotiates subtitle ownership (bit 262144, operation 19). Native
still evaluates layout and timing but suppresses its presentation primitives and
page uploads when the Godot Control provider is active. Legacy keeps the original
draw path. Godot retains pages by revision and draws a transient source-glyph
FontFile through Controls outside FSR2. The editor creates `ui.subtitles.scene`,
with editable text placement, color, size, outline and Latin font replacement,
plus ordinary PAUSE Label and dim ColorRect nodes. Save detaches retail fonts and
page state; export/reopen retains authored edits. A fully custom Control can
consume the documented native layout without taking over native timing.

The native/Godot formatting and ZIP tests establish the implemented contract.
Human review of all subtitles and modal states across the campaign remains
pending. Unicode translation of arbitrary original bank indices and offline
preview of every cinematic font bank are not implemented; the runtime handles
those banks by retaining the actual source glyphs. See [wire layout](GODOT_PROTOCOL.md#subtitles-minor-17).

## 10. Radar state and Godot presentation

`include/mgs_radar.h` exposes a renderer-independent, frame-local observation of
`menu/radar.c`. `MENU_ResetSystem()` clears it on each native UI frame; collection
is enabled after Godot radar ownership is negotiated and disabled for Legacy.
The returned view is valid until the next frame reset. Protocol 15.18 operation
20 publishes this state to the `ui.radar` Control slot before FRAME.

- Frame: visibility, map/jamming/evasion/alert/custom/countdown mode, native tick,
  placement, radar scale, alert level, recovery counter, console cursor and noise
  seed. These are pre-transition values, so the Control must not advance
  native timers or replay sound/script callbacks.
- Contacts: native-filtered position, player/near/other-floor/noise classification,
  original color and attributes, current control-list index, and the actual sixteen
  noise offsets. The index is frame-local, not a persistent actor binding ID.
- Vision cones: four resolved points and original center/edge colors. Walls:
  resolved endpoints, normal/other-floor/special classification and static/dynamic
  origin. Positions are relative to `(269+x, 42+y)` on the native 320x224 UI;
  interior bounds are `(-34,-26,69,52)`. Framebuffer double-buffer offsets are excluded.
- Escape countdown: the only configured custom radar callback is
  `overlays/s19b/menu/countdwn.c`. Its frame reports ticks before decrement; native
  code retains expiry and actor-destruction procedure execution. An unknown custom
  provider fails explicitly under Godot ownership.

Capacity is checked (96 contacts/cones, 4096 walls). Under ownership, the native
radar routine runs against a private 128 KiB primitive buffer and ordering table;
no radar primitives enter the rendered ordering table, and its per-frame palette
uploads are skipped. This retains the original RNG, state transitions, sounds and
countdown callbacks while removing the old shared 8 KiB menu-buffer cutoff.
The adapter still constructs CPU primitives internally; separating native mutation
from presentation completely remains part of M5.01. Initial shared artwork loading
also remains, without contributing radar pixels to the final Godot image.

The default Control scene supplies walls, contacts, additive vision cones,
alert/evasion/jamming panels, recovery wipe and escape countdown. Radar artwork
and digit palettes are prepared from the local RPK, and countdown warning textures
resolve through local disc identities. Saving detaches all original textures.
The authored scene and five scripts, with custom dependencies, can be exported,
relocated and reopened. Native frame/session/epoch and display visibility govern
presentation; UI stays outside 3D upscaling.

The native regression uses the recovered radar/countdown functions and real PsyZ
integer transforms. It checks wall/group/contact filtering, noise bounds, contact
blink, cinematic/map absence, hide/slide behavior and both framebuffer buffers.
A 100-frame collection-off/on comparison matches drawing-command hashes, RNG,
alert recovery, console progression, sounds and uploads. Countdown checks retain
expiry exactly once, menu suppression and actor-destruction callbacks. These checks
establish native behavior. Additional owned-mode checks compare the same native
state/RNG/sounds, assert zero real ordering-table/primitive writes and dynamic
palette uploads, and retain 601 walls beyond the old cutoff. Godot tests cover
protocol rejection, editable layout/palette/custom artwork, original-free ZIP
round trips on both discs, and Vulkan/FSR2 presentation. Human campaign/UI review
and frame-pacing acceptance remain pending.
