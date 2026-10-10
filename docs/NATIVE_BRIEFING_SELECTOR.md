# Briefing selector recovery

The `brf` selector's ten assembly-only functions now have native C implementations. The original Integral `brf/96a7.b` overlay loads at `800C3208`; all ten source assembly blocks match the extracted original. This document covers the selector, not the separate briefing scene/graph actors.

| Native suite | Original routines | Cases |
| --- | --- | ---: |
| `mgs_brf_draw_test` | `C62B0`, `C6E88`, `C731C`, `C7488`, `C75F0`, `C7B94` | 9,583 |
| `mgs_brf_state_test` | `C829C` | 16,224 |
| `mgs_brf_decode_test` | `C56C0`, `C5A68` | 2,304 |
| `mgs_brf_init_test` | `C99C0` | 384 |

All 28,495 fixtures compare native code with original MIPS execution. Geometry tests preserve packet payloads and actor state while accounting for native ordering-table tags. State tests cover all 38 authored states plus the default state, input priority, transition timers, callbacks, script arguments, and ordered calls to controlled actor/audio/graphics boundaries. Decoder tests use synthetic palettes and packed runs, cover both pixel formats, odd palette sizes, bit widths, absent cache IDs, and scratch-buffer wrap. Constructor tests cover all 128 combinations of seven GCL options and the 53 texture bindings. Public fixtures contain synthetic inputs and results; executable and retail resource bytes remain private.

The implementation splits loading, decoding, initialization, packet geometry, reveal animation, navigation helpers, and the main state machine into separate translation units. The original 40-byte `POLY_FT4` layout was checked before translating field accesses; native code uses typed packet indexing. The original scratch region `801CD000..801DFFFF` becomes the corresponding `MEM_BOTTOM`-relative region in native RAM. Resource pointers and controller pointers have explicit types, and two/eight-element GCL argument lists use contiguous `long` arrays.

The initial declaration gave completion flags 16 elements followed by 12 padding bytes. Original state 27 also writes index 16 after the introductory briefing; the native declaration names all 19 existing slots without changing the prefix layout. The constructor reports primitive-allocation failure to the actor factory instead of allowing a later null dereference. Invalid compressed-image code widths terminate with a diagnostic rather than executing the original divide-by-zero trap. These two failure-path definitions are outside the original-equivalence fixture count.

Individual selector translation units compile without warnings. The scoped production Aislop scan reports nine nonfixable maintainability warnings: original function parameter counts and long recovered routines, including the main state switch. No error or fixable warning remains. Automated comparisons do not establish a complete briefing playback, rendered output, or human playability; those require the graph actors, retail resources and integrated runtime checks.
