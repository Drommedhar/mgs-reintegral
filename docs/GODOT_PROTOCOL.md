# Godot local renderer protocol (prototype v15.35)

This byte-level protocol also serves independent presentation renderers. The
historical filename and native `MGS_GODOT_*` variable names remain for compatibility;
see [the launch API 2 host contract](PRESENTATION_HOST.md) for independent package
startup, ownership and capability declarations.

The native 32-bit runtime connects to the 64-bit Godot process on a randomly selected
loopback TCP port. `tools/run-godot.ps1` owns both processes. The native process uses
SDL for timing, audio and physical controllers; the Godot window forwards keyboard
buttons. Input still passes through the existing recording/replay layer.

There is no native GPU device in this backend. Godot RenderingDevice executes the
original primitive stream. In scene mode, Godot also renders rigged ArrayMeshes into
a SubViewport and merges its color/depth into the original ordering table.
Godot-owned KMD polygons and supported physical effects are suppressed in the native
draw stream in scene mode. Negotiated UI ownership replaces goggles, bars,
subtitles, radar, inventory, Codec, Options, title/new-game and game save/load drawing with editable Controls. Other draw
commands still supply remaining menus, photo/album file screens and compatibility effects.
All rendering happens in Godot; complete removal of legacy drawing is unfinished.

## Framing

Automatic presentation screenshots require `MGS_GODOT_DIAGNOSTIC_CAPTURE=1`.
`MGS_GODOT_PERFORMANCE_RUN=1` always disables them, including direct calls to
the runtime capture method. Normal launcher processes clear inherited capture
settings and set this performance flag. Visual test harnesses must explicitly
call `GodotSession.EnableDiagnosticCapture`; ordinary play never opts in.
Capture runs are visual evidence only and must not be used for cadence claims.

All scalars are little-endian; a message begins with `uint32 payloadBytes`, then
`uint32 operation`. Maximum buffered data is 64 MiB. No pointers, platform structs,
process handles or resource paths cross this transport. Connection failures and
malformed packets terminate the prototype with an explicit error.

Native writes are bounded to 16 KiB and the receiver drains all currently available
bytes before parsing. Message framing is independent of these writes. A single
large scene write on Windows loopback could deliver about 192 KiB immediately,
then stall its remaining bytes for 25â€“32 ms; bounded writes avoid that observed
delay without changing command order or the protocol version. The native cadence
CSV's `submit_us` records time spent exchanging commands/replies with Godot,
including readbacks. It is host elapsed time, not GPU execution time.

| Operation | Payload |
| --- | --- |
| 1 HELLO | Six uint32 values: magic `0x3152474d`, major `15`, minor `31` (or package-pinned `30`), vertex stride `20`, offered capability bits, required capability bits; followed by 16 session-token bytes (40 bytes total) |
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
| 12 CONTEXT | Native clock/resource-stage sample: schema6 is96 bytes including loading state; schemas5/4/3/2/1 are84/80/56/52/36 bytes for older peers; no reply |
| 13 PALETTE | Session-bound retained face color/packet create, update or retire; described below; no reply |
| 14 RETAINED_SCENE | SCENE with palette revision references replacing inline color/packet arrays; no reply |
| 15 MODEL_SOURCE | 76-byte native model source declaration with disc identity; 72 bytes without capability 256; no reply |
| 16 ACTOR | 136-byte schema-1 elevator spawn/update/retire; no reply |
| 17 UI | 68-byte schema-1 goggles state; no reply; presented at the following FRAME |
| 18 BARS | 32-byte header and zero to 16 status-bar records; no reply; presented at the following FRAME |
| 19 SUBTITLES | 128-byte frame header, optionally followed by positioned source glyphs; no reply; presented at the following FRAME |
| 20 RADAR | 104-byte frame header, followed by contacts, vision cones and walls; no reply; presented at the following FRAME |
| 21 INVENTORY | 176-byte header, panel records and optional source glyphs; no reply; presented at the following FRAME |
| 22 CODEC | 320-byte header, optional source glyphs and changed portrait images; no reply; presented at the following FRAME |
| 23 OPTIONS | 104-byte header, 57 named-element records when active, and visible help layouts; no reply; presented at the following FRAME |
| 24 SAVE_UI | 68-byte header and up to 30 save-entry records; no reply; presented at the following FRAME |
| 25 TITLE | 72-byte header, 55 named-element records when active, and visible help layouts; no reply; presented at the following FRAME |
| 26 DISPLAY | 48-byte session-bound native display state; reply is a 20-byte projection request or no-op |
| 27 SAVE_ACTION | 32-byte session-bound action acknowledgement; reply is a 40-byte save action or no-op |
| 28 OPTIONS_ACTION | 32-byte session-bound action acknowledgement; reply is a 32-byte Options action or no-op |
| 29 TITLE_ACTION | 32-byte session-bound action acknowledgement; reply is a 28-byte title action or no-op |
| 30 CODEC_ACTION | 68-byte session-bound action acknowledgement and Codec action view; reply is a 28-byte action or no-op |
| 31 INVENTORY_ACTION | 652-byte session-bound action acknowledgement and inventory action view; reply is a 32-byte action or no-op |

HELLO must be the first command and may occur only once per connection. The
receiver rejects commands before HELLO and repeated handshakes before dispatching
rendering work. Invalid magic, size, version and vertex stride produce distinct
diagnostics. Version 15 negotiates capabilities as described below. A launcher-owned token authenticates incoming native sessions. Session-bound clock/resource-stage samples are implemented; atomic retained baselines and reconnect remain pending.

HELLO, READ, SYNC, FRAME, DISPLAY, SAVE_ACTION, OPTIONS_ACTION, TITLE_ACTION, CODEC_ACTION and INVENTORY_ACTION require replies. Reply operation is request operation
OR `0x80000000`. Reply payload begins with uint32 pressed-button bits in the original
PsyQ layout, followed by readback bytes for READ or three uint32 values for HELLO: selected
major, selected minor and selected capability bits. When capability 16 is selected,
HELLO appends a 16-byte public session ID (28 reply bytes after the button word). The native side validates reply
operation and exact size. The renderer preserves command order and acknowledges
submitted work; GPU readback additionally synchronizes when requested.
Button-word bit 31 requests an orderly native quit; bits 0..15 are input.
With selected minor31, bit16 (`0x00010000`) delivers one F2 controller-port
switch through an SDL key-down event after the entire reply is validated. It is
an event, not a held button: queue distinct presses, ignore key repeats, and
consume one only after a successful reply write. Never include it in HELLO.
The existing native replay guard remains authoritative. Minor30 ignores bit16;
the host accepts30–31 and the launcher pins independent packages to their declared
minor through native `MGS_PRESENTATION_MINOR` (default31).
With capability 67108864, bit 30 (`0x40000000`) captures native host input for a
Godot modal UI. Godot suppresses forwarded keyboard buttons, and the native SDL
adapter neutralizes digital buttons and all four analog axes on both logical
controller ports before passing the sample to the recording/replay layer.
Connection/type bytes remain intact. On release, each port stays neutral until
buttons are released and sticks return within 16 of center; forwarded keyboard
keys also require release. This prevents a held menu action from entering the
game. Unsupported peers ignore this bit; the default display menu remains
unavailable without negotiation. Capture does not pause native simulation or
replace authoritative replay input. Closing
the Godot window keeps the connection alive until the game writes its recording
footer and disconnects. Unexpected disconnects remain errors.

CONTEXT, PALETTE, MODEL_SOURCE, ACTOR, SCENE and RETAINED_SCENE are ordering barriers: pending GPU commands execute against the previous
snapshot before the new snapshot is applied. Before the next WORLD submission,
the changed color and metadata viewports render once. The renderer waits for that
draw before consuming their textures. Scene updates never overtake earlier WORLD
commands; unchanged scenes reuse their previous render targets.

## Capability negotiation

Legacy through Godot selects command rendering without scene ownership. It uses
Legacy's integer RGB5 blending, max-axis internal scale (224 source rows for a
widescreen session, otherwise240), scaled VRAM authority and native transfer/resolve
ordering. FRAME retains the original full display height and display-timing aspect
when no presentation override exists. Final filtering, integer viewport fitting
and the single-triangle GPU blit match the preserved native renderer. Full scene
mode retains its separate world-color precision and quality scaling.

