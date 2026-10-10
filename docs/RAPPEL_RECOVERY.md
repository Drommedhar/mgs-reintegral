# Rappel and its helicopter

`s11d` now builds and runs as native C. Its remaining 37 assembly blocks have implementations: twelve helicopter routines and twenty-five rappel routines, covering 5,786 original instruction words. The checked source matches the 60,856-byte Integral Disc 1 overlay. Its ten constructor entries were already named upstream and required no new bindings.

The [helicopter](../vendor/mgs/source/overlays/s11d/chara/hind/hind.c) preserves its seven routes, banking, hover phases, targeting modes, gunfire, messages and timed destruction. The recovered 2,428-byte actor contains seven 32-point route arrays; the earlier partial declaration overlapped the first route with an extra counter. Native polygons use complete pointer headers, and invalid route lengths or missing resources reject construction.

The [rappel actor](../vendor/mgs/source/overlays/s11d/chara/rope/rope.c) preserves the original 4,248-byte layout, motion controller, collision handling, camera, pendulum calculations, jump input, damage/death states, voice and GCL continuations. Typed native callbacks replace MIPS function addresses. Upper/lower rope meshes and the shadow use native packets. The original vibration sequences and helicopter gun offset are represented by typed arrays/vectors with the same bytes and values.

Two tests compare recovered C with independent execution of the original MIPS instructions:

- `mgs_rappel_test`: 1,536 cases covering flight, banking, bobbing, hover phases, messages and all four targeting modes. Comparisons include complete actor state and ordered engine-boundary traces.
- `mgs_rope_test`: 1,280 cases covering contact/rope angles, both pendulum axes, hanging mesh geometry and jump impulses. Original integer math remains active, including the original square-root instructions; the MIPS harness supplies the hardware leading-zero registers. Comparisons include complete actor state, primitive geometry and sound/vibration traces.

Allocation, world transforms, rendering and other engine boundaries are isolated in these fixtures. They are not a complete state-machine or encounter test. All five stage translation units also pass a standalone `-Wall -Wextra` syntax check without warnings, and the complete Debug game links.

[The runtime fixture](../tests/fixtures/s11d_story178.cdb) uses story 178 and the original `s11g` procedure `sub_E9FB` incoming position `(-3000,23000,-13500)`, heading 2048, map `7df9`. The preceding authored rope-item trap selects this story state. The fixture initializes that checkpoint and observes constructors; it does not force later state transitions.

In a 1,800-VSync Debug run, the original script constructs Rope and Hind, the arrival animation reaches its rest controller, and the incoming Codec closes normally. Ordinary Right input then moves Snake 2,320 units over 35 game ticks, including 25 movement ticks and two collision ticks. The image shows Snake suspended against the tower, rope geometry and active helicopter gunfire. The run exits cleanly without a native exception. Evidence is in `build/movie-audit/rappel178.log` and `rappel178.bmp`.

This run validates entry and lateral control. It does not validate the complete descent, jump sequence, landing transition, every damage/death branch, continuous campaign arrival or human playability. The first generic Up probe overlapped the incoming Codec and recorded no input frames; it is not evidence about climbing behavior.

The scoped Aislop scan has no errors or fixable warnings. Eleven nonfixable complexity findings remain: ten long recovered routines retain the original branch structure, and the existing `rope.c` exceeds the file-length threshold. The test/helper scan has no findings. Exact block addresses, test scope and runtime evidence are recorded in [the ledger](data/s11d_recovery.json). [The incremental patch](../patches/mgs-rappel.patch) contains only this overlay's source and native headers; original disc assets remain untracked.
