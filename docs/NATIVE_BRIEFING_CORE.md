# Briefing drawing helper comparisons

`mgs_brf_core_test` passes **9,404 original-MIPS cases** against the live native C in `graph_fog.c` and `graph_metrics.c`:

- 5,040 fog cases cover both normal routines, white fog, all phase values, fade boundaries, unchanged out-of-range frames, and aliased polygon arguments.
- 1,548 face-animation cases cover negative counters and two complete 128-frame cycles.
- 512 coordinate-display cases check both single- and paired-polygon bounds, negative coordinates, digit clipping, and varying texture dimensions and origins.
- 768 geometry cases check signed packed coordinates, scales, positive and negative divisors, and zero through six geometry entries.
- 1,536 timed-geometry cases check stop flags, the exact limit frame, state updates, and positions before and after the limit.

The fixtures contain synthetic inputs and hashes of original instruction results. Tests compare actual native polygon payloads and state fields, with controlled texture lookup and the same digit-clamping contract on both sides. Native pointer tags are excluded. These results do not substitute for full briefing playback or visual inspection.

No source changes were needed to pass these comparisons. The test scans without findings.
