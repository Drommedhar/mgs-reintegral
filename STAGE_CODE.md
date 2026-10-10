# Where the stage code is

The editable game C is in **`vendor/mgs/source/`**. This includes the reused vendor
implementation and the functions reconstructed during this project. `src/`
contains the Windows adapters and development probes, so looking there alone
will miss almost all stage implementation work.

`vendor/` is Git-ignored. Changes to downloaded code are preserved as reviewed
patches under **`patches/`**, with application order in
[sources.lock.json](sources.lock.json). The patch files are the versioned changes;
the files linked below are the actual editable C compiled by the build.

## Open the recovered implementations

| Area | Actual C implementation | Recovery/change record |
| --- | --- | --- |
| Briefing | [Scene dispatch](vendor/mgs/source/overlays/brf/onoda/brf/b_graph.c), [biography timeline](vendor/mgs/source/overlays/brf/onoda/brf/graph_bio_timeline.c), [portrait scenes](vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_late.c), [camera controls](vendor/mgs/source/overlays/brf/onoda/brf/graph_camera.c), [selector](vendor/mgs/source/overlays/brf/onoda/brf/select_state.c) | [Recovery evidence](docs/data/brf_recovery.json): 43 missing assembly blocks containing 61 routines replaced with C |
| Photo album | [State machine](vendor/mgs/source/overlays/camera/unknown/camera_state.c), [photo decoding](vendor/mgs/source/overlays/camera/unknown/camera_photo.c), [card operations](vendor/mgs/source/overlays/camera/unknown/camera_card.c), [controls](vendor/mgs/source/overlays/camera/unknown/camera_controls.c) | [Recovery and validation](docs/CAMERA_ALBUM_RECOVERY.md): all 16 missing blocks implemented, initial UI verified |
| Liquid rooftop fight | [Actions](vendor/mgs/source/animal/liquid/liquid_action.c), [thinking](vendor/mgs/source/animal/liquid/liquid_think.c), [tactics](vendor/mgs/source/animal/liquid/liquid_tactics.c), [sequences](vendor/mgs/source/animal/liquid/liquid_sequence.c) | [mgs-liquid.patch](patches/mgs-liquid.patch), [validation](docs/LIQUID_RECOVERY.md) |
| Rooftop Snake | [Actor](vendor/mgs/source/overlays/d18a/animal/snake18/snake18.c), [native movement](vendor/mgs/source/overlays/d18a/animal/snake18/native_09.c), [targeting](vendor/mgs/source/overlays/d18a/animal/snake18/native_target.c) | [Snake18 evidence](docs/NATIVE_SNAKE18_RECOVERY.md) |
| Metal Gear REX | [REX actor](vendor/mgs/source/kojo/mgrex.c), [laser](vendor/mgs/source/kojo/mgrexlzr.c), [collision](vendor/mgs/source/kojo/mgrexhzd.c), [particles](vendor/mgs/source/kojo/rex_particles.c), [native types](vendor/mgs/source/overlays/s17a/rex_native.h) | [mgs-rex.patch](patches/mgs-rex.patch) |
| Rappel | [Rope actor](vendor/mgs/source/overlays/s11d/chara/rope/rope.c), [native rope motion](vendor/mgs/source/overlays/s11d/chara/rope/rope_native_motion.h), [Hind](vendor/mgs/source/overlays/s11d/chara/hind/hind.c) | [mgs-rappel.patch](patches/mgs-rappel.patch), [validation](docs/RAPPEL_RECOVERY.md) |
| Escape garage | [Jeep](vendor/mgs/source/overlays/s19a/props_jeep.c), [Snake](vendor/mgs/source/overlays/s19a/props_snake.c), [companion](vendor/mgs/source/overlays/s19a/props_companion.c), [gate](vendor/mgs/source/overlays/s19a/props_gate.c) | [mgs-garage-props.patch](patches/mgs-garage-props.patch), [validation](docs/GARAGE_PROPS_RECOVERY.md) |
| Escape chase | [Road controller](vendor/mgs/source/overlays/s19b/takabe/jeep_srl.c), [mounted Snake](vendor/mgs/source/overlays/s19b/takabe/jeep_sne/jeep_sne.c), [driver](vendor/mgs/source/overlays/s19b/takabe/jeep_mrl/jeep_mrl.c), [Liquid](vendor/mgs/source/overlays/s19b/takabe/jeep_liq/jeep_liq.c) | [mgs-escape.patch](patches/mgs-escape.patch), [validation](docs/ESCAPE_RECOVERY.md) |
| Ranking and PocketStation menus | [Ranking source directory](vendor/mgs/source/overlays/rank), [menu card I/O](vendor/mgs/source/overlays/rank/menu/pocket_card.c), [background actor](vendor/mgs/source/overlays/rank/chara/pocket/pkt_back.c) | [mgs-ranking.patch](patches/mgs-ranking.patch): 97 missing game assembly blocks replaced with C |
| Camera item | [Capture/encoder actor](vendor/mgs/source/equip/jpegcam.c) | [Native memory fix and original encoder comparison](docs/EQUIPPED_CAMERA_CAPTURE.md) |

Earlier guard, Mantis, Ninja, Wolf, Raven, tower and cinematic changes are indexed
in [PROGRESS.md](PROGRESS.md) and the corresponding `patches/mgs-*.patch` files.
Some actors are shared between stages and live outside `overlays/`; the paths
above point to their actual implementation locations.

## How this becomes the executable

[config/stages.json](config/stages.json) selects all 92 campaign/menu identities.
[The linker selection template](vendor/mgs/build/linker_command_file.txt) assigns
C objects to them; [source generation](tools/generate_sources.py) resolves those
objects and native actor tables. The optimized build currently compiles 738 game
C translation units plus the native adapters and platform library.

`build/gpu-validation/native-source/` contains generated encoding-adjusted copies.
**Edit the source paths above, not those generated copies.** The executable is
`build/gpu-validation/mgs-integral-native.exe`; the ordinary Debug build is
`build/windows-x86-debug/mgs-integral-native.exe`.

The [campaign audit](docs/CAMPAIGN_CODE_AUDIT.md) found no omitted main-stage
constructor entry or active native assembly body. This establishes source
coverage. Connected campaign progression, encounter completion and human
playability are still being validated; individual recovery documents record
their exact evidence and limitations.
