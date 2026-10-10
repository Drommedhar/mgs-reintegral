# Normal startup

The native executable defaults to the original title path. It does not normally jump to the dock or another development scene. Both `src/main.c` and `tools/run.ps1` default to `title`; an explicit `-Stage` selects a development entry. The host still loads the original `init` resources first.

## Original sequence

This sequence comes from Disc 1's original `init/ea54.g`, `title/ea54.g` and `opening/ea54.g`, together with [the recovered title actor](../vendor/mgs/source/onoda/open/open.c). The inspected scripts remain private at `build/campaign-audit/{init,title,opening}.gcl`.

| Step | Original behavior | Evidence in the code/data |
| --- | --- | --- |
| Initialize | The resident loader requests `init`; its main script initializes the game and loads `title`. | `GM_CreateLoader`, `init` main and `sub_DF2A`. |
| Konami | Cold startup passes byte variable `000049 = 0` as title option `-x`, selecting state 0. It displays `op_konami_l/r`. | `GetResources` start-flag switch; actor state 0. |
| KCE Japan | State 1 displays `op_kcej_l/r` after the Konami fade. | Actor states 0/1 call `title_open_800CD23C` with texture pairs 18/20. |
| Opening presentation | Without input, the second logo invokes the script's `-f` callback, which loads `opening`. Its three authored demo parts are `s0101a0.dmo`, `s0101a1.dmo` and `s0101a2.dmo`. | Title `sub_CD69` → `sub_B294`; opening script. |
| Title screen | Finishing the opening sets byte `000049 = 1` and returns to `title`; skipping it sets 2. These choose title animation state 4 or ready state 6. | Opening `sub_5306`/`sub_7192`; title start-flag switch. |
| Copyright/menu | The copyright is the `op_copy` texture within the title presentation, not a separately scripted startup screen. Start opens the selectable menu. | Texture index 8; title states 4–7. |
| New Game | The menu selects difficulty; its original callback initializes a new game and loads `d00a`. The intro leads to `s00a` and the opening Codec. | Title `sub_13EF`, `sub_C8CF`, `sub_B7ED`; runtime transition trace. |

Each uninterrupted logo uses its own actor counter: fade in through 20, hold through 82, fade out through 102, then transition. These are actor updates, not fixed wall-clock timestamps or process-wide VSync numbers. Input can shorten the logos and opening through their original handlers. The unattended opening is a rendered demo sequence, not a missing Sony boot movie.

## What has actually been verified

- A fresh default Debug launch with no stage override or probe visibly shows the full Konami logo: [startup-konami400.bmp](../build/cinematic-audit/startup-konami400.bmp). The command was `./tools/run.ps1 -Configuration Debug -Frames 400 -Capture build/cinematic-audit/startup-konami400.bmp`; its log records the original `init` → `title` load and `start flag = 0`.
- The no-input capture [title-normal-600.bmp](../build/title-normal-600.bmp) visibly shows the KCE Japan logo and its presentation line. Its log records `init` → `title`, `start flag = 0` and normal memory-card checks. This proves that this native startup did not immediately jump to a menu or gameplay scene.
- The normal `new-game` controller probe follows `title` → `d00a` → `s00a`, advances the Codec and records sustained movement plus collision contact. The trace is `build/renderer-contract-new-game.log`. That probe presses normal buttons and can skip startup presentations; it does not prove unattended playback of every logo or cinematic frame.
- A separate `intro` probe confirms New Game at the title and then releases every button. After the sound-clock and renderer corrections, `build/cinematic-audit/default-intro5000.log` records the full 1,981-frame infiltration reaching the dock Codec naturally in the default Debug executable. No stage/build-directory override or periodic screenshot capture is used. Active playback takes 66.117 seconds; the largest animation-update interval is 50.077 ms. See [sound-clock validation](NATIVE_AUDIO_CLOCK.md).
- The final uninterrupted default startup, `build/cinematic-audit/default-cold13500.log`, uses no input, probe or stage/build-directory override. It records `init` → `title` with start flag 0 → all three `opening` streams → `title` with start flag 1, the original completion path. All three demos reach their final frames: 3,439, 870 and 1,450. The [final capture](../build/cinematic-audit/default-cold13500.bmp) visibly shows the Metal Gear Solid Integral title, **Press Start Button** and copyright. Earlier cold-start captures show the submarine room and sonar room with English narration; see [intro timing](INTRO_TIMING.md#cold-startup-submarine-evidence).
- English Codec dialogue and briefing subtitles are visibly verified in [English text validation](ENGLISH_TEXT.md). This is not a survey of every title tooltip, movie subtitle or menu string.

The uninterrupted startup now verifies completion of all three opening parts and
the return to the title. Opening the selectable menu and starting New Game are
verified separately through normal controller input. The measurements describe
native playback; they are not a frame-for-frame or audio-phase comparison against
console hardware. The final unattended command is:

```powershell
./tools/run.ps1 -Frames 13500 `
    -CadenceLog build/cinematic-audit/default-cold13500.csv `
    -Capture build/cinematic-audit/default-cold13500.bmp
```

The native process does not run the PlayStation BIOS. Its Sony Computer Entertainment/PlayStation firmware screens are not part of these game-owned title actors and are not a prerequisite for native startup. The game's physical-disc authentication is replaced by explicit host image validation, described in [native compatibility](NATIVE_COMPATIBILITY.md#native-title-disc-validation).

## Default English Debug launch

After importing the supported Integral discs:

```powershell
./tools/build.ps1 -Configuration Debug
./tools/run.ps1 -Configuration Debug
```

This launches `build/windows-x86-debug/mgs-integral-native.exe` with English text selected and no frame limit, automated probe or development-stage override. Options can change the language; loading a saved game restores its saved configuration. The supplied executable still requires the imported original disc image. `-Stage s00a` is an explicit development shortcut, not the default launch.
