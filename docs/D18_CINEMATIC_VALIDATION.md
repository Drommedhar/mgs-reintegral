# The original cinematic transition into Liquid's fight

`d18a` completes its authored story-275 cinematic and loads `s18a` in the native game. The test changes only the incoming story variable; it supplies no controller input and does not force cinematic completion or the next stage.

The original Disc 2 `ea54.g` script selects `sub_9142` at story 275. That procedure sets story 277, creates the scene timer and starts `s2501e0.dmo` with stream code `e5d3`. Its callback `sub_EF70` fades out, waits 35 ticks and calls `sub_6493`, which loads `s18a` with map `7df9` for the default story branch. The fixture is [d18a_story275.cdb](../tests/fixtures/d18a_story275.cdb).

Three Debug observations establish the result:

- At 1,800 VSyncs, the capture shows Liquid standing beside Snake and Meryl on REX, with scene models and lighting rendered. The run exits without a native exception.
- At 6,000 VSyncs, the original stream has ended and the authored continuation requests `s18a`. This bound stops during loading; it does not establish completed entry by itself.
- At 7,200 VSyncs, `s18a` has loaded, its original script has created native Liquid and Snake18, and its countdown has started. The capture shows Liquid speaking with the countdown displayed. The run exits cleanly without a native exception.

Evidence is in `build/movie-audit/d18a275-cinematic.log` / `.bmp`, `d18a275.log` / `.bmp`, and `d18a275-transition.log` / `.bmp`. The final image still shows the fight introduction, so these runs do not establish free combat, victory, continuous campaign arrival or human playability. `d18ar` has build and original-code comparison evidence, but was not exercised by this runtime fixture. The source/constructor comparison is recorded in [d18_stages.json](data/d18_stages.json).
