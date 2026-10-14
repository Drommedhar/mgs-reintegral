# Godot presentation coverage inventory

Recorded 12 October 2026 for M0.04–M0.06 of the [execution ledger](GODOT_SDK_PROGRESS.md). Resource presence, import preparation, source tracing and executed presentation acceptance are separate states.

The generated content inventory below was refreshed on 13 October against both prepared campaign catalogs. The producer tables preserve the initial audit baseline; later implementation evidence is recorded in the ledger and the dated updates at the end of this document.

## Content boundary

The [generated inventory](data/godot_presentation_coverage.json) contains all 92 configured stage names, 95 entries on each Integral campaign disc and script fingerprints. Both discs contain all 92 configured names. The three additional entries per disc are the resident sets `init`, `init_tux`, `init_ve`. Identical stage names on different discs are separate content identities; neither matching names nor prepared resources prove an identical playable scenario.

Both prepared catalogs now cover all 95 resource entries on their respective discs: **190 catalogued entries**, up from the initial ten disc-1 entries. Disc identities, source image hashes and STAGE.DIR hashes are validated independently. None is labelled complete-presentation acceptance; conditional scene assembly, category coverage and human playability remain separate requirements.

```powershell
& .\.venv\Scripts\python.exe -m tools.audit_godot_presentation --catalog .local/godot-content/catalog.json --catalog .local/godot-content-disc2/catalog.json --output docs/data/godot_presentation_coverage.json
```

The tool verifies serials, prepared `STAGE.DIR` hashes and catalog provenance. It rejects cross-disc asset IDs. It writes names, resource counts, sizes and fingerprints, never original resource bytes. Its synthetic tests are registered as CTest `godot_presentation_inventory`.

| Scenario/variant class | Current evidence | Required follow-up |
| --- | --- | --- |
| Configured stage entry | Enumerated on both discs; scripts fingerprinted | Compile/launch/visual checks remain separate |
| `d00a` opening and `d01a` cinematic set | Prepared; current overlay aliases use `s00a` / `s01a` | Explicit scenario/content relationships, not a general alias rule |
| `s00a` dock gameplay | Modded boot and movement probe; partial Godot rendering | Dynamic declarations, native attachments and full visual ownership |
| Title/front-end/resident sets | Resources enumerated; title observed in intro probe | Editable Godot UI and complete transitions |
| Conditional script branches | **Unresolved**, not assumed simultaneous actors | Provenance-aware declaration/control-flow inventory |
| Other cinematic-only clips/sets | Receipt-checked inventory: 79 disc-1 and 40 disc-2 clips; track/resource identities and motion summaries | Clip-to-script/scenario activation remains unclassified |
| Disc changes and same-name content on disc 2 | Both catalogs prepared under separate disc identities; runtime supports both | Actual mid-session disc-change and scenario transition checks |

M0.04's content enumeration is complete. Variant classification remains open; the table explicitly preserves those gaps rather than treating all 190 resource entries as supported scenes.

## Native producer / current consumer map

Paths below are source owners to resume from. “Partial” means a semantic world path exists but does not eliminate every legacy contribution. This initial matrix is not an exhaustive audit of every stage overlay.

