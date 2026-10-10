The REX phase-completion routines and Liquid victory routine match the supplied Integral Disc 2 instructions in **964 new state-and-callback comparisons**. This check found no missing terminal callback or incorrect recovered behavior, so it changes no gameplay source. It does not establish that a full boss fight has been completed.

[The native test](../tests/mgs_boss_terminal_test.c) extracts the actual recovered bodies using [the preparation helper](../tests/prepare_boss_terminal_test.py). Its expectations come from [independent original-MIPS execution](../tests/reference_boss_terminal.py), not a second implementation of the state machines. The fixtures contain synthetic input/output hashes and metadata, with no executable or game-asset bytes.

| Routine | Cases | Behavior compared |
| --- | ---: | --- |
| `RexFunc_800DB268` | 432 | The 33-tick boundary, motion-request acceptance, signed shake interpolation, health bar, game-over suppression, both ordered messages, complete actor snapshot, deferred destruction and first completion callback |
| `RexFunc_800DB478` | 432 | The 40-tick boundary, alternate motion request and completion callback, game-over suppression, snapshot/destruction order and distinct game-status clearing |
| `liquid_800CE6B4` | 100 | First-tick callback only, absent/zero/positive procedure identifiers, later ticks, animation 29, and rereading the counter after a callback changes it |

Every case compares all 6,904 REX actor bytes plus all 6,904 snapshot bytes, or all 2,636 Liquid actor bytes, together with game status and the ordered external-call trace. The REX motion-transition helper and resident `GV_NearExp8` execute their real implementations on both sides. Only RNG, health-bar drawing, messages, deferred actor destruction and GCL execution are controlled boundaries. Callback doubles deliberately mutate the counter and status in half the inputs to check call ordering and post-callback reads. The routines' unused return-register artifacts are not part of the assertions.

The executable ranges were compared directly with the extracted retail overlay bytes before generating expectations:

| Original range | Instructions | SHA-256 |
| --- | ---: | --- |
| `800DB268..800DB478` | 132 | `ff51df4a0f6fdea3987f3b5796ed00e368e4229a72d8dad65a40fb7d3efb7f13` |
| `800DB478..800DB63C` | 113 | `f2a4261eb6d428ed3e9f0b1816ca5af7c5da579225e86ea458e91ff7a9fbc3f5` |
| `800CE6B4..800CE710` | 23 | `2441e01c17de0341fcd6da6c597bbd2ecfa4b7eb5582b8efd3b017696588b55b` |

The original REX script supplies `sub_1E04` for both `-z` callbacks. That procedure sets the stage flag and invokes `restart`. [RestartCmd](../vendor/mgs/source/game/script.c:701) calls [GM_SetLoadCallbackProc](../vendor/mgs/source/game/gamed.c:666), producing request `0xC0`; the [loader condition](../vendor/mgs/source/game/gamed.c:614) consequently preserves the overlay and `RexDefaults`. The native overlay reset therefore does not erase the snapshot on this path. Liquid's `-e sub_EAEE` sets story 278 and `STATE_PADRELEASE`, fades, and schedules the same-stage restart after 18 ticks. These are source/script checks; the new test stops at the GCL boundary.

Standalone Windows x86 compilation passed with `-Wall -Wextra -Werror`, and all 964 comparisons passed. A negative-control copy that removed only Liquid's `GCL_ExecProc` call failed at kind 2, seed 5, with different state and a missing five-word callback trace. The tracked gameplay source was untouched. Scoped Aislop checks report 100 with zero findings; the C scanner reports that optional `cppcheck` is unavailable.

Reference regeneration needs the user's private resident-plus-overlay images and Unicorn:

```powershell
.venv/Scripts/python.exe tests/reference_boss_terminal.py `
  --rex-image .local/recovery/s17a/s17a.analysis.exe `
  --liquid-image .local/recovery/s18a/s18a.analysis.exe `
  --output tests/mgs_boss_terminal_fixtures.h
```

Later ordinary-input scenarios complete the supplied Normal Liquid retry fight,
its post-fight scenes and garage entry; see [Liquid runtime evidence](LIQUID_RECOVERY.md).
REX's full victory remains unverified; its best supplied scenario leaves the
cockpit with 136 health. These terminal unit tests remain distinct from those
runtime results. The broader selected-source audit did not establish another
missing active stage-function body; inactive assembly branches, original no-ops
and decompilation matching comments must not be counted as missing native code.

## Torture round, recovery, and surrender

The subsequent completion audit adds **2,432 original-MIPS comparisons** for
the reused `s03b` torture actor. Its round handoff, Circle recovery and Select
surrender behavior agree with the supplied instructions; no gameplay repair is
justified by these checks.

| Executed production routine | Cases | Coverage |
| --- | ---: | --- |
| `s03b_torture_800C5AF8` | 1,536 | Entry animation and one-argument script callback, intermediate/final rounds, pending recovery, voice completion, next-action scheduling, final mode message and original completion-message reader |
| `s03b_torture_800C3EB8` and `800C5E48` | 768 | Recovery flag gating, pre-increment timer argument, Circle press, signed health and 16-bit addition, maximum-life clamp, expiry clearing |
| `s03b_torture_800C4314` | 128 | Select press, blocked surrender after completion, state/counter update and returned acceptance |

[The test](../tests/mgs_torture_test.c) extracts the actual production actor
layout and function definitions with [prepare_torture_test.py](../tests/prepare_torture_test.py).
It compares all 2,308 actor bytes, game status, ordered calls and the surrender
result. Pointer identities are normalized. Animation configuration, script
execution, voice completion, RNG, outgoing messages and HUD destruction are
controlled boundaries; the real incoming-message reader executes on both
sides. Some script callback doubles set the recovery flag to verify that the
handoff rereads actor state after the callback. No stage resources or original
instructions are stored in the fixture header.

The original source is Disc 1 `s03b/46fc.b`, offset **16,111,616**, size
**66,980**, loaded at `800C3208`. Its SHA-256 is
`cd728e144c960e7419d389c81802d3de73c00a2f31e9bfd7eea33ed3ed2be083`.
[The reference runner](../tests/reference_torture.py) uses the private
resident-plus-overlay image `.local/recovery/s03b/s03b.analysis.exe`:

```powershell
.venv/Scripts/python.exe tests/reference_torture.py `
  --image .local/recovery/s03b/s03b.analysis.exe `
  --output tests/mgs_torture_fixtures.h
```

Win32 optimized compilation and all comparisons pass. Replacing only the
recovery dispatcher's timer argument with zero in a private extracted copy
fails kind 1, seed 8. The tracked gameplay source is unchanged. Scoped Aislop
checks, including separate copies of reference/fixture files excluded by the
normal scanner, score 100 with no findings; cppcheck and clang-tidy are absent.

This verifies the selected subroutines and their boundary contracts. A complete
live torture session, its shock/health-loss timeline, both resulting campaign
branches, and later prison escape remain outside this regression.
