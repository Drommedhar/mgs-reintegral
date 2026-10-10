# Native SPU volume sweeps

The PsyZ mixer previously returned zero for a voice volume with bit 15 set and treated main volume as a fixed gain. It now maintains separate left/right sweep state for all 24 voices and the main output. Inactive voices continue to update their volume registers.

The implementation follows the documented signed direct gain, delayed direct-volume latch, linear/exponential modes, phase inversion, rate counter and saturation rules. Rate 127 freezes the current level. Reprogramming a control resets its counter while retaining the latched gain. Current levels are readable at main offsets `0x1b8/0x1ba` and voice offsets `0x200..0x25e`. See [psx-spx SPU volume documentation](https://psx-spx.consoledev.net/soundprocessingunitspu/#spu-volume-and-adsr-generator).

Two corner cases deliberately follow that specification: exponential increase slows above `0x6000`, and the counter increment is clamped to at least one after exponential adjustment. [DuckStation's implementation](https://github.com/stenzek/duckstation/blob/master/src/core/spu.cpp) instead slows at equality and clamps before adjustment. Main current-volume writes preserve DuckStation's writable behavior. These choices have not been measured against physical hardware.

`mgs_spu_sweep_test` exercises the actual PsyZ register and sample APIs:

- All 50 independent channels, including inactive voices and signed direct limits.
- Every encoded rate, including slow-counter saturation and rate 127.
- 168 explicit sequence cases across first/last voice and both main channels.
- Wrong-sign starts, exponential thresholds, parameter changes, key-on/off independence and hot/cold reset.
- ADPCM mixer output with signed fixed gains, a voice sweep and an inverted main sweep.

These are specification-driven regression tests, not original-MIPS comparisons or a hardware audio comparison. The unrelated ADSR generator, interpolation, noise and modulation paths are outside this change.

## Live envelope updates — 9 October follow-up

The separate `psyz-live-adsr.patch` fixes writes to a playing voice's two ADSR
registers being ignored until the next key-on. This matters to both detection
and alert sound effects: MGS's `se_off` requests release rate zero, and `spuwr`
sends key-off before updating that rate. The previous mixer kept the old rate,
allowing a looping sample to remain audible much longer than requested.

Register writes now update the active envelope parameters without resetting
the sample position, envelope phase or counter. `mgs_audio_test` drives the
public SPU SDK: a looping sample remains audible with slow release, then reaches
zero envelope and silent output after the live fast-release write on voices
0, 13 and 23. It also verifies changes during attack and sustain without
restarting the envelope. Existing sweep, IRQ-clock and replay-clock tests pass.
The user's 74,909-input prefix still matches after this change. This verifies
the shared mixer defect; listening confirmation of the reported sting/siren
artifact remains for the playthrough.