Capability bits are `1` command rendering (DRAW/UPLOAD/MOVE/READ/SYNC/FRAME/CLEAR),
`2` scene meshes (SCENE/WORLD), `4` debug text, `8` native context (CONTEXT),
`16` session-bound context, `32` retained palettes (PALETTE/RETAINED_SCENE),
`64` native model source identity (MODEL_SOURCE), `128` elevator actors (ACTOR),
`256` disc identity in context, model declarations and scene instances,
`512` cinematic source/frame context, `1024` independent-view model/effect semantics,
`2048` untextured world snow, `4096` emissive/one-sided world surfaces,
`8192` semantic object appearance, `16384` native vision context and
`32768` thermal model heat/compositor ownership, `65536` native goggles UI ownership,
`131072` native status bar ownership, `262144` subtitle ownership, `524288` radar ownership,
`1048576` inventory ownership, `2097152` Codec ownership, `4194304` Options ownership,
`8388608` game save/load ownership, `16777216` title/new-game ownership and
`33554432` live display control, `67108864` modal input capture and
`134217728` direct native save/load actions, `268435456` direct native Options actions,
`536870912` direct native title actions, `1073741824` direct native Codec actions and
`2147483648` direct native inventory actions.
Bits 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384 and 32768 require
minor 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 and 13 respectively. Godot offers 1, 4, 8 and 16, plus
2, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432, 67108864, 134217728, 268435456, 536870912, 1073741824 and 2147483648 in scene mode. Native offers all32 bits (`0xffffffff`, unsigned4294967295); its required set remains536870911. Title, Codec and inventory actions are optional negotiated additions. Inventory actions require minor30, INVENTORY, INPUT_CAPTURE and scene/context/session/disc/cinematic capabilities. Codec actions require minor29, CODEC and the same input/context dependencies. Title actions require minor28, TITLE and those dependencies. Options actions require minor27, OPTIONS, INPUT_CAPTURE and scene/context/session/disc/cinematic capabilities. Save actions require minor26, SAVE_UI, INPUT_CAPTURE and scene/context/session/disc/cinematic capabilities. Input capture requires minor25 and bits2 and16. Display control requires minor24 and bits2 and16. Title requires minor23 and bits2,8,16,256 and512. Save/load requires minor22 and those context bits; Options minor21, Codec minor20, inventory minor19, radar minor18, subtitles minor17 and status bars minor16 require the same bits.
Goggles UI requires minor 15 and bits 2, 8, 16, 256 and 512;
Godot advertises it only after its default or modded Control scene and local artwork have initialized.
Vision context requires bits 2, 8, 16, 256 and 512;
thermal ownership additionally requires bit 16384.
Both retained operations require
bits 2 and 32; MODEL_SOURCE requires bits 2 and 64. ACTOR requires bits 2, 8, 16 and 128. These are prototype capabilities, not the future full-image,
actor-binding or editor APIs.

Required bits must be a subset of offered bits and available renderer bits.
Unknown optional bits are ignored; unknown required bits reject the session.
The selected set is the intersection of native-offered and renderer-available bits.
Commands requiring an unselected capability are rejected before dispatch.
Major versions must match; this implementation selects the lower of its minor 27 and the client minor.
The current native requires minor 27 and session-bound context; an older Godot
server fails explicitly instead of silently omitting session identity. Native validates the selected
version/set in the reply. No semantic feature is advertised before implementation.

Version 13/14 HELLO is incompatible with version 15. Rebuild/deploy the native and
Godot files together; an older client receives a length diagnostic instructing that.
Older minor-1/2 clients retain their existing command layouts; current native uses the retained operations in scene mode. A legacy-renderer build does
not use this connection and is unaffected.

## Launcher-owned session token

Each launcher `GodotSession` generates a fresh 128-bit cryptographically random
bearer token. `tools/run-godot.ps1` does the same for command-line sessions.
Both child processes receive the same 32-digit hexadecimal value through
`MGS_GODOT_SESSION_TOKEN`; it is not placed in command-line arguments or logs.
Native decodes it into the final 16 HELLO bytes. Godot requires an exact match
before accepting the handshake or dispatching commands. Missing/malformed host
configuration and a wrong peer token fail explicitly. Tests use their own tokens.

This binds an incoming connection to the intended launcher session; a random
loopback port alone did not. It is local bearer authentication, not encryption,
mutual server authentication or a sandbox against code running with the same
user's privileges. A mod script/native extension has those privileges. The token
is not a public actor/session identifier and must not be exposed in mod snapshots.
A new launch creates a fresh token. Reconnect and renderer replacement remain
unimplemented and will need an explicit host-managed token/lifetime policy.

## Native context samples (15.1, 15.2, 15.6, 15.7 and 15.12)

CONTEXT starts with these little-endian fields: uint32 schema, uint32 resource-stage
generation, uint64 sample sequence, uint32 raw `GV_Time`, uint32 `GV_PauseLevel`,
int32 `GV_PassageTime`, and eight zero-padded ASCII resource-stage bytes.
Schema 2 appends the 16-byte public session ID negotiated in HELLO. Schema 3 adds
uint32 disc number at offset 52, yielding 56 bytes, when bit 256 is negotiated.
Disc must be 1 or 2 and comes from the validated native inserted-disc state.
Schema 4 appends six 32-bit cinematic fields at offsets 56 through 76:
generation, source disc, DEMO.DAT sector, total source frames, signed applied
source frame, and active flag (0/1). Generation increments for each demo actor.
Frame is -1 before a usable sample. Source selection comes from stream control;
successful `FrameRunDemo` camera application publishes its actual packet frame,
not a wall-clock estimate. Destruction or a changed scene epoch releases camera
ownership. File/debug demos without a selected disc stream keep active=0.
Localized demo packs retain Integral's type-5 animation packets, so their camera
frame/source identity stays tied to the Integral disc. Arbitrary replacement
stream provenance remains separate work.

Schema 5 appends uint32 vision mode at offset 80: 0 normal, 1 night vision,
2 thermal vision. It samples `GM_GameStatus` after native actor updates; thermal
takes precedence if both native flags are set. Unknown modes reject the sample.
The copied mod context exposes `vision_mode`. This field does not grant Godot
authority over equipment, visibility, AI or other gameplay state.

Night vision uses an editable Godot post-transparent compositor on world and
empty-background views, preserving depth and alpha. A mode change resets temporal
history. Native `scn_mask.c` suppresses its night-vision tint/scanlines only while
scene rendering owns this effect. With capability 32768, thermal mode similarly
suppresses the native thermal tint/scanlines and uses a Godot thermal compositor.
Reference-only and Legacy rendering retain both masks. Native palette callbacks,
thermal-only line primitives and first-person sight UI remain in place.

Thermal model classification uses the existing instance flags word: native
`DG_FLAG_IRTEXTURE` (0x0200). No per-model wire field was added. Godot mirrors
visible IR-marked model parts into a heat/depth pass sharing their mesh, skin and
skeleton, then rejects heat behind the final camera's scene depth. Hidden parts,
native visibility changes and mod removals remain authoritative. Authored model
replacements inherit the native IR classification; scripts may override heat on
individual MeshInstance3D nodes. `get_instances()` exposes a copied `thermal` bool.
This is source-backed heat classification, not a physical temperature simulation.

Protocol15.35 scene mode sends schema6: schema5's84 bytes followed by uint32
loading (0/1) and eight ASCII bytes for the upcoming stage, zero-padded. An idle
loading state has an empty upcoming stage. This lifecycle drives loading presentation
and mod-resource prefetch; it does not advance gameplay. Peers through15.34 retain
schema5; command-only mode retains schema2.

During renderer replies, the native owning thread services audio at device demand
outside active gameplay frames. Native stops, fades and pause remain authoritative;
gameplay clock/frame counters do not advance during these presentation waits.
Schema 1 omits the session suffix and is accepted only when bit 16 was not
negotiated. All versions expose a connection-local public ID to mods.
The sequence starts at 1 and increments exactly once per sample, bounded by
INT64_MAX. Godot rejects gaps, stale generations, malformed names and stage-name
or disc changes without a new generation before publishing any field.

The source samples after native channel updates and before any SCENE packet.
It also publishes during reference-only/menu rendering. `MgsNativeSelectStage`
increments generation for every resource-stage load, including same-name reloads
and resident `init` loads. A changed inserted disc also advances the generation,
even when the resource-stage name is unchanged. Generation 0 with an empty stage names pre-load state.
This is a resource-load boundary, not a claim that every scenario or camera cut
has its own generation. The public session ID is a fresh random 128-bit value created by Godot after
authenticating HELLO, independent of the private token. Native retains the ID
and echoes it in every schema-2-or-newer context. Godot rejects a mismatching ID before
changing state. Scenario identity and reconnect/resync remain pending.

CONTEXT is an ordering barrier: queued rendering work completes before its sample
becomes visible to the mod API. A following SCENE therefore observes that context.
It does not yet carry an atomic retained-resource/actor baseline or implement
resync. Rejected samples fail the session; reconnect recovery remains pending.

`GV_Time` is an actor-loop counter from the native daemon and can advance while
normal actors are paused. `GV_PassageTime` is native tick passage, not seconds.
Consumers must observe the pause mask and authoritative poses; neither field is
a universal animation clock. Cinematic frame identity/time still needs its own
provider. Godot must not advance native gameplay using its render delta.

## Primitive data

The draw header contains vertex/index counts (uint32), scissor x/y/w/h (int32),
eight vertex-uniform floats, then force-mask/preserve-mask (uint32), render scale
(float) and sampling flags (uint32). The uniforms match the pinned Psyz shaders.
Each 20-byte vertex contains int16 x,y; uint16 u,v,CLUT,texture-page/flags;
uint8 r,g,b,a; and four texture-window bytes. The initial reference renderer uses
1024x512 VRAM for native readback and texture/CLUT addressing. A separate scaled
color target combines high-resolution world geometry with HUD and effects.
Its vertex pixel-center offsets are divided by the presentation scale.

