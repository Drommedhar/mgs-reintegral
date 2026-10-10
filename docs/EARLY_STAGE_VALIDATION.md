# Early-stage native validation

On 8 October 2026, the Debug build linked 313 recovered game translation units
for `title`, `s00a`, `s01a`, `d00a`, `d01a`, `s02a`–`s02e`, `s03a`, `s03b`,
`s03c`, `s03e`, `s04a`–`s04c` and `s06a`. This records that build; the selected
stage list may subsequently grow. No original overlay machine code executes.

The eight stages after the `s02` group added 45 C files to the source union.
All 45 compile individually without warnings. The incremental
[early-stage patch](../patches/mgs-early-stages.patch) corrects integer `NULL`
arguments, an obsolete MIPS register binding, pointer signedness and eight
stateful GCL argument-evaluation sequences. Sepia palette iteration is explicitly
sequenced in the native base patch.

## Runtime evidence

Each of the following 13 direct stage entries reached 900 VSyncs under the x86
debugger, completed its initial scenario and exited without an access violation.
They used the original disc and no scripted controller, position writes or story
flag changes. Logs and captures are in
[`build/early-stages-audit`](../build/early-stages-audit).

| Entries | Observed result at the frame limit |
| --- | --- |
| `s02a`, `s02b`, `s02d` | Tank hangar, Snake and active guards; alert UI visible. |
| `s02c`, `s02e` | Tank hangar, Snake and radar visible. |
| `s03a`, `s03e` | Cell-area geometry and radar; camera points at an empty corridor. |
| `s03b` | Resource load and scenario complete; framebuffer remains black. |
| `s03c` | Prison cinematic renders Otacon and Japanese subtitles; multiple authored voice streams advance. |
| `s04a` | Radar and partial geometry/Snake visible, mostly dark. |
| `s04b`, `s04c` | Ocelot arena entrance renders with radar jamming. |
| `s06a` | Warehouse geometry and radar render; sound-distance issue found and corrected as described below. |

These development entries do not supply the authored transition arguments or
prior story state. A black or incomplete direct-entry scene is not counted as
playable. Human movement, natural transitions, torture, boss completion and a
campaign route through these stages remain separate acceptance work.

Repeat an entry with the imported-disc manifest:

```powershell
./tools/run.ps1 -Configuration Debug -Stage s03c -Frames 900 `
    -Capture build/early-stages-audit/s03c-repeat.bmp
```

Earlier, `s01a` naturally requested `d01a`; a 7,200-VSync run advanced its real
DEMO stream and returned to the authored Mei Ling Codec. The local
[`heliport-7200.log`](../build/intro-audit/heliport-7200.log) records changing demo
frames and camera values, stream completion and subsequent Codec voice streams.

## Ocelot progression contract — completion unverified

The retained `s04b.log` and `s04c.log` launch with only `--stage`, `--frames 900`
and capture options. Both show `init` followed by the explicit development-stage
redirect; [smoke.cdb](../build/early-stages-audit/smoke.cdb) sets no gameplay state.
They therefore inherit the original initialization loadout before the title can
reset it, just like the [Tank entry fixture](TANK_COMPLETION_AUDIT.md#runtime-entry-caveat-and-next-encounter-check).
The `init` script's `sub_65D5 -> sub_2151` gives all ten weapons 99 rounds,
Rations 3/3, and ownership of Stealth, Bandana and Body Armor; the fresh-process
state is Easy, unarmed/unequipped, with 256/256 health. This is a source-derived
starting-state finding, not an inventory measurement in those old logs. The
entrance checks must not be reused as ordinary campaign-arrival evidence.

The original Disc 1 `s04c/ea54.g` supplies a concrete next acceptance route:

- Story 37 plays the introduction. Its `sub_E816` callback sets incoming map
  `c248`, position `(-500,0,10500)`, heading 2048 and restarts into story 38.
- Story 38 creates Ocelot with `-e sub_97B5`; Normal difficulty gives him 614 HP.
  In [revolver.c](../vendor/mgs/source/onoda/s04b/revolver.c), lethal damage selects
  state 4/time 0. `s04c_revolver_800D1120` invokes the callback once, provided
  `GM_GameOverTimer` is zero. Baker damage and the wire actors can instead cause
  game over, so boss HP alone is not a sufficient success condition.
- `sub_97B5` sets story 39 and schedules a restart after 32 ticks. Authored
  cinematics then advance 39→40 (`7662`, or `7DFE` after the retry condition),
  40→42 (`8592` then `9790`), 42→44 (fade), and 44→47 (`9B89`), loading `s16c`.

The original `471d.b` instructions at `800D1120`–`800D11C4` agree with the native
terminal callback's arguments, game-over guard and one-shot latch. No discrepancy
was demonstrated, so this audit changed no gameplay code. The meaningful next
check is ordinary-input combat with an authentic incoming save or explicitly
documented finite-inventory scenario, followed by the complete authored handoff.
Neither victory nor that connected transition has been validated here.

Local evidence is `.local/recovery/s04c-progression/scenario.gcl`. SHA-256 of
the original `ea54.g` is
`22b08b8698474de75dc80ced6f82da20af53c90c968d39263023c07a566238c3`;
the original `471d.b` is
`5e6bc0c9b13f009c69c2ebdfb401fe9d55a6cd6ee8610cbdd95ee9f3dd71f32a`.

## Corrections verified against the original binary

The trap-floor grenade branch in `takabe/dummy_fl.c` really is defective in the
original `s04a` overlay: instruction `0x800d649c` clears each grenade pointer,
then `0x800d64a0`–`0x800d64b0` reads address zero. The native-only correction
retains live grenade entries, skips empty slots, transforms their actual
positions and marks grenades inside the open floor. The PSX branch is retained.
This is an intentional original-bug correction, not a claim of instruction
equivalence. That grenade interaction has not yet been exercised in gameplay.
The supplied overlay SHA-256 is
`59b541a13b987478d6717643c3c146018b070fe374ffae0eaaf3f9a8bdc2ffb6`.

In `s06a`, a camera/enemy Z difference of 49,572 exposed the host `Square0`
adapter squaring full 32-bit values. Original `Square0` at `0x80093340` loads
signed 16-bit GTE IR registers, executes `0x4aa00428`, then stores MAC1–3.
The adapter now uses that real GTE operation. Its regression checks truncation,
in-place operation, output padding and GTE register results. No square-root or
game distance formula was replaced. Original instructions and debugger vectors
are recorded in `original-square0.txt` and `s06a-vectors.log` in the audit folder.

## Movie validation

PsyZ lacked VLC and MDEC decoding when the movie actor entered the source union.
The entry runs above did not request an FMV. Subsequent work replaced the
temporary failure boundary with real VLC/MDEC, mixed STR/XA delivery and DMA
completion. A separate original-disc movie component run rendered footage and
reached the actor's end condition. See [MOVIE_VALIDATION.md](MOVIE_VALIDATION.md)
for evidence, source licenses and remaining campaign/timing limitations.

Scoped Aislop checks found no errors or fixable warnings: the 22-file actor scope
retains 44 inherited complexity warnings; the sound diagnostic adjustment retains
two. The GTE scope has one nonfixable warning about an existing, fixed-size
`memcpy` between equal-size matrix arrays. Movie implementation scan results are
recorded with its separate validation evidence.
