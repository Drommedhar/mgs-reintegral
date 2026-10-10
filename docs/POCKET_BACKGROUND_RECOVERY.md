# PocketStation background recovery

The rank overlay's `pkt_back.c` is native C, including all **28 previously missing assembly blocks (1,961 instruction words)**. Every upstream instruction word was checked against the user's Integral Disc 2 `rank` overlay; no mismatches were found. The constructor is `0x800D0DA0` and its actor remains 108 bytes.

The implementation restores the three scrolling, fading, and zooming texture layers, their queued state changes, the 96-frame exit fade, primitive allocation, and actor cleanup. It retains the original integer arithmetic, texture hashes, phase boundaries, and draw depths. The background does not read the PocketStation score table.

- [Recovered actor](../vendor/mgs/source/overlays/rank/chara/pocket/pkt_back.c)
- [Typed actor/node layouts](../vendor/mgs/source/overlays/rank/chara/pocket/pocket_native.h)
- [Instruction inventory and evidence](data/pocket_back_recovery.json)

## Native adaptations

FT4/GT4 arrays use their native structure sizes and preserve the complete packet length when copying packets or changing draw depth. Node links now check absent neighbors, and the unused smooth primitive can remain null. The original PS1 code wrote through null list links and read the unused primitive from low memory; Windows cannot use those addresses.

Failed packet allocation removes its newly allocated node. Missing required textures and invalid random crop ranges terminate with a concrete diagnostic. The zoom denominator is the original integer `200` at `0x800CB434`; the raw decompiler incorrectly described it as an element past a neighboring bitmap. Back and entry texture setup share the same recovered helper, with its texture-null check moved before dereferencing the texture.

## Validation

[mgs_pocket_back_test.c](../tests/mgs_pocket_back_test.c) compares live source against **2,822 original-MIPS cases**: 510 animation states, 512 crop/zoom cases, 264 state/queue cases, 512 RGB fades, 512 primitive copies, and 512 real texture-initialization cases. The fixtures include phase boundaries, negative and overflowing short coordinates/timers, both native polygon layouts, invisible packets, saturated queues, and untouched packet fields. Native allocation tests also exercise initial allocation failure, packet allocation failure, the eight-node limit, and head/middle/tail removal.

The private reference generator executes the original instructions. Animation tests replace texture lookup, texture initialization, and random cropping with recorded boundary calls; geometry, state, fade, and packet-copy logic execute directly. Separate texture cases execute the complete original texture helper with a synthetic texture descriptor. The regular CTest target is `mgs_pocket_back_test`; tests require no game assets.

Scoped Aislop scans report zero errors, warnings, or fixable findings for the actor/header and test/preparation script. These comparisons establish the covered state and packet behavior. Full rank-stage rendering, menu interaction, and PocketStation transfer flow remain part of the parent integration work.
