# Intro transparency, transition audio and Godot loading

Status: implemented and delivered in SDK24; human retest pending
Date: 2026-10-14
Ledger tasks: M4.03h, M7.09a, M3.06e

## Requested outcomes and settled decisions

- Correct the flickering transparent presentation visible in full Godot but absent in Legacy through Godot.
- Preserve sounds across presentation waits unless original native code stops, fades or finishes them.
- Reduce actual in-game Godot scene-transition time without reducing authored visual quality or changing native gameplay/cinematic timing. User explicitly excludes startup asset checks from this optimization.
- Show a delayed lower-right outline animation during loading, following the latest presentation override below.

Q1 confirmed: only the existing integral emblem, gently pulsing in the lower-right of black loading screens at startup and subsequent scene changes. Show it after a short delay to avoid flashes, remove it as soon as loading completes, and add no text or progress bar. This supersedes the earlier startup-only/no-later-loading-UI decision for the game window. Existing launcher content preparation and actionable errors remain a separate workflow.

Q2 supplied: the right-hand wall map display behind the diagonal railing in the submarine intro. The user supplied a red-outlined screenshot showing SHADOW MOSES, BERING SEA, ALASKA and PACIFIC OCEAN. This identifies the affected surface; a still image does not establish the temporal failure mechanism. No new unmodded comparison has been claimed.

Q3 supplied: the sound cuts immediately after selecting difficulty to start a new game. Preserve original music and stream stops; specifically investigate the difficulty-confirmation sound tail.

Q4 confirmed: implement and validate all four changes. Later correction: optimize real scene loading, not startup asset verification. Startup checks remain unchanged; the accepted emblem still covers black startup and later loading screens.

Latest presentation override: the user replaced the integral emblem with an outline-only silhouette of the supplied Solid Snake pixel animation and explicitly requested credit to its original author. Source verified as Irbif (u/Irbif) at https://www.reddit.com/r/gaming/comments/p9725h/im_a_pixel_artist_i_made_this_animation_of_solid/. Use the original37 frames at100ms each, light outline with transparent interior/background, same delayed lower-right lifecycle. Preserve the original motion, including bandana and weapon changes. Credits ship in docs/THIRD_PARTY.md and licenses/loading-animation/NOTICE.txt. Generated image approximations were discarded once the original animation became available. No license grant is inferred from attribution.

## Source findings, not runtime acceptance

### Transparency

Full Godot and Legacy through Godot have different composition paths. Original transparent model color passes already disable depth writes and use a later depth companion (`reference_shader.gd`, `reference_materials.gd`, `reference_transparent_depth.gdshader`). Native effect quads are grouped by texture with one average depth per batch (`world_effects.gd:116-146`). Authored water/frost have separate policies and are not the supplied reproduction.

Inspect the submarine screen's prepared surface, native live texture producer and any overlapping geometry/overlay before choosing a correction. A global depth bias or transparent priority change is not supported by the evidence. Prior SDK22 live-texture checks do not establish that this newly reported flicker is fixed.

Narrow source trace identifies current prepared `opening/d82d.k`: `mesh_001` uses map texture `a5cc`, and `mesh_006` uses overlay `4f2b`. These surfaces and live `efaa`/`efab` text quads overlap on Z=-19 m. Original model flags imply ordering raises (-500, -1000 and 0) through `vendor/mgs/source/libdg/obj.c:8-17`, but `mesh_006` is an extension part and the bridge uses its owner's raise: these values are not proven runtime packet offsets. `src/mgs_godot_scene.c:295-310` publishes adjusted packet ordering, but the spatial color shaders leave the coplanar geometry in place; ordering metadata is consumed separately. Missing native layer ordering in spatial color is therefore a concrete hypothesis to test. Verify extension ownership and actual packet order in a focused fixture. Live text parts are recorded as opaque, so generic transparent-particle batching is not the demonstrated cause.

Retained visual evidence already includes this view: `build/godot-sdk-m0/submarine-texture-audit-20261014/submarine-production33-r2/capture-003000.png` and `submarine-legacy-reference-r3/screen-003000.png`, with adjacent 3002-3010 samples. These were inspected during this interview; no new capture ran. Start by comparing these samples and the specific coplanar layers, then prove a focused regression against the current renderer. Old diagnostic timings are not performance evidence.

### Audio

`src/mgs_loading.c:34-35,48-49` suppresses output at accelerated loading begin/end. `vendor/psyz/psyz/src/platform/sdl3_audio.c:305` pauses and clears the output stream at both toggles; suppressed generated samples are discarded. The user's current settings and recent normal launch enable fast loading.

Separately, `runtime.gd:665-683` waits for mod resources and synchronously updates the scene before continuing frame processing. Native transport blocks waiting for a frame reply. Native-thread audio production can therefore exhaust its buffer during a renderer wait. The full-Godot deterministic reserve is about 93 ms, insufficient for second-long loads.

Native stop commands remain authoritative. The difficulty menu plays `SE_MENU_SELECT` on confirmation (`vendor/mgs/source/onoda/open/open.c:1801-1822`). Its earlier music-stop path and `sng_off` affect music channels, separate from sound-effect voices (`sound/sd_ioset.c:141-159`). Thus the confirmation tail is a plausible victim of the host mute, despite nearby native `SongStop` log messages. Per-voice timing/waveform proof is still needed.

Do not merely remove mute calls, extend buffers indefinitely or move serviced SPU generation into an SDL callback. Backlog handling can drop audio, and serviced SPU interrupts can invoke native task scheduling. Accelerated native loading and renderer-only waiting need separate servicing/timing treatment.

