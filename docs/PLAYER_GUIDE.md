# Player guide: play RE:INTEGRAL and install mods

This guide covers the 0.3.0 game and SDK packages. Both include the same
launcher and gameplay host; the SDK adds authoring tools. The separately released
native **0.2.0-alpha.1** package has its own [alpha guide](ALPHA.md); it does not
include the Godot editor or Godot visual mods.

For making mods, use the [mod creator guide](MOD_CREATOR_GUIDE.md).

## What you need

- 64-bit Windows 10 22H2 or Windows 11, with .NET Framework 4.8 for the launcher.
- A GPU and current driver capable of running Godot's Vulkan Forward+ renderer.
  The preserved Legacy renderer uses Direct3D 12. Hardware coverage is still
  being tested; a steady frame rate on every GPU is not established.
- Your Japanese Integral campaign discs: Disc 1 (`SLPM-86247`) and Disc 2
  (`SLPM-86248`), as single-track MODE2/2352 BIN/CUE images. Select the **CUE**
  files and keep each referenced BIN in the location described by its CUE.
- Space for the extracted SDK, locally prepared game content and your mods.
  Large replacement maps also need space for their Godot import caches.

Game files are not included. Plain ISO images and other regional releases are
not substitutes for the Integral gameplay discs. The VR disc is optional for
preparation; this guide covers the campaign, not VR Missions playability.
Missing Godot, PowerShell and Python tools download on first use with pinned
checksum verification, then work offline. Initial setup needs internet access;
no compiler or separate Python installation is needed.

## First launch with Godot

1. Extract the **entire game or SDK ZIP** into a writable folder. Keep its subfolders
   together; copying only `RE-INTEGRAL.exe` is insufficient.
2. Open **Prepare.cmd**. Select both campaign CUE files together. Preparation
   reads your discs and creates local map/model/texture previews. Let it finish
   before starting the game. Keep the source disc images available afterwards.
3. Open **Play.cmd**. It installs missing runtime tools before opening the
   launcher. Once setup is complete, `RE-INTEGRAL.exe` also works directly.
4. In **Discs and display**, select Disc 1 and Disc 2, then choose your output
   resolution, fullscreen and widescreen settings.
5. In **Graphics**, select **Godot**, then **Godot scene rendering**.
6. Leave **Developer options → Startup stage** at `title` and **Frame limit**
   at `0` for normal play. Click **Save and play**.

