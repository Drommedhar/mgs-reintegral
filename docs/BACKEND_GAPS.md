# Backend gaps

Inspected on 2026-10-09. These follow-ups accompany the stage and campaign work in [ARCHITECTURE.md](ARCHITECTURE.md). Vendor links resolve after bootstrap. Complete graphics, audio and campaign acceptance before full-game sign-off.

**New Game cinematic stalls — reproduced and corrected.** Lost SPU IRQ events
slowed the original stream clock, and per-batch GPU buffer allocation caused
up to 702 ms stalls. Servicing audio boundaries on the game thread and reusing
bounded GPU upload ranges fixes these measured faults. The complete unskipped
intro reaches the dock Codec with correct timing in optimized and default Debug
builds. Underwater commands also have corrected native packet layouts and memory
ownership. See [intro timing](INTRO_TIMING.md), [audio clock](NATIVE_AUDIO_CLOCK.md)
and [upload arena](GPU_UPLOAD_ARENA.md). These checks do not establish graphical
accuracy or timing throughout every campaign stage.

**GPU masks — implemented and covered by pixel regressions.** The SDL_GPU
backend now preserves bit15 separately from blending, respects destination
protection, and applies the proper upload/copy/fill rules. Native and 2× D3D12
checks and software transfer tests pass; original Codec feedback tests still
pass. See [GPU mask evidence](GPU_MASKING.md). Complete primitive-edge, wrapping,
reset and scene-level fidelity remain acceptance work.

**Save/load — original menu round trip works in a documented scenario fixture.**
The Windows card backend now delivers the original completion events, preserves
20-byte PS1 filenames and capacity limits, and reports transfer errors. Tests use
recovered game card APIs across process restarts. Original Mei Ling save and title
Load Game menus completed a CRC-checked `s02a` restoration and controller movement
in an explicit story=1 debugger fixture. See [save evidence](NATIVE_SAVES.md).

Normal campaign saving, all overwrite/delete/error screens and crash durability
remain acceptance work. The backend uses card directories; raw `.mcr` import and
export are not implemented. Unsupported raw-sector operations fail explicitly.

**Audio — real DMA/IRQ support and volume sweeps are implemented; gameplay fidelity still needs verification.** [The audio tests](../tests/test_audio.c) exercise actual RAM transfers, completion callbacks, nonzero ADPCM output, interrupt masking and IRQ rearming. SPU address hits queue events for the game thread. Voice/main volume sweeps now have clocked state, signed readbacks and mixer regressions; see [sweep evidence](NATIVE_SPU_SWEEPS.md).

The live SDL device now maintains the original 98.4375 Hz interrupt clock during
the complete New Game cinematic. Broader music, effects, Codec speech/subtitles,
pause/resume and long-running stream synchronization still require comparison
against the original game.

**XA and movies — real playback works; campaign integration and fidelity remain open.** The [movie implementation](MOVIE_VALIDATION.md) now decodes v2 VLC, color MDEC and interleaved STR/XA sectors, with actual DMA completion. The original movie actor rendered a Disc 1 clip and reached its normal end condition in an injected component test. XA supports 4-bit mono/stereo at 37.8 and 18.9 kHz; 8-bit sectors fail explicitly.

Validate the remaining clips, Disc 2, authored movie triggers, scene restoration and audiovisual synchronization. Compare decoded pixels and interpolation against the original hardware before claiming fidelity. Monochrome MDEC, v3 VLC and resumable legacy VLC calls remain unsupported; the game movie path uses the bounded whole-frame decoder.
