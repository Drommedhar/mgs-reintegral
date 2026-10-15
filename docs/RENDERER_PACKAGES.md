# Launcher renderer packages

Select an installed renderer on the launcher's **Graphics** tab, then **Save and play**. The selection is stored as `RendererId` in the existing settings profile. Switching takes effect on the next game session. Saves, disc paths, language packs and visual-mod selections remain in the same profile. Native backends do not load Godot visual ZIPs; the launcher reports that without deleting or disabling those selections.

The launcher discovers `renderer.json` beside itself and in immediate subdirectories of either its `renderers` directory or the profile's `renderers` directory. **Renderer folder** opens the latter; **Refresh** reloads descriptors. Missing saved selections stay visible as unavailable. Duplicate IDs disable all conflicting entries. A missing executable or unsupported schema/API/backend/architecture produces a diagnostic instead of selecting another renderer. Full Godot scene mode additionally requires local prepared content before Play.

## Descriptor schema 1 / launch API 1

Launch API 1 covers the bundled native and Godot backends. Native packages launch their own compatible native executable; Godot packages launch a matched native executable plus the Godot companion. Independent companion renderers use API 2 below.

```json
{
  "schema": 1,
  "launchApi": 1,
  "id": "legacy",
  "name": "Legacy 0.2",
  "version": "0.2.0-alpha.1",
  "backend": "native",
  "nativeArchitecture": "x86",
  "rendererArchitecture": "x86",
  "executable": "mgs-integral-native.exe",
  "nativeGraphicsOptions": false
}
```

- IDs use lowercase letters, digits, `.`, `_` and `-`, beginning with a letter, at most64 characters. `legacy` and `godot` are the bundled choices; community packages should use their own IDs.
- `schema` and `launchApi` are integer version numbers. Unknown versions are unavailable. `version` is the package's displayed version; runtime protocol compatibility is checked by the companion handshake, not inferred from this label.
- `backend` is `native` or `godot`. Both use the current native CLI (`--disc`, `--disc-two`, resolution, stage and gameplay options). New launch mechanisms require a new supported contract.
- Executable and resource paths are relative to the descriptor. They are resolved independently of the launcher's working directory. Native processes always use the shared profile as their working/save directory.
- `nativeGraphicsOptions` enables the existing optional perspective/subpixel/depth switches for a native package that implements them. Legacy and Godot do not receive these switches. Saved checkbox values are preserved when unavailable.
- Godot additionally requires `rendererArchitecture: "x64"`, `godotExecutable`, `godotProject` (directory containing `project.godot`) and `godotAssets` (local prepared-content directory containing `catalog.json`). The launcher copies the runtime project/mods into its content-addressed profile cache and starts the declared engine. It does not copy or export the original disc content into mod ZIPs.
- Descriptor changes after discovery require Refresh or restarting the launcher before Play. Deleting an executable after selection is caught before starting a session.

Godot also offers a saved **Legacy through Godot** graphics mode. It displays the original primitive stream through Godot without prepared scene content, scene lighting/PBR or visual mods. Switching back to full Godot restores the preserved mod selections. Standalone **Legacy 0.2** remains a separate renderer choice. Both Godot modes require the engine and runtime project, but only full scene mode requires the prepared catalog.

## Descriptor schema 1 / launch API 2

API 2 starts an independent renderer process and a matched native presentation host.
It has no dependency on Godot or the launcher's assembly. The sample descriptor is:

```json
{
  "schema": 1,
  "launchApi": 2,
  "id": "example.wireframe",
  "name": "Community wireframe sample",
  "version": "0.1.0",
  "backend": "companion",
  "nativeArchitecture": "x86",
  "rendererArchitecture": "x86",
  "executable": "presentation-host.exe",
  "companionExecutable": "wireframe.exe",
  "companionArguments": [],
  "protocol": {"major": 15, "minor": 30, "capabilities": 29, "mode": "commands"}
}
```

`rendererArchitecture` may be x86 or x64; x64 requires a 64-bit OS. The native host
is x86. `companionArguments` is an array of literal argument strings; the launcher
quotes each argument and does not invoke a shell. Optional `presentationAssets`
points to locally prepared content with `catalog.json`; omit it for renderers
that do not use that representation. Never include those original assets in the package.

Community launch API2 currently accepts protocol **15.30–15.32** and offers the package's declared
minor, preserving existing15.30 packages. Readiness must still match the descriptor
exactly. Minor31 adds the one-shot F2 host shortcut. `commands` mode requires
capability mask **29 / 0x1d**; `scene` requires **536870911 / 0x1fffffff**.
Additional implemented capabilities may be declared. The readiness record must
match the descriptor exactly; the subsequent native handshake independently
checks the selected version and required features. A version/name label is not
a compatibility substitute. Incompatible startup fails visibly and cleans up
the companion; it does not select a different renderer.

See [the presentation-host contract](PRESENTATION_HOST.md) for environment,
readiness, authentication, settings and lifetime, and [the wire protocol](GODOT_PROTOCOL.md)
for commands and semantic payloads. Godot ZIPs currently remain Godot-only;
API 2 does not claim a general community-mod capability/dependency schema.

## Development builds and validation

CMake generates a descriptor beside the built executable. The Godot development descriptor refers to the checked-out project, pinned engine and local prepared assets using relative paths. It is not a standalone player distribution. `tools/package-godot-sdk.ps1` builds the relocatable development SDK; final M8 acceptance remains open.

Old settings without `RendererId` use the launching build's declared default until saved. A saved explicit ID never falls back to that default if its package is removed.

`launcher_renderers` covers discovery, duplicate/malformed/missing descriptors, stale selection, deleted executables, old settings, persistence and backend-specific arguments. Existing launcher settings/mod/provider tests remain applicable. `tests/launcher_renderer_live.cs` is a separate opt-in WinForms fixture: compile it beside the built launcher, pass an isolated prepared settings profile, and optionally a mod ZIP to install into that profile. It switches Legacy→Godot, saves each choice, checks executable/process ownership and shared configuration, and requires an actual Godot world composite before accepting completion. Both packages and local discs must already be configured. This is a launch check, not campaign or performance acceptance.

Build the independent sample package from the checkout:

```powershell
./tools/package-community-renderer.ps1 -OutputDirectory build/renderer-packages/community-wireframe
```

Use a new output directory. The script compiles the sample, copies the matched
native host, includes source/notices/contracts, checks the inventory against both
local prepared-content catalogs, and emits a ZIP with a SHA-256 sidecar. This
development build step uses the checkout's Python environment and .NET compiler;
players need neither Godot nor Python to run the sample. Extract into an immediate
child of **Renderer folder**, then Refresh. `START-HERE.md` describes controls and
rebuilding the independent sample from the extracted source.

CMake registers `community_wire` (framing/authentication/native context/readback)
and `presentation_readiness` (real companion process with incompatible readiness
and cleanup), without requiring retail content. The built
`presentation_session_tests.exe` optionally accepts four arguments: a new evidence
directory, matched native executable, disc-one CUE and disc-two CUE. This also
checks rejection of an incompatible actual native handshake. The live launcher
fixture accepts a third comma-separated renderer-ID argument, for example
`example.wireframe,legacy`; pass an empty second argument when no ZIP is needed.
