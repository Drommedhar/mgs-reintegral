# Native presentation host, launch API 2

The native process owns gameplay, collision, animation sampling, audio, disc I/O,
save files and timing. A renderer is a separate process implementing the versioned
loopback protocol. No private native pointers or Godot objects are exposed.
Install it through [renderer.json](RENDERER_PACKAGES.md); no launcher rebuild is
required for a new compatible package. Changing renderer starts a new game session.

## Startup contract

The launcher starts `companionExecutable` with the descriptor's argument array
and the shared profile as working directory. Resolve the renderer's own resources
relative to its executable, not that working directory. The launcher supplies:

| Environment variable | Meaning |
| --- | --- |
| `MGS_PRESENTATION_PORT` | Selected loopback TCP port; listen on 127.0.0.1 |
| `MGS_PRESENTATION_TOKEN` | Private 16-byte session token encoded as 32 hex characters |
| `MGS_PRESENTATION_READY_FILE` | Absolute path for the atomic readiness JSON |
| `MGS_PRESENTATION_STOP_FILE` | Absolute path created when shutdown is requested |
| `MGS_PRESENTATION_RENDERER_ID` | Descriptor ID to echo in readiness |
| `MGS_PRESENTATION_RESOLUTION` | Requested width x height, such as `1280x720` |
| `MGS_PRESENTATION_FULLSCREEN` | `1` or `0` |
| `MGS_PRESENTATION_ASSETS` | Optional absolute local prepared-content path, otherwise empty |
| `MGS_SETTINGS_PORT` | Authenticated shared settings service on loopback |

After listening and initializing, write the following to a temporary file beside
the requested ready path, then rename it to that path. Echo the descriptor's
protocol values exactly; do not include the private token.

```json
{
  "schema": 1,
  "rendererId": "example.wireframe",
  "protocol": {"major": 15, "minor": 30, "capabilities": 29, "mode": "commands"}
}
```

The launcher allows 30 seconds for readiness and checks that the process is still
alive. It then launches the matched native executable with the configured local
discs, shared save directory and gameplay options. The native adapter currently
retains historical environment names `MGS_GODOT_PORT`, `MGS_GODOT_SESSION_TOKEN`
and `MGS_GODOT_SCENE_VIEW`; the launcher sets these independently of renderer brand.
`commands` maps to scene flag0, `scene` to flag1.

## Wire and semantic contracts

[GODOT_PROTOCOL.md](GODOT_PROTOCOL.md) is the current **15.31** byte-level contract
for every renderer using this host, despite its historical filename. Scalars are
little-endian; each packet is uint32 payload size, uint32 operation, then payload.
The buffer limit is 64 MiB. Handle partial reads and ordered commands. HELLO must
come first, authenticate the private token and agree on version/capabilities.
Replies echo the operation with bit31 set and begin with the input button word.
The public session ID in HELLO is different from the private token.
The host also accepts15.30 packages. It passes their declared minor to the native
process as `MGS_PRESENTATION_MINOR`, so strict15.30 companions still receive a
15.30 offer. Built-in Godot uses31; its reply bit16 forwards one F2 press through
SDL while preserving native recording/replay control.

Command mode implements DRAW/UPLOAD/MOVE/READ/SYNC/FRAME/CLEAR and session-bound
native clock/stage context. Preserve upload and readback semantics: native game
code consumes these results, so a renderer must not acknowledge fake success.
The sample preserves uploaded RGBA texture data and overlapping moves; its
wireframe raster presentation intentionally does not implement full textured
framebuffer rendering or photo fidelity.

Scene mode additionally consumes retained model resources, source/disc identity,
sampled poses, actor anchors/state, effects and native UI/action payloads according
to the negotiated bits. The Godot implementation is the current full scene-mode
reference. Native time and pause state are authoritative; mod scripts cannot
advance gameplay time or alter collision by moving a visual node. Existing actor
support is still partial; ordered events, generalized lifecycle and atomic
baseline/reconnect recovery remain unfinished. The longer-term
[presentation contract](PRESENTATION_CONTRACT.md) records those requirements and
does not make them implemented merely by describing them.

Use `MGS_PRESENTATION_TOKEN` as the token field for requests to the separate
[settings service](SETTINGS_CONTRACT.md). Readiness does not mutate settings.
The service validates writes, revisions and which settings apply next launch.

## Shutdown and failure

Window close should set bit31 in the input word of the next reply to request an
orderly native quit. Native controller input remains in SDL; a renderer forwards
its window keyboard input through the protocol. On native EOF, release rendering
resources and exit. Check the stop-file path while waiting for connection/work.
When disposing a session the launcher requests stop, waits up to two seconds,
then terminates an unresponsive companion and drains stdout/stderr into profile
logs. Connection/protocol failures are errors, not permission to continue with
stale state or fall back to another renderer.

The included Windows Forms sample is independent source, compiled without Godot
or a launcher reference. Its ready-record mismatch test runs in ordinary CTest;
real-host handshake and launcher runs require the user's local discs. These prove
integration and compatibility rejection, not final campaign or rendering fidelity.
