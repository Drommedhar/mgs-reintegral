# Godot local renderer protocol (prototype v3)

The native 32-bit runtime connects to the 64-bit Godot process on a randomly selected
loopback TCP port. `tools/run-godot.ps1` owns both processes. The native process uses
SDL for timing, audio and physical controllers; the Godot window forwards keyboard
buttons. Input still passes through the existing recording/replay layer.

There is no native GPU device in this backend. Godot RenderingDevice executes the
original primitive stream. In scene mode, Godot also renders rigged ArrayMeshes into
a SubViewport and merges its color/depth into the original ordering table.
Godot-owned opaque KMD polygon submission is suppressed in scene mode; other native draw
commands supply menus, Codec, HUD and effects. All rendering happens in Godot.

## Framing

All scalars are little-endian; a message begins with `uint32 payloadBytes`, then
`uint32 operation`. Maximum buffered data is 64 MiB. No pointers, platform structs,
process handles or resource paths cross this transport. Connection failures and
malformed packets terminate the prototype with an explicit error.

| Operation | Payload |
| --- | --- |
| 1 HELLO | uint32 magic `0x3152474d`, version `3`, vertex stride `20` |
| 2 DRAW | 72-byte draw header, vertices, uint16 indices |
| 3 UPLOAD | int32 x,y,width,height, followed by width*height RGBA8 pixels |
| 4 MOVE | int32 source x,y,width,height,destination x,y |
| 5 READ | int32 x,y,width,height; reply includes RGBA8 pixels |
| 6 SYNC | empty; execute queued commands |
| 7 FRAME | uint32 enabled,x,y,width,height,aspectNumerator,aspectDenominator |
| 8 CLEAR | int32 x,y,width,height,r,g,b (original 8-bit color inputs) |
| 9 SCENE | scene snapshot described below |
| 10 WORLD | int32 clipX,clipY,clipWidth,clipHeight,forceMask,preserveMask,nearDepth,farDepth,viewX,viewY,viewWidth,viewHeight |

HELLO, READ, SYNC and FRAME require replies. Reply operation is request operation
OR `0x80000000`. Reply payload begins with uint32 pressed-button bits in the original
PsyQ layout, followed by readback bytes for READ. The native side validates reply
operation and exact size. The renderer preserves command order and acknowledges
submitted work; GPU readback additionally synchronizes when requested.
Button-word bit 31 requests an orderly native quit; bits 0..15 are input. Closing
the Godot window keeps the connection alive until the game writes its recording
footer and disconnects. Unexpected disconnects remain errors.

## Primitive data

The draw header contains vertex/index counts (uint32), scissor x/y/w/h (int32),
eight vertex-uniform floats, then force-mask/preserve-mask (uint32), render scale
(float) and sampling flags (uint32). The uniforms match the pinned Psyz shaders.
Each 20-byte vertex contains int16 x,y; uint16 u,v,CLUT,texture-page/flags;
uint8 r,g,b,a; and four texture-window bytes. The initial reference renderer uses
1024x512 VRAM at internal scale 1. Window enlargement is presentation scaling.

GPU texture feedback, palette lookup, transparent-zero, STP, destination masks and
the four PS1 blend modes remain explicit shader behavior. World geometry uses
Godot's mesh rendering/depth and perspective interpolation before composition.

## Scene snapshot

The 64-byte header contains an 8-byte zero-padded stage field, twelve float32 values
for the original view matrix (three rows of rotation plus translation), float32
projection distance and uint32 instance count. Each instance has a 32-byte header:
uint32 lifetime ID, uint32 original resource hash, 8-byte definition-stage field,
uint32 original flags, uint32 extended part count, uint32 visible part count and
uint32 lighting-color count.
It is followed by 52 bytes per part: twelve floats for that part's final local-to-view
transform, with the 58/64 vertical overscan removed, and uint32 Godot-mesh visibility.
Godot reconstructs the world pose using the inverse view matrix. This uses the final
`DG_OBJ.screen` matrix because the cinematic screen channel makes static `.world`
matrices camera-relative while animated `.world` matrices remain absolute. Treating
both as world coordinates applies the camera translation twice to scenery.
Extended mesh parts inherit their primary part's matrix.
Parts with runtime texture placeholders or original transparency remain
on the compatibility path; the corresponding Godot mesh is hidden to avoid drawing
the same part twice. This classification is explicit, not a failed-load fallback.

After the part matrices, each instance carries `colorCount * 4` bytes of original
lighting: RGBA8 in model-part/face/corner order. RGB comes from the game's shaded
polygon packets; the fourth byte is reserved. The converter stores palette UVs in
TEXCOORD_1. A per-instance texture supplies the shader's original 128-neutral RGB
modulation, keeping imported meshes immutable. Visibility also respects the native
map group and bounds. Menu, movie and Codec rendering uses the command layer.

WORLD composites only Godot pixels in the half-open depth interval
`[nearDepth, farDepth)`, in original camera units. A CompositorEffect copies linear
depth from Godot's opaque depth buffer while that buffer is valid. Its output
texture is owned by the bridge. Depth saturates at 65535 like the original GTE;
background has depth 65536 and is excluded. Camera projection is inverted from
RenderSceneData, rather than assuming a particular projection matrix layout.

Native markers surround populated ordering-table buckets. They draw intervening
depth ranges before the next bucket, then that bucket's geometry after its original
primitives. This keeps sky, framebuffer clears and near/far compatibility effects
in their original order instead of painting all compatibility effects over the
entire Godot scene. Force/preserve-mask state also applies to the world composite.
Color and depth use the same nearest sample to avoid different edge coverage.
The view rectangle comes from the original drawing offset (centre minus 160,112,
extent 320x224). The clip rectangle only crops that projection; it must not resize
the world image when cinematic bars or an effect restrict the drawing area.
Remaining compatibility geometry retains the original 256-unit depth buckets;
this is not per-fragment depth testing of those original polygons.

Live semitransparent packets and 16-bit framebuffer materials (including stealth)
remain on the command path even if their original model definition was opaque.
The presentation rectangle uses the active display height, not the larger GPU
mode height; a 224-line menu must not include 16 extra blank rows.

Definition IDs are formed as
`mgs/integral-j/disc1/stage/<definition-stage>/<four-hex-digits>.k`.
The definition-stage is captured when the loader registers the resource; resident
`init` assets keep their namespace after stage transitions. Actor lifetime IDs are
monotonic and assigned on queue insertion. A live actor can legitimately switch its
model; consumers replace its visual resource while retaining the lifetime ID.
Absent instances are removed after processing a complete scene snapshot.

Generated model ID `0x80000001` identifies `mgs/generated/lit_mdl`, the procedural
helipad light model. Its transforms and metadata have an explicit scene identity;
its changing geometry is currently rendered through the compatibility command
layer. It is registered by its actor factory rather than pretending to be a disc
resource. Unknown generated kinds are rejected.

Converted models retain original part names, hierarchy, seam-vertex ownership and
skin binds. Coordinates use metres at 1000 source units/metre, with `(x,-y,-z)` as
the axis conversion. Reference camera projection includes the original 58/64
vertical overscan factor. The prototype uses a 580x448 world SubViewport mapped to
the 320x224 game view to express that pixel aspect without changing gameplay.

This is an internal prototype protocol, not yet the public modding SDK contract.