Protocol15.32 adds sampling bit6 for original WaterView distortion/tint batches.
The host tags only those bounded command groups; older negotiated minors omit
the bit. An upgraded visible water region may suppress them when its underwater
volume contains the presentation camera. Ordinary effects and HUD draws remain;
Legacy through Godot never enables suppression. Native WaterView state/timing
and swimming/oxygen are unchanged.

Protocol15.34 adds sampling bit7 for bitmap caption draws. Native Telop actors
bound their existing subtract/add sprite pairs with text-card markers; negotiated
older minors omit the flag. Full Godot with sharp text enabled reconstructs their
coverage with cubic filtering at presentation resolution. Native position, color,
ordering and fade timing remain authoritative. Original-pixel text and Legacy
through Godot clear this flag and use the original nearest-pixel path.

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
Each instance starts with a 36-byte header when capability 256 is selected, otherwise 32 bytes:
uint32 lifetime ID, uint32 original resource hash, 8-byte definition-stage field,
uint32 original flags, uint32 extended part count, uint32 visible part count and
uint32 lighting-color count, then uint32 model source disc at offset 32 when
capability 256 is selected. The source disc is retained at model registration;
a resident model loaded from disc 1 still references disc 1 after inserting disc 2.
The enclosing scene header remains 68 bytes. Older peers resolve models on disc 1.
Capability 8192 appends 12 bytes to this header (48 bytes with disc identity):
uint32 appearance kind (0 normal, 1 optical camouflage), float32 amount in [0,1]
and uint32 RGB tint with the top byte zero. Components use 128 as neutral, matching
the native effect color. The consumer rejects unknown kinds, nonfinite/out-of-range
amounts and invalid tint words. Kind 0 restores the regular material and shadow
policy; amount/tint are unused for that kind. Native registration/reuse starts at
kind 0, and camouflage actor cleanup or thermal-vision switching clears the state.
Native constructors and transition progress supply kind 1; this is independent of
the original framebuffer texture-page/UV rewriting, which remains for Legacy.
Godot uses original mesh UVs and its own scene texture, suppresses legacy packet
metadata for the affected object, and disables its opaque shadow while camouflaged.
It is followed by 52 bytes per part: twelve floats for that part's final local-to-view
transform, with the 58/64 vertical overscan removed, and uint32 part flags:
bit 0 enables the color/metadata mesh, bit 1 enables shadow casting, and bit 2
selects a transparent material for live semitransparent packets. At minor35,
bits16–31 carry the signed16-bit native owner.raise (extension parts inherit it).
Positive raise orders a coplanar part nearer; negative raise orders it farther.
The spatial renderer uses2 micrometres per raise unit in camera depth, preserving
projected XY, foreground geometry and shadow positions. Color and metadata use the
same depth adjustment. Bits3–15 remain reserved; older peers reserve bits3–31.
Unknown reserved bits are rejected. The version handshake prevents older renderers from interpreting a
shadow-only part as a visible part.
Godot reconstructs the world pose using the inverse view matrix. This uses the final
`DG_OBJ.screen` matrix because the cinematic screen channel makes static `.world`
matrices camera-relative while animated `.world` matrices remain absolute. Treating
both as world coordinates applies the camera translation twice to scenery.
Extended mesh parts inherit their primary part's matrix.
With capability 1024, active owned parts remain color-visible and shadow casters
outside the native camera bounds; Godot performs view and shadow culling.
Inactive map groups, hidden actors, unused parts and visual mod removals still
disable them. Godot uses `SHADOWS_ONLY` when bit 1 is set without bit 0; authored
replacement `Cast Shadow` settings are retained.
Parts with runtime texture placeholders, subtractive blending or framebuffer
textures remain on the compatibility path; the corresponding Godot mesh is hidden to avoid drawing
the same part twice. This classification is explicit, not a failed-load fallback.

After the part matrices, each instance carries `colorCount * 4` bytes of original
lighting: RGBA8 in model-part/face/corner order. RGB comes from the game's shaded
polygon packets; with capability 1024 the fourth byte is 255 for a natively
projected face, 127 for valid material data outside native projection, and zero
when no packet exists. Older peers use only 255/zero.
The converter stores palette UVs in
TEXCOORD_1. A per-instance texture supplies the shader's original 128-neutral RGB
modulation, keeping imported meshes immutable. Visibility respects the active native
map group and explicit hide flags. Unmigrated menu/save and movie rendering uses the command layer.

The lighting palette is followed by `colorCount * 16` bytes: four float32 values
per corner containing normalized live U, V, original ordering depth after the
part's `raise` adjustment, and blend selector (0 opaque, 1 half, 2 additive,
4 quarter-additive). Subtractive packets remain on the command path.
Lighting and packet palettes use
the same part/face/corner order. Godot uploads them separately as RGBA8 and RGBAF
textures. Color and shadow passes use valid material data independently of native
face visibility. Only metadata uses the native projected-face bit, because its
ordering depth is meaningful only there; other faces use Godot depth for composition.
Both original-color and Godot-lit meshes use Godot's geometry culling: the original low-resolution
projection can collapse small distant faces that remain visible at the output
resolution. Native material packets stay allocated and shaded for active off-screen
models, preserving animated UVs. Prepared UVs apply only when no packet exists.
Native actor/part visibility still
applies. Replacement models retain their authored topology and materials.
Truncated palettes, incompatible prepared color counts, duplicate lifetime IDs
and unknown generated models are rejected.

After all instances, v7 and later append uint32 effect-quad count, followed by 196 bytes
per quad: uint32 original texture hash and four vertices in native packet order
(top-left, top-right, bottom-left, bottom-right for billboards). Each vertex is
twelve float32 values: view-space position in Godot metres plus camera-facing depth bias in metres; normalized
U/V and red/green modulation; blue modulation, blend selector and two billboard offsets.
With capability 1024, each billboard vertex carries its centre in native-view
space and horizontal/vertical corner offsets in final-camera metres. Godot applies
the offsets in the edited camera's view; the vertical offset removes the native
58/64 overscan. Spatial quads carry world-derived view positions and zero offsets.
Older peers send already-expanded positions and zero offsets. Native projection
tags no longer discard owned effects behind/outside that camera. Explicit visibility,
map groups, animation, UV changes and fades remain active. Batch sorting uses the
final camera. Actors that never spawn an effect because of native point checks
still need separate semantic emitter work; this capability does not cover them.

Registered water surfaces/ripples, gameplay and cinematic bubbles, and smoke/breath, fog and casing
animation textures use this path. Godot batches by texture into reusable meshes
and RGBAF geometry palettes.

SDK19 adds optional effect blend flag64 for a native surface-ripple actor. Its
eight POLY_FT4 quads are contiguous, have the same texture identity and carry the
current ring geometry and fade. The payload layout and protocol15.32 stay unchanged;
older renderers ignore this flag and draw the original ring. New renderers transform
the ring through the original native camera, offer it to visible upgraded water
regions and omit those eight quads only if one accepts it. Unowned rings and other
effects keep their original path. A new snapshot replaces the accepted native rings;
it does not spawn an additional disturbance each frame.

SDK26 adds effect blend flag128 for native footprint floor quads (`asiato`,
`asiato2`, `demoasi`, texture `dc55`). The packet layout remains15.35. These
explicitly registered effects may carry subtractive blend3; other subtractive
and framebuffer primitives retain their compatibility path. Native placement,
left/right UV orientation, eligibility, fade and destruction remain authoritative.
Godot uses a subtractive material with a2mm camera-facing depth bias and no
colorless depth write, preserving the receiving surface's depth. This is a
floor quad, not a projection onto replacement geometry at a different height.
The Effects editor creates a matching editable/exportable footprint material.

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

With capability 2048, effect resource ID `0x10000` identifies built-in snow rather
than a retail texture hash. Its quads carry world-derived centres, normalized
native RGB (`/255`), blend mode zero and billboard offsets in original pixel units.
Godot resolves it as `mgs/effects/snow`, with generated white albedo and opaque mask;
no original texture is needed. Its shader expands the offsets using the final
camera depth/projection and reference 320x224 image with 4:3 display aspect. Native
1/2-pixel sizes stay consistent across depth, FOV and widescreen while centres,
occlusion, fog and lighting use the Godot view. Only explicitly registered spatial
TILE snow groups use this semantic; UI tiles and camera/sort/free-packet primitives
remain excluded. Native wind, spawn/RNG, color animation and on/off messages remain
authoritative. Spawn volumes still follow the native camera; an independently
authored camera cannot create snow outside that simulated volume yet.
Under Godot lighting, texture color is decoded before applying the native fade
multiplier, so low-intensity ripples fade linearly. The shader uses Godot's built-in
two-sided normal handling; a second backface flip would invert ripple lighting.