| Category | Native producer / boundary | Current Godot consumer | Coverage / migration concern |
| --- | --- | --- | --- |
| Static and animated models | `game/object.c`, `libdg`, `src/mgs_godot_scene.c` | `scene_view.gd`, `model_contract.gd`, reference materials | Partial; instance IDs lack authored actor/lifetime identity |
| Native actor motion/visibility | Actor modules such as `takabe/elevator.c`; `DG_OBJS` transforms | Scene snapshots and replacement meshes | No generic named-anchor/state/event contract |
| UV, palette and runtime textures | Object packets, texture uploads and VRAM addressing; scene/world bridge | Reference shaders, `renderer.gd` | Mixed semantic/command paths; complete dynamic-texture inventory open |
| Particles, bubbles, breath, water/ripples | `takabe/ripple.c`, `ripples.c`, other effect actors; `src/mgs_godot_effects.c` | World effect meshes/materials and command fallback | FT4/GT4 support is partial; camera/sort-only, subtractive and framebuffer cases need classification |
| Lighting and emissive effects | `src/mgs_godot_lights.c`, native light/effect producers | `map_lights.gd`, `event_lights.gd` | Existing light adapters; complete producer/anchor coverage open |
| Fades, flashes, vision, framebuffer feedback | Effect/equipment actors; `takabe/fadeio.c`; original ordering table | `renderer.gd`, world composition and shader feedback | Legacy primitive contribution still present |
| Video/movie presentation | `game/movie.c`, `libfs/movie.c` | Upload/draw command image path | No public semantic decoder/placement contract |
| Gameplay/cinematic camera | `game` camera logic; `kojo/demoexec.c`, `demoscrn.c` | Scene camera snapshot | Native-clock tracks and editable ownership missing; submission still tied to original camera |
| HUD/radar/life/subtitles/inventory | `menu/menuman.c`, `radar.c`, `life.c`, `jimaku.c`, `item.c`, `weapon.c` | Original primitive/VRAM drawing | Native state and drawing are coupled; see source notes |
| Codec/dialogue | `menu/radio.c`, `radiomes.c`, radio face/animation/texture modules | Original drawing and local textures | Editable Control view models/actions missing |
| Save/load/disc/system screens | `menu/datasave.c`, `mload.c`, native card/disc providers | Original UI path | Detailed action and error-state audit open |
| Title/difficulty, briefing, photo album, ranking/credits | `stage/title.c`, selection code, `overlays/brf`, `overlays/rank`, ending actors | Original UI path | Exact per-screen owner inventory still open |
| Photo camera / readback | `equip/jpegcam.c` calls `StoreImage`; bridge READ request | `renderer.gd` readback of command-rendered image | Must explicitly read the final Godot-owned image |

Godot script paths are relative to `renderers/godot/project/`; game paths are relative to `vendor/mgs/source/`. The transport is `renderers/godot/native/transport.c`. Its current [protocol v15.5](GODOT_PROTOCOL.md) supports DRAW/UPLOAD/MOVE/READ/SYNC/FRAME/SCENE/WORLD; it is not the planned renderer-neutral presentation protocol.

## Visibility and ownership risks

- Current scene state uses `DG_OBJS` / per-part matrices, not a complete actor graph. Runtime IDs are monotonic within the process and associated with object addresses; the SCENE packet has no authored declaration identity. Protocol 15.1 now precedes it with connection-local clock/resource-generation context; that does not yet establish complete actor lifetimes or scenario identity.
- Group visibility, hidden state, part bounds and original camera-derived transforms still matter. Publishing off-camera shadow casters does not prove arbitrary authored camera coverage. Trace libdg visibility and `DG_OBJ.screen` before removing filters.
- `src/mgs_godot_world.c` inserts world markers into ordering buckets. The final image still depends on original composition order, depth/mask semantics and remaining primitives. “Rendered in Godot” does not mean “no legacy visuals.”
- `visual_mod_api.gd` v1 now exposes the initial elevator binding, camera registration, thermal sources and inventory/Codec/title/options/save/settings actions. General actor providers, ordered events and reconnect/full-state resync remain implementation gaps.
- Do not disable menu callbacks as though they only draw: they mutate inventory, pauses and damage display state. [Native source notes](GODOT_NATIVE_BINDING_NOTES.md) record concrete examples.

M0.05 remains open until the matrix is extended to the exact remaining screen/effect owners and readback callers. M0.06 source evidence now identifies the attached platform railing; live binding acceptance remains M2 work.

## Readback and resource-copy audit

