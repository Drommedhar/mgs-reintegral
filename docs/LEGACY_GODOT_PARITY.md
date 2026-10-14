# Legacy through Godot parity checks

The reference graphics backend is from the preserved0.2.0-alpha.1 MPL source
archive, SHA256 `c46959c2296b89e7dc9de4fc0feb8017d1f977b05d0b468bb0ce37cf036e49fd`.
The fixture links that backend to the current common Psyz/SDL libraries; it is
not a rebuild of the complete historical executable. Original disc data is not
needed for these checks.

Build the Godot native `mgs_legacy_parity_fixture` target, then run:

```powershell
tools/build-legacy-parity-reference.ps1
tools/test-godot-legacy.ps1
tools/test-godot-legacy.ps1 -Width 320 -Height 240 -Wide 0
tools/test-godot-legacy.ps1 -Width 640 -Height 480 -Wide 0
tools/test-godot-legacy.ps1 -Width 641 -Height 481 -Wide 0
tools/test-godot-legacy.ps1 -Width 2560 -Height 1440 -Fullscreen
```

The reference builder requires the preserved local archive and a compiled native
Psyz/SDL library under `build/windows-x86-relwithdebinfo`; both paths are parameters.
It records archive/backend/library/executable hashes beside the fixture.
Fullscreen1440p requires a matching display. Capture extents must match exactly;
the test rejects a window shortened by the desktop's available area.

Each pair draws identical primitives: all four semi-transparency modes, dithered
Gouraud geometry, native and scaled framebuffer sampling, overlapping MoveImage,
partial uploads/clears and a rendered palette. A magenta bottom band detects
accidental224-row cropping in original-aspect mode. Both320x240 RGB5551 readback
and final RGB GPU presentation must match byte-for-byte. The reference capture
uses SDL's GPU blit into a readback target; the native convenience screenshot API
uses CPU scaling and is not an exact oracle for filtered GPU presentation.

`tests/compare_legacy_captures.py` writes `comparison.json` and a difference image
on failure. The5-case matrix passed on the local RX9070XT with the archived SDL
D3D12 backend and Godot Vulkan. This is deterministic renderer evidence, not
campaign-wide visual or playability acceptance.

`legacy_runtime_test.gd` additionally checks first-frame viewport coverage, scale
selection, integer fitting, F2/F4/F6/Escape behavior, old-host gating and SDL
debug-overlay glyph/color parity.
The native `mgs_godot_host_input_test` CTest checks authenticated wire delivery and
15.30 compatibility. Full-scene resolution and depth-composition tests run with
and without FSR2 to protect the separate Godot presentation path.