With capability 4096, the blend selector is an integer-valued float with low three
bits retaining blend modes 0â€“4, bit 8 indicating an emissive surface and bit 16
indicating one-sided visibility. Both color and composition-depth passes discard
one-sided backfaces. Registered `NewTextureLamp` actors emit these flags and update
their texture identities when native scripts/messages change frames. Raw-texture
lamp packets send neutral modulation; modulated packets retain their native RGB.
Emissive surfaces remain subject to fog, transparency and world occlusion, without
requiring external light. This does not create additional scene lights.

Minor 14 adds blend-selector flag 32 for registered textured line beams. Four
vertices carry endpoints A/B/A/B, with independent native UVs and per-corner RGB;
billboard offsets are zero. Godot expands a camera-facing strip using the final
view and reference 320x224 pixel size. It smoothly rotates the strip instead of
copying the old rasterizer's dominant-axis step. `beam_width` scales that width.
Native clipping tags/projected coordinates are never used for this geometry.
The native peer requires minor 14, so an older consumer cannot silently interpret
beam endpoints as an ordinary degenerate quad. Capability bits remain `0xffff`.

`takabe/ir_cens.c` registers its eight `lsight` segments as emissive beams. Native
goggles, cigarette proximity, activation messages and target interception still
control shade and endpoints. Zero shade discards color, composition depth and
heat. The matching depth shader accepts `thermal_pass` to render beam heat into
reserved layer 18 using the same geometry/coverage; this pass is enabled only
in thermal mode. Opaque world depth rejects occluded heat. Authored depth shaders
used by beams must expose this boolean or loading reports an actionable error.
Other native line actors are not implicitly registered by this change.

Effect registrations can cover individual face ranges, retaining each texture in
multi-texture cinematic bubble actors. KMD texture ID zero follows the prepared
asset importer's null-surface contract: its color and metadata surfaces are empty,
regardless of triangle area. It no longer rejects the surrounding textured mesh
part. Framebuffer, unsupported packet and subtractive modes on non-null faces still
retain compatibility ownership. This intentionally avoids interpreting undefined
null-texture VRAM data as authored artwork.

Protocol v8 appends a light section after the effect quads: uint32 count, followed
by 40 bytes per light. Each record contains uint32 identity, uint32 kind, float32
position XYZ, float32 direction XYZ, float32 native radial range and float32 native
box cutoff. Positions/ranges are renderer-world metres; directions use its axes.
Kind 1 is a temporary omni light, with identities 1â€“8 matching native temporary
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
`mgs/integral-j/discN/stage/<definition-stage>/<four-hex-digits>.k`.
The source disc and definition-stage are captured when the loader registers the resource; resident
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
original ripple effects use the existing world-effect path; SDK19 can route
explicitly tagged surface rings into an upgraded water region as described above.

## Retained face palettes (minor 3)

PALETTE starts with six uint32 fields: action, native instance ID, kind, previous
revision, new revision, payload byte count. A 16-byte public session ID follows,
then the payload (40-byte header total). Kind 1 is face RGBA8 colors (stride 4);
kind 2 is RGBAF packet metadata (stride 16). Action 1 creates with revisions 0/1;
action 2 updates current/current+1; action 3 retires current/0 with no payload.
A resource key is `(native instance ID, kind)`, not an authored content ID.
Instance IDs are monotonic within the native process and are not reused.

RETAINED_SCENE has the existing SCENE layout except that, for an object with
nonzero color count, two uint32 revisions replace its inline color and packet
arrays after its parts. They reference that instance's kinds 1 and 2 respectively.
The receiver validates exact revision and byte size against the scene count.
Missing/stale references, foreign sessions and invalid lifecycle transitions fail
explicitly before that resource is mutated. There is no automatic resync yet.
Operation 9 remains available for older full-snapshot clients.

Each side bounds resident palette payload to 64 MiB; the receiver also limits
resources to 2,048 (up to four per native instance). Native removal sends retirement and
frees its cache. Godot drops the transport entry; already submitted scene/GPU
resources keep their own references until their normal scene cleanup. Ordered
SYNC/FRAME replies cover preceding work; there is no separate resource retirement
acknowledgment. Geometry, general textures, content IDs and dependency lifetimes
are not yet covered by this protocol slice.

Native compares serialized candidates byte-for-byte and sends changed payloads
only. Every 300 retained snapshots, `[godot-palettes]` reports cumulative raw
payload bytes sent/reused, resident bytes and cache allocation/resize count.
These counters exclude headers, transforms, effects and GPU copies. Candidate
serialization still runs each snapshot. Godot preserves unpadded resource bytes
and creates padded image copies only when a changed palette needs GPU upload.

### Native deformation (minor 32)

When minor32 is selected, every nonempty RETAINED_SCENE palette reference gains
a third uint32 revision after color and packet revisions. Zero means no native
deformation. A nonzero value references PALETTE kind3: `colorCount` XYZ float32
deltas, stride12, in the same original part/face/corner order as the color palette.
Coordinates use prepared mesh axes `(x,-y,-z)` in metres, before skinning. All
components must be finite. Older selected minors retain the two-word layout.

The native loader captures original linked-vertex ownership before relocating
parent indices, including the packed KMD loader. ShakeModel marks shared model
data when it changes or restores vertices; the bridge samples actual native
coordinates. Each model builds deltas once per changed version, and each instance
publishes only changed payloads. Models without a deformation provider allocate
no delta buffers. Mapping/delta storage and retained palettes each have a64MiB
budget. Model address reuse resets ownership and baseline state.

Godot clones original ArrayMesh position buffers per instance, preserving skin,
material and corner mapping. Visible, depth and shadow passes share the changed
positions. Replacement geometry does not inherit an inferred vertex mapping.
An explicitly mapped replacement mesh may set `mgs_native_deformation=true`:
UV2 must encode original corner `i` as `((i%256+0.5)/256,
(floor(i/256)+0.5)/ceil(colorCount/256))`, and retain the corresponding original
skin bone. Unmapped custom geometry remains unchanged. This is a deformation
mapping contract, not permission to export original meshes.

### Live native textures (minor 33)

Minor33 appends a fourth uint32 revision after color, packet and deformation
references for each nonempty RETAINED_SCENE palette. Zero selects the prepared
texture. Nonzero references PALETTE kind4, `colorCount * 16` bytes: float32 raw
U, V, texture-page-plus-one and CLUT address per original face corner. Coordinates
include a half-texel offset. Page zero marks a corner without a live texture;
reserved texture depth3, nonfinite/out-of-range values and fractional addresses
are rejected. The palette has the same session, revision, retirement and memory
limits as other retained resources. GPU padding must copy retained bytes.

Only registered native producers use this path. The submarine `optxtscn` actor
registers after configuring its live page/CLUT. Godot samples the existing VRAM
target using 4/8/16-bit lookup, transparent zero and STP semantics in both color
and metadata passes. Explicit mod texture replacements take precedence. Older
negotiated minors keep these producers in native drawing ownership. This does
not introduce a generic framebuffer replacement for unrelated materials.

### Generic Wall provider and part anchors (minor 32)

ACTOR schema1 also accepts provider`0xec77` for the recovered Wall constructor.
It retains the136-byte record and exact declaration identity; phase/progress/
duration are zero and are omitted from the public Wall state. Native destruction
retires the instance. Providers are negotiated; older minors receive only the
existing elevator provider. Actor state does not make collision editable.

Authored `mgs_native_part` nodes receive the final scene part poses, including
rotation/scale and extended-part ownership, with their authored local offsets.
The existing actor body sample is still available; final scene poses drive
visual attachments so they agree with the original mesh during cinematics.

## Native model source declarations (minor 4)

MODEL_SOURCE contains four uint32 values: model ID (low 16 bits), original cache
ID (extension index in the high 16 bits), bounded source byte size and model offset
within that source. These are followed by stage name (8 zero-padded ASCII bytes),
public session ID (16 bytes) and SHA-256 of the raw source buffer (32 bytes).
Capability 256 appends uint32 source disc at offset 72, yielding 76 bytes;
otherwise the declaration remains 72 bytes. The source buffer is limited to
64 MiB and is never sent here.
The consumer limits declarations to 65,536 stage/model keys per connection.

The native loader hashes once before `GV_LoadInit` mutates pointers or parent
indices, after any native resource override is applied. KMD registration emits
the declaration before a later SCENE can reference it. Standalone `.k` models
require offset zero and matching model/source names. Packed `.z` registrations
retain archive identity/digest and subresource offset; they are not relabelled
as independently hashed `.k` files. Current preparation lacks packed-subresource
provenance, so attempting to render one produces an explicit diagnostic.

With capability 64, every nongenerated scene model requires a preceding source
declaration and an exact catalog source digest match before instantiation. A new
load replaces the declaration for its disc/stage/model key. Native resource overrides
whose bytes differ from the prepared model fail explicitly. Generated light
models have no original file and bypass this check. On disconnect, Godot reports
counts of declared and successfully matched models.

With capability 256, declarations and scene instances resolve the matching
`mgs/integral-j/discN/stage/...` catalog. Current context selects the stage's
map definitions, textures and overrides; resident models retain their source disc.
Missing prepared discs fail explicitly. This is not yet a complete renderer-neutral
resource incarnation or actor identity. Source retirements, archive preparation and
resource dependency acknowledgments remain M1/M3 work. No live buffer pointer
crosses the wire. Older minor clients retain their existing scene path.

