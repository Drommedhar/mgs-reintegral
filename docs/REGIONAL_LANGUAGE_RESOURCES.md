# Regional text and voice resources

Read-only feasibility audit, 10 October 2026, against native commit `e3c3a88`.
The supplied US and German campaign pairs can provide localization assets while
Integral remains the gameplay base. The audit below preceded implementation;
see [optional language packs](LANGUAGES.md) for the current experimental importer,
launcher selections and coverage limits. Mapping alone does not establish full
cross-region playability.

## Supplied discs

Identities below come from `SYSTEM.CNF`, ISO directory entries and executable
contents, rather than filenames alone. All six campaign images have complete
raw-sector lengths and readable ISO catalogues. The extracted game files passed
the existing sector/header/extent checks. This is structural validation, not a
comparison against an independent reference hash of each retail dump.

| Release | Disc 1 | Disc 2 | Main executable SHA-256, identical on both discs |
| --- | --- | --- | --- |
| Integral | `SLPM_862.47` | `SLPM_862.48` | `4b8252b65953a02021486406cfcdca1c7670d1d1a8f3cf6e750ef6e360dc3a2f` |
| US English, supplied as v1.0 | `SLUS_005.94` | `SLUS_007.76` | `3342f75717c5134aec832547691c2354e67a253abfcfa9e0e823e2133bb1fc32` |
| German PAL | `SLES_015.07` | `SLES_115.07` | `324f05cf342afe21bf861c0d213f30b523ace0da4bee8022d4bf185e20d8044d` |

The German boot executables are separate from the actual game programs,
`MGS/MGS1.EXE` and `MGS/MGS2.EXE`. A future importer must validate the game
program as well as the boot identity. The German images have no CUE files;
inspection used their MODE2/2352 BIN data directly.

The English pair contains both campaign discs and the major stage, Codec,
speech, cinematic and movie banks, including Disc 2 ending content. It is not
the small demo release. The current Integral importer still requires exactly
three Integral CUEs, so the now-mixed source folder cannot be reimported using
that command unchanged. Donor selection should be a separate import operation.

## What is already available