Source inspection on 12 October searched all `vendor/mgs/source` C files for direct `StoreImage`, `StoreImage2`, `MoveImage` and `MoveImage2` calls. This found 14 call sites in seven files. This scope does not prove absence of indirect calls or host/library uses.

| Native owner | Calls | Meaning | Required semantic replacement |
| --- | --- | --- | --- |
| `equip/jpegcam.c:492`, `JpegCompressFrame` | 1 StoreImage | Rendered photograph, read in 16×16 tiles; source rectangle `(16,16,288,176)`; encoder may retry with different quantization | Freeze one identified final Godot scene sample; resample/crop to native photo dimensions and XBGR1555 encoding; serve all tiles/retries from that sample |
| `menu/radiotex.c:31` and `:32` | 2 StoreImage | Save palette `(768,256,256,4)` and portrait texture `(896,336,64,96)` before Codec changes, later restored by LoadImage | Preserve texture/palette resource bytes and revisions, not a screen screenshot |
| `menu/radiotex.c:88` and `:94` | 2 MoveImage | Copy portrait palette/image regions | Revisioned texture-region copies; preserve ordering before face rendering |
| `takabe/palette.c:20`, `:32`, `:68` | 3 StoreImage/StoreImage2 | Palette storage and effect conversion | Native palette data/readback or equivalent semantic palette updates |
| `takabe/goggle.c:80`, `goggleir.c:93` | 2 StoreImage2 | Night/infrared palette conversion loops | Preserve native effect state and palette semantics while rendering editable Godot vision effects |
| `takabe/sepia.c:68`, `:199` | 2 StoreImage2 | Sepia palette conversion loops | Palette resource access; not final-image reads |
| `libdg/palette.c:14`, `:19` | 2 MoveImage | Palette swap/copy | Ordered resource copies |

Current `renderer.gd::execute` operation 5 accepts a VRAM rectangle and calls `read_region`. It carries no semantic distinction between a photograph and palette data. Do not globally redirect it to the final viewport. The semantic bridge needs separate resource access and final-image capture; retaining original texture data locally does not require retaining legacy raster visuals.

For the photo provider, confirm the exact native capture point and HUD exclusion before implementation. A frame/sample token and one immutable converted image avoid a different frame for each tile, repeated GPU stalls, or different images across compression retries. Native JPEG/card formatting stays authoritative.

## Additional screen owners and side effects

- Title/difficulty: `stage/title.c` registers `CHARA_OPEN` (`0xcf79`), implemented by `onoda/open/open.c::NewOpen` / `Act`. That implementation also references the `sp_album` menu entry; menu entry presence alone does not prove the album's complete drawing owner.
- Stage selection: `stage/select.c` registers `CHARA_STAGESELECT` (`0xd2f6`), resolved to `game/select.c::NewSelect`. Do not confuse this with title/difficulty or VR selection.
- Ranking: `stage/rank.c` registers `NewRanking` (`0x04f2`), implemented in `overlays/rank/onoda/rank/rank.c`. `DrawFadeOut` executes `GCL_ExecProc(work->time_proc)` and destroys the actor after its timer; stripping this draw-named function would prevent progression. `Act` also increments native time and dispatches save-dialog state.
- Save/load: `menu/mload.c` calls `MENU_SetLoad` with mode 1/2. Its save actor resets `gTotalFrameTime` until `GM_LoadRequest`; that lifecycle must survive UI replacement. `menu/datasave.c` remains the detailed card-dialog owner to split into state/actions and Controls.
- Briefing: `overlays/brf/onoda/brf/select_state.c`, `select_draw.c`, `graph_control.c`, `graph_render.c` separate useful source responsibilities. Scene-script scheduling still needs mapping.
- Ending roll: `CHARA_ENDINGROLL` (`0xb789`) resolves to `takabe/ending2.c::NewEndingRoll`; ranking is a separate actor.
- Movies: `game/movie.c` decodes into `dctout` and uploads via LoadImage; native timing, PAD_CROSS handling, end procedure and `MgsVideoMovie` lifecycle remain native. A semantic frame/placement provider replaces image presentation, not completion/audio control.

