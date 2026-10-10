# Primitive extent limits

The SDL GPU renderer and its software rasterizer now reject triangles wider than
1023 coordinate units or taller than 511, and reject line segments with the same
excessive spans. Each half of a quad is checked independently. These are original
[PS1 vertex limits](https://psx-spx.consoledev.net/graphicsprocessingunitgpu/#vertex-parameter-for-polygon-line-rectangle-commands),
before clipping to the drawing area; a large polygon crossing the screen must
not become a full-screen flash merely because part of it intersects the viewport.

An instrumented, unskipped New Game run found 58–87 oversized polygon bounding
boxes per 120 VSyncs during the dock cinematic. This establishes that the scene
exercises the missing rule. It does not establish that every such quad has an
invalid individual triangle, or that this rule explains all reported flashes.
The temporary counters have been removed from production sources.

The shared cases in `tests/gpu_extent_cases.h` check valid and invalid horizontal
and vertical boundaries for triangles and lines, plus a quad with either its
first or second triangle out of range. They execute through the actual public
GPU packet path at native and 2× resolution, and through the software rasterizer.
The old SDL GPU source fails the new test: a pixel that should remain black is
drawn red. The corrected source passes; existing mask, blend and texture-feedback
regressions still pass. Logs are `build/intro-extents-before.log` and
`build/intro-extents-after.log`.

Aislop reports no errors or fixable findings in the changed C files. Nine
nonfixable vendor complexity/size warnings remain; the test C files have no
findings. `cppcheck` is unavailable, limiting the static-analysis coverage.

Live scene comparison and the separate audio-clock correction are required
before claiming that cinematic rendering and motion are fully corrected.
