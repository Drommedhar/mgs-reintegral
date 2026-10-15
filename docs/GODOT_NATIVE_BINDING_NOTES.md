# Native binding investigation — dock and UI

Source investigation for M0.06 with a separately labeled initial live-provider check below. This is **not the completed public binding contract or SDK acceptance**. See the [coverage matrix](GODOT_PRESENTATION_COVERAGE.md); the historical execution ledger is `docs/GODOT_SDK_PROGRESS.md` in the source checkout.

## Actual dock elevator declaration

`vendor/mgs/source/stage/s00a.c` registers `CHARA_ELEVATOR`, class `0x2abc`, implemented by `NewElevator` in `vendor/mgs/source/takabe/elevator.c`. `CharaCmd` in the script runtime supplies the actor name and current map. The disc-backed dock script is `s00a/ea54.g`, SHA-256 `40e6084b4cbf0c38660c3044238613ad2d7b24442aa2677530df49ef71ac66c8`.

Parsed declaration metadata, with no original script body:

| Field | Value |
| --- | --- |
| Declaration byte offset / length | 5981 (`0x175d`) / 98 |
| Enclosing procedure | `0x053d`, block offset 5894, length 244 |
| Enclosing delayed execution | Command `0x430d`, `-t 2`, nested block; offset 5950 |
| Constructor / actor name | `0x2abc` / `0xb15b` |
| Start / end | `(1000, 0, -28800)` / `(1000, 8000, -28800)` |
| Body model / hazard | `0x6da3` / `0x6da3` |
| Duration / initial progress | `450` / `-450` |
| Absolute coordinate option | `-a 1` |
| Passenger | `0x13e8` |
| Additional hazards | `0x6da4`, `0x6da5`, `0xe224`, `0xe224` |
| Sound mask / callback procedure | `7` / `0xd2b3` |
| Optional secondary model (`-f`) | **Absent** |

Local extraction evidence: `build/godot-sdk-m0/elevator-declaration.json`. Header/options and enclosing procedure were parsed; this was not complete GCX control-flow execution or proof of runtime activation. The callback procedure contains game messages/camera/UI/audio behavior; its body is not copied into this document.

The `0x6da3` body model has five parts, each with parent `-1` and zero rest translation. Its resource SHA-256 is `a2fe959f83e4a81ac0d4f33d698b7bbffdbbe9cd7b1cf7a08a4fd0ffe06fff45`. The user clarified that the target is the railing attached to this platform. It is a separately editable part of the body, not the optional secondary object. Exact editor part labels still need visual verification; do not label a part from bounds alone.

## Generic implementation semantics

These fields describe the current C implementation. A future typed contract should translate verified semantics, not expose opaque field names permanently.

| Internal state (`f5C0`) | Meaning | Callback hash on transition |
| --- | --- | --- |
| 0 | At start endpoint; departure changes state to 1 | `0x361e` |
| 1 | Travelling from start to end; arrival changes state to 2 | `0xadbf` |
| 2 | At end endpoint; departure changes state to 3 | `0xf624` |
| 3 | Returning to start; arrival changes state to 0 | `0xedb8` |

Progress uses `f584 / f580`; `f560` is the start and `f568` is the displacement. The actual dock declaration starts at the upper endpoint and descends. The absolute flag selects `f570`; relative mode uses `f578`. Native code also moves passengers, updates dynamic floors/walls and attached gameplay objects, and invokes the callback. Visual replacement must preserve all of that.

For a declaration that actually supplies `-f`, the generic secondary object follows the body with a vertical offset `f5AC`. `GV_NearExp4` eases that offset toward `-1500` or `0`; values below `-1000` hide the secondary object. Code around lines 423–439 applies its transform. **The parsed dock declaration does not enable this path.**

`HZD_VEC` declares components as `x, z, y, h`. Its member names can mislead when the code casts it to an `SVECTOR`: the assignment to `.z` in that secondary transform is the vertical component in memory. Do not build an anchor conversion from member spelling alone. Message `0x335e` adjusts `DG_OBJ.raise`, a sort offset; it is not evidence of physical bar motion.

### Confirmed railing scope and cinematic evidence

The user explicitly identified the **railing attached to the platform**. Expose separate editable model-part targets, sharing the native platform motion. Independent anchors remain required for genuinely articulated actors elsewhere; do not publish a fictitious dock `door_open` event.

The receipt-checked `tools.audit_godot_cinematics` inventory reads both discs (79 and 40 clips). Model `6da3.k` occurs in two disc-1 clips:

| Stream sector | Model track | Declared frames | Joint counts | Nonzero joint indices |
| --- | --- | --- | --- | --- |
| 5185 | 3 | 1981 | 0, 5 | None |
| 6845 | 2 | 1407 | 0, 5 | None |

`kojo/demoexec.c` applies the track's body transform and joint adjustments. Both tracks keep all five joints at zero while the body moves. Runtime demo incarnation counters are not stream sectors: cinematic bindings must retain the clip source and track identity. The report at `build/godot-sdk-m0/cinematic-coverage.json` contains hashes, resource identities and motion summaries, not original animation tracks. Scenario activation and runtime binding acceptance remain unverified.

See [presentation contract v1](PRESENTATION_CONTRACT.md) for the proposed identity and pose rules. M2 must verify editing, attachment, pause, reload and visual suppression while keeping native boarding, collision and callbacks intact.

## UI drawing has native side effects

