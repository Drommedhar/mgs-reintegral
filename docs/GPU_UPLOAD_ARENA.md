# Dock cinematic upload stalls

The renderer previously cycled its vertex transfer buffer, vertex buffer and
index buffer for every drawing batch. Water distortion produces hundreds of
ordered batches. SDL's D3D12 backend allocated additional buffers while previous
copies remained referenced, causing visible stalls when batch counts increased.

Temporary phase measurements in the clock-corrected intro isolated the cost:

| Frame | Batches | Map | Buffer uploads | VRAM snapshot | Rendering |
| --- | ---: | ---: | ---: | ---: | ---: |
| 725 | 230 | 93.28 ms | 185.02 ms | 1.75 ms | 3.30 ms |
| 1614 | 569 | 231.70 ms | 456.43 ms | 4.31 ms | 8.08 ms |

The renderer now appends batches into a bounded upload arena holding 65,536
vertices and 98,304 indices. Transfer and destination ranges are disjoint within
a frame. The three buffers cycle together only at presentation or capacity wrap;
vertex/index bindings select each batch's range. Clear commands have a separate
small transfer buffer. Drawing order, framebuffer sampling and mask semantics
remain intact. The implementation uses SDL GPU APIs and lives entirely in the
replaceable renderer.

An optimized 5,000-VSync run selected New Game, released all inputs, played the
complete 1,981-frame intro and naturally reached the dock Codec. The observed
clip lasted 66.10 seconds. Its maximum draw time fell from 701.73 ms to 5.59 ms;
there were no audio starvation warnings or animation-update gaps above 250 ms.
The largest update gap was 50.05 ms, following an optional periodic capture.
Most updates were two VSyncs apart. Logs and cadence data are under
`build/cinematic-audit/intro-arena5000.*`.

The normal sprite/mask, 2× mask and texture-feedback pixel suites pass. The
[upload-arena regression](../tests/test_gpu_upload_arena.c) submits 20,000 opaque
one-pixel tiles (80,000 vertices) before any readback or presentation, forcing
capacity wrap. Drawing-offset commands split the batches; five interleaved
clears overwrite earlier grid pixels. It checks all 20,480 grid pixels, presents
with VSync, then repeats with different colors to check subsequent-frame reuse.
Both native and 2× cases pass in 0.59 seconds total in Debug `movie-audit`; the
log is [gpu-arena-test-run.log](../build/movie-audit/gpu-arena-test-run.log).
The test requires the same initial `DrawSync` as existing SDK tests; the first
attempt omitted that initialization and failed before drawing its first tile.
The corrected test also passes in the default Debug build. Live comparisons
still do not establish full campaign graphical accuracy.

The temporary profiling code is removed. Aislop reports no errors or fixable
findings in the changed renderer; five existing nonfixable size/complexity
warnings remain. See also [sound clock correction](NATIVE_AUDIO_CLOCK.md),
[water packet recovery](WATER_PACKET_RECOVERY.md) and
[primitive limits](GPU_PRIMITIVE_LIMITS.md).