## Elevator actor provider (minor 5)

ACTOR schema 1 is a fixed 136-byte record, all scalar words little-endian:

| Byte offset | Value |
| --- | --- |
| 0â€“44 | Twelve uint32: schema=1, action (1 spawn/2 update/3 retire), slot, generation, birth epoch, body scene instance, part count, actor name, map mask, provider=0x2abc, actor sample tick, phase |
| 48â€“52 | Script cache ID and command statement byte offset |
| 56â€“63 | Original script stage, zero-padded ASCII |
| 64â€“95 | SHA-256 of original script bytes before native relocation |
| 96â€“107 | Three float32: body position in native-world metres |
| 108â€“115 | int32 progress numerator and duration denominator |
| 116â€“119 | uint32 native visibility |
| 120â€“135 | Public session ID |

Slots are 1â€“128. A reused slot increments generation; exhaustion is fatal.
Birth epoch is fixed for an incarnation. New actors publish after their first
native update, with a complete sample; destruction before first publication
needs no renderer retirement. Retired published actors remain queued until the
next channel sample. Full samples replace pose/state; pause holds the last pose.
CONTEXT precedes each channel's actor records. Enclosing context supplies the
presentation sequence; the actor sample tick records its last actual update.
There is no independent delta baseline or reconnect support yet.

The provider reads the elevator's chosen position after native movement, and does
not derive it from camera-space matrices. This actor uses identity rotation.
Phase 0 is at start, 1 toward end, 2 at end, 3 toward start. Progress measures
position along start-to-end, not elapsed Godot time. No callback is replayed or
removed. The provider currently supplies one body anchor; separate part labels,
other articulated anchors and ordered arrival/departure events remain pending.

Selected GCX source identity is retained before `GCL_LoadScript` mutates its
procedure table. Nested `GCL_Command` scopes restore their caller. A chara command
inside the selected script yields its statement offset; a constructor outside
that source has offset 0xffffffff and no resolved declaration. Never interpret
an unresolved origin as a model-name match. Procedure metadata, cinematic spawn
origins and both-disc namespaces remain pending.

Godot rejects foreign sessions, stale generations, identity changes and nonfinite
poses. Old-epoch anchors are hidden until explicitly carried/replaced by future
lifecycle work. `VisualModAPI.get_native_actors()` returns copied records and live
body Node3D references; `native_actors_updated` announces accepted records.
`resolve_native_actor` requires exact source stage/script/digest/statement/provider
identity and considers only the current epoch. Missing and ambiguous declarations
remain explicit; runtime IDs and model names are not fallback selectors. Context
notifications observe the updated actor epoch. See the modding guide for result
statuses and an example.
Children use ordinary Godot parenting. Body transforms compensate for structural
parent transforms; singular parents fail explicitly. Original visuals, collision
and gameplay remain owned by their existing paths. This is an initial provider,
not completion of M1's general actor/state/event contract or M2 editor workflow.


## Goggles UI state (minor 15)

Operation 17 follows CONTEXT in each semantic scene publication. It has no reply.
The receiver validates it against the current native session and scene epoch,
then presents the pending state at FRAME; it does not advance timers locally.

| Byte offset | Type | Meaning |
| --- | --- | --- |
| 0 | uint32 | Schema 1 |
| 4 | uint32 | Native scene epoch |
| 8 | uint32 | 0 inactive, 1 night vision sight, 2 thermal sight |
| 12 | uint32 | Bit 0 active, bit 1 indicator HUD visible, bit 2 SCAN visible |
| 16 | uint32 | Player heading masked to 0..4095 |
| 20 | uint32 | Native goggles sight timer |
| 24 | uint32 | Visibility bits for the three static sight layers |
| 28 | 6 int32 | Layer 0/1/2 x,y offsets in the native 320x224 UI coordinate system |
| 52 | 16 bytes | Public session identity |

Hidden layers have zero offsets. Inactive state has zero mode, flags, heading,
timer, layer mask and offsets. An epoch change clears goggles state. The native
sight actors still process ownership, input, messages and lifetime; negotiated
Godot ownership suppresses only their text/primitive submission. The SCAN clock
was separated from drawing without changing its pre-increment visibility rule.
Without capability 65536, including Legacy builds, native drawing remains active.
The goggles view is independent of the global vision compositor mode: cinematic
scripts can create a sight directly. Other UI still uses compatibility rendering.


## Status bars (minor 16)

Operation 18 follows CONTEXT. Its schema-1 header contains four little-endian
uint32 values: schema, scene epoch, record count and record stride (72), followed
by the 16-byte public session identity. An empty frame has count zero. Receivers
validate the complete message before updating pending state, then present it at
FRAME alongside the goggles UI. No timer runs in the Godot presenter.

Each 72-byte record contains:

| Offset | Type | Field |
| --- | --- | --- |
| 0, 4 | int32 | Native UI x/y, in 320x224 coordinates |
| 8, 12, 16 | int32 | Delayed value, current value, maximum |
| 20 | int32 | Interior height, 0..5 pixels |
| 24 | uint32 | Kind: 0 other/boss, 1 player life, 2 oxygen |
| 28 | uint32 | Bit 0: damage text tint; other bits zero |
| 32, 36 | uint32 | Left/right gradient RGB, packed as 0x00BBGGRR |
| 40 | 32 bytes | NUL-terminated ASCII label |

Records retain native submission order, including repeated player bars and
independently named boss/protection/torture bars. The default scene draws later
submissions behind earlier ones to match menu ordering. Identity within the UI
is kind + name + occurrence; no native pointer is exposed. This is presentation
identity, not gameplay actor identity.

MENU_ResetSystem clears the collection each native frame. The common bar drawer
publishes only after its photo/life-off/demo visibility gate and suppresses the
legacy primitive submission only when capability 131072 is negotiated. Health,
oxygen, damage consumption, slide/hide counters and shared callers still execute
in native code. An epoch change discards prior bars. Exceeding the 16-bar or
31-character label capacity fails explicitly rather than dropping bars.


## Subtitles (minor 17)

Operation 19 separates native timing/layout from Godot presentation. The native
`menu/jimaku.c` actor still advances timers, handles caption settings, Circle
confirmation, GCL continuation, pause/restart and procedure callbacks. With
capability 262144, it suppresses its sprites, PAUSE label, dim tile and page
uploads. Legacy and command-only rendering keep those draws. Native font code
still computes its layout; Godot does not consume its raster buffer.

The 128-byte header contains:

| Offset | Type | Meaning |
| --- | --- | --- |
| 0 | uint32 | Schema 1 |
| 4 | uint32 | Native scene epoch |
| 8 | uint32 | Page revision; zero for inactive frames |
| 12 | uint32 | 1 when source glyph layout follows, otherwise 0 |
| 16 | 16 bytes | Public session identity |
| 32,36,40 | uint32 | Active, visible (caption setting), kind: 0 caption / 1 modal area / 2 forced caption |
| 44 | int32 | Pre-update native timer; -1 waits for native confirmation |
| 48,52 | int32 | Native text origin in the 320 x 224 UI canvas |
| 56,60,64 | int32 | Sprite width/height and measured text width |
| 68,72 | int32 | Character/line spacing |
| 76,80 | uint32 | Local glyph layout backing width/height, only with a layout |
| 84,88 | uint32 | Glyph count and stride (80) |
| 92 | uint32 | Reserved, zero |
| 96 | 16 uint16 | Original 15-bit font palette, only with a layout |

Each 80-byte glyph record has uint32 kind/code at 0/4, int32 x/y at 8/12,
uint32 width/height/color/sourceBytes at 16/20/24/28 and 48 bytes of padded packed
source at 32. Kinds are 1 half-width, 2 full-width, 3 ruby, 4 dash, 5 emphasis,
6 erase. Half-width codes identify native character bytes; full-width codes are
bank * 4096 + one-based index; ruby uses a one-based resource index. These are
native identities, **not Unicode**. Source is MSB-first 2bpp; half/full use glyph
width as pitch, ruby uses six pixels. Dashes/emphasis are generated marks without
source bytes. Odd-x dashes have width 20 and omit local pixel 1; even-x ones have
width 18. Erase records preserve native Kinsoku backtracking.

Page source bytes are copied when native printing resolves the font bank, so
later reuse of stream/GCL/radio bank memory cannot corrupt a displayed page.
A new page, epoch or session publishes its layout once; following frames retain
it by revision. Revisions remain distinct across subtitle resets. Bounds are
4096 glyphs, a 256 x 128 layout and 48 source bytes per glyph. Invalid sizes,
source lengths, kinds, session/epoch or undefined page references are rejected.
A missing/inactive frame clears the UI at the following FRAME; Godot never
advances subtitle timers itself.

