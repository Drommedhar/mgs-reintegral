# Tank completion path

The selected `s05a` Tank resource cleanup and victory calls match the original
Integral instructions in **1,260 differential cases**. Native teardown now also
unregisters its camera callbacks before releasing the Tank, fixing the user's
post-fight crash. This is bounded cleanup evidence, not proof of every Tank AI
or collision path.

## Camera teardown crash, 9 October 2026

The invulnerable recording `run-20261009-165718-122.mgsinput` reaches the Tank's
victory cleanup. The debugger reproduces a null read at `s05a_800E1D7C + 0x58`
after all 5,823 input samples / 5,827 VSyncs match. The director has cleared
`s05a_dword_800C362C`, but the main camera still calls the Tank callback, which
reads the director's `E5C` field.

The main camera runs at `GV_ACTOR_ASSIST`; the Tank director and its camera run
later at `GV_ACTOR_USER`. Waiting for the Tank camera's next update is therefore
too late. Original overlay instructions at `800E1448..800E1498` schedule deferred
camera destruction, and `800E1A68..800E1AA4` clear only callback slot 1. These
match the recovered code; the native repair is an intentional lifetime change.

The director now removes Tank-owned callbacks from both slots before releasing
resources or invoking script procedures. The camera uses the same idempotent
cleanup when retiring and in its destructor. Original deferred actor freeing
remains in place. Callback pointers and mode bits belonging to another camera
are preserved. Export: `patches/mgs-tank-camera-lifetime.patch`.

Five focused CTests pass. The camera regression runs 24 live/retiring/absent-Tank
cases and a camera-before-director case through the production actor scheduler.
The completion regression asserts camera release before script/resource cleanup
while retaining all 1,260 original resource/victory trace comparisons. The Debug
build matches every recorded input, then survives a bounded 600-VSync tail and
enters the original post-fight cinematic (`NewStream 49068`). The tail exits at
its diagnostic limit, not with complete-movie success; the cinematic's remainder
and arrival at `s06a` are still for the user's playthrough. The old snowfield
checkpoint and source movie remain unchanged.

Local artifacts: `build/tank-next-crash-20261009`. Scoped Aislop has no errors or
fixable warnings; nine inherited vendor size/complexity warnings remain,
confirmed against the preceding patch stack. `cppcheck` is unavailable.

## Gunner retirement crash, 9 October 2026

The user's `run-20261009-163917-586.mgsinput` starts from the authentic cached
snowfield entry and reaches the Tank fight. After 10,487 input samples / 10,491
VSyncs, the native debugger catches a null read in `s05a_800E00EC`: the gunner
actor still exists during its death animation, but its target was freed and
cleared by `s05a_800DDF18`. The aim helper dereferenced that cleared target.

Retail overlay instructions at `800E0154..800E0194` check the gunner actor,
then read its target at offset `1C0` and center at offset `8`, with no target
null check. The native correction deliberately treats a removed gunner target
like an absent gunner: grenade assist uses the existing Tank-position branch,
and both blast hooks skip the removed target while retaining Tank-body handling.
Actor destruction and the gunner replacement/victory lifecycle remain intact.
The change is exported in `patches/mgs-tank-gunner-retirement.patch`.

The new regression exercises absent, dying and live gunners, all six aim
motions, the Tank-position fallback and blast reset paths during retirement.
The repaired build matches all 10,487 original input checks with invulnerability
disabled, then survives a bounded 600-VSync held-input continuation past the
previous crash. That continuation ends deliberately with the diagnostic-tail
status; it is not a successful complete movie or proof of Tank completion.
Artifacts are in ignored `build/tank-crash-20261009`.

## Original encounter contract

The locally supplied Disc 1 `s05a/ea54.g` creates class `9d71` with `-z sub_273D sub_2213` in all four difficulty branches. `NewM1E1` stores these as the restore and victory procedures at actor offsets `E1C` and `E20`. The restore procedure is empty in this script. The victory procedure sets the entry map to `7df9`, updates story state to 68, disables the menus and schedules a restart after 15 ticks. The story-68 branch then enters the post-battle cinematic; its completion sets story 69 and loads `s06a`.

The director observes the gunner's death state at offset `1F0`, decrements the remaining gunner count and enters mode 5 after the last gunner. It starts a 30-tick fade and destroys itself when that timer expires. The destructor always releases its owned resources; it invokes the victory procedure only in mode 5 with a nonnegative procedure identifier. Cancellation must therefore preserve cleanup without advancing the story.

This script interpretation and the director's terminal branch were inspected against the local source and original instructions. The automated comparison below executes the destructor, not the enclosing combat simulation or GCL procedure bodies.

## Differential evidence

The reference executes original MIPS `800D5E30..800D6278` from `s05a/473b.b`, loaded at `800C3208`. Overlay SHA-256: `fd08923d1e1ad01b8638f7e8f4a101e270a5f399f3d1afed47abca7532a8c081`. The script SHA-256 is `660d4b420129719a1cd69be567462fb3bf01be708b793e2f2775f968250a1107`.

