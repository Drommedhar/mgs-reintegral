# Godot local renderer protocol (prototype v13)

The native 32-bit runtime connects to the 64-bit Godot process on a randomly selected
loopback TCP port. `tools/run-godot.ps1` owns both processes. The native process uses
SDL for timing, audio and physical controllers; the Godot window forwards keyboard
buttons. Input still passes through the existing recording/replay layer.

There is no native GPU device in this backend. Godot RenderingDevice executes the
original primitive stream. In scene mode, Godot also renders rigged ArrayMeshes into
a SubViewport and merges its color/depth into the original ordering table.
Godot-owned KMD polygons and supported physical effects are suppressed in the native
draw stream in scene mode. Other draw commands supply menus, Codec, HUD, emissive
and framebuffer effects. All rendering happens in Godot.

## Framing

All scalars are little-endian; a message begins with `uint32 payloadBytes`, then
`uint32 operation`. Maximum buffered data is 64 MiB. No pointers, platform structs,
process handles or resource paths cross this transport. Connection failures and
malformed packets terminate the prototype with an explicit error.

Native writes are bounded to 16 KiB and the receiver drains all currently available
bytes before parsing. Message framing is independent of these writes. A single
large scene write on Windows loopback could deliver about 192 KiB immediately,
then stall its remaining bytes for 25–32 ms; bounded writes avoid that observed
delay without changing command order or the protocol version. The native cadence
CSV's `submit_us` records time spent exchanging commands/replies with Godot,
including readbacks. It is host elapsed time, not GPU execution time.

| Operation | Payload |
| --- | --- |
| 1 HELLO | uint32 magic `0x3152474d`, version `13`, vertex stride `20` |
| 2 DRAW | 72-byte draw header, vertices, uint16 indices |
| 3 UPLOAD | int32 x,y,width,height, followed by width*height RGBA8 pixels |
| 4 MOVE | int32 source x,y,width,height,destination x,y |
| 5 READ | int32 x,y,width,height; reply includes RGBA8 pixels |
| 6 SYNC | empty; execute queued commands |
| 7 FRAME | uint32 enabled,x,y,width,height,aspectNumerator,aspectDenominator |
| 8 CLEAR | int32 x,y,width,height,r,g,b (original 8-bit color inputs) |
| 9 SCENE | scene snapshot described below |
| 10 WORLD | 52 bytes: int32 clipX,clipY,clipWidth,clipHeight,forceMask,preserveMask,nearDepth,farDepth,viewX,viewY,viewWidth,viewHeight,dither |
| 11 DEBUG_TEXT | UTF-8, at most 255 bytes; empty hides the overlay; no reply |

HELLO, READ, SYNC and FRAME require replies. Reply operation is request operation
OR `0x80000000`. Reply payload begins with uint32 pressed-button bits in the original
PsyQ layout, followed by readback bytes for READ. The native side validates reply
operation and exact size. The renderer preserves command order and acknowledges
submitted work; GPU readback additionally synchronizes when requested.
Button-word bit 31 requests an orderly native quit; bits 0..15 are input. Closing
the Godot window keeps the connection alive until the game writes its recording
footer and disconnects. Unexpected disconnects remain errors.

SCENE is an ordering barrier: pending GPU commands execute against the previous
snapshot before the new snapshot is applied. Before the next WORLD submission,
the changed color and metadata viewports render once. The renderer waits for that
draw before consuming their textures. Scene updates never overtake earlier WORLD
commands; unchanged scenes reuse their previous render targets.

## Primitive data

The draw header contains vertex/index counts (uint32), scissor x/y/w/h (int32),
eight vertex-uniform floats, then force-mask/preserve-mask (uint32), render scale
(float) and sampling flags (uint32). The uniforms match the pinned Psyz shaders.
Each 20-byte vertex contains int16 x,y; uint16 u,v,CLUT,texture-page/flags;
uint8 r,g,b,a; and four texture-window bytes. The initial reference renderer uses
1024x512 VRAM for native readback and texture/CLUT addressing. A separate scaled
color target combines high-resolution world geometry with HUD and effects.
Its vertex pixel-center offsets are divided by the presentation scale.

