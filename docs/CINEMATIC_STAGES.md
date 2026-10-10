# Native cinematics, menus and credits

The native selection includes `d03a`, `d11c`, `d16e`, `opening`, `preope`,
`option`, `roll`, `ending` and `endingr`. These reuse recovered vendor C and
the original constructor tables. Their inclusion adds 18 translation units;
the combined build with the Raven warehouse has 517 game translation units
and passes 37 CTest suites. This is a build milestone, not campaign completion.

## Portability corrections

`sub_efct.c` and `envmap3.c` used MIPS-only pipelined GTE macros. Native C now
uses the equivalent synchronous PsyZ GTE operation for each actual normal or
vertex, with no read beyond the final partial group. The original SDK's `_b`
variants encode the same rotation instruction and only omit pipeline delays.
Environment-map packet processing now reads `getlen()` rather than inspecting
the upper bits of a native ordering-table pointer. The regression checks UV
coordinates, partial groups, bounds, and preservation of all other packet bytes.

The credits use a second movie actor in `ending2.c`. It now calls the bounded
VLC decoder with the original frame length and allocated output capacity, and
yields while waiting for streamed data. A further runtime check identified a
busy wait while the movie task awaited the actor's start cue; that native wait
now yields to the game fiber. The corrected actor completes the 6,000-VSync
runtime check described below.

The credits' timing table was split into 26 unrelated C globals, then indexed
as a one-element array. It is restored as one 26-entry array, including its
terminator. All values match Disc2 `roll/ca26.b` at offset `0xb4`; the original
39,384-byte resource has SHA-256
`dfe3ca728b6e409613ef7a3dc11b48ecaa236d8ba6cd0951ce4321329842beae`.

Native `BreakDraw()` drains the queued GPU operations through `DrawSync(0)`.
PsyZ copies and consumes whole GPU chains on the game thread, so after draining
there is no interrupted DMA resume address. A pixel regression checks this
operation together with texture/palette feedback. It is not an empty SDK stub.

## Runtime evidence

Direct entries for Options, Previous Operations and the opening complete
600 VSyncs without an access violation. Captures show their original option
menu, game-history menu and opening presentation text respectively. These
checks do not establish menu navigation or a completed opening sequence.

- [Options capture](../build/cinematic-audit/option.bmp)
- [Previous Operations capture](../build/cinematic-audit/preope.bmp)
- [Opening capture](../build/cinematic-audit/opening.bmp)

The `d11c` story182 and `d16e` story252 fixtures complete 1,800 VSyncs and show
their original characters and subtitles. The ending story292 fixture completes
1,800 VSyncs and shows Snake, his companion, the cave and snowmobile. A longer
opening run reaches its submarine scene at 7,200 VSyncs. These runs have no
observed access violation; none establishes the complete cinematic chain.

The roll phase1 fixture instantiates the original credits actor and movie task.
At 6,000 VSyncs it has decoded frame1,446, reached credit block5, and displays
scrolling staff credits over snowy video footage. The capture reads the full
320-pixel-high interlaced framebuffer; this is not a claim of exact television
aspect or scanout fidelity. [Capture](../build/cinematic-audit/credits-6000.bmp),
[log](../build/cinematic-audit/credits-6000.log),
[fixture](../tests/fixtures/roll_credits.cdb).

The earlier 1,800-VSync black capture was investigated independently: FFmpeg
decoding of the original raw clip confirms video is black through 91.5 seconds.
That capture occurs between visible credit content. It is not retained as a
renderer failure. The first attempt before the scheduler correction did hang;
its incomplete log remains `build/cinematic-audit/roll-long.log`.

Fixtures explicitly identify supplied story/sequence values. Original scripts
then select and run their actors; this remains separate from reaching those
scenes through normal campaign play. The earlier checks stopped before the
complete credits clip and ranking transition; the extended checks below cover them.

## Complete ending scenarios

The new [ending fixture](../tests/fixtures/ending_chain.cdb) starts at story 292,
map `7df9`, with fresh Normal-difficulty state. Its default companion is Meryl;
setting the CDB pseudo-register `$t10` to 1 selects the original Otacon flag.
Use Disc 2 and `--stage ending` or `--stage endingr` respectively. The
[ending probe](../src/mgs_ending_probe.c) observes the original state changes and
uses the existing SDL virtual controller for ranking/save prompts. It supplies
no cinematic skip input and never writes campaign variables.

Both 60,000-VSync scenarios now complete the two ending scenes (story 293 and
294), credits phases 0 through 4, post-credits playback, ranking, a completed-
mission save through the original menu and return to title. The Meryl ranking constructor runs at
VSync 41,050; Otacon's runs at 39,979. Completion count becomes 1, with unlock
flag 1 for Bandana or 2 for Stealth respectively. This is a late-game scenario
test, with development statistics; it does not verify the displayed rank for a
full campaign playthrough.

- [Meryl trace](../build/campaign-completion/meryl-final.log)
- [Otacon trace](../build/campaign-completion/otacon-final.log)
- [Save payload inspection](../build/campaign-completion/save-payloads.json)

Each isolated test card contains an actual 8,192-byte original save file. All
three redundant 2,624-byte payload copies have valid original CRCs, Normal
difficulty, completion count 1 and the earned item. Meryl's file has Bandana 1
and Stealth -1; Otacon's has Stealth 1 and Bandana -1. Original save files and
recordings in the user's normal runtime directory are unaffected.

After saving, the probe selects No in the original optional PocketStation prompt
using Right, release, then Circle. Its input sequence starts when the prompt
becomes ready; a global button timer could confirm Yes before sending Right and
loop in the original no-device screen. Both original callbacks now return to
title: the title overlay loads at VSync 42,455 for Meryl and 41,374 for Otacon.
The probe then sends no input; the title's ordinary idle opening movie follows.
Loading the completed-mission saves remains a separate acceptance check.

The scenarios use the existing deterministic recording clock and unpaced
presentation for unattended execution. Their raw input logs are local diagnostic
artifacts requiring the supplied initial-state fixture, not ordinary portable
recording sessions. Backlogged presentation audio is discarded while emulated
samples continue; these runs establish state progression, not real-time audio
fidelity. The fixture itself retains normal pacing; the local CDB wrappers enable
unpaced presentation only for deterministic recordings.

The extended Debug run exposed the footprint actor's unused null-map read before
its movement eligibility check. The [native correction](NATIVE_COMPATIBILITY.md#cinematic-footprint-eligibility)
preserves active footprints and allows playerless endings to run. The 3,446-case
regression rejects the original eager read. All 108 CTest suites pass in the
rebuilt default, with 60 MGS and 15 PsyZ patches verified.

The new probe and regression files have no scoped Aislop findings. Optional
`cppcheck` and `clang-tidy` engines are unavailable in this environment.

Scoped Aislop checks report no errors or fixable findings. Four non-fixable
complexity warnings remain in the recovered credits source. Its existing
credit-resource type TODO also remains open; this is recorded rather than
hidden by suppressing the scanner.

Models, textures, camera streams, movies and audio remain original external
resources. The changes continue through the shared resource and renderer
boundaries described in [RENDERER_MODULES.md](RENDERER_MODULES.md).
