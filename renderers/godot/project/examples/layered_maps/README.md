# Shared location and exact scenario lighting

These two mods contain ordinary Godot lights and Environment resources. They contain
no original game assets and do not change native gameplay or collision.

1. Open a docks map in your active workspace.
2. Under **Mod → Enabled mods**, add `shared/mod.json` and `intro/mod.json` from this
   example. The active workspace is also enabled.
3. Select **Maps → Test → Preview profile**. On `s00a`, SharedLamp appears. On the
   `d00a` intro variant, both lamps appear, with the intro Environment at energy1.25.
   Its exact-scenario scope wins even though priority10 is lower than shared500.
4. Disable the intro mod to see the inherited shared lighting. Change priorities to
   resolve competing mods within the same scope. The conflict panel names winners.
5. Edit each `map.tscn` using Godot's Inspector, save it, and refresh Profile Preview.
   Use **Run** for native behavior; cinematic maps offer the title/New Game route.

Profile Preview is an editor-local view of saved scenes. Save/Export continues to
package only the active workspace. The preview tab and enabled list are not shipped
in that ZIP. This example intentionally changes lighting; it is not a default-fidelity
reference or a campaign validation fixture.

From the SDK/repository root, the matching command-line profile can be used directly:

```powershell
& .\tools\run-godot.ps1 -Scene3D -Stage title -ModProfile .\renderers\godot\project\examples\layered_maps\profile.json
```

Start New Game to enter the intro through native sequencing. Local prepared content
is required. `res://` paths refer to the SDK's Godot project and survive relocation.
