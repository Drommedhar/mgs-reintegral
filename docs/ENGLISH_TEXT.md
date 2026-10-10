# English text verification

Native startup sets `GM_CONFIG_ENGLISH` in `GCL_StartDaemon`. The existing game code then chooses its original English resources. This changes text selection; it does not replace or translate assets. The dock capture at `build/cinematic-audit/codec-english600.bmp` shows English Codec dialogue and the visible `140.85` frequency.

## Scope of the original language setting

Integral's language option selects subtitles, as described in
[Konami's manual](https://metalgear.konami.net/manual/mc1/mgs1_integral/xbox/en/page13.html)
and its [original release information](https://www.konami.com/mg/archive/integral/whats/mgsi2.html).
It does not provide complete English UI localization. The selected
`menu/item.c` and `menu/weapon.c` read Japanese description tables directly,
without checking `GM_CONFIG_ENGLISH`. The user's 9 October snowfield recording
retains configuration `0x0100`, confirming that these Japanese descriptions
appear while English is enabled. Earlier English validation covered dialogue
and subtitles, not every description or menu.

Optional [English and German language packs](LANGUAGES.md) now import executable
description tables, German glyphs, matched dialogue and speech from the supported
US and German campaign pairs. Integral remains the gameplay base. Coverage is
partial; full UI graphics and movie localization are not implemented.

The supplied US and German campaign pairs have now received a
[read-only compatibility audit](REGIONAL_LANGUAGE_RESOURCES.md). It identifies
the executable text tables, regional Codec addressing, font encoding and
cinematic timing work needed for optional packs. Runtime language-pack support
remains unimplemented.

## Briefing subtitles

The missing text in the initial 900/1,800-VSync screenshots was not sufficient evidence of a subtitle failure. A read-only inspection of Disc 1 `MGS/VOX.DAT`, starting at sector 7, found both original subtitle streams. Channel 3 is Japanese; channel 6 is English. `NewJimakuControl` selects channel 6 with the English flag, and discards channel 3. Both use the existing `jimctrl.c` subtitle reader.

The first English block starts at byte `7 * 2048 + 0x93c`. Its header covers cue clocks 0 through 2680. Its first three cues start at 181, 237 and 339 and last 51, 58 and 81 ticks respectively. These clocks are `get_str_counter() >> 2`, not the host VSync count.

A debugger observation of the normal native briefing recorded calls to `MENU_JimakuWrite` at stream counters 725 and 948, selecting the first and second English cues. At the 1,800-VSync capture, the counter was 1293, giving cue clock 323. The preceding English line had ended at 295 and the next began at 339: no caption was expected then. The configuration was `0x0500`, with English enabled and captions permitted. The trace is `build/cinematic-audit/english-subtitles1800.log`; debugger actions only observed state.

The independent normal run below produced `build/cinematic-audit/brf-english1500.bmp`. The inspected image visibly reads “I should have known you” and “were behind this, Colonel.” No input, subtitle timing, stream state or outcome was forced.

```powershell
./tools/run.ps1 -BuildDirectory build/gpu-validation -Stage brf -Frames 1500 `
  -Capture build/cinematic-audit/brf-english1500.bmp
```

This verifies selected English Codec dialogue and actual briefing subtitle rendering. It is not a complete survey of every menu, movie subtitle or campaign line, nor a hardware timing comparison. No subtitle production-code change was necessary.

These captures precede the [SPU interrupt scheduling correction](NATIVE_AUDIO_CLOCK.md).
The original cue numbers and language selection are unchanged, but process VSync
numbers from those older captures are not timing targets for the corrected build.