- `menu/menuman.c` owns `MenuWork`, initializes radar/radio/item/weapon/life/subtitle modules, invokes their updates under game/pause conditions, and submits primitives. It reads native pad state.
- `menu/item.c` around lines 1110–1180 handles opening the inventory, sets `MENU_LEFT_OPEN`, sets `GV_PAUSE_MENU`, changes quick-equipped items and emits sounds. Navigation, item use and drawing share this update path.
- `menu/weapon.c` similarly owns weapon-menu transitions and selection. Removing its update call to suppress drawing would remove native behavior.
- `menu/life.c` around line 227 consumes and clears `STATE_DAMAGED`, initializes/decrements the damage display counter and changes life-bar status. This cannot be treated as a stateless draw helper.
- `equip/jpegcam.c` calls `StoreImage` for the photo feature. Final-image readback must survive removal of the legacy framebuffer through an explicit Godot readback service.

M5 must separate state update from primitive submission and verify the former still runs. Godot Controls consume view models and invoke validated native actions; they do not reimplement inventory rules, pause ownership or save behavior.

## Camera, coordinates and lifecycle constraints

`kojo/demoexec.c` saves the prior camera, selects the cinematic channel, samples source frame eye/target/roll/lens values and restores camera state on exit. Its model updates also change control positions/rotations and choose rigid or animated object updates. `kojo/demoscrn.c` contributes projection/screen transformations. A scene snapshot matrix must therefore be identified by space and sample time before reusing it as a world anchor.

The editor's map coordinates are native `(x,y,z)/1000`, Y up. Prepared mesh/runtime space currently uses `(x,-y,-z)/1000`. `renderers/godot/project/map_coordinates.gd` bridges these with a 180-degree X rotation (determinant +1). Apply this conversion once at the documented root/space boundary, including orientation; do not negate Y alone or add a second conversion to child attachments. The public coordinate/pose contract and nontrivial parent-transform example are still M0.08 work.

Current protocol v15.5 carries a resource-stage generation and native clock sample, and an initial elevator actor provider, but has no complete scenario identity, general actor lifecycle or reconnect/resync implementation. Static asset IDs, authored declarations, live actor IDs and mesh parts are different identities. M0.07–M0.10 specify those boundaries; the execution ledger records partial M1 implementation and remaining validation.

## Source-backed provider example (design, not a live capture)

The declaration's `-i -450` is parsed into `f584=450` and `f5C0=3`, selecting travel toward the start endpoint. It is not negative normalized progress. `f580=450`; `f568=end-start=(0,8000,0)`. At a sampled update with `f584=225`, the position equation in `ElevatorAct_800D8EA8` gives `(1000,4000,-28800)`. The absolute option selects `f570` when submitting the body. The future semantic payload can therefore represent this source-derived example as:

```json
{
  "provider": "elevator",
  "origin": {
    "stage": "s00a",
    "script": "ea54.g",
    "declaration_offset": 5981,
    "constructor": "2abc",
    "actor_name": "b15b"
  },
  "body_asset": "6da3.k",
  "state": {
    "phase": "toward_start",
    "position_numerator": 225,
    "position_denominator": 450
  },
  "body_position_native_metres": [1.0, 4.0, -28.8],
  "secondary_object_present": false
}
```

This is a partial design example, not an on-wire record: full asset/script hashes come from the declaration above; session, epoch, actor generation, sample tick and current visibility must come from the actual provider. They are deliberately not fabricated here. Progress describes position along start-to-end, so it decreases while travelling toward start; do not drive an animation with elapsed Godot wall time. The internal world rotation described in the contract maps this example to `(1,-4,28.8)` exactly once.

`NewElevator` registers at `GV_ACTOR_USER`. `libgv/actor.c::GV_ExecActorSystem` skips lists whose pause mask intersects `GV_PauseLevel`; that level uses `GV_LEVEL_NORMAL` (stop, pause, menu and read-error flags). The renderer must hold the last native pose when this actor does not advance. The current source trace does not imply a separate railing timer or visibility state.

A transition example is native state 3 reaching state 0, observed with callback hash `0xedb8`. Publish the current endpoint state and a new ordered arrival event only when the transition actually occurs. A later binding receives the endpoint state without replaying the callback/event. Native script invocation remains untouched.

## Live provider verification — 12 October 2026

The existing dock input probe was extended to 10,500 VSyncs without changing its
controls or native script flags. It waits at the dock spawn after its short motion
check. The normal permission timer creates the elevator at actor tick 4248;
the first received state is phase 3, progress 449/450 and native position
`(1,7.982,-28.8)` metres. Source identity matches declaration 5981 and the GCX
digest above. The body reports five parts and scene instance 32 in this run.
Instance 32 is session-specific, not an authored target.

At tick 4698 the provider reports phase 0, progress 0 and position `(1,0,-28.8)`.
An ordinary Godot child with local offset `(0,0.5,0)` followed all 1,177 received
samples through descent and the bottom stop. Native and Godot exit 0. Evidence:
`build/godot-sdk-m0/actor-timer-20261012/`, with observer source
`build/godot-sdk-m0/observe-elevator.gd`. This proves the basic live body anchor;
it does not verify separate railing targets, boarding/ascent, callback event
delivery, pause/reload, a replacement mod, human appearance or frame pacing.

The older `xbox-01` recording was also tried using a separate copied prefix and
session. It fails its inventory checksum at sample 3606, before elevator creation.
No checkpoint comparison was disabled. Its original SHA-256 remains unchanged.
Failure evidence: `build/godot-sdk-m0/actor-live-20261012/`. Do not reuse it as a
verified current-build route without investigating that divergence separately.