The first launch of a large mod can take a minute or more while Godot imports
its assets. The launcher shows preparation/import status and elapsed time.
Later launches reuse the cache where possible. Startup checks show their status
to the left of the outline animation. During scene loading, the animation
appears in the lower-right after a short delay and disappears when ready.
Scene transitions show no progress text. Sounds continue through renderer waits
unless the original game stops or ends them. The animation is by
**Irbif (u/Irbif)**; see the [artist credit](THIRD_PARTY.md#tooling-and-local-content).
The optional FPS/debug overlay remains a separate setting under **Developer options**.

Normal launcher sessions disable automatic image captures and ignore inherited
capture/probe environment settings. The FPS overlay does not capture images.

Godot scene mode enables **High-quality text** in **Graphics** by
default. Turn it off for the original pixel fonts. Bitmap location cards and
credits also receive smooth scaling; these retain their original artwork rather
than being replaced with a different typeface. This keeps the game's
wording and layout; illustrated title cards and lettering baked into textures
retain their original resolution. Both Legacy modes retain their original text.

## Choose a renderer

| Graphics selection | What it displays | Godot visual mod ZIPs |
| --- | --- | --- |
| Legacy 0.2 | Preserved native renderer | Not loaded |
| Godot → Godot scene rendering | Godot geometry, materials, lights, effects and editable interfaces | Loaded when checked in Mods |
| Godot → Legacy through Godot | Original native drawing commands presented by Godot | Not loaded |

Both Godot modes need the downloaded pinned engine and included runtime project. Full scene
rendering also needs prepared disc content. Renderer changes take effect when
starting the next game session. Switching modes preserves your mod selections
and uses the same launcher save location.

Compatible community renderer packages are a separate kind of download. Follow
their installation instructions; **Mods → Add ZIPs…** accepts visual mods,
not renderer packages. The [renderer reference](RENDERER_PACKAGES.md) describes
discovery through **Graphics → Renderer folder → Refresh**.

## Install, update or disable a mod

1. Close the game normally and return to the launcher.
2. Select **Graphics → Godot → Godot scene rendering**.
3. Open **Mods → Add ZIPs…** and select the creator's exported mod ZIP. You can
   select several ZIPs. There is no need to unpack them yourself.
4. Check the mods you want to use, then click **Save and play**.

An exported package has `mod.json` at the ZIP root. A GitHub source archive,
an SDK ZIP or a ZIP containing an extra enclosing folder is not that package.
Use the creator's installation ZIP and the SDK version they tested.

**To update**, add the new ZIP through the same button. A package with the same
mod ID replaces the old entry in the launcher's list and is enabled. If its
creator changed the ID, it appears as a separate mod; uncheck the older entry.
Keep the previous ZIP if you want to reinstall that version later.

**To disable**, uncheck the entry. **Remove** removes its selection from the
list; it does not promise to delete cached files or reclaim their disk space.
Use **Save settings** to retain changes without starting the game.

Several checked mods can be used together, but two mods may edit the same
material, map or interface. The launcher does not offer manual load-order
controls. Follow the creators' compatibility instructions. If a combination
looks wrong, try each mod alone to identify the overlap. Authors can inspect
conflicts and priorities in the editor's enabled-mod profile.

Mod installation and Godot importing do not certify a mod's behavior. Mods can
include scripts and native extensions; use packages from creators you trust.

## Controls and menus

Keyboard bindings use physical SDL key positions. These labels are for a
QWERTY keyboard; the Square key is labelled **Y** on German QWERTZ keyboards.

| PlayStation input | Keyboard | Xbox-style gamepad |
| --- | --- | --- |
| D-pad | Arrow keys | D-pad |
| Circle | D | B |
| Cross | X | A |
| Square | Z | X |
| Triangle | S | Y |
| L1 / R1 | Q / R | LB / RB |
| L2 / R2 | W / E | LT / RT |
| Start | Enter | Menu / Start |
| Select | Backspace | View / Back |

**Circle confirms and Cross cancels** in Integral menus: **D/B to confirm,
X/A to cancel**. Enter/Start follows the native menu context; it is not a
universal confirm button. Inventory retains the original hold-button behavior:
hold L2 or R2 to open the corresponding menu, select, then release to equip.

- **F4** toggles fullscreen; **Escape** quits the game.
- **F2**, or pressing **L3 + R3** together, swaps controller ports for Psycho
  Mantis. Repeat to return to the previous port.
- In Godot scene mode, display settings are under **Options → Display**.

## Saves, languages and updates

Use the game's ordinary save/load actions. Godot scene mode presents a flat
saved-game list and **New Save**, backed by the existing native memory-card
storage. Changing the renderer does not create a new save format.

The launcher stores its profile outside the installation:

| Location under `%LOCALAPPDATA%\RE-INTEGRAL` | Contents |
| --- | --- |
| `settings.xml` | Disc paths, renderer, selected mods and launch settings |
| `bu00`, `bu10` | Native memory-card save directories |
| `logs` | Native game, Godot and import logs |
| `mods` | Installed mod packages |
| `godot-projects` | Prepared runtime projects and mod import caches |
| `languages` | Optional locally imported language packs |

**Open save folder** opens this profile. Back up `bu00` and `bu10` while the
game is closed. These directories are not emulator `.mcr` images. Editor
**Run** sessions use separate test folders and do not automatically contain
your launcher saves.

For optional US English or German text/speech from your own matching regional
discs, use **Languages → Import from discs…**. Integral remains the gameplay
base, and coverage is partial. See [language installation](LANGUAGES.md).

For an SDK update, extract the new package into a separate folder, follow its
preparation instructions and launch from that folder. The normal launcher
profile survives. Keep your old SDK and mod ZIPs until the update works for
you. Creators should also back up their editable workspaces before moving to
a new SDK; those live inside the old SDK folder.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Mod is checked but nothing changes | Select **Godot scene rendering**, restart the session, and enter a map the mod actually edits. Check its required SDK version. |
| Godot says prepared content is missing | Run this SDK's **Prepare.cmd** with both campaign discs. Selecting disc paths in the launcher alone does not prepare Godot content. |
| First launch takes a long time | The top banner shows the current work and a progress bar. Measurable phases show a fraction; a large scene import uses an animated bar and elapsed time because Godot provides no meaningful percentage during that step. The animation is not an estimate of remaining time. Imports are cached for later launches; inspect **Open logs** if an error appears. |
| ZIP installation fails | Use an exported mod ZIP with `mod.json` at its root. Keep the exact error and filename for the creator; do not edit the archive to bypass validation. |
| Menu buttons seem reversed | Integral uses Circle/B/D for confirm and Cross/A/X for cancel. If these still misbehave, report the input device and exact menu. |
| Low FPS or camera jitter | Compare with the same mods disabled, then with the editor closed. Record the resolution, renderer mode, mods and FPS/debug overlay; closing the editor is a diagnostic, not proof of the cause. |
| Game closes or freezes | Use **Open logs**. Keep the newest native log and matching `godot-*` logs, including import logs if startup failed. Note the exit code shown by the launcher. |

Development builds still need broader Godot campaign, controller and performance
testing. SDK19 fixes a native shading failure reproduced from the docks elevator
crash dump; **human elevator retesting is still pending**. A short successful
run does not establish full playability.

When reporting a problem, include the SDK/build version, renderer mode, mod names
and versions, Windows/GPU/controller details, the last action before the problem,
and relevant logs. Review logs for private paths before sharing. Do not attach
disc images, extracted game data or imported language packs.
