# RE:INTEGRAL roadmap

This roadmap describes intended work, not a promise that a feature is already
available or a commitment to delivery dates. The native main campaign is the
starting point; the alpha's supported configuration is in [ALPHA.md](ALPHA.md).

## Make the native release easy to use

- A straightforward prerequisite setup and reproducible Debug build.
- A downloadable Windows build with a shared setup/settings launcher.
- Persistent saves and configuration, useful logs, and reliable updates.
- Broader testing of campaign branches, controllers, graphics hardware and
  display settings, with fixes driven by reported defects.

## Expand language and edition support

- Support text and voice resources from additional regions and editions.
- Identify supported disc revisions and explain compatibility during setup.
- Offer language selection where the supplied resources support it, while
  keeping scripts, timing, subtitles and spoken dialogue consistent.

## Replace the rendering pipeline with Godot

- Develop the experimental Godot renderer as a replacement for the native
  rendering backend, preserving recovered gameplay behavior.
- Support custom graphics and resource mods through clear renderer boundaries.
- Improve rendering only where its behavior and compatibility can be tested.

The Godot prototype is currently paused and is not part of the native alpha.
The existing renderer boundary is a source-level interface, not a stable
binary plugin API or a completed modern mesh/material pipeline.

## Build practical modding tools

- Extend the current exact-length resource overrides to common image, model
  and audio formats, including resized replacements.
- Make resource inspection, export, replacement and validation easier.
- Develop a map/stage editor after the underlying resource and renderer
  interfaces are ready.

## Broaden game and platform coverage

- Recover and validate VR Missions and other content outside the current
  main-campaign scope.
- Keep host-specific code isolated so future platforms remain possible.
  Windows x86 is the supported initial target; x64 and other operating systems
  need separate implementation and validation.

Track defects and proposed improvements in the
[issue tracker](https://github.com/Drommedhar/mgs-reintegral/issues).