### Loading

Latest inspected ordinary full-Godot startup: `C:/Users/domin/AppData/Local/RE-INTEGRAL/logs/godot-20261014-193553-579-startup.txt`: project 609 ms, import 0 ms, renderer 13,167 ms. Matching renderer log records parallel disc validation at 10,627 / 10,667 ms for 45,478 asset entries and 86,992 files total. These are existing session observations, not a controlled before/after experiment.

`prepared_catalog.gd` hashes every unique prepared file and checks dependency documents on each startup. This cost is outside the clarified task scope; leave startup verification unchanged.

`scene_resources.gd` already uses threaded mod resource loading. `scene_view.gd`, `model_contract.gd`, `reference_materials.gd` and `map_composition.gd` still perform synchronous original model parsing, texture decoding/mipmap creation, instantiation and composition. Existing original template/texture caches mean first visits and revisits differ. Measure these phases before selecting caches, local binary resources or incremental assembly. Retention/prefetch must have bounded memory use and must not run native gameplay ahead.

Godot documents that retrieving a threaded resource before completion can block, and active scene-tree work is not thread-safe. Use the pinned 4.8-dev7 build's actual APIs; do not assume every scene operation can move to a worker. References: [background loading](https://docs.godotengine.org/en/latest/tutorials/io/background_loading.html), [thread-safe APIs](https://docs.godotengine.org/en/latest/tutorials/performance/thread_safe_apis.html).

### Loading emblem (initial findings; superseded by the animation override)

The existing asset is `assets/branding/re-integral-logo.png`, also packaged in the Godot project. Reuse its integral mark with a texture region; no replacement artwork is needed.

`startup_screen.gd` currently contains full branding, text and progress and permanently hides on the first display-enabled command. A reusable loading lifecycle is required. Trigger the emblem from actual loading/preparation, not every black frame or cinematic fade. Animation follows presentation time and must remain responsive during loading work. Avoid adding a minimum display duration that delays readiness.

## Proposed implementation and acceptance

1. Identify and correct the submarine map display's actual layer/depth fault. Add a focused overlap/live-texture regression and compare the matching Legacy-through-Godot scene at relevant camera positions. Keep intended screen scanlines, map labels, transparency and railing occlusion.
2. Trace the difficulty-confirmation sound through native stop/key-off commands, fast-loading suppression and queue starvation. Repair host-induced interruption while preserving native music/stream stops, audio pitch and later cinematic synchronization. Validate both fast and normal loading paths.
3. Add low-cost timing for actual scene transitions. Reduce measured synchronous scene preparation costs, with bounded retention and no loss of authored features. Leave startup asset checks unchanged. Compare first visits and revisits separately; report actual elapsed time and memory, not a promised speedup.
4. Implement the confirmed outline animation on actual black loading intervals. Test startup, later loads, quick loads, failure, shutdown, intentional cinematic black and transition to the first ready frame. Preserve the FPS/debug overlay and original UI elsewhere.
5. Run relevant tests/scans and scoped real-disc validation after platform changes. Keep performance runs capture-free. Visual diagnostic capture requires explicit diagnostic opt-in and cannot provide performance evidence. Never launch competing probes during user testing.
6. Export reproducible vendor patches if needed; package the verified deliverable under `build/releases/current/`, retain rollback archives under `build/releases/archive/`, and keep temporary evidence under `build/evidence/transparency-loading-audio/`.

## Current handoff

All four changes are implemented, validated within the scope recorded in docs/GODOT_SDK_PROGRESS.md and delivered in `build/releases/current/RE-Integral-SDK-dev-24.zip`. SHA256: `229ad9a70e04cbda3b18f89c7a8f8f0ab2403d7742e9b9ace5d1adedfaea6270`. SDK23 is preserved under `build/releases/archive/`.

Native owner.raise controls coplanar layer ordering, including extension ownership. Audio retains queued output across accelerated loading and services renderer waits on the native thread, preserving original key-off, pause and gameplay clocks. Original geometry import avoids duplicate textures, while incremental preparation overlaps native loading. Final capture-free modded transition measures5.748s versus6.343s for the comparison path; readiness remains native frame540, with no additional starvation or backlog clears from difficulty selection through readiness. Startup asset verification and user mods/settings/original assets remain unchanged.

The loading presentation uses Irbif's actual37-frame animation at100ms per frame, rendered as a hollow light outline with the original motion. The0.25s delay, immediate readiness hide, cinematic-black exclusion and FPS overlay are preserved. Author credit and the original post link ship in the player guide, third-party documentation and artwork notice; no license grant is inferred.

Ten native and four launcher CTests pass, along with focused Godot/GPU checks, all37animation frames, original model-import equivalence, real-disc New Game/intro boots, reproducible130MGS/34Psyz patch stacks and package provenance/CRC/hash checks. Scoped Aislop scores100 with0findings. cppcheck/clang-tidy and vendor clang-format were unavailable; GDScript/shaders are unscored. Eight inherited modded-shutdown ObjectDB warnings remain. Human flicker/audio/appearance acceptance is pending.

No unfinished production edits or owned processes remain. Automatic approval review rejected deletion of the verified temporary SDK24 staging folder with "blocked by policy"; `build/evidence/transparency-loading-audio/RE-Integral-SDK-dev-24` remains intact. Next action is user retest with the current launcher, followed by inspection of matching normal logs if feedback requires it. Do not repeat completed probes or resume unrelated historical tasks.
