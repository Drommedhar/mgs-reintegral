# Community wireframe renderer

This development example connects an independent C# renderer to the native game.
It draws colored triangle outlines using Windows Forms/GDI+, receives the native
clock/stage/pause context, forwards keyboard input, and implements original texture
uploads, moves and readbacks. Gameplay, audio, controllers, timing and saves stay
in the native process. No Godot engine or prepared Godot content is required.

It is a transport example, not a faithful game renderer: textures, complete
rasterization, Godot scenes/mods, semantic actors and editable UI are not presented
by this sample. It does not meet the final visual or performance acceptance gates.

## Install and run

1. Use the current RE:INTEGRAL launcher with launch API 2 support. Configure your
   own Integral campaign discs in its shared profile.
2. Open **Graphics → Renderer folder**. Extract this package there so the package's
   `renderer.json` sits in one immediate child folder. Move the complete folder;
   paths within the descriptor are relative.
3. Select **Refresh → Community wireframe sample → Save and play**.
   Only install one copy of this renderer ID. Duplicate IDs are unavailable.

Arrow keys are the directional pad; W/E/Q/R map L2/R2/L1/R1, S/D/X/Z map
Triangle/Circle/Cross/Square, Enter maps Start and Backspace maps Select.
Physical controllers remain native SDL inputs. Closing the sample requests a
native quit; logs are written under the launcher's shared profile `logs` folder.
Selecting Godot or Legacy for the next session preserves shared saves and settings.

## Rebuild and integrate

Windows .NET Framework 4.x supplies the compiler. From an extracted package, run:

```powershell
& ./source/community-wireframe/build.ps1 -OutputPath ./wireframe-custom.exe
```

Set `companionExecutable` in `renderer.json` to `wireframe-custom.exe`, then Refresh.
For a separate renderer use a new `id`, name and version. The sample has no
launcher assembly dependency. Implement the documented transport in your own
language/engine and declare only capabilities it implements.

Read [the package contract](docs/RENDERER_PACKAGES.md) and
[the presentation-host contract](docs/PRESENTATION_HOST.md). In the development
checkout those documents are under `docs/` at the repository root.
See `SOURCE-AND-NOTICES.txt`, `LICENSE`, `licenses/`, and `docs/THIRD_PARTY.md` for
license scopes. All original assets remain on the user's local discs.
