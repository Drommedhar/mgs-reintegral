# GPU mask and blend validation

The SDL_GPU backend now stores PS1 bit15 independently of color blend opacity.
Mask-setting changes flush pending primitives. Destination-dependent draws read
the preceding VRAM contents; protected pixels and transparent texels are discarded.
The shader performs the four PS1 color blend modes with integer 5-bit components
and writes the texture mask bit or the explicitly forced mask bit.

CPU uploads and VRAM copies preserve protected destination pixels and apply the
forced bit. A same-position copy can therefore still change bit15. Fill-VRAM
bypasses masking and clears bit15. The software backend follows the same transfer
rules. GP0(E6) also updates the emulated status mask fields. These rules follow
the independently researched [PSX GPU specification](https://psx-spx.consoledev.net/graphicsprocessingunitgpu/#gp0e6h-mask-bit-setting).

The previous implementation returned 0x801e for an untextured full-red draw that
should produce 0x001f. The new pixel regression first reproduced that failure,
then passed with the fix. It checks all four mask modes, consecutive overlapping
draws, masked/unmasked CPU transfers and copies, same-position copies, fill bypass,
texture bit15, transparent and opaque texels, and all four blend modes. The same
suite passes at native and 2× internal resolution on D3D12. A separate software
transfer test passes. Existing framebuffer/CLUT feedback tests continue to pass.
A 6,000-VSync optimized run then followed the original title/New Game route,
advanced the Codec and observed 431 movement units and 21 collision-contact ticks
in the dock. Its framebuffer was inspected and no renderer diagnostics appeared.
[Runtime log](../build/gpu-mask-new-game.log),
[capture](../build/gpu-mask-new-game.bmp).
Local logs: `build/gpu-mask-before.log`, `gpu-mask-after.log`,
`gpu-mask-scaled.log`, `gpu-feedback-after-mask.log`, and
`gpu-validation-tests.log` (22 passing suites).

This does not establish complete GPU accuracy: primitive edge rules, unusual
self-overlapping polygons, all VRAM wrapping cases, reset behavior and every
original scene remain separate acceptance work. Masked VRAM copies currently
use bounded row readback, which favors correctness over transfer speed. A modern
renderer remains replaceable through the source module interface.

## Regenerating shaders

The GLSL source and regenerated SPIR-V, MSL and DXIL headers are included in
`patches/psyz-masking.patch`. Windows builds consume the signed DXIL header;
shader compilers are not required for an ordinary game build.

This generation used glslang 16.6.0 (Windows archive SHA256
`82bf434e69b9bb4829de7e2b4bc2c5e7a7861e53d66cf75e5cc70f5f694a8d9b`),
SPIRV-Cross `aa217aeb6c9f0ace7a0ab233b28807edf45eb165`, and Windows SDK
10.0.26100.0's x64 DXC. The tools remain under ignored `.tools/shaders` and the
installed Windows SDK. To regenerate after GLSL changes:

```powershell
./.venv/Scripts/python.exe tools/build_gpu_shaders.py `
    --glslang .tools/shaders/glslang/bin/glslang.exe `
    --spirv-cross .tools/shaders/spirv-build/spirv-cross.exe `
    --dxc 'C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe' `
    --shader psx.frag
```

Omit `--shader` to regenerate all four shaders. All compilers must succeed before
headers for a shader are replaced. The helper and tests scan without Aislop
findings. The five changed vendor C/header files retain twelve nonfixable size,
function-length or parameter-count findings; there are no errors or fixable
warnings. Missing analysis engines still limit scan coverage.
