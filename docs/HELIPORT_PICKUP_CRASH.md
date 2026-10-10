# Heliport Chaff pickup crash

The user's Xbox recording reproduced an access violation in the original item
actor's completion callback. The native build now dispatches an inline script
block as a block, preserving the pickup behavior and authored script update.

## Recording and reproduction

The original `.local/replays/xbox-01.mgsinput` remains unchanged:

- SHA-256: `1c0a6f36ff8ab1019f9e17c84ab999f42b587a5d84b25d7964a98fc008aeb1be`.
- 3,809,280 bytes: 15,675 complete input samples and a 172-byte partial row.
- Last complete sample 15,674, VSync 15,678, stage `s01a`, game tick 8,409,
  position `(-8290,1093,6622)`, health 256, Stealth equipped, Very Easy difficulty.
- No clean end record. This is an incomplete recording, not a successful full
  replay.

Its campaign sequence includes `s00a → d00a → d01a → s01a`. The human recording
and matching replay establish that authored dock-to-heliport route on this
difficulty with bonus inventory. Other routes and the rest of the campaign
remain unverified.

A separate diagnostic copy contains the complete rows and a synthetic endpoint
at their last completed input boundary. Its session metadata records the
original hash and recovery limits. The diagnostic replay checks every retained
sample normally, then holds the last two-port controller packet for 120 extra
VSyncs. These added inputs have no recorded checkpoints and are explicitly
labeled unrecorded. The run returns failure at its diagnostic limit rather than
claiming the damaged recording is complete.

The old item dispatch reproduces `PROC ... NOT FOUND` and an access violation
beyond the retained prefix. The address changes with process layout; the script
bytes and calling actor identify the same failure. The debugger stack is
`item.c Die → GCL_ExecProc → GCL_ExecBlock`, with a read at address `00000003`.
[Original trace](../build/xbox-crash/replay-original.log).

## Cause and repair

The heliport Chaff Grenade item at `(0,1000,7000)` has an inline `-x` callback
which assigns scenario byte `00007B` from byte `000000`. After collection, the
item displays its message; destruction then runs this callback.

The [item destructor](../vendor/mgs/source/game/item.c) used a signed address
test: negative values meant PS1 script addresses and nonnegative values meant
procedure IDs. Original MIPS at `80033FEC` uses the corresponding `bgez` branch.
Native Windows addresses can be positive, so a script pointer was passed as a
nonexistent procedure number. The null block lookup plus three bytes caused the
invalid read.

The native branch now distinguishes the original 16-bit procedure-ID range from
block pointers, following the native delayed-command actor's existing convention.
The nonnative branch retains the original signed test. Cleanup order and script
content remain intact; the callback is executed, not suppressed. Reproducible
patch: [mgs-item-callback-native.patch](../patches/mgs-item-callback-native.patch).

## Validation

The regression extracts the actual item structure and destructor from vendor
source. Its 104 cases cover cleanup order, all item states, absent callbacks,
procedure-ID boundaries, native pointers and PS1-style negative addresses. The
old dispatch fails the same test; the correction passes.

The fixed live replay matches all 15,675 retained samples. At game tick 8,415,
the debugger observes the Chaff inline callback with destination byte `00` and
source byte `80`. It survives the 120-VSync diagnostic tail; the destination is
then `80` at tick 8,469. The terminal failure is the deliberate incomplete-movie
limit, not an access violation. [Fixed trace](../build/xbox-crash/replay-fixed-observed.log).

The recorder now flushes each completed row. A concurrent-reader test verifies
that rows are available before closing the writer; the footer-only predecessor
fails that test. This reduces process-crash buffer loss without promising
power-loss durability or inventing an endpoint for a crash. The parser suite
has 944 checks. Ten adapter contract cases distinguish successful complete
replay from diagnostic-tail failure.

The rebuilt default Debug executable passes all 103 CTest suites.
[Test log](../build/xbox-crash/final-ctest.log). Bootstrap verifies all 57 MGS and
15 PsyZ patches. The original recording's SHA-256 is unchanged after validation.

Scoped first-party scans report no findings. The item source retains inherited,
nonfixable function-length warnings for `Act` and `GetResources`; `cppcheck` is
unavailable. These warnings are unrelated to the repaired dispatch condition.