Integral already supplies English speech and selectable English dialogue
subtitles. This is also described by [Konami's original release information](https://www.konami.com/mg/archive/integral/whats/mgsi2.html)
and [language-option documentation](https://metalgear.konami.net/manual/mc1/mgs1_integral/xbox/en/page13.html).
Its native item/weapon description tables still contain Japanese text; the
original language flag does not select replacement tables there.

Direct inspection found the localized item descriptions in the US game
executable and in the German `MGS1.EXE`. These are executable data tables,
not strings that can all be recovered from `RADIO.DAT` or a stage archive.
Menus, script strings, fonts and UI textures also need separate coverage.

The first opening cinematic provides a useful control: its US and Integral
audio packet payloads and animation packet payloads match; its US subtitle
payload matches Integral's English channel. Whole speech banks do not match,
so this observation must not be extended to every recording or revision.

## Compatibility findings

| Resource | Direct observation | Consequence |
| --- | --- | --- |
| `FACE.DAT` | Same size and SHA-256 on all six discs | Integral's Codec portraits can stay. |
| `RADIO.DAT` | Integral is 11,198,464 bytes; US 1,776,851; German 1,747,286 | Dialogue addressing/layout differs substantially. |
| `VOX.DAT` | Integral has 1,108 / 754 streams; US 1,107 / 754; German 1,101 / 734 | Disc-specific mappings are required; stream ordinal is not a reliable identity. |
| `DEMO.DAT` | All releases have 79 / 40 streams, but offsets and some contents differ | Equal stream counts do not prove interchangeable cinematics. |
| `STAGE.DIR` | Integral has 95 stage names; US 96; German 94; each donor shares 82 with Integral | Keep Integral's stages and scripts, including its additional variants. |
| `init/ca68.r` (`font.res`) | Integral 18,184 bytes; US 3,580; German 6,956 | Existing exact-size overrides cannot substitute these fonts. |
| `ZMOVIE.STR` | Four movie entries per disc; shared IDs but differing offsets, with two German Disc 2 frame counts differing | Map by validated movie identity and inspect XA/subtitle tracks separately. |

Stream counts above come from walking every framed packet to its `0xf0`
terminator, then advancing to the next 2,048-byte sector. All twelve VOX/DEMO
banks parsed to their ends. The table counts include non-dialogue streams;
differences in counts alone do not establish which lines are missing.

### Codec addressing and gameplay effects

One matched Colonel call in `s00a/ea54.g` demonstrates the addressing change:

| Release | Script call operand | Actual `RADIO.DAT` byte offset |
| --- | --- | --- |
| Integral, English selected | `0x01010366` | `0x1b3800` |
| US | `0x000afa5d` | `0x0afa5d` |
| German | `0x000adcf0` | `0x0adcf0` |

The Integral operand packs a starting sector and Japanese/English sector
counts. The two donor operands in this verified example are byte offsets.
The English message bodies match; the German body has a different length.
`menu/radiomes.c:sub_80047D70` currently decodes only the Integral layout.

Codec data also executes conditions, variable operations, contact changes and
save operations. It is not just a text table. Comparing decompiled `s00a`
scripts also exposes changed game-variable offsets between Integral and US.
Replacing whole donor scripts would import gameplay assumptions. Match calls
by Integral stage/procedure/call context, retain Integral's control flow, and
substitute only validated text, font and speech references. Any larger dialog
replacement needs explicit verification of all side effects and variable IDs.

### Speech, captions and cinematic timing

`game/strctrl.c` resolves VOX and DEMO requests through relative sectors.
The streams multiplex sound, captions, caption setup and, for DEMO, animation.
Integral selects caption channel 6 for English and 3 for Japanese. The checked
US and German opening/briefing streams put their single language on channel 3.
A donor stream cannot simply inherit Integral's English channel selection.

The opening's first animation header ends at frame 3,439 in Integral/US and
2,866 in German PAL. These are consistent with approximately equal duration
at 30 versus 25 authored frames per second. German caption cue positions also
differ: the first three opening cues start at 869/928/961, versus
897/996/1050 in Integral English. The first briefing caption block ends at
2,565 in German versus 2,680 in Integral/US. Caption clocks are driven by
`get_str_counter() >> 2`, not directly by animation frame number or host VSync.

Keep Integral's animation/camera/event packets. Assemble localized audio and
captions around that timeline, checking stream completion and script callbacks.
Do not apply one PAL conversion factor indiscriminately to sound, captions and
animation. Independently selecting German text with English voices also needs
line/segment alignment to the selected speech; donor cue timing is not enough.

The stream audit identifies audio payloads, not isolated spoken-word stems.
Check clips for music/effects mixed into their audio before promising that a
voice swap preserves every other sound. XA movies are a separate path through
`game/movie.c` and `libfs/movie.c`; their raw Form 2 sectors must be preserved.
This audit read their movie tables, but did not validate localized movie playback.

### Fonts and dynamic UI text

German strings use sequences such as `0x1f 0x20` in words containing an umlaut.
Integral's `font/font.c` consumes `0x1f` as an unhandled control character,
so copying those bytes would lose the intended glyph. Import must decode the
regional encoding and supply the matching glyphs or convert to a supported
representation. Replacing the global font wholesale would also remove glyphs
needed by remaining Integral content.

The current item renderer writes the card level into description byte 46.
The weapon renderer edits SOCOM description bytes at `0x70` depending on the
silencer. Localized strings have different layouts: use named dynamic fields
or selected variants instead of carrying those byte offsets into a language pack.
Frozen item descriptions, disabled mine-detector text, button glyphs and
Integral's Very Easy MP5 description need explicit entries and coverage checks.

## Recommended implementation

1. Add a donor importer accepting explicitly selected BIN or CUE pairs. Pin the
   observed executable revisions, validate extents, retain source hashes, and
   write assets only under ignored local content directories. Keep the runtime's
   Integral base-disc validation intact.
2. Start with English UI localization: stable text keys for executable tables,
   menus and script messages, safe dynamic fields, and compatible fonts. Retain
   Integral's existing English speech and captions. This has the smallest
   impact on timing and directly addresses the remaining Japanese UI.
3. Build German UI and Codec support. Use a manifest keyed by Integral resource
   identities, with separate mappings for each disc and explicit coverage for
   Integral-only content. Support variable-length localized resources through
   their owning loader; the present `MgsModsApply` copies exact-size buffers.
4. Add German cinematic and movie speech/captions after validating timing and
   completion semantics. Support independent text/voice choices only where
   their cue alignment has been verified. Prefer Integral English as the initial
   English voice option; a separate US voice option offers little demonstrated
   benefit and still requires revision mapping.

The intended launcher choices are **Text language** and **Voice language**, plus
an import/source selection for additional packs. Resolve them independently
from the saved Japanese/English configuration bit. A pack manifest should
record its format version, base edition, donor disc hashes, mapping version,
resource sizes/hashes, encoding and timing metadata, and unresolved entries.
Report fallback coverage explicitly; never treat an absent mapping as a valid
unrelated offset. Reject incompatible or malformed packs at setup.

Localization identity also belongs in replay/session compatibility data:
different speech lengths can change when a Codec or cinematic finishes.
Treating it as presentation-only would be unsafe.

Acceptance should cover the dynamic item descriptions and German glyphs,
briefing, opening, a conditional Codec call, skipping speech, Disc 2 switching,
movies, ending branches and Integral-only variants. Assert that the Integral
stage geometry, gameplay script and collision resources are still selected.

## Local evidence and reproducibility

Ignored `build/language-audit/` holds the six extracted `MGS` directories,
`inventory.json` (image/executable/resource hashes and sector receipts),
`streams.json` (every stream's location, packet counts and per-channel payload
hashes), and `comparison.json`. No extracted retail content is checked in.

ISO/sector inspection reused `Disc`, `catalogue` and `extract_file` from
`tools/import_content.py`; stage inspection reused `tools/list_assets.py`.
Packet headers are little-endian 32-bit values: low byte is the type, remaining
24 bits are total packet size including its four-byte header. Payload hashes
concatenate a stream's packets of the same type without those packet headers.
Opening/briefing cue headers were checked against `game/jimctrl.c`.

The selected `opening`, `s00a`, `title` and `option` scenario scripts were
decompiled with the already-installed [g-e-o compilation tools](https://github.com/g-e-o/mgs_compilation_tools/tree/4fd41810eee0bec636addee5bf7b551fce6d17fd),
with outputs retained locally. Neither the original MGSR project nor the
source disc images were edited. The audit itself changed no engine behavior;
the subsequent implementation is documented separately.
