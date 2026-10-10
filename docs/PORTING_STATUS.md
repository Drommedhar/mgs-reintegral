# Porting status and campaign plan

The native Windows x86 source port now starts through the original title and
New Game flow. Stage registry generation, Japanese identifier encoding and
per-overlay writable-state restoration are implemented. The current selection
is [config/stages.json](../config/stages.json); concrete build/runtime milestones
and limitations are tracked in [PROGRESS.md](../PROGRESS.md).

The current builds compile 738 game translation units across all 92 configured
campaign and menu stages, including a native disc-safety replacement. All 94
CTest suites pass in Debug and the optimized renderer-module build. Counts measure compiled sources, not percentage
completion or playable content. Integration and backend work continue.

The complete New Game intro now runs without its reproduced long pauses in both
optimized and default Debug builds. Its audio clock, underwater packets and GPU
uploads have documented regressions. See [intro timing](INTRO_TIMING.md).

## Source recovery and validation

Upstream's main executable milestone does not cover every stage overlay. Native
registration rejects unresolved literal PS1 constructor addresses. We bind
constructors only against original overlay evidence, then compile recovered C or
implement missing functions using original instruction/data evidence. Unknown
actors must not become success stubs or generic replacements.

The prison encounter `s03d` required 32 functions across 21 missing assembly
blocks, in addition to constructor and data-pointer recovery. Its scenario
fixture now instantiates original guards and observes movement and damage.
Tank/tower constructor bindings are recovered, but direct-entry rendering alone
does not validate their encounters. See [stage recovery](STAGE_RECOVERY.md) and
[early-stage validation](EARLY_STAGE_VALIDATION.md).

Validation has separate levels: source compilation, bounded runtime entry,
controller-driven behavior, explicit debugger scenario fixtures, original
campaign transitions, and human playability. A frame-limit exit alone is not a
loaded-stage or gameplay pass. No human dock walkthrough has occurred.

## Practical order

1. Restore missing campaign stages and their original actor/data behavior. Follow
   the early campaign while separating required scenario state from port defects.
2. Exercise connected stages and encounters with controller input, including
   guards, inventory, damage/death/restart, Codec, bosses and outgoing transitions.
3. Complete save/load, movie/audio synchronization, GPU semantics, disc switching,
   ending and credits. Recheck stage revisits and overlay lifetime under those flows.
4. Expand resource import/editing after campaign behavior is dependable. Preserve
   the renderer/resource boundaries during all recovery work. VR-specific content
   needs its own executable/overlay audit.

## Existing MGSR tools worth retaining

The sibling `D:/git/MGSR` checkout is useful tooling, not a runtime dependency. Reuse requires validation against Integral PS1 data; the established converter corpus is primarily the PC edition.

| Existing component | Useful later | Boundary |
| --- | --- | --- |
| [GCX/GCL adapter](../../MGSR/converter/public_scripts.py) and [scene adapter](../../MGSR/converter/public_scene.py) | Script inspection, entity lists, stage previews, and eventually checked script edits. | Verify PS1 opcode/resource identities and compile/round-trip behavior. Exported JSON alone does not replace the native GCL VM. |
| [MINT model adapter](../../MGSR/tools/UpstreamExport/Program.cs), animation tools, and standard glTF validation | Model/skeleton inspection and authoring previews. | Existing texture, palette/STP, stream, and packed-model adaptations include PC-specific behavior. Native import/re-encoding, resource sizes, and PS1 rendering semantics remain separate work. |
| [Collision preview conversion](../../MGSR/converter/native_collision.py) | Show collision surfaces and retain original flags/identities in an editor. | It explicitly provides a static preview surface; native gameplay should keep recovered `libhzd` behavior. |
| [PC actor-table reader](../../MGSR/converter/public_registry.py) | Inspect identifiers and provenance. | Its function addresses are opaque PC tokens. It cannot supply PS1 constructors or replace native stage registration. |

The current mod contract remains `mods/stages/<stage>/<hash>.<extension>` with exact-length original-format replacements; executable `.b` overlays are excluded. A future editor should preserve stage/resource identities and unknown fields, emit validated native-format resources, and add explicit allocation/size handling before allowing resized assets. Keep standard PNG/glTF authoring formats at that conversion boundary until their native import paths are implemented.
