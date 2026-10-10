# Native campaign disc change

The original `change` stage now opens a virtual drive, inserts the supplied
second image, waits for Start and runs its original disc-identification and
scenario callback. Windows-specific image selection is in
[`mgs_disc.c`](../src/mgs_disc.c). The recovered actor retains its UI, timing,
filesystem reset and transition script.

```powershell
./tools/run.ps1 -Configuration RelWithDebInfo `
  -Disc 'D:/games/Integral-disc1.cue' -DiscTwo 'D:/games/Integral-disc2.cue'
```

When available, `run.ps1` obtains Disc 2 from the imported `disc2/manifest.json`.
The executable accepts `--disc-two` directly. Images remain read-only. The native
boundary reports a missing or invalid image explicitly. Both supported Integral
images still undergo content validation; the original actor checks that the
inserted image is Disc 2. Reverse swapping and an interactive image picker are
not implemented.

## Runtime evidence, 9 October 2026

An optimized 2,400-VSync run started with `--stage change --probe disc-change`
and both original CUE paths. It used no debugger edits to game variables. The
SDL virtual controller supplied Start; the original actor opened/closed the
drive, accepted the volume check, rebuilt filesystem positions and identified
Disc 2. Its original `sub_1F7C` callback set the disc variable and called
`sub_DECC`, which loaded `s13a` with map `4986` and position
`(7724,19536,10932)`.

The probe observed both fully loaded stages in order, player readiness at frame
1,121, 57 directional input frames, 27 movement ticks and 3,112 horizontal units
of movement. It completed normally at frame 2,400. The inspected capture shows
Snake on the furnace stairway.

- [Runtime log](../build/late-stage-audit/disc-change.log)
- [Final capture](../build/late-stage-audit/disc-change.bmp)
- Original `change` GCX SHA-256:
  `8c817e9ee47433ccd1b15099854c21899735d15d755c47a07287f4c5ef87c472`

This establishes the authored **change → Disc 2 → furnace** handoff from a
development entry. It does not establish the full campaign route into `change`
or human playability. An earlier independent furnace fixture supplied the
incoming position from `s12c`; that fixture remains separately recorded in
[`s13a_incoming.cdb`](../tests/fixtures/s13a_incoming.cdb).

## Regression coverage and limits

The `disc_change` CTest uses two synthetic valid raw-sector images. It checks
lid status, actual sector reads before/after insertion, the second executable
identity, track information and native safety validation. The safety suite
accepts the original volume-descriptor request at LBA 16 while rejecting the
adjacent position and a corrupt stage table.

The complete optimized build passed 27 CTest suites. Scoped authored-code
aislop scanning reports no findings; the recovered disc actor retains one
nonfixable warning for its 317-line original state machine and two inherited
structure-duplication FIXME comments. Missing scanner engines remain documented
in [validation](VALIDATION.md).
