# RE:INTEGRAL roadmap

This roadmap separates delivered foundations from planned work. Future items
have no committed delivery dates. The native main campaign is the starting
point; the alpha's supported configuration is in [ALPHA.md](ALPHA.md).

As of 11 October 2026, Godot is the primary renderer and modding SDK/editor
direction. The recovered C runtime remains responsible for gameplay, collision,
animation, audio, saves and timing. Remix Plus is retained as a separate
experiment; further integration work is deferred. The native alpha remains
the playable baseline during this work.

## Native alpha foundations

- [x] Official-source prerequisite setup and a documented Debug build.
- [x] A downloadable Windows build with a shared setup/settings launcher,
  including gameplay options and additional command-line arguments.
- [x] Saves and settings outside the installation folder, plus versioned logs.
- [ ] Broader testing of campaign branches, controllers, graphics hardware and
  display settings, with fixes driven by reported defects.

## Expand language and edition support

- Support text and voice resources from additional regions and editions.
- Identify supported disc revisions and explain compatibility during setup.
- Offer language selection where the supplied resources support it, while
  keeping scripts, timing, subtitles and spoken dialogue consistent.

## Godot renderer

- [x] Complete protocol v4 scene decoding, metadata rendering and composition;
  build and test a working pair in the separate Godot build directory.
- Check no-input startup, the unskipped opening, docks, helipad, Codec and their
  transitions against the native reference, including draw ordering and effects.
- Migrate transparent meshes, live textures, palette effects and framebuffer
  effects into appropriate Godot passes while retaining compatibility rendering
  for behavior that has not yet been migrated and checked.
- Measure frame pacing without diagnostic captures, then expand resolution,
  widescreen and campaign coverage.

The [Godot integration milestone](GODOT_RENDERER_PLAN.md#active-direction-11-october-2026)
records the immediate work and acceptance criteria. Godot is not yet part of
the native alpha. The alpha's [experimental renderer](../renderers/modern/README.md)
remains available for existing users and comparison. Renderer transport and
mod manifests are prototype contracts, not a stable public SDK.

## Deliver the Godot modding SDK and editor

- Build on the [MGS Visuals plugin](GODOT_MODDING.md): stable asset IDs,
  model/texture overrides, rig validation and stage lighting scenes.
- [x] Verify local disc preparation, stage preview export and in-game mesh,
  texture and lighting replacements, with invalid-mod regression checks.
- [x] Add native GDExtension lifecycle hooks, Godot PBR materials and dynamic
  shadow lights, with compiled-extension and GPU tests.
- [x] Author visual map overlays: inspect local originals, place lights/objects,
  hide originals and export edits/custom assets without the captured map files.
- Define versioned public manifests, compatibility rules, diagnostics and
  asset-free examples once the renderer and authoring workflow are verified.
- Expand resource inspection, export and replacement to audio and scripts;
  define gameplay and collision editing through explicit native runtime APIs.
- Expand visual map authoring into gameplay/collision editing on those native
  interfaces. Current removals and additions affect visuals only.

## Broaden game and platform coverage

- Recover and validate VR Missions and other content outside the current
  main-campaign scope.
- Keep host-specific code isolated so future platforms remain possible.
  Windows x86 is the supported initial target; x64 and other operating systems
  need separate implementation and validation. The x64 port is deferred, with
  its feasibility audit retained locally.

Track defects and proposed improvements in the
[issue tracker](https://github.com/Drommedhar/mgs-reintegral/issues).