The native test extracts the actual selected actor layout and destructor from [m1e1act.c](../vendor/mgs/source/overlays/s05a/kojo/m1e1act.c). It checks the original `0x139C` actor size and callback/collision offsets. Both reference and native runs observe external calls without executing the allocator, collision manager, child destructors or GCL interpreter. Their ordered traces include:

- Optional destruction of both child actors, with the global hook state sampled at each call.
- All five arguments passed to the restore procedure, including signed, sequential integer divisions and speed conversion.
- All 20 dynamic segment and 10 dynamic floor removals, followed by seven object frees, eight target frees and control cleanup.
- Clearing all five engine callbacks, grenade-motion override and the current Tank pointer; invocation of the victory procedure after cleanup.

Cases cover modes 0, 1, 4, 5 and 6; absent, zero and positive procedure identifiers; all four child-presence combinations; and seven negative, zero and positive acceleration/speed inputs. The harness also verifies that the actor's own memory remains unchanged when external calls are isolated. Each fixture records a hash and length of the complete integer call trace, with native pointers normalized to actor offsets or target/child indices.

[The regression](../tests/mgs_tank_completion_test.c) passed all 1,260 original-MIPS comparisons in an isolated Windows x86 build. A negative control changing only the victory condition from mode 5 to mode 4 failed at fixture 532. That initial audit left the vendor source unchanged; the later camera-lifetime repair above adds separate native callback cleanup without changing these resource/victory traces.

The checked-in fixtures contain only derived trace metadata. Regeneration requires the user's original overlay and Unicorn:

```powershell
.venv/Scripts/python.exe tests/generate_tank_completion_fixtures.py `
  --overlay .local/recovery/s05a/473b.b `
  --output tests/mgs_tank_completion_fixtures.h
```

The next meaningful Tank acceptance is an ordinary-input encounter through both gunners, the real story-68 restart/cinematic, and entry into `s06a`. These tests alone establish none of those connected runtime outcomes.

## Runtime entry caveat and next encounter check

The existing [story-65 debugger fixture](../tests/fixtures/s05a_story65.cdb)
changes only the story variable. It is an entry fixture, not a faithful incoming
campaign state. Direct `--stage s05a` redirects the original `init -> title`
load in [mgs_stages.c](../src/mgs_stages.c), so the title never resets the
initialization loadout. The original Disc 1 script, locally decompiled at
`build/campaign-audit/init.gcl`, calls `sub_65D5 -> sub_2151`: all ten weapons
have 99 rounds, grenade capacity is 10, chaff capacity is 5, Rations are 3/3,
and stealth, bandana and body armor are owned. Snake starts unarmed and
unequipped with 256/256 health and Easy difficulty. This is established from
the initialization and stage source paths, not a new runtime measurement.

At the initial audit, no authentic pre-Tank or `s05a` checkpoint was found in
the inspected recordings. The user's 9 October playthrough now supplies one:
`run-20261009-161256-777.mgsinput` reaches the snowfield from the prison without
development stage overrides. Its strict 54,470-input prefix exports a cached
`s05a` entry with the recorded inventory and Very Easy difficulty. The run
then exposed a [claymore trajectory crash](STAGE_RECOVERY.md#snowfield-claymore-crash),
now fixed. This establishes a connected arrival; Tank fight completion remains
unverified. Future checks must retain that provenance and avoid substituting
the old fixture's 99-round loadout.

The original story-65 intro calls `sub_A4AD`, which supplies story 66, map
`0041`, Snake at `(-1000,0,18000)` facing 2048, and two 640-health gunners via
restart. The battle supplies grenade boxes at `(-9000,-1000,-15000)`,
`(-5000,-1000,-25500)`, `(10500,-1000,-17500)` and
`(10000,-1000,-11000)`, each containing four grenades. Chaff boxes at
`(-12250,-1000,-10750)` and `(10500,-1000,-20000)` contain three each.
Rations are at `(-8000,0,19000)` and `(6000,-1000,-21000)`, with another at
`(-9500,-1000,-7750)` on Easy. These are script coordinates, not validated
navigation waypoints.

An input driver should collect supplies, use normal inventory and throw
controls, and observe gunner replacement and damage cooldowns. On Normal,
the original grenade assist accepts launch distance up to 11000 and facing
error within approximately 50 degrees. Grenades begin with a 120-actor-tick
fuse; holding cooks it, and menus/cinematics suspend the thrown actor's fuse
progress. After both gunners die, the driver should cease input and observe
the real story-68 restart, both outgoing demos, and story 69 entering `s06a`
at `(7500,4000,22000)`. Strict replay and a valid original map-entry export
should follow. No new Tank gameplay discrepancy, controller, fixture or
completed encounter was produced by this read-only audit.
