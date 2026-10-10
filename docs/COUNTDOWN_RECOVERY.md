# Original countdown display

The shared countdown renderer is native C in `overlays/s19b/menu/countdwn.c`,
preserving the original PS1 assembly in its non-native branch. Liquid and the
escape sequence can select the same module. Stage integration is recorded in
their separate recovery documents.

The recovered renderer corresponds to `s19b` address `800C3C90` and `s18a`
address `800C6BDC`: 319 original instruction words, with 14 address relocations.
Its original time is measured in 30-Hz ticks. Drawing captures the displayed
time before decrementing it; expiry invokes the configured script exactly when
the positive count reaches zero. Warning textures pulse with the original
frame phase. Both original draw-mode words, including bit `0x400`, are retained.

The vendor border table was missing its second four-byte rectangle. The source
now contains the original eight bytes, verified in both supplied Disc 2
overlays. Packets allocate the native structure size and retain full ordering
table pointers, so a replacement renderer receives the same primitive payloads.

`mgs_countdown_test` passes 252 original-MIPS comparisons: 14 timer boundaries
and 18 frame phases. Reference execution runs the original renderer, texture
packet helper, and expiry helper. The digit-drawing and script-service boundaries
record their arguments. The native test compares the remaining timer, procedure
state, ordered calls, and all 11 generated packet payloads. The boundary checks
do not claim that an entire boss or escape sequence has been completed.

The patch is [mgs-countdown.patch](../patches/mgs-countdown.patch). Golden cases
are in [mgs_countdown_fixtures.h](../tests/mgs_countdown_fixtures.h); local reference
execution and logs are in `build/cinematic-audit`. The touched source has no
Aislop errors or fixable findings; one nonfixable parameter-count warning remains
on the tile helper. Test files have no findings.