Sampling bits: 0 = framebuffer texture source, 1 = screen-aligned UVs,
2 = scaled destination (set by the renderer), 3 = reads destination for blending
or masking, 4 = textured batch, 5 = preserve Godot world color precision (set
locally by the renderer when a world viewport is attached). That last bit keeps
destination blending and framebuffer texture modulation in floating point,
avoiding repeated five-bit quantization of Godot lighting during fullscreen
fades/feedback. Original texture decoding, STP, masks and blend modes remain in
effect; the command-only reference renderer retains five-bit arithmetic.
The native backend supplies the clipped batch
bounds. Snapshots copy only accumulated writes and only when a draw needs them;
WORLD also reads the destination when compositing transparent world pixels.
Protocol v6 introduced these
dependency bits so older senders cannot silently blend against stale pixels.

GPU texture feedback, palette lookup, transparent-zero, STP, destination masks and
the four PS1 blend modes remain explicit shader behavior. World geometry uses
Godot's mesh rendering/depth and perspective interpolation before composition.

## Scene snapshot

The 68-byte header contains an 8-byte zero-padded stage field, twelve float32 values
for the original view matrix (three rows of rotation plus translation), float32
projection distance, uint32 instance count and float32 horizontal projection scale.
Protocol v9 adds that scale: 1 for original aspect, or (4/3) / output aspect for
widescreen. Godot expands horizontal field of view and viewport width together,
preserving vertical framing and aligning with the native packet transform and
expanded visibility bounds. Color and metadata cameras use the same projection.
The scale is carried with each scene, independently of preceding menu/movie
presentation frames. Rebuild both sides when upgrading; mod ZIPs are unchanged.
Each instance has a 32-byte header:
uint32 lifetime ID, uint32 original resource hash, 8-byte definition-stage field,
uint32 original flags, uint32 extended part count, uint32 visible part count and
uint32 lighting-color count.
It is followed by 52 bytes per part: twelve floats for that part's final local-to-view
transform, with the 58/64 vertical overscan removed, and uint32 part flags:
bit 0 enables the color/metadata mesh, bit 1 enables shadow casting, and bit 2
selects a transparent material for live semitransparent packets. Unknown bits
are rejected. The version handshake prevents older renderers from interpreting a
shadow-only part as a visible part.
Godot reconstructs the world pose using the inverse view matrix. This uses the final
`DG_OBJ.screen` matrix because the cinematic screen channel makes static `.world`
matrices camera-relative while animated `.world` matrices remain absolute. Treating
both as world coordinates applies the camera translation twice to scenery.
Extended mesh parts inherit their primary part's matrix.
Active opaque parts remain shadow casters outside the camera's native bounds.
Inactive map groups, hidden actors, unused parts and visual mod removals still
disable them. Godot uses `SHADOWS_ONLY` when bit 1 is set without bit 0; authored
replacement `Cast Shadow` settings are retained.
Parts with runtime texture placeholders, subtractive blending or framebuffer
textures remain on the compatibility path; the corresponding Godot mesh is hidden to avoid drawing
the same part twice. This classification is explicit, not a failed-load fallback.

After the part matrices, each instance carries `colorCount * 4` bytes of original
lighting: RGBA8 in model-part/face/corner order. RGB comes from the game's shaded
polygon packets; the fourth byte is 255 for a submitted face and zero otherwise.
The converter stores palette UVs in
TEXCOORD_1. A per-instance texture supplies the shader's original 128-neutral RGB
modulation, keeping imported meshes immutable. Visibility also respects the native
map group and bounds. Menu, movie and Codec rendering uses the command layer.

The lighting palette is followed by `colorCount * 16` bytes: four float32 values
per corner containing normalized live U, V, original ordering depth after the
part's `raise` adjustment, and blend selector (0 opaque, 1 half, 2 additive,
4 quarter-additive). Subtractive packets remain on the command path.
Lighting and packet palettes use
the same part/face/corner order. Godot uploads them separately as RGBA8 and RGBAF
textures. Original-color and metadata passes use the native face visibility.
Godot-lit meshes use Godot's geometry culling: the original low-resolution
projection can collapse small distant faces that remain visible at the output
resolution. Lit faces and shadow passes use prepared UVs when the native packet
is culled, avoiding stale packet coordinates. Native actor/part visibility still
applies. Replacement models retain their authored topology and materials.
Truncated palettes, incompatible prepared color counts, duplicate lifetime IDs
and unknown generated models are rejected.

