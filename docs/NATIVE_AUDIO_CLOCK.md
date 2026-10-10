# Native sound interrupt timing

The SPU clock fix moves audio generation to the owning game thread when PsyZ is
built with `PSYZ_POLL_IRQ_ONLY`. SDL plays queued PCM; its audio thread does not
execute game code. The ordinary threaded PsyZ configuration retains its audio
callback.

MGS uses a silent voice playing a 512-byte looping ADPCM sample at pitch 4096.
Its interrupt handler alternates the IRQ address between the beginning and
midpoint of that sample. Each 256-byte half contains 448 decoded samples, giving
44,100 / 448 = 98.4375 interrupts per second. The original stream-clock conversion
`ticks * 64 / 105` remains unchanged.

Previously, the audio thread generated up to 2,048 samples while a single SPU IRQ
remained latched. The game thread updated the next IRQ address only at its later
poll. Subsequent address crossings within that buffer were lost. Dispatching many
callbacks afterward would still allow MTS interrupt messages to coalesce.

`Psyz_SpuPullSamplesServiced` now finishes a sample, dispatches its newly raised
IRQ, and invokes the registered task-service callback outside the kernel interrupt
handler before producing the next sample. The callback applies MTS's existing
deferred priority scheduling. The sound task can refill streamed samples and
update registers between IRQs. Unacknowledged interrupts remain latched; this
does not synthesize repeated interrupts or change hardware acknowledgement rules.

The SDL pump fills a bounded 2,048-frame queue during blocking VSync calls. It
does not run for VSync timing queries or while paused. A reentrancy guard protects
the active audio buffer across fiber switches. Queue-query and queue-write errors
are fatal; an exhausted queue is reported. Long game-thread stalls can still
starve audio and are a separate rendering/performance problem. This design does
not silently discard generated samples or invent sound ticks during such a stall.

Validation:

- `mgs_spu_irq_clock_test` uses the native SPU decoder, kernel IRQ delivery, and
  Windows fibers. Batches of 1, 7, 448, 735 and 2,048 samples produce exactly five
  callbacks and sound-task runs over 2,048 samples, and 99 over 44,100 samples.
  The old deferred entry point produces only one IRQ in the first 2,048-sample
  buffer. The test also checks acknowledgement, disabled IRQs, critical-section
  deferral, and alternating audible/silent regions when the sound task changes
  volume within one buffer.
- Existing SPU sweep and audio DMA/mixer/IRQ tests pass.
- `build/cinematic-audit/intro-audio-fixed1800.log` records an unskipped New Game
  intro. Sound ticks are 300, 792, 1,285 and 1,777 at VSyncs 900, 1,200, 1,500 and
  1,800: 492/493 ticks per approximately five seconds, consistent with 98.4375 Hz.
  The earlier run measured approximately 59 Hz. The 1,800-frame cap intentionally
  ends before the intro finishes, so the probe reports incomplete rather than
  campaign success.
- The same trace contains 266 ms and 676 ms rendering spikes, with explicit queue
  exhaustion warnings. It does not establish that the user's intermittent visual
  stalls are fully fixed.
- The subsequent full run, `intro-audio-fixed5000.log` and `.csv` in the same
  directory, passes the normal title → New Game → d00a → dock Codec chain with
  no input after title. The demo reaches frame 1,981 naturally, with 1,978 applied
  updates; its original clock catch-up loop skips three frame records. Active
  playback takes 67.238 seconds. Desired versus applied frame differs by at most
  one frame. The three remaining long update intervals are 286.643, 284.328 and
  701.949 ms, coincident with GPU upload stalls; all other intervals are at most
  64.071 ms. This rules out recurring second-long demo-clock plateaus in that run.
  The loaded dock is observed at VSync 4,903 versus 7,709 before the clock fix.
- With the renderer's bounded upload arena, `intro-arena5000.log` and `.csv`
  pass the same complete unskipped intro. Active playback takes 66.133 seconds
  (66.100 seconds measured from the first applied frame). Maximum active-demo
  draw time drops from 701.726 ms to 5.588 ms; maximum frame time is 16.831 ms.
  The largest demo-update interval is 50.050 ms, with none above 250 ms and no
  audio queue exhaustion. The demo reaches frame 1,981 with 1,980 updates;
  applied minus desired frame stays between -1 and +2. Periodic screenshots are
  synchronous readbacks and remain part of this measured run. These observations
  validate this opening sequence, not every cinematic or human gameplay session.
- Final verification uses the default Debug executable through `tools/run.ps1`,
  without a build-directory or stage override and without periodic captures:

  ```powershell
  ./tools/run.ps1 -Probe intro -Frames 5000 `
      -CadenceLog build/cinematic-audit/default-intro5000.csv `
      -Capture build/cinematic-audit/default-intro5000.bmp
  ```

  This exits successfully after the unskipped intro reaches the dock Codec.
  Active playback takes 66.117 seconds; the maximum update interval is 50.077 ms,
  maximum draw time 7.226 ms and maximum frame time 16.713 ms. No queue exhaustion
  or update gap above 250 ms occurs. The frame divisor stays at two throughout.
  The demo reaches frame 1,981 with 1,963 applied updates, exercising the original
  catch-up path; applied minus desired frame remains between -1 and +2. The
  recording is `default-intro5000.log`/`.csv`, with its analysis in
  `default-intro5000-summary.json`. This is bounded Debug scheduling variation,
  not evidence of perfect frame-for-frame equivalence with the console.
- An untouched default launch, `default-cold13500.log`/`.csv`, subsequently
  completes all three submarine-opening parts and returns to the title with
  original start flag 1. The three demos reach frames 3,439, 870 and 1,450 in
  observed playback intervals of 114.632, 29.046 and 48.399 seconds. Their largest
  update intervals are 33.407, 33.442 and 33.603 ms. All recorded update intervals
  span two VSyncs, and none exceeds 250 ms. One queue-exhaustion warning occurs
  before the initial `init` stage load; none occurs during the three demos. The
  final image shows the original title and Press Start prompt. This run uses no
  probe, stage/build-directory override or periodic capture.

SDL's queued-stream path follows its documented
[null-callback device setup](https://wiki.libsdl.org/SDL3/SDL_OpenAudioDeviceStream),
[input queue measurement](https://wiki.libsdl.org/SDL3/SDL_GetAudioStreamQueued), and
[PCM submission](https://wiki.libsdl.org/SDL3/SDL_PutAudioStreamData).
