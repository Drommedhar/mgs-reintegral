# Godot renderer prototype

Godot is the primary renderer and visual modding direction. Protocol v11 scene
decoding, live materials and depth/ordering composition now form a tested native
runtime/renderer pair. Full visual and campaign acceptance remain outstanding.
The campaign-complete native build and its replay archive remain separate;
the released native alpha is unchanged.

```powershell
$p = 'D:\git\mgs-integral-native'
& "$p\tools\prepare-godot-content.ps1" -DiscDirectory 'C:\Users\domin\Downloads\mgs'
& "$p\tools\run-godot.ps1" -Build -Scene3D
```

With `-Scene3D`, opaque and supported transparent world geometry use Godot meshes, skeletons, depth and
perspective-correct textures. UI, Codec and remaining effects use Godot's command
renderer. Omitting `-Scene3D` selects that command renderer for everything, as a
comparison reference. The prototype is not the campaign-ready renderer.

The Godot build's `build/windows-x86-godot/RE-INTEGRAL.exe` also starts this
renderer directly. Use **Mods → Add ZIPs…**, tick the packages you want, then
**Save and play**. ZIP installation, resource import and saved selections are
handled by the launcher. It uses the prepared local disc content above.

The runtime uses Forward+. Its world viewport inherits the project's positional
shadow atlas settings (4096 by default). Active opaque meshes remain shadow
casters outside the original camera bounds, including animated characters.
Hidden actors and mod removals do not cast shadows. Camera visibility is separate
from shadow eligibility. Rebuild the native backend when updating to protocol v11.
Existing mod ZIPs require no changes. Original blob-shadow geometry and static
emitter halos are omitted in 3D mode; native actor logic remains active.

Dock patrol beacons use two opposing, rotating red spotlights with shadows. Their
activation and transforms follow the native beam objects. Adjust their appearance
through the normal `EventLightTemplates/AlarmSpot` node in a map overlay. Each
beacon also has a gentle red `AlarmFill` omni, with shadows. The red glass glows
while the alarm is active, and the housing retains its normal material. Existing
mod ZIPs use default templates for any missing alarm lights.

