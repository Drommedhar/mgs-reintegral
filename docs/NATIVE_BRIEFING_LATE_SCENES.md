# Briefing portrait and panel scenes

Thirteen original briefing routines are recovered in `graph_scenes_late.c` and `graph_late_animation.c`: `800D5E54`, `800D5ED0`, `800D674C`, `800D693C`, `800D69A8`, `800D6F98`, `800D70A4`, `800D75F0`, `800D8060`, `800D0234`, `800D02F4`, `800D1BDC`, and `800D26E4`. The biography and smoke scenes use three additional focused C files.

The recovered code preserves portrait changes, caption reveals, dialogue-scene state transitions, sound cues, and the five-panel animation. The panel sequence uses a typed table for its original timing and positions. Original `Work + 0x8000` accesses and pointers into adjacent PS1 structures are expressed as actual fields and array indices, so enlarged native polygon packets do not shift game state accidentally. Japanese texture-label hashing retains the original bytes.

`mgs_brf_late_test` compares **14,364 synthetic cases** against the original Integral instructions. It covers every frame from -32 through 1,408 for the panel animation with four initial-data patterns, every biography frame from -32 through 1,040, short-coordinate boundaries, fade boundaries, reveal sounds, scene states, entry flags, texture changes, and ordered calls into shared briefing helpers. All cases pass. Comparison includes 75 polygon payloads, depth and glyph-presence arrays, scene state, and animation counters; native pointer tags are excluded from byte comparison.

Shared engine/helper calls are controlled consistently on both sides. These are function and state-transition comparisons, not proof that the entire briefing plays correctly. Full-stage linking and runtime evidence are tracked in the project progress ledger.

The source scan has no errors or fixable warnings. Four nonfixable warnings identify the long original scene switches. The test scans without findings.
