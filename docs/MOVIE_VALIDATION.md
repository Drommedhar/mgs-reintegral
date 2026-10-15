# Native movie decoding

On 2026-10-08, the original movie actor displayed a disc-backed FMV through
the native VLC, MDEC, STR and XA paths. This replaces the temporary fail-fast
movie boundary. No encoded movie or decoded game image is tracked in the repo.

## Implementation and provenance

The [SDK patch](../patches/psyz-movies.patch) adds a bounded VLC decoder, MDEC
run-level/IDCT/color conversion, input/output DMA completion and mixed STR/XA
sector delivery. The [game patch](../patches/mgs-movies.patch) passes the actual
compressed frame size and output capacity to the decoder, and lets the native
scheduler advance while the original movie actor waits for sectors.

The VLC table and v2 decoding rules come from
[PSn00bSDK vlc2.c](https://github.com/Lameguy64/PSn00bSDK/blob/5d9aa2d3dfc7d6e51c2eb942ab4cdbae5571a40a/libpsn00b/psxpress/vlc2.c),
revision `5d9aa2d3dfc7d6e51c2eb942ab4cdbae5571a40a`, under MPL 2.0.
The native adaptation checks both buffers and avoids undefined bit shifts.
The public `DECDCTTAB` type now reserves the full 34,816-byte native table.

MDEC arithmetic derives from
[psxe mdec.c](https://github.com/allkern/psxe/blob/8459c63ed78c703f46e3c51daa65a2fdf96d02e6/psx/dev/mdec.c),
revision `8459c63ed78c703f46e3c51daa65a2fdf96d02e6`, under MIT.
The adaptation uses bounded macroblocks and 64-bit transform accumulation.
Copyright notices and license texts are included in the patch. This reuses a
decoder component; it does not run an emulated CPU or original MIPS code.

## Evidence

- [VLC tests](../tests/test_vlc.c): known DC, AC and escape codes; truncated and
  unsupported inputs; output and public table allocation guards.
- [MDEC tests](../tests/test_mdec_decode.c): 15-bit and 24-bit pixels, signed
  output, bit15, clipping, truncated input, and real DMA callbacks. Output can
  be requested before input, as the original movie actor does, and the callback
  can request the next output strip.
- [CD tests](../tests/test_cd.c): interleaved STR/XA sectors, complete-frame
  publication, ring wrap, nonzero XA samples and independently checked output
  lengths for 37.8 and 18.9 kHz stereo input. Existing SPU tests also pass.

The Debug component run loaded `s04b` from the user's Disc 1, then used a debugger
call to the original `NewMovie(0x97ed)` after initial stage setup. No movie frames
or end conditions were forced. The 1,800-VSync capture shows the Metal Gear
schematic sequence. A second run reached `n_frames = 413` of the 414-frame clip,
stopped XA and destroyed the original movie actor, then exited normally at
3,600 VSyncs. Undistributed local evidence was recorded in
`build/movie-audit`: `movie-frame.bmp`, `movie-run.log`,
`movie-complete.log`, and the debugger command scripts.

This is component validation. It does not establish an authored campaign
transition into or out of the movie. The post-completion capture retains the
last movie image; normal scene restoration must be checked from its real script
context. Audio decoding produces real samples, but audiovisual timing has not
been measured against original hardware.

## Remaining limits

The first frame of each of the four Disc 1 clips was inspected: all use v2 VLC
and 320×160 video. Only clip `0x97ed` has been run to completion here. Disc 2
and all authored movie triggers remain acceptance work.

The native decoder supports color MDEC output. Monochrome modes and v3 VLC are
rejected. Resumable legacy VLC calls are not implemented; the game uses the
bounded whole-frame API. Color conversion follows the reused decoder and is
not claimed to be hardware-bit-exact. XA supports 4-bit mono/stereo at both
sample rates; 8-bit XA fails explicitly. The existing Hermite resampler is not
a reproduction of the PSX interpolation filter.

Movie input/output bounds, invalid STR sequencing and audio queue overflow
produce explicit failures. Decoder tests contain synthetic data only. Scoped
Aislop checks report no errors or fixable warnings; the seven-file SDK scope
retains four inherited size/complexity warnings, and the movie actor retains
two. All three test files scan cleanly.
