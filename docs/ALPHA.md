# RE:INTEGRAL — 0.2.0-alpha.1

This alpha adds optional graphics enhancements, faster map loading, and German
or US English text/speech imported locally from your own discs.

- **Graphics:** perspective-correct model textures, subpixel geometry and depth
  testing are independently selectable. The character-joint seam fix is included.
  The experimental PBR test has been removed.
- **Loading:** optional faster map loading preserves geometry processing.
- **Languages:** import and validate private language packs directly in the
  launcher, with progress and cancellation. No packs or game data are distributed.

Graphics enhancements and faster loading default to off. Existing saved settings
are retained. Language coverage is partial; unmatched dialogue and movies use
Integral's original resources.

Download the `windows-x86.zip` asset, extract the entire folder, and open
**RE-INTEGRAL.exe**. Keep the launcher beside `mgs-integral-native.exe`.
Keep the `language-importer` folder alongside them for optional language imports.
The symbols and MPL source ZIPs are separate downloads for debugging and
source access; they are not needed to play.

## Requirements

- Windows 10 22H2 or Windows 11, with .NET Framework 4.8 enabled for the launcher.
  The game is a 32-bit executable and also runs on 64-bit Windows.
  Creating optional language packs requires 64-bit Windows.
- A Direct3D 12 capable GPU and driver supporting the bundled SDL GPU backend.
  A broader hardware compatibility matrix is still to be established.
- Your Japanese Integral Disc 1 (`SLPM-86247`) and Disc 2 (`SLPM-86248`) in
  single-track MODE2/2352 BIN/CUE format. Select the CUE files and keep their
  BIN files alongside them. Integral remains required for gameplay. US English
  v1.0 and German campaign pairs can supply optional text and speech. Plain ISO
  images and VR Missions are unsupported. No game content is supplied.

Players do not need Git, Python, CMake, Visual Studio, or PowerShell scripts.
The launcher uses Windows' .NET Framework; the native C/C++ runtime and SDL are
linked into the game. The executables are unsigned.

## First launch

1. Select both disc CUE files in **Discs and display**.
2. Choose a resolution and enable widescreen/fullscreen as desired.
3. Review **Gameplay** for optional bonus items, invulnerability, auto-card,
   faster map loading and Psycho Mantis memory profiles. Defaults leave gameplay
   aids disabled. **Graphics** contains the three optional rendering enhancements.
4. Click **Save and play**. Disc identities are checked before the game starts.

For 240p comparison recordings, select **320x240** and turn **Widescreen** off.
This uses 1× internal rendering with the original 4:3 output. Turn off the three
**Graphics** enhancements for a baseline comparison. Resolution does not set
the frame rate; the developer **Frame limit** stops the game after a number of
frames, so leave it at **0** for an ongoing recording.

For optional German or US English text and speech, open **Languages → Import
from discs…**, choose the regional release and its two images, then click
**Import and use**. The launcher creates and checks a pack locally; no Python
installation is needed and nothing is uploaded or downloaded. Allow several
minutes and several GiB of free memory and disk space. Coverage is partial;
unmatched dialogue and movies retain Integral. See `LANGUAGES.md` for details.

**Developer options** exposes debug overlay, startup stage and frame limit.
The additional-arguments field accepts the remaining native command-line
options, including mod paths and recording/replay arguments. These arguments
are passed directly to the engine after the other settings; they can override
those settings. **Argument help** lists accepted flags and **Show command**
displays the command. Random Mantis profiles choose a seed for each command.
Development stage entry does not establish the campaign state required by a
scene. The source checkout's `tools/run.ps1` remains the richer recording and
replay-session workflow; the launcher does not generate its session sidecars.

## Saves, settings and logs

The launcher stores data in `%LOCALAPPDATA%\RE-INTEGRAL`:

- `settings.xml`: disc paths and launch options.
- `bu00` and `bu10`: native memory-card saves, created by the game.
- `logs`: a separate timestamped log for each game process, with version and
  commit information. Logs can contain local file paths and launch arguments.
- `languages`: private imported language packs and their source/coverage receipts.
  The `logs` folder also contains language import logs. Do not share these packs.

Updating or replacing the application folder preserves this data. Existing
development saves under `.local/runtime/bu00` and `bu10` can be copied to the
corresponding folders while the game is closed. Back up both locations first.
The launcher prevents simultaneous instances sharing its save directory.

If the game requests a restart, the launcher starts it again with the same
arguments. If startup fails, use **Open logs** and include the relevant error
when reporting a bug. Reopen the launcher to repair paths after moving discs.

## Controls

- Arrows: D-pad; X/D/Z/S: Cross/Circle/Square/Triangle.
- Q/R: L1/R1; W/E: L2/R2; Enter: Start; Backspace: Select.
- Circle confirms and Cross cancels in Integral menus. Keys use physical SDL
  positions; Square is labelled Y on German QWERTZ keyboards.
- SDL gamepads are supported. Xbox A/B/X/Y map to Cross/Circle/Square/Triangle.
- **F2 or L3 + R3** swaps controller ports for Psycho Mantis; repeat to return.
- F4 toggles fullscreen; Escape quits.

## Alpha status and feedback

One main-campaign route was completed through credits on 10 October 2026.
That does not establish coverage of all branches, optional modes, controllers
or GPUs. That playthrough used the original renderer; the optional graphics and
language features have targeted checks and still need broader playtesting.
Complete regional coverage, VR Missions, the replacement Godot renderer and
broader mod formats remain future work; see the repository roadmap.

Report bugs at https://github.com/Drommedhar/mgs-reintegral/issues with the
version, reproduction steps, Windows/GPU/controller details, and relevant log.
Do not attach retail disc images or extracted game content.

Original project contributions have the scoped MIT license in `LICENSE`.
Third-party terms, known uncertainties and corrections are documented in
`THIRD_PARTY.md`; accompanying license texts are in `licenses` and source-access
information is in `SOURCE-AND-NOTICES.txt`.

Unofficial project; not affiliated with or endorsed by Konami.