## Off-axis camera boundary

`src/mgs_godot_scene.c` publishes every queued object's parts but derives poses from `DG_OBJ.screen` (local-to-view), including a 64/58 row correction. Active parts receive shadow eligibility; visible eligibility additionally requires both object and part `bound_mode`. Current camera-frustum visibility is therefore still encoded in the scene packet. The new bridge must publish authoritative world poses and distinguish gameplay visibility from camera culling. Removing the bounds condition alone does not establish correct world transforms or valid dynamic face packets.

Next source checks: album/disc-error ownership, stage-specific framebuffer/texture effects and script-to-clip activation. This audit advances M0.05 but does not close it.

## Camera visibility audit, 13 October 2026

M4.02a/b retain active owned model packets outside the native camera in both the standard and fog pipelines. Hidden objects and inactive map groups remain excluded. Native bounds are preserved for gameplay. Both pipelines rebuild temporary connected-part color references before shading retained packets; otherwise the indirect shader can interpret the previous frame's RGB value as a pointer. Standard/fog thermal palette updates also follow retained objects. These changes do not establish complete scene or emitter coverage.

The initial disc-2 `s12c` smoke run reached 900 VSyncs after fixing that indirect-shading fault, but reported zero world composites. The subsequent fog-composition slice below resolves world-marker insertion. Material/visibility checks, native boot and rendered-image evidence remain distinct.

| Native view-dependent check | What it controls | Required treatment |
| --- | --- | --- |
| `okajima/wolf/unknown.c` point/bounds checks | Scope aiming, combat timers, action state and sound | Preserve native checks; do not bypass whole branches for an edited camera |
| `okajima/dog/dog.c` bounds/round-robin selection | AI, targeting, attacks, timers, movement and sound | Preserve native scheduling; any extra pose interpolation belongs to presentation |
| `okajima/mouse.c` bounds check | Random-number consumption and mouse sound | Preserve; changing the check also changes native RNG progression |
| `okajima/chafgrnd.c::Act` point checks | Particle respawn around the native view with random draws; TILE-based drawing | Native chaff timing/state stays native; a Godot emitter needs its own presentation implementation |
| `enemy/action.c` and related guard action code | Immediate rotation versus smoothing, vision direction | Preserve AI semantics |
| `enemy/think.c` bounds checks | Offscreen relocation to navigation zones | Preserve native movement decisions |
| `game/item.c` offscreen early return | Spin/bounce updates plus pickup processing below the return | Do not bypass the whole return; extra visual animation needs separate state |
| `overlays/s15c/okajima/valcan/crow.c` bounds/selection | Full actor state machine, attacks, random destinations and collision | Preserve native cadence |
| `enemy/camera.c::CameraAct_800D5F64` light-matrix gate | Material lighting after unconditional control/object updates | Pure presentation candidate; still open |

These are inspected source findings, not human acceptance of the corresponding encounters. Remaining M4.02 work includes unsupported primitive families, view-dependent emitter creation and mutated model topology. The broader M0.05 producer audit remains open.

## Fog composition and queued-world audit, 13 October 2026

`FogSortChanl_800D4E98` now inserts the same world markers as the standard sorter and skips individual Godot-owned effect faces plus replaced native blob shadows/glows. Unowned content retains its original fog sorting and coloring. Paired Legacy/Godot tests execute the actual sorter with the production world-marker implementation, including mixed-owned faces, native meshes, pause, both buffers, distance rejection and hidden/inactive groups.

`MGS_GODOT_WORLD_AUDIT=log` reports queued mesh-group/effect-face ownership and the remaining primitive-type bitmask; `strict` fails on compatibility content. Counts include off-camera eligible queues, not only visible pixels. The disabled default does no queue scanning. UI, video, other channels and custom sorters are outside this audit, so zero world compatibility counts alone cannot close full-image ownership.

