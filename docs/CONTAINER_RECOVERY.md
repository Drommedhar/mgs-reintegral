# Container and Raven actor recovery

The `s15c` container actor is now native C, including damage, model replacement,
falling panels, collision updates, impact noise/vibration, item drops and saved
state. The accompanying Raven actor is recovered separately in
[VALCAN_RECOVERY.md](VALCAN_RECOVERY.md). This stage's original 16-entry constructor
table does **not** instantiate Raven; recovery of that actor alone does not prove
the Raven boss stage is playable.

## Original evidence

The supplied Integral Disc 2 overlay is 131,720 bytes at offset 46,100,480 in
`MGS/STAGE.DIR`, loaded at `0x800c3208`. Its SHA-256 is
`7a6d398f600f359a04b8d9fcb7c006fdc888f4fcbdffd761e09ef4a932195483`.
All 26 vendor assembly blocks, containing 5,997 instruction words, match that
image. Eleven blocks belong to Raven; the remaining blocks implement containers.
The block named `s15c_dyncon_800D7A84` is the tail of the preceding actor update,
not an independent missing function.

The actor remains exactly `0x4170` bytes, with explicit arrays for 72 container
entries, eight panels, four tops and four fragments. Dynamic collision storage
has five rows, as used by the original code. Typed fields replace arithmetic
through unrelated structure members and assumptions about adjacent C globals.
The retail shared globals are availability at `0x800e3448`, collapse phase at
`0x800e3458`, destruction state at `0x800e3468`, and Raven position at `0x800e3470`.
Several vendor labels were shifted four bytes relative to those actual accesses.

## Validation

- Eight fixtures execute the original geometry instructions and compare every
  output byte of four collision walls and two floors, including rotations,
  translation, inverted bounds and a degenerate volume.
- 133 fixtures execute the original actor/setup instructions and compare native
  state plus the ordered engine-call trace. They cover all collapse phases and
  four quadrants, 50-tick fall/impact sequences, item drops, damage clamping,
  hit thresholds, saved-state modes, object setup and serialization.
- Engine boundaries are controlled in the state fixtures. Their transform model
  uses identity rotation; this does not test complete rendered object motion.
  Geometry has its separate real-GTE comparison described above.
- The optimized 486-game-source build links and passes all 35 CTest suites,
  including the 352 independent Raven navigation/damage fixtures.

The reference harnesses and raw traces are retained locally in
`build/s15c-audit/reference_geometry.py`, `reference_state.py`, and their output
files. Checked-in fixture constants contain no disc image. Tests include the
actual recovered C definitions, not a second implementation of their behavior.
[Machine-readable provenance](data/s15c_recovery.json) records constructor hashes
and patch checksums.

Retail serialization packs 40 state values, including the first four entries
of the following previous-damage array. Native C preserves that defined byte
sequence with a bounded copy. Two retail writes to an unused twenty-first
argument have no observable callback effect and are omitted. Missing saved-state
lists in malformed scripts now fail resource loading; target allocation failure
also returns an error instead of dereferencing a null target.

The `s15c` story242 fixture runs 900 VSyncs, observes native container mode3,
passes 2,996 horizontal movement units over 24 movement ticks, and renders Snake,
containers and radar. It uses the original saved pose from `sub_13CE` with an
explicit empty serialized damage state. [Fixture](../tests/fixtures/s15c_story242.cdb),
[log](../build/s15c-audit/story242.log), [capture](../build/s15c-audit/story242.bmp).

A second explicit save-state fixture fills all 40 serialized values with damage5.
The original mode3 restore path loads that state, completes 900 VSyncs and again
passes 2,996 movement units over 24 movement ticks without an access violation.
This is an authored maximum-damage fixture, not an existing player save or an
in-game destruction sequence. [Fixture](../tests/fixtures/s15c_collapsed.cdb),
[log](../build/s15c-audit/collapsed.log), [capture](../build/s15c-audit/collapsed.bmp).

Two earlier checks are retained as failures: the default story0 entry remains
inside its introduction at 1,800 VSyncs, and story219 requests model `d1cd.k`,
which is present in `s15a` but absent from `s15c`. That mismatched story/resource
fixture faults while constructing its wall actor. No missing-model fallback was
added. These results do not establish connected campaign progression or human
playability.

## Modding and review

Model identifiers remain original resource hashes, while positions, collapse
states and effects are ordinary C fields and functions. Renderer calls continue
through the existing object/graphics boundary; no proprietary executable code is
called. Loose resource overrides and the replaceable renderer remain available.

Scoped Aislop checks report no errors or fixable findings. Three non-fixable
parameter-count warnings retain the original helper signatures for comparison.
The host scan also reports generic C11 secure-CRT policy warnings on bounded
`memset` and constant-format `fprintf`; these are not buffer-bound failures and
have not been suppressed.