The default Godot Control uses a transient FontFile atlas of the positioned
source glyphs, preserving palette groups and erasure/overlap semantics. It draws
outside FSR2, with native cardinal outlines. Fonts carry retail provenance and
are detached on editor save. Only the active page is retained; original glyphs
must never be serialized into mod ZIPs. A custom `ui.subtitles.scene` receives
`active`, `visible`, `kind`, `timer`, `position`, `size`, `text_width`, spacing and
`layout` (epoch, revision, size, palette, positioned glyph records) through
`apply_native_state`. Native text is not incorrectly presented as UTF-8.


## Radar (minor 18)

Operation 20 requires capability 524288 and the scene/context/session/disc/cinematic
capabilities. Godot advertises it only after the default or modded radar Control
and its local artwork initialize. It is an ordering barrier with presentation at
FRAME. Native state, alert recovery, RNG, sounds and countdown callbacks remain
native. An unsupported custom radar callback is a fatal diagnostic under ownership.

The schema-1 header is 104 bytes:

| Offset | Field |
| --- | --- |
| 0 | uint32 schema = 1 |
| 4 | uint32 epoch, equal to current native context |
| 8, 12, 16 | uint32 contact, sight and wall counts (limits 96, 96, 4096) |
| 20, 24, 28 | uint32 strides = 152, 40, 24 |
| 32 | 16-byte public session ID |
| 48 | uint32 active (0/1) |
| 52 | uint32 mode: map 0, jamming 1, evasion 2, alert 3, escape countdown 5 |
| 56 | uint32 native tick |
| 60, 64, 68 | int32 x/y placement offsets and radar scale |
| 72, 76 | int32 alert level and pre-update recovery counter |
| 80, 84 | int32 pre-update console x/y cursor |
| 88 | int32 countdown ticks before native decrement (30 per second) |
| 92, 96 | uint32 map-visible and noise-present flags (0/1) |
| 100 | uint32 native noise seed |

Records follow in contact/sight/wall order. Points are pairs of int32 coordinates
relative to radar center `(269+x, 42+y)` on the 320x224 canvas. The interior starts
at `(235+x,16+y)` and measures 69x52. Native framebuffer offsets are excluded.

- Contact (152 bytes): position, uint32 kind (player 0, near 1, other floor 2,
  noise 3), control-list index, original attributes, packed source RGB, then
  sixteen noise points. Control indices are frame-local and cannot bind actors.
- Sight (40 bytes): four points in native quad order, packed center and edge RGB.
  The center is point 1; triangles are 0/1/2 and 1/3/2.
- Wall (24 bytes): two points, uint32 kind (normal 0, other floor 1, special 2)
  and dynamic flag (0/1).

Packed RGB has red in bits 0..7. A hidden frame has no records, visible map or
noise; it clears the previous UI. Session, epoch, stride, count, enum and exact
payload size are validated before replacing pending state. An epoch change before
publication produces an empty frame. Godot must not advance the transmitted
counters, reseed native RNG, run countdown procedures or change detection rules.

The native ownership adapter preserves the recovered drawer's state side effects
using a private CPU packet buffer. Those packets never enter the real ordering
table, and dynamic radar palette uploads are suppressed. This is image ownership,
not yet a complete separation of native update code from packet construction.

## Inventory (minor 19)

Operation 21 requires capability 1048576 plus scene/context/session/disc/cinematic
capabilities. The default or modded `ui.inventory.scene` must initialize before
Godot advertises ownership. Native item/weapon selection, consumption, quick equip,
scrolling, menu animation, pause and sounds keep their original update routines.
Leaf panel/description/PAL-key drawing publishes semantic state; inventory-specific
VRAM image/palette uploads are suppressed under ownership. Legacy drawing remains
available when ownership is not negotiated.

| Offset | Field |
| --- | --- |
| 0, 4 | uint32 schema 1 and native scene epoch |
| 8, 12 | uint32 panel count (0..32) and stride 80 |
| 16 | uint32 PAL key state 0/1/2; 0xffffffff means absent |
| 20..31 | Three reserved zero words |
| 32..47 | Public session ID |
| 48..175 | Existing 128-byte subtitle-layout header, used for the description |
| 176 onward | Panel records, followed by optional 80-byte glyph records |

Each 80-byte panel holds twelve 32-bit fields: side (0 item, 1 weapon), signed item
ID (-1 empty), x/y, original RPK icon index, flags, quantity, maximum, card level,
magazine quantity/capacity and burst count (0 or 3), followed by a zero-terminated
32-byte ASCII display name. Coordinates use the 320x224 UI canvas. Flags are
1 disabled, 2 frozen, 4 quantity/max counter, 8 card level, 16 timer, 32 dim icon,
64 selection highlight and 128 magazine replacing the name label.

Description `kind` is 0 item / 1 weapon. Its position/extent and native KCB glyph
layout preserve localized text, symbols, spacing and formatting. A layout is sent
when revision, epoch or session changes; unchanged frames retain it. Inactive
frames clear visible panels/description without replaying stale state. The Godot
receiver validates the complete outer message and embedded description before
publishing it at FRAME.

The `inventory_state.gd` presentation dictionary has `epoch`, `active`, `panels`,
`shape` (-1 absent) and `description`. Panel dictionaries expose the fields above,
with x/y combined into `position`. Mod scenes receive `apply_native_state(state)`.
Original RPK sprites and fonts resolve locally, never through legacy draw packets
or assets copied into a distributable mod.

## Codec (minor 20)

Operation 22 requires capability 2097152 and scene/context/session/disc/cinematic
capabilities. The default or modded `ui.codec.scene` initializes before ownership
is advertised. Ownership remains active while the native world scene is hidden
for a conversation. Native input, audio, script callbacks, portrait animation,
contact selection and save actions retain their original update routines.
Conversation drawing and portrait VRAM operations are replaced. Minor 22 also
replaces game save/load screens through their separate ownership capability.

| Offset | Field |
| --- | --- |
| 0, 4 | uint32 schema 1 and native scene epoch |
| 8, 12 | uint32 changed-image mask (bits 0..3) and reserved zero |
| 16..31 | Public session ID |
| 32..95 | Sixteen uint32 view fields listed below |
| 96..159 | Two 32-byte portrait records |
| 160..191 | Eight uint32 visible contact frequencies; zero for an empty row |
| 192..319 | Existing 128-byte subtitle-layout header |
| 320 onward | Optional 80-byte glyph records, then changed 6656-byte images |

View fields are `active`, `incoming`, `mode`, `frequency`, `action`, `signal`,
`fade`, `scanline`, `wait_mark`, `exit_hint`, `memory`, `memory_top`,
`memory_selected`, `memory_count`, `memory_animation`, and reserved zero, in that
order. Coordinates use the 320x224 UI canvas. The frequency is an integer in
hundredths. Native mode also distinguishes save transitions so retained gameplay
HUD controls are hidden throughout conversations and save screens.

Each portrait record contains signed x/y/width/height, uint32 previous-image
weight (0..128), signed bracket extent and scanline position, and uint32 visibility.
Images are left-current, left-previous, right-current, right-previous. Each image
contains a 64x96 indexed-byte plane followed by 256 little-endian 16-bit palette
entries. The visible portrait is 52x89. The first message of an epoch sends all
four images; subsequent messages send only changed images in ascending bit order.

Text kind 0 is dialogue and kind 1 is the contact-name layout. The publisher
snapshots the displayed layout before native input can regenerate a later page.
Session/epoch/revision changes resend retained glyph data. Godot validates the
entire message before publishing it at FRAME. Its `codec_state.gd` dictionary
exposes the view fields plus `faces`, `images`, `contacts` and `message` to
`apply_native_state(state)`. Original textures/fonts remain transient local
resources; mod packages contain authored Controls, scripts and custom assets.

## Options (minor 21)

Operation 23 requires capability 4194304 and scene/context/session/disc/cinematic
capabilities. The default or modded `ui.options.scene` initializes before ownership
is advertised. The native `option` actor retains input, staged settings, apply/exit,
audio and vibration behavior. Its four drawing groups and help-text uploads are
suppressed under ownership. Legacy continues to use its original drawing path.

| Offset | Field |
| --- | --- |
| 0, 4 | uint32 schema 1 and native scene epoch |
| 8, 12 | uint32 actor generation and semantic revision (zero without OPTIONS_ACTIONS) |
| 16..31 | Public session ID |
| 32..63 | Eight uint32 fields: active, selection, animation, vibration, test, controller row, controller type, reverse |
| 64..95 | Eight uint32 staged native option values (each 0 or 1) |
| 96, 100 | uint32 element count (0 or 57) and text count (0..31) |
| 104 onward | Element records followed by text records |

Each 32-byte element is a uint32 texture hash; signed x/y/width/height; and uint32
RGB, layer and blend. Coordinates use the 320x224 UI canvas. RGB bytes are native
red/green/blue, with 128 neutral. Layer 0 hides an element; layers 1..3 preserve
front-to-back ordering. Blend 0 is opaque/mix, 1 half, 2 additive, 3 subtractive,
4 quarter-additive. Texture hashes reference locally prepared `stage/option/*.p`
assets. Their stable indices and readable node names are in `options_layout.gd`:
27 main-page elements, four screen-adjustment elements, 17 controller elements and
nine selection-highlight elements. No GPU packet, VRAM address or original pixel
array is sent for this artwork.

