# Godot renderer prototype

Experimental renderer with unresolved visual defects in the default `-Scene3D`
path. It is not ready for a playthrough. The campaign-complete
native build and its replay archive remain separate. The default native launcher
still uses the original SDL GPU backend.

```powershell
$p = 'D:\git\mgs-integral-native'
& "$p\tools\prepare-godot-content.ps1" -DiscDirectory 'C:\Users\domin\Downloads\mgs'
& "$p\tools\run-godot.ps1" -Build -Scene3D
```

With `-Scene3D`, opaque world geometry uses Godot meshes, skeletons, depth and
perspective-correct textures. UI, Codec and remaining effects use Godot's command
renderer. Omitting `-Scene3D` selects that command renderer for everything, as a
comparison reference. The prototype is not the campaign-ready renderer.

```powershell
& "$p\tools\run-godot.ps1" -Scene3D -Stage s00a
```

Keyboard mappings match the native build: arrows move; X/Cross, Z/Square,
S/Triangle, D/Circle; Q/R are L1/R1, W/E are L2/R2; Enter/Start and
Backspace/Select (Codec). Physical controllers remain on SDL. F6 shows the raw
mesh viewport; press it again for the composed game view. F7 exports a local stage
preview for the MGS Visuals editor plugin.

The launcher currently requests 320x240 native drawing and enlarges it in a
resizable Godot window. The bridge displays the active 224-line image. Godot depth
places scene pixels between the original effect ordering buckets. Compatibility
polygons still use their original depth buckets. Higher internal resolutions,
widescreen and full campaign validation are not completed. Audio remains
in the original runtime. Models preload before boot; initial shader compilation,
map loads and F7 scene serialization can still stall presentation.
The native FPS overlay has not been ported; recordings still produce timing CSVs.

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

Your retained Xbox recording passed 15,675 samples through the title/opening,
docks-to-helipad transition and Codec. A separate 1,446-sample dock recording also
replayed with replacement geometry and optional Godot lighting/fog. These are
automated checks, not a human playthrough of the new renderer.

For visual diagnostics, `MGS_GODOT_CAPTURE_EVERY=120` together with
`MGS_GODOT_CAPTURE_FILE=<absolute-path>/frame.png` saves numbered presentation
captures every 120 frames. `MGS_GODOT_CAPTURE_WORLD=1` also saves the raw scene
viewport. Captures wait for presentation and can affect timing measurements.

See [the migration plan](../../docs/GODOT_RENDERER_PLAN.md),
[the modding/editor guide](../../docs/GODOT_MODDING.md) and
[the transport specification](../../docs/GODOT_PROTOCOL.md).