The loaded disc-2 `s12c` run reaches 900 VSyncs with **12,422 world composites**, empty renderer stderr and a visually inspected snowy-world image. Its audit reports **217 Godot mesh groups, one compatibility mesh group and 104/106 compatibility effect faces** in sampled frames. Remaining primitive mask `0x00040200` identifies TILE and FT4 families; producer attribution remains open. `stage/s12c.c` registers snow from `thing/snow.c`, whose rectangular TILE groups are a concrete next source owner. Preserve native random-number consumption and simulation when migrating their presentation.

Evidence lives under `build/godot-sdk-m0/`: `fog-composition-host.log`, `fog-composition-run/godot.log`, `fog-composition.png`, `fog-composition-world.png`, `fog-composition-ctest-final.log` (16 passing checks), and the world-effects/depth-composition GPU logs. This proves native-view world composition; authored off-axis fog views, environment parity, full campaign coverage and 1440p frame pacing are still unverified.

## World snow migration, 13 October 2026

`thing/snow.c` now registers its native TILE groups for Godot's semantic effect batch. Positions, packet dimensions/colors, native wind and RNG remain authoritative; Godot owns drawing, fog, lighting and occlusion. The built-in snow material requires no retail texture. Pixel-sized billboards use the final camera's depth/projection, keeping size stable across depth, FOV and aspect changes. Native camera-relative spawning and editor material customization remain open.

The matching live s12c run now reports **96 fewer compatibility faces**: only **8/10 FT4 faces** and one mesh group remain, mask `0x00040000`. No TILE content remains in that world's compatibility queues. Sampled frame-900 world passes fell 48 to 12 and copied bytes 132.9 to 33.3 MiB. This reduces composition work but does not establish 60 FPS frame pacing. Evidence: `world-snow-host.log`, `world-snow-run/`, inspected `world-snow.png`, native `snow-ctest.log`, GPU `snow-effects-final.log` and `snow-depth.log` under `build/godot-sdk-m0/`. Footprint sources `enemy/asiato.c` and `asiato2.c` allocate subtractive FT4 and are the next source candidates; exact attribution is still required.


## 13 October: scripted world surfaces

Texture-lamp actors now use semantic emissive Godot surfaces with native texture-frame changes and one/two-sided visibility. The runtime null-texture contract matches prepared empty surfaces; a null face no longer sends a whole dog part to legacy rendering. Live s12c queues report zero compatibility meshes/effect faces (218 mesh groups, 104+ effect faces owned). Protocol 15.10 and detailed attribution diagnostics are documented in the protocol/modding guides. The loaded view, 16 native checks and GPU emission/fog/occlusion tests pass; UI, other channels, editor effect customization, other campaign scenarios and 1440p pacing remain open. Exact evidence is in M4.03c of the execution ledger.


## 13 October: authored camera ownership and fog-stage proof

Mods can register ordinary perspective Camera3D nodes with gameplay, exact-clip or stage-wide scope. Native world poses remain unchanged; the selected camera controls rendering, metadata and fog background, and ownership changes reset temporal history. An exported/reopened original-free mod ran s12c with a shifted, rotated 100-degree view; the inspected image includes retained scenery, lamps, snow and fog. Lifecycle, coordinate, ZIP and GPU history/effect/depth checks pass. This is bounded workflow evidence, not exhaustive off-axis visibility, custom native-time AnimationPlayer support, full campaign image ownership or 1440p cadence acceptance. See M6.07a / M6.08c in the execution ledger for exact artifacts and diagnostic limitations.


## 13 October: editable world-effect materials