Each text record starts with uint32 text index (0..30), followed by the existing
128-byte subtitle-layout header and any changed 80-byte glyph records. Text layouts
are retained per index; session, epoch, actor generation, revision or palette
changes resend their data. At most 4096 new glyphs are published per frame. Hidden
text and inactive Options frames disappear at FRAME; retained layouts are only
reused within their session/generation. The receiver validates the complete message
before changing visible state.

`options_state.gd` exposes the eight view fields, `values`, `elements` and `texts`
to `apply_native_state(state)`. Default controls preserve authored offsets, sizes,
visibility and custom textures. Native help layouts are runtime previews; offline
help-text selection is not implemented. This operation is the presentation view;
operation 28 provides direct actions. Renderer/display settings use the separate
editable Display panel and its shared launcher registry.

### Direct Options actions (minor 27)

Operation 28 follows the Options view and is a synchronous ordering barrier. Its
32-byte payload is schema 1, epoch, public session ID (16 bytes), action ID and
status (all other fields uint32). Statuses match Save actions: none 0, pending 1,
applied 2, stale 3, busy 4, invalid 5. After the transport button word the reply
contains eight uint32 values: schema 1, ID, epoch, actor generation, semantic
revision, kind, target, value. A no-op is schema 1 and seven zeroes. IDs strictly
increase; only one request may be outstanding. Foreign sessions and malformed
sequences fail explicitly; stale/unavailable actions return a recoverable status.

Kinds: select 1, set 2, activate 3, back 4. Main-page target IDs are captions 1,
language 2, sound 3, vibration 4, vibration test 5, screen adjustment 6, controller
8, exit 10. Set takes values 0/1 for targets 1..5: on/off, Japanese/English,
stereo/monaural, on/off, weak/strong respectively. Unsupported vibration modes
reject actions. Activate accepts 6, 8 or 10. On the Controller page, Select takes
row 0 (mapping), 1 (first person) or 2 (exit); Set takes target 0 with type 0..2
(A/B/C), or target 1 with normal/reverse 0/1. Back takes zero target/value. It leaves
a secondary page, or applies and exits the main menu. Opening/closing rejects input.

The native worker validates the semantic revision at receipt and consumption.
Transient animation/vibration pulse counters and per-frame drawing resets do not
invalidate a request; changing page, settings, supported hardware, actor or epoch
does. Applying uses the original setting/audio/vibration functions and menu
sounds, with no synthesized pad samples. Values are staged until apply/exit, just
as in the native menu; this does not add a separate configuration file or alter
native save persistence.

`visual_api.get_options_actions()` returns a provider with `get_snapshot()`,
`request(action, target=0, value=0)`, `is_pending()`, `capture_input(active)`,
`captures_input()`, `state_changed(state)` and `action_finished(id,error)`.
Request returns its ID or zero with `last_error`; completion is emitted at FRAME
after the corresponding view is current. An optional UI-root
`connect_provider(provider)` binds custom Controls. The default scene captures
input while active, releases on close and suspends behind the Display panel.
Older authored scenes without that method retain the existing native pad path.

## PC save/load (minor 22)

Operation 24 requires capability 8388608 and scene/context/session/disc/cinematic
capabilities. `ui.save_load.scene` initializes before ownership is advertised.
The native game-save worker retains file I/O, checksums, overwrite handling and
restoring gameplay. A flat-list controller maps opaque save IDs or New Save to
the original private storage/file requests. Physical storage capacity is unchanged.
Photo and album file families retain their existing path. Legacy is unchanged.

| Offset | Field |
| --- | --- |
| 0, 4 | uint32 schema 1 and native scene epoch |
| 8..23 | Public session ID |
| 24..67 | Eleven uint32 fields: active, generation, revision, loading, state, message, count, selected_id, can_create, cursor, choice |
| 68 onward | `count` records, each 96 bytes |

Each record starts with eight uint32 fields: id, hours, minutes, disc, difficulty,
completion, area and metadata_valid. The final 64 bytes contain a NUL-terminated
ASCII display location decoded from native KCB menu text. Neither storage indices
nor filenames cross the bridge. IDs survive enumeration reorder within a generation;
native target resolution checks generation/revision and current list membership.
State values are browse 0, checking 1, confirmation 2, busy 3 and result 4.
Choice 1 is the default cancellation choice. Cursor indexes the flat list, with
New Save after its final entry when available. Loading never offers New Save.

`save_state.gd` validates the complete session/epoch-bound message before publishing
at FRAME. Default editable Controls retain original menu fonts and colors through
local references. Direct actions below drive the default interactive buttons;
previously authored UI copies without an action binding retain native navigation.

### Direct save/load actions (minor 26)

Operation 27 follows the save view and is a synchronous ordering barrier. Native
sends schema 1 and epoch (two uint32), public session ID (16 bytes), then uint32
action ID and status. Initial ID/status are zero. Statuses: pending 1, applied 2,
stale 3, busy 4, invalid 5. Applied means accepted by the native worker, not completed
file I/O; operation 24 must reach RESULT to establish the result of saving/loading.

After the usual button word, Godot replies with ten uint32 values:
schema 1, action ID, epoch, catalog generation, revision, expected state, expected
message, expected selected_id, action kind, target ID. A no-op is schema 1 followed
by nine zeroes. IDs strictly increase within the session and only one action may
be pending. Malformed replies/sequence violations fail the session; stale or
unavailable user actions return a nonfatal status. Native validates catalog and
dialog identity both on receipt and immediately before consumption.

Kinds are select 1, activate 2, new_save 3, confirm 4, back 5, continue 6. Select
accepts a stable entry ID or zero for New Save if available. Activate requires an
entry ID. Other kinds take no target. Confirm is only valid in CONFIRM; continue
only in RESULT. Checking/busy states reject actions. Activation of an existing
save still opens the native overwrite prompt; no combined overwrite bypass exists.

`get_save_actions()` on the visual API returns the Godot provider. It exposes
`get_snapshot()`, `request(action, target_id = 0)` (ID or zero plus `last_error`),
`is_pending()`, `capture_input(active)`, `captures_input()`, `state_changed(state)`
and `action_finished(id, error)`. Completion signals occur at FRAME after its save
snapshot is visible. Closing the native dialog releases capture. The display menu
suspends save interaction while it owns focus. Capture does not replace native
save-worker timing or the existing native pause state.

## Title and new game (minor 23)

Operation 25 requires capability 16777216 and scene/context/session/disc/cinematic
capabilities. `ui.title.scene` and its local artwork initialize before ownership
is advertised. The recovered `open` actor retains navigation, sounds, animation
timing, difficulty selection, native storage checks and game-start callbacks.
Its four drawing groups and help-text VRAM uploads are suppressed under ownership;
Legacy keeps its original drawing path. The separate animated Metal Gear logo
actor and other front-end actors are not covered by this capability.

| Offset | Field |
| --- | --- |
| 0, 4 | uint32 schema 1 and native scene epoch |
| 8, 12 | uint32 actor generation and reserved zero |
| 16..31 | Public session ID |
| 32..63 | Eight uint32 fields: active, mode, selection, difficulty, extreme, storage choice, storage A status, storage B status |
| 64, 68 | uint32 element count (0 or 55) and text count (0..24) |
| 72 onward | Element records followed by text records |

Mode retains the native actor state (0..21); difficulty 0..4 maps Very Easy
through Extreme. Selection is 0..5, extreme and storage choice are 0/1.
Storage status values drive the original title warning: both slot statuses,
the original question, Yes/No selection and native help text. The PC Save/Load
list is a separate UI slot. Active is false when this actor has
no visible elements or labels. Inactive messages contain no elements or texts.

Each 52-byte element holds a uint32 texture hash; signed x/y/width/height;
signed source-crop x/y/width/height; and uint32 top RGB, bottom RGB, layer and
blend. Positions use the 320x224 canvas. Rectangle animation may produce zero or
negative dimensions; absolute sizes are bounded to 2048 and positions to 4096.
Crop positions are 0..255 and dimensions 1..256. Layer 0 hides the element;
1..7 preserve native ordering. RGB uses red/green/blue bytes with 128 neutral;
the two colors define a vertical gradient. Blend has the same 0..4 meanings
as Options. `title_layout.gd` identifies the 55 elements and allowed local
`stage/title/*.p` texture hashes. Texture switching and cropping preserve native
background animation and portrait blinking without sending GPU packets.

Each text record starts with uint32 index (0..23), then the existing 128-byte
subtitle-layout header and changed 80-byte glyph records. Title and Options
share the bounded retained-text writer. Session, epoch, actor generation,
revision and palette changes resend layouts; at most 4096 changed glyphs are
published per frame. `title_state.gd` validates the entire message before
committing retained text, then presents it at FRAME. Stale epochs are hidden.

The presentation dictionary exposes the eight fields (`storage_a`/`storage_b`),
epoch, generation, elements and texts to `apply_native_state(state)`. Original
artwork/fonts are local references and detached from authored scene exports.
Native input remains authoritative; explicit custom-button actions are separate
work. This capability does not claim migration of every title-adjacent screen.

