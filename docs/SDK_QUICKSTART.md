# Start here: RE:INTEGRAL Godot SDK

This 0.3.0 SDK includes the launcher, Godot renderer/editor project, native
gameplay host and preserved Legacy 0.2 renderer. No game assets, prepared
previews, saved games or user mods are included. Campaign-wide Godot fidelity,
playability and performance acceptance remain in progress.

## Choose your guide

- **[Player guide](PLAYER_GUIDE.md):** prepare your discs, launch the game,
  install/update mod ZIPs, choose a renderer, use the controls and back up saves.
- **[Mod creator guide](MOD_CREATOR_GUIDE.md):** make your first visual mod,
  edit original and custom content, test it in the native game and export a ZIP.
- **[Technical reference](GODOT_MODDING.md):** manifests, scripts, resource
  bindings and native extensions.
- **[Snow volumes](GODOT_SNOW.md):** placeable snowfall, two-sided geometry collision and Inspector controls.
- **[Water and frost](GODOT_WATER_FROST.md):** reusable pool/ocean/puddle resources,
  underwater effects, frost and original actor visuals.

## First steps

1. Extract the entire ZIP into a writable folder. Keep the directory layout.
   No development checkout is needed. The first command downloads missing tools;
   allow internet access and space for Godot, PowerShell and Python.
2. Run **Prepare.cmd** and select both Integral campaign CUE files together.
   Keep each CUE with its referenced BIN. Preparation reads them locally; keep
   the images available afterwards. The optional VR disc does not establish VR
   Missions playability.
3. **To play:** open **Play.cmd**. Select both discs in the launcher, choose
   **Graphics → Godot → Godot scene rendering**, add visual mods through
   **Mods → Add ZIPs…**, then **Save and play**.
4. **To create:** open **Editor.cmd**. Use **Open ZIP…** for an existing mod,
   or **Mod → Workspace → Save As…** for an independent workspace. Find a map
   under **Maps → Browse** and use ordinary Godot editing tools.
5. Test with **Maps → Test → Run**, then **Mod → Workspace → Export ZIP**.
   Use **Stop** to end an editor test. Export includes authored changes and
   custom dependencies; original previews stay local references.

The launcher uses your normal profile and saves under
`%LOCALAPPDATA%/RE-INTEGRAL`. Editor tests use isolated folders under
`build/godot-editor-runs`. **Legacy through Godot** presents native drawing
commands without scene lighting or visual mods; **Legacy 0.2** is the separate
preserved renderer. Switching renderers takes effect on the next session.

Loading/import progress belongs to the launcher and editor. Large models can
make a first import take a minute or more. The in-game FPS/debug overlay remains
an independent option; loading progress does not appear over gameplay.

## Preparation and relocation

From PowerShell in the extracted SDK folder, you can select a disc folder:

```powershell
.\Prepare.cmd -DiscDirectory "C:\My Games\Integral"
```

For a small initial authoring check, append `-Discs 1 -Stages s00a`. Run full
preparation afterwards for the other gameplay/cinematic variants and Disc 2.
Use comma-separated lists for multiple values: `-Discs 1,2 -Stages s00a,s01a`.

Move the entire SDK folder to relocate it. Prepared content resolves relative
to the SDK root, but disc receipts retain the source image paths. If your discs
also move, prepare them in a fresh SDK folder. Back up editable mod workspaces
before updating; existing mods retain their copied scripts and need deliberate
updates to adopt newer SDK helpers.

## Examples and package information

The editor project is `renderers/godot/project/project.godot`; its `examples`
folder includes water/frost, native-time cameras, layered maps and named
resources. GDExtension sources are under `renderers/godot/sdk`; compiling them
requires a separate C++ toolchain and the pinned godot-cpp source.

The package's `sdk.json` identifies its build and tool versions.
`package-files.json` records packaged input hashes; the adjacent `.zip.sha256`
records the archive hash. Preserve `SOURCE-AND-NOTICES.txt` and license files.
Distribute exported mod ZIPs, not your populated SDK or prepared game content.

## Tool downloads

**Editor.cmd** and **Play.cmd** install the pinned Godot and PowerShell versions
if missing. **Prepare.cmd** also installs embedded Python; preparing content,
opening a ZIP or saving a workspace copy in the editor installs it when needed.
Windows PowerShell 5.1 starts the
bootstrap, so no PowerShell 7 or Python installation is required beforehand.
Downloads and required executable files are verified against SHA-256 values in
`sources.lock.json`. A completed tool installation is reused offline and is not
automatically upgraded. The archive itself contains no downloaded `.tools` tree.

If a download fails or its checksum differs, the command reports the error and
does not install that download. Run the same command again to retry. Keep the
whole package, including its populated `.tools` folder, when moving it for
offline use. Installing tools never prepares or downloads game content.

See [release notes](RELEASE_0.3.md) for the current validation limits.