After all instances, v7 and later append uint32 effect-quad count, followed by 196 bytes
per quad: uint32 original texture hash and four vertices in native packet order
(top-left, top-right, bottom-left, bottom-right for billboards). Each vertex is
twelve float32 values: view-space position in Godot metres plus camera-facing depth bias in metres; normalized
U/V and red/green modulation; blue modulation, blend selector and two zeros.
Modulation is 128-neutral. Positions come from live world vertices; billboard
corners use native projected corners and the centre's view depth, with overscan
removed. Native animation, UV changes, particle fades and visibility remain active.

Registered water surfaces/ripples, gameplay and cinematic bubbles, and smoke/breath, fog and casing
animation textures use this path. Godot batches by texture into reusable meshes
and RGBAF geometry palettes.
They receive lights/shadows when the selected stage overlay disables original
lighting. Transparent original KMD parts use the same blend convention, with their
normal/PBR maps retained. Opaque parts keep their opaque shader and shadow path.
Both use premultiplied blending. Effects and transparent original model parts blend
without writing depth, then colorless passes write their depth for world composition
after transparent color rendering. Original model depth uses material next-pass
priority 126; effect depth uses priority 127. This prevents water from erasing rings
slightly below its surface and overlapping particles from occluding each other. Ripples
blend after the water with a 1 mm camera-facing bias to avoid coplanar depth fighting;
their world positions and lighting normals are unchanged. STP-zero
texels remain opaque; transparent-zero texels are discarded. Original shadow
geometry stays suppressed; emissive effects are not reclassified as smoke.

Additive effects factor their linear color into coverage and normalized albedo
before premultiplied blending. This preserves unfogged color while weighting fog
by the texture and native fade, so black or expired ripple quads do not become
visible rectangles in fog. Zero-contribution additive texels also skip the depth
pass; that colorless pass explicitly disables fog.
Under Godot lighting, texture color is decoded before applying the native fade
multiplier, so low-intensity ripples fade linearly. The shader uses Godot's built-in
two-sided normal handling; a second backface flip would invert ripple lighting.

Effect registrations can cover individual face ranges, retaining each texture in
multi-texture cinematic bubble actors. Textureless KMD faces remain on the command
path unless both triangles contain repeated, identically transformed vertices.
Those permanently collapsed faces are discarded in Godot's color and metadata
passes so the rest of a textured character part can receive Godot lighting.

Protocol v8 appends a light section after the effect quads: uint32 count, followed
by 40 bytes per light. Each record contains uint32 identity, uint32 kind, float32
position XYZ, float32 direction XYZ, float32 native radial range and float32 native
box cutoff. Positions/ranges are renderer-world metres; directions use its axes.
Kind 1 is a temporary omni light, with identities 1–8 matching native temporary
light slots. Radius and cutoff follow `DG_SetTmpLight`; zero-range lights are omitted.
The native double buffer is read at the same phase as original object lighting.
Kind 2 is a weapon spotlight, with a generation-aware identity above 8, position
at the `famas_l` primitive's local offset and direction down the barrel (local -Y).
Its range comes from the authored Godot template. Hidden/inactive primitives and
attachments without a valid pose are omitted. Primitive destruction unregisters
the attachment. Protocol v10 adds kind 3 for patrol-beacon spotlights: one record
per native beam object, with its own identity above 8. Each beacon has two beams
180 degrees apart. Position starts at the beam's local +X tip (122 original units),
and direction follows local +X. Visibility and map activation gate these lights;
object destruction unregisters them. The Godot path suppresses the original beam
models, wall glow primitives and fullscreen alarm tint while retaining the housing
and native actor logic. `EventLightTemplates/AlarmSpot` supplies red color, range,
angle, energy and shadows; older mod ZIPs receive the default template.
Protocol v11 adds kind 4 for one soft red omni per beacon, centered at its pivot
with zero direction/radius/cutoff; `EventLightTemplates/AlarmFill` supplies its
range, energy and shadows. Its lifetime follows the first native beam.
Object flag `0x40000` identifies beacon glass assemblies; `0x20000` marks active
alarms. Their transparent parts receive red emission while active and do not
cast opaque shadows over the beacon lights; opaque housing parts are unchanged.
At most 264 records are accepted; malformed states, duplicate IDs, changed kinds,
unknown kinds and trailing bytes are errors. Absent lights stop illuminating that
snapshot, and stage changes discard their instances.