Compatibility fades and framebuffer effects preserve Godot's color precision;
they no longer round the lit world back to five-bit color. The editor's **Open
mod ZIP for editing…** resumes a workspace and restores local disc references.
Choose its active mod before editing models/textures, then export using the Save
dialog. Character material edits store changes against original asset IDs;
custom rigged models and texture replacements can be assigned from the dock.
See the [editor workflow](../../docs/GODOT_MODDING.md#editor-workflow).

Native muzzle/impact temporary lights now drive shadow-casting Godot omni lights.
Soldier gun-light primitives provide position, aim and visibility for attached
shadow-casting spotlights. Edit their native light properties under
`EventLightTemplates` in the map scene. Existing ZIPs use built-in defaults.
SDFGI can be enabled in the authored Environment without baking or packaging disc
geometry. Declared map meshes contribute GI; actors and particles only receive it.
SSIL remains an independent authoring choice, not a renderer requirement.

Dock/helipad cutscenes inherit their gameplay map overrides unless a cutscene
override is explicitly supplied. Transparent model surfaces, native water/ripples,
bubbles and breath/smoke effects receive the selected Godot lighting while retaining live
geometry, UVs and blending. See [the modding guide](../../docs/GODOT_MODDING.md).

```powershell
& "$p\tools\run-godot.ps1" -Scene3D -Stage s00a
```

Keyboard mappings match the native build: arrows move; X/Cross, Z/Square,
S/Triangle, D/Circle; Q/R are L1/R1, W/E are L2/R2; Enter/Start and
Backspace/Select (Codec). Physical controllers remain on SDL. F6 shows the raw
mesh viewport; press it again for the composed game view. In the MGS Visuals
editor dock, select a map and click **Open map**. Geometry and textures come
directly from the prepared disc data; no gameplay session or F7 is required.

The launcher's output resolution controls both the Godot window and internal
rendering. Enable **Widescreen** to expand the scene to that resolution's aspect;
disable it to retain 4:3. The script accepts the same settings through
`-Resolution 2560x1440 -Widescreen`.
The native command buffer remains 320x240; a separate scaled framebuffer preserves
Godot mesh detail when combining it with the original HUD and effects. The bridge
displays the active 224-line image at the selected aspect. Menus, Codec and movies
retain their original 4:3 framing. Godot depth
places scene pixels between the original effect ordering buckets. Compatibility
polygons still use their original depth buckets. Full campaign
validation remains outstanding. Audio remains
in the original runtime. Models and representative shader variants warm up before
boot, including omni, spot, directional and area-light shadow paths. Stage textures
and model materials prepare during stage loading; effect batches reserve space
for particle bursts. Map loading and remaining cutscene hitches still require work.
The launcher's **Show debug overlay** option displays native FPS, frame time and
peak frame time in the Godot window. The script accepts `-DebugOverlay`. It also
shows draw/composite counts, copied MiB and CPU command-submission time for the
last rendered game frame, plus CPU scene-update time (not GPU time).
Recordings still produce timing CSVs. The command pump runs at up to 1000 Hz to
avoid adding 4 ms to each synchronous native request. Native VSync still controls
game timing, and world/metadata viewports render only when a new scene needs them.

For a repeatable performance check with an exported ZIP, build the
`reintegral_mod_tests` target and run:

```powershell
& .\tools\test-godot-performance.ps1 -ModZip .\my-mod.zip -Resolution 2560x1440
```

This uses the launcher's mod installation and rendering path in an isolated test
directory, runs the existing dock input probe, and records every VSync without
image readbacks. The default run measures 2500 frames after 1100 loading/intro
frames; `-Frames 6000` extends it. It writes `timing.csv` and `summary.json` under
`build/godot-performance/`, including average FPS, percentiles, maximum duration
and frames exceeding the native budget by 2 ms. The check fails on any such frame
or mean duration exceeding the native budget by 50 microseconds. The NTSC target
is 59.94 Hz (16.683 ms), preserving gameplay timing. This scoped dock check does
not establish performance across the whole campaign or under other GPU loads.

`MGS_CADENCE_ALL_FRAMES=1` enables buffered per-frame output with `--cadence-log`;
the default CSV still records slow frames only. Native stdout uses the C runtime's
normal buffering so diagnostic lines do not stall gameplay on redirected output.

Asset preparation reads the verified `.local/content/disc1` import. It checks the
STAGE.DIR receipt, converts resident variants, the unskipped startup opening, title,
docks/helipad and intro resources, and writes
`.local/godot-content/catalog.json`. Original disc assets, generated glTF/PNG files,
shader copies and Godot imports are excluded from Git. For a new disc installation,
use the existing `tools/import_content.py --source <disc-folder> --output <ignored-content-folder>`
first, then pass its `disc1` folder to `prepare_godot_assets.py --content`.

The prototype uses separate cards in `.local/godot-runtime`. Record a new test:

```powershell
$r = "$p\.local\replays\godot-$((Get-Date).ToString('yyyyMMdd-HHmmss-fff')).mgsinput"
& "$p\tools\run-godot.ps1" -Scene3D -RecordInput $r
```

The v4 pair passes a 4,496-sample unskipped opening replay in scene and command
modes, plus a 1,446-sample dock replay with model, texture and lighting replacements.
No-input startup is also checked. The older full Xbox route now diverges at the
same inventory checkpoint in both modes; its historical pass does not validate
current transitions. These are scoped automated checks, not a human playthrough.

Run `./tools/test-godot.ps1` for the asset, scene, mod and GPU regression suites;
`-SkipGpu` runs the CPU checks only.

Map models, parts and original fixed lights appear in Godot's Scene tree with
resource IDs. Use normal Add Node, gizmos, materials, visibility and Inspector
tools; MGS Visuals handles disc loading and mod export. The original light tables
also feed the runtime renderer. Its ZIP exporter saves edits/custom assets without
the original map reference. Native GDExtension hooks and a working x64 C++ light mod are available
through `./tools/build-godot-mod.ps1`. The suite also checks extension lifecycle,
PBR/shadows and map export; `-SkipNativeMod` omits the C++ build when needed.

For visual diagnostics, `MGS_GODOT_CAPTURE_EVERY=120` together with
`MGS_GODOT_CAPTURE_FILE=<absolute-path>/frame.png` saves numbered presentation
captures every 120 frames. `MGS_GODOT_CAPTURE_WORLD=1` also saves the raw scene
viewport. Captures wait for presentation and can affect timing measurements.

See [the migration plan](../../docs/GODOT_RENDERER_PLAN.md),
[the modding/editor guide](../../docs/GODOT_MODDING.md) and
[the transport specification](../../docs/GODOT_PROTOCOL.md).
