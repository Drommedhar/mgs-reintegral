# Native briefing recovery and runtime

The `brf` overlay is linked into the native game. All 43 missing assembly blocks,
containing 61 actual routines and 21,122 original instruction words, now have C
implementations. The original selector, 19 scene layouts, interview camera
controls, portraits, biographies, graphics, noise and text-resource loading are
retained. The stage contributes 51 translation units to the full build.

The recovered routines pass **109,348 synthetic comparisons against original
Integral MIPS execution**, plus native allocation-failure checks. Individual
suites and their controlled engine boundaries are described in:

- [Selector and resource loading](NATIVE_BRIEFING_SELECTOR.md)
- [Fog, geometry and shared state](NATIVE_BRIEFING_CORE.md)
- [Portrait and biography scenes](NATIVE_BRIEFING_LATE_SCENES.md)
- [Early/final scenes and camera controls](NATIVE_BRIEFING_FINAL_SCENES.md)
- [Instruction inventory and proof counts](data/brf_recovery.json)

## Actual game checks

A direct Disc 1 `brf` entry completed 1,800 VSyncs without an access violation and
rendered Snake's interview, animated camera display and original subtitles.

The `briefing` probe then passed a separate 1,800-VSync run through ordinary SDL
controller input. It observed intro scene 16, pressed Cross to follow the original
cancel path, waited for the selector, pressed Right to enter its unlocked topic
list, and pressed Circle to start scene 0. That scene advanced 383 actor ticks by
the final capture. Actor hooks only report state; the probe does not alter scene
variables, unlock flags, timing or script progress.

```powershell
./tools/run.ps1 -Stage brf -Probe briefing -Frames 1800 `
  -Capture build/briefing-input.bmp
```

Local evidence: `build/cinematic-audit/brf1800.log/.bmp` and
`build/cinematic-audit/brf-input1800.log/.bmp`. These first captures used the
previous Japanese default; English is now selected at fresh native startup.

This validates initial playback and the original selector-to-topic transition.
It does not establish every topic's complete playback, human playtesting or
controller-driven pan/zoom acceptance. Camera input routines have original-MIPS
comparison coverage; that is a separate level of evidence.

The scoped source scan reports no errors or fixable findings. Original-shaped
state-machine lengths and legacy function signatures retain nonfixable warnings.