Registered world effects now have a ShaderMaterial override path keyed by complete original texture identity; snow uses `mgs/effects/snow`. Editor resource creation, material/PNG export and reopening, runtime dependency loading without import caches and matching color/depth alpha were verified. An exported mod changed snow and two scripted lamp targets in live s12c while retaining native emission/lifetime. This does not migrate additional compatibility producers or provide per-emitter particle scenes, simulation editing or complete effect previews. M4.03d in the execution ledger records artifacts and limits; the modding guide documents the workflow.


## 13 October: semantic optical camouflage

Native optical-camouflage constructors and transitions now publish per-instance kind, amount and tint through protocol 15.11. Godot renders editable scene refraction and restores ordinary materials on removal/thermal switching; Legacy packet behavior is preserved. Original-free material ZIP export/reopening, paired native lifecycle tests, GPU native-resolution/FSR2 checks and a live equipment-menu run pass. Thermal/night-vision rendering itself, per-character targeting, original vertical-wipe parity and full campaign/cadence acceptance remain open. See M4.04a in the execution ledger and Optical camouflage material in the modding guide.

## 13 October: native vision state and editable night vision

Protocol 15.12 publishes native normal/night/thermal mode. The night-vision compositor filters Godot world color (including transparent effects) and the empty background, preserves depth/alpha and resets temporal history on mode changes. Inspector controls and the copied compute script export/reopen without original assets. The original night-vision screen mask is suppressed only when the Godot scene owns it; reference rendering, Legacy and thermal masks retain their paths. Native equipment and palette callbacks remain unchanged.

Paired native ownership/context checks, authoring/ZIP tests, native-resolution/FSR2 GPU checks, depth-composition regressions and a rebuilt 1800-VSync loaded dock movement smoke pass. The live run did not equip goggles; it verifies startup/integration, not live night-vision appearance. Thermal heat/visibility and first-person sight UI remain unmigrated. M4.04b/M4.04c in the execution ledger distinguish the implemented slice from this remaining work and full campaign/cadence acceptance.

## 13 October: thermal model heat and compositor

Protocol 15.13 negotiates thermal ownership. Existing instance flag `DG_FLAG_IRTEXTURE` drives a Godot heat pass for original/replacement model parts; ordinary mesh/skin/bone transforms and visibility are retained. The thermal compositor compares heat depth with scene depth, colors cold scenery and hot models independently, and filters the empty background. Custom meshes can register a normalized heat value through the visual API. An Inspector-editable resource and its scripts round-trip in an original-free ZIP.

Native mask ownership/flag serialization checks, GPU native-resolution/FSR2 checks (including skinning, motion, occlusion and restoration), authoring/ZIP tests and a loaded 1800-VSync dock smoke pass. The live run did not activate goggles. Thermal-only IR sensor beams still use `DG_PRIM_LINE_GT2` and are not migrated by this model pass; native sensor shade/visibility, mine visibility, palette callbacks and gameplay remain unchanged. Arbitrary custom shader deformation/discard and blend-shape matching in the heat pass, first-person sight UI, full campaign appearance and 1440p cadence remain open. M4.04c remains unchecked.


## 13 October: IR sensor beam presentation

Protocol 15.14 adds registered native line endpoints and reveal colors to the existing semantic effect path. The `ir_cens.c` actor retains native movement, thermal/cigarette reveal, interruption and alarm behavior. Godot renders editable camera-facing beam strips with matching color/depth/heat coverage. Width, tint, emission, custom texture and thermal heat are material parameters; ZIP relocation preserves authored values without retail artwork.

Paired actual-actor native tests and GPU native-resolution/FSR2 camera, clipping, occlusion, reveal and heat checks pass. A rebuilt s02c disc-1 startup run loaded successfully but did not spawn an active `lsight` batch or equip goggles; live beam/goggles appearance remains unverified. That world audit reports 97 Godot mesh groups, zero compatibility meshes, 36 Godot effect faces and five remaining compatibility faces. First-person sight UI is the next typed UI/Control slice. M4.04d is bounded implementation evidence, not full special-vision, campaign or pacing acceptance.