## Live display control (minor 24)

Operation 26 requires capability 33554432, scene meshes and public session identity.
It is session scoped, not tied to a map epoch. `Main` sends it before each
`GV_ExecActorSystem`, after the preceding work has completed. Godot flushes pending
draw commands before handling the barrier. No actor/culling update runs between
a requested projection change and its acknowledgement.

| Offset | Native state field |
| --- | --- |
| 0 | uint32 schema 1 |
| 4 | Last acknowledged request ID, initially zero |
| 8 | Last result: 0 accepted, 1 rejected |
| 12 | Live projection supported, 0/1 |
| 16..31 | Public session ID |
| 32, 36 | Applied output width, height |
| 40 | Widescreen enabled, 0/1 |
| 44 | Current frame requires original canvas, 0/1 |

After the standard button word, the reply contains five uint32 values: schema 1,
request ID, width, height and widescreen. A no-op has ID/width/height/widescreen all
zero. Other IDs strictly increase. Native rejects invalid dimensions/aspects
without changing the configured projection. It immediately sends the resulting
state again, allowing Godot to commit prepared buffers or request restoration
before releasing this actor boundary. At most four exchanges may occur at one
boundary; invalid identities or an unsettled transaction terminate explicitly.

Supported extents match the settings registry: width 320..2560, height 240..1920
in original aspect or 240..1792 in widescreen; widescreen ratios are 4:3..4:1.
Returning to original aspect clears the presentation override and culling ratio.
Codec/movie/menu rendering remains on its original canvas. Fullscreen belongs to
the visible Godot window and is verified there, not reported as a native window
property. See [the settings contract](SETTINGS_CONTRACT.md) for the prepare,
commit, timed confirmation, persistence reconciliation and rollback API.

### Direct title actions (minor 28)

Capability `536870912` adds operation 29; it requires TITLE, INPUT_CAPTURE and
scene/context/session/disc/cinematic capabilities. The current pair offers/selects
`0x7fffffff`. Native's previous required set remains `0x1fffffff`; title actions
are additionally negotiated. Operation 25's reserved word at byte 12 becomes the
semantic revision when actions are supported. Zero means input is unavailable
(opening/closing or an unsupported title subpage); the packet stays 72 bytes.

Operation 29 follows the title view and uses the same 32-byte schema/epoch/session/
action-id/status acknowledgement as other menu actions. Reply: seven uint32s,
`schema=1, id, epoch, generation, revision, kind, target`. A no-op is schema 1 and
six zeroes. IDs increase, with one outstanding action. Kind is select1, activate2,
back3. Native checks identity and availability both on receipt and consumption.

Modes0/1 accept activate target0 to skip branding using the original native branch.
Modes4/5/6 accept activate target0 (Start); mode7 accepts main targets0..4
(New Game, Load, Options, Briefing, Special); mode21 targets0..4 correspond to
Very Easy through Extreme, with Extreme guarded by the native unlock. Modes18/19
accept target0 Continue or1 Cancel at the storage warning. Back target0 is valid
in modes7/18/19/21. Native owns all transitions, sounds, memory checks and new-game
procedures. Special subpage13 retains native input and has no direct actions yet.
Default authored title Buttons use `get_title_actions()`. A relocated UI ZIP has
passed mouse/controller-driven branding skip, main selection, Options/Title return,
difficulty selection, Back and New Game into a loaded, rendered `d00a` scene.
Native/client tests cover stale identities, locked Extreme, unavailable pages and
in-flight requests. Special subpage actions and physical-controller acceptance
remain separate work.

### Direct Codec actions (minor 29)

Capability `1073741824` adds operation 30, requiring CODEC, INPUT_CAPTURE and
scene/context/session/disc/cinematic capabilities. Operation 22's artwork and
portrait payload is unchanged. Operation 30 carries the following 68-byte view:

| Offset | Field |
| --- | --- |
| 0, 4 | uint32 schema=1, epoch |
| 8 | 16-byte public session ID |
| 24, 28 | uint32 action ID, status (none0, pending1, applied2, stale3, busy4, invalid5) |
| 32, 36 | uint32 generation, semantic revision |
| 40, 44, 48 | uint32 active, opened, native mode |
| 52, 56 | uint32 frequency (14000–14199), allowed-action bitmask |
| 60, 64 | uint32 selection, entry count (contacts or dialogue choices) |

The reply is seven uint32s: `schema=1, id, epoch, generation, revision, kind, target`.
A no-op has schema1 and six zeroes. IDs increase with one outstanding request.
Native checks availability and identity on both receipt and consumption. Revision
also tracks the native dialogue item, so an advance queued for one line cannot
affect another. No script pointer is sent to Godot. Results and view changes become
visible to Controls only at the following FRAME.

| Kind | Target and availability |
| --- | --- |
| 1 open | Target0; native gameplay guards permit opening |
| 2 tune | Absolute frequency14000–14199, e.g.14085; idle tuning mode1 |
| 3 call | Target0; call current frequency in mode1 |
| 4 memory | Target0; open contacts from mode1 |
| 5 select | Absolute entry index; contacts mode10 or choices mode16 |
| 6 confirm | Absolute entry index; call contact or commit dialogue choice |
| 7 advance | Target0; native waiting line mode4 or completed No Response mode9 |
| 8 skip | Target0; native voice mode5 only when its script permits skipping |
| 9 back | Target0; leave idle tuning or return from contacts |

Bit `1 << kind` in `allowed` is authoritative. Transition timers, incoming calls,
unskippable voice and contacts opening/closing can temporarily remove actions.
`active` means the provider is usable, including closed gameplay; only `opened`
means Codec is modal. Default Controls capture while opened, except native save
modes12/14, where Save/Load owns input. Native owns voice, script results, callbacks,
sounds and timing. Commands enter its existing branches without synthesizing pad
events. An authored UI without the new provider keeps native input handling.

Client/native/wire checks cover stale identities, bounds, locked skip, single
flight, prompt routing and Save/Load input ownership. A relocated original-free UI
ZIP passed live tuning, contacts select/back/call, a manual Campbell call, permitted
skip/advance and return to advancing gameplay. Physical controller parity, held
direction repeat and full campaign interaction review remain M5.12 work.

### Direct inventory actions (minor 30)

Capability `2147483648` adds operation 31, requiring INVENTORY, INPUT_CAPTURE and
scene/context/session/disc/cinematic capabilities. Operation 21's artwork payload
is unchanged. The action view has a fixed size of 652 bytes:

| Offset | Field |
| --- | --- |
| 0, 4 | uint32 schema=1, epoch |
| 8 | 16-byte public session ID |
| 24, 28 | uint32 action ID, status (none0, pending1, applied2, stale3, busy4, invalid5) |
| 32, 36 | uint32 menu generation, semantic revision |
| 40, 44, 48 | uint32 active, mode (closed0, items1, weapons2), owned by Godot |
| 52, 56, 60 | uint32 open-side mask, allowed-action mask, entry count (0–36) |
| 64, 68, 72 | int32 selected ID, equipped item ID, equipped weapon ID |
| 76 | 36 entries of16 bytes each: uint32 side, int32 ID, int32 quantity, uint32 flags |

Entry sides are items0 and weapons1. IDs are native item0–23 or weapon0–9;
`-1` means None. Flags are equippable1 and usable2. Quantity is native inventory
data (including the card level for the card entry), not a generic permission to
consume. Unused entry slots are zero. The open-side mask uses `1 << side`, while
the allowed-action mask uses `1 << kind`. `active` means commands may be served,
including closed gameplay; it does not mean an inventory is open.

The reply is eight words: `schema=1, id, epoch, generation, revision, kind, side,
target`. Only target is signed. A no-op has schema1 and seven zeroes. Action IDs
increase with one outstanding request. Native validates the current view on both
receipt and consumption; state changes, depletion and menu lifecycle changes can
reject a previously valid request. Views and acknowledgements become visible to
Controls at the following FRAME.

| Kind | Target and availability |
| --- | --- |
| 1 open | Target0; side must be permitted by open_mask and both inventories closed |
| 2 select | Native ID on the open side; owned but disabled entries can still be inspected |
| 3 equip | Native ID with equippable flag on the open side; selects it and starts native close |
| 4 use | Currently selected usable item ID, side0; original consumption checks apply |
| 5 close | Target0; starts native close with the current selection |

Closing commits the selection, including None, following the original inventory
behavior. It does not restore the previously equipped item. Ration freezing/full
health, posture, player/menu guards and item/weapon disable rules remain native.
No command changes native pad samples or writes gameplay inventory directly.

An accepted Godot action sets `owned`. Default Controls then capture input and keep
the menu open until equip/close. Opening by the original held L2/R2 buttons keeps
`owned=0` and native input, including release-to-close. Explicit mouse or scripted
actions can take over that open menu. Closing releases capture with the shared
input-release barrier. Menu destruction invalidates pending actions and advances
the next generation; clearing a drawing frame does not cancel a pending command.