Original declared map meshes contribute static GI. Animated actors, transparent
water/particles and metadata duplicates do not contribute static GI; lit color
meshes still receive it. Custom mod geometry retains its authored GI settings.

WORLD composites only Godot pixels in the half-open depth interval
`[nearDepth, farDepth)`, in original camera units. Original meshes use their live
packet ordering depth. A separate camera on reserved render layer 20 writes the
16-bit ordering depth, source STP mask and original-color quantization flag to a
metadata viewport. Its environment is independent of authored stage lighting.
Metadata is used only when its surface depth agrees with the visible color
surface within one source unit; custom foreground geometry must not inherit
metadata from an original mesh behind it. Custom geometry uses physical depth.

A CompositorEffect copies linear
depth from Godot's depth buffer after transparent rendering. Its output
texture is owned by the bridge. Depth saturates at 65535 like the original GTE;
background has depth 65536 and is excluded. Camera projection is inverted from
RenderSceneData, rather than assuming a particular projection matrix layout.

Native markers surround populated ordering-table buckets. They draw intervening
depth ranges before the next bucket, then that bucket's geometry after its original
primitives. This keeps sky, framebuffer clears and near/far compatibility effects
in their original order instead of painting all compatibility effects over the
entire Godot scene. Force/preserve-mask state also applies to the world composite.
Original-color materials use native five-bit texture modulation and the WORLD
dither flag; replacement textures and authored lighting retain their color range.
STP or force-mask sets the destination mask independently of the visible alpha.
World color is composited over the current native/scaled destination using its
coverage alpha, including additive RGB with zero coverage.
Color and depth use the same nearest sample to avoid different edge coverage.
The view rectangle comes from the original drawing offset (centre minus 160,112,
extent 320x224). The clip rectangle only crops that projection; it must not resize
the world image when cinematic bars or an effect restrict the drawing area.
Remaining compatibility geometry retains the original 256-unit depth buckets;
this is not per-fragment depth testing of those original polygons.

16-bit framebuffer materials (including stealth) and subtractive packets remain
on the command path even if their original model definition was opaque.
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
vertical overscan factor. The world SubViewport uses `290x224 * max(2, scale)`
mapped to the logical 320x224 game view to express that pixel aspect without
changing gameplay. `MGS_GODOT_RENDER_SIZE=WIDTHxHEIGHT` selects
`scale = ceil(min(width/320, height/240))`, bounded to 1..8. The launcher passes
its resolution to this setting and to Godot's window arguments.

At scales above one, a separate scaled VRAM target preserves world detail through
composition, primitive drawing, masks, texture uploads and framebuffer moves.
Texture/CLUT sampling and native readback retain the 1024x512 VRAM dimensions.
Display rectangles are scaled only for presentation; protocol coordinates do
not change. Both native and Godot processes must receive `MGS_GODOT_SCENE_VIEW=1`
to compose the mesh world into the displayed game.

This is an internal prototype protocol, not yet the public modding SDK contract.

## Background composition (v12 and later)

WORLD range `[65536,65537)` composes the opaque sky/fog background before native
world packets. Ordinary ranges remain `[0,65536)`. A quarter-resolution viewport
shares the world and camera projection, renders no geometry, and includes lights
on reserved layer 19. Layer 20 remains ordering metadata.
This keeps empty-space fog behind the native HUD while preserving the main world's
transparent color and physical depth. Marker insertion first removes prior markers
so sorting an ordering table twice (including Codec transitions) cannot form a cycle.

Protocol v13 removes the experimental WATER operation. Native puddles and their
original ripple effects remain on the existing world-effect path.
