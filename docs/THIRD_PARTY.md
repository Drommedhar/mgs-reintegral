# Third-party source and build provenance

The exact normal-build inputs and patch order are recorded in [sources.lock.json](../sources.lock.json). Downloaded checkouts live under ignored `vendor/`; local game content lives under ignored `.local/`. Patches identify our modifications separately from their upstream revisions.

## Project license and corrections

Original RE:INTEGRAL software and documentation are offered under the
[MIT License](../LICENSE), within the scope stated there. That grant does not
cover recovered game or SDK code, game assets or data, third-party material,
or patches to upstream code. Those materials retain their applicable terms
and notices, including the unresolved scopes documented below.

We aim to document sources, authorship, and licensing accurately using the
upstream information available to us. If you are an author, contributor, or
rights holder and believe an attribution, license description, or use of your
work needs correction, please open a **Licensing or attribution** issue in this
project's GitHub repository. Include the relevant files or release and any
supporting source or licensing information. We welcome clarification and will
review it in good faith and make appropriate corrections. A correction request
is welcome at any time; the absence of one is not treated as permission.

Use the [licensing/attribution issue form](https://github.com/Drommedhar/mgs-reintegral/issues/new?template=licensing.md)
to identify the affected material and supporting information.

## Source inventory

| Input | Pinned revision | Role |
| --- | --- | --- |
| [FoxdieTeam/mgs_reversing](https://github.com/FoxdieTeam/mgs_reversing/tree/f54dbb2a58adfc2755403296c9ebb653fbec277b) | `f54dbb2a58adfc2755403296c9ebb653fbec277b` | Recovered Integral game C and stage linker template |
| [Xeeynamo/psyz](https://github.com/Xeeynamo/psyz/tree/6d9c5730c414da327dbb12a8e6600b7774b49201) | `6d9c5730c414da327dbb12a8e6600b7774b49201` | PSY-Q-compatible runtime, platform backends, and decompiled SDK portions |
| [libsdl-org/SDL](https://github.com/libsdl-org/SDL/tree/fa2c02bb6e21974a89ea9824bc53c9932abe5f9c) | `fa2c02bb6e21974a89ea9824bc53c9932abe5f9c` | SDL 3 host services, built statically through PsyZ |
| [David Montero's ESP32 port branch](https://github.com/davidmonterocrespo24/mgs_reversing/tree/5a2c7ee2be477bdde465654b5bf52de1275e1096) | `5a2c7ee2be477bdde465654b5bf52de1275e1096` | Native-port and disc-extraction reference; no normal-build checkout |
| [PSn00bSDK](https://github.com/Lameguy64/PSn00bSDK/tree/5d9aa2d3dfc7d6e51c2eb942ab4cdbae5571a40a) | `5d9aa2d3dfc7d6e51c2eb942ab4cdbae5571a40a` | VLC lookup table and v2 decoding rules adapted in the movie patch |
| [psxe](https://github.com/allkern/psxe/tree/8459c63ed78c703f46e3c51daa65a2fdf96d02e6) | `8459c63ed78c703f46e3c51daa65a2fdf96d02e6` | MDEC run-level, IDCT and color conversion adapted in the movie patch |

## License scopes recorded upstream

We have not found a repository-wide license grant in the pinned FoxdieTeam tree. Its recovered game code and stage data are outside this project's MIT license. This port does not grant rights to the original game or its content.

PsyZ's [root license inventory](https://github.com/Xeeynamo/psyz/blob/6d9c5730c414da327dbb12a8e6600b7774b49201/LICENSE) assigns different scopes. `psyz/src/platform/` and `psyz/src/psyz/` carry MPL 2.0; the root inventory labels `psyz/include` and `psyz/src/psyq` “Unlicensed.” The [decomp subtree](https://github.com/Xeeynamo/psyz/blob/6d9c5730c414da327dbb12a8e6600b7774b49201/decomp/LICENSE) has its own MIT notice crediting psyqz members and sotn-decomp contributors. Several tools and samples are separately MIT-licensed. Preserve these distinctions and their notices when preparing any distribution; PsyZ is not uniformly MIT-licensed.

SDL's [license](https://github.com/libsdl-org/SDL/blob/fa2c02bb6e21974a89ea9824bc53c9932abe5f9c/LICENSE.txt) is the zlib license. Its source tree also contains component-specific notices, including HIDAPI and YUV conversion code. The complete fetched tree retains those notices.

The experimental `renderers/modern/sdl3_gpu.c`, `sdl3_draw.h` and `shaders/`
are derived from PsyZ's MPL 2.0 platform renderer, including our cumulative
patched baseline. Their location outside `vendor/` does not change that scope.
[The module provenance](../renderers/modern/README.md#provenance-and-shader-builds)
records the revision and patch boundary; shader bytecode is regenerated from
the included GLSL. No DuckStation implementation code is included.

The ESP32 branch is credited as reference material, particularly for native adaptation and the ISO9660/raw-sector extractor. It is not a verified Windows port and is not a substitute for the pinned FoxdieTeam/PsyZ build inputs. Its existence does not resolve rights in the recovered game source.

The adapted PSn00bSDK `vlc2.c` component is MPL 2.0, credited to spicyjpeg; the adapted psxe `mdec.c` component is MIT, credited to Allkern (Lisandro Alarcón). The [movie patch](../patches/psyz-movies.patch) preserves notices and includes their license texts. These files are included by the patch rather than fetched as additional build checkouts. [MOVIE_VALIDATION.md](MOVIE_VALIDATION.md) records the adaptation and its limits.

## Prerelease license check — 10 October 2026

Checked the pinned source trees, their license files and relevant file headers,
the upstream default branches, and the existing upstream license discussion.
This records the published terms and remaining questions; it does not establish
clearance to distribute the complete game executable.

- **FoxdieTeam:** the pinned revision remains the upstream `master` revision.
  The complete Git tree contains no LICENSE, COPYING or NOTICE file, and no
  repository-wide grant was found in the README or game-source notice search.
  [Issue #2040](https://github.com/FoxdieTeam/mgs_reversing/issues/2040) asks about
  the missing license. Its sole comment at the time of this check is general
  commentary by an account with no repository association reported by GitHub;
  it grants no redistribution permission. The issue being closed is not a grant.
- **PsyZ:** both the pinned revision and current `main`
  (`03d890da808c36dae30da39df8a19b3df51fafd4`) retain the scope inventory above.
  The word "Unlicensed" does not provide the terms of the public-domain
  [Unlicense](https://unlicense.org/). The inventory's `psyz/src/psyq` path is
  absent from the pinned tree; the build instead compiles SDK implementations
  from the separately MIT-noticed `decomp` subtree. The headers remain in use.
  Windows also compiles `psyz/src/dbgserver/dbgserver.c`, which is outside the
  listed MPL directories and has no file-level grant or enclosing license.
  Its license scope needs clarification. Its bundled `stb_image_write.h` has
  its own MIT/Unlicense choice, which does not license the debug server itself.
- **Explicitly licensed components:** SDL is zlib, the adapted PSn00bSDK VLC
  decoder is MPL 2.0, and the adapted psxe MDEC decoder is MIT. Preserve their
  notices and modification provenance. SDL includes additional notices:
  HIDAPI offers a BSD-style option, yuv2rgb uses BSD-3-Clause, and the Vulkan
  headers used by the GPU backend identify Apache-2.0. The final package needs
  an inventory of its actual linked components and accompanying runtime files.

For the MPL portions, executable recipients must be told how to obtain the
corresponding MPL-covered source, including our modifications, under MPL 2.0.
An upstream link alone omits our changes. File-level copyleft does not require
unrelated first-party files to adopt MPL. See [MPL sections 3.1–3.3](https://www.mozilla.org/en-US/MPL/2.0/)
and [Mozilla's distribution FAQ, questions 8–11](https://www.mozilla.org/en-US/MPL/2.0/FAQ/).

Release preparation can continue with dependency downloads from upstream and
local builds. Fetching sources during CI, linking statically, or requiring the
user's discs does not itself supply the missing redistribution grants. Public
binary publication remains a separate unresolved decision; no blanket license
has been assigned to recovered or third-party code. No upstream contacts were
made during this check.

The alpha package now includes the listed notices, MPL source-access
instructions, and a separate modified MPL source archive. The optimized native
executable's import table contains only Windows system DLLs; SDL and the C/C++
runtime are statically linked. No tool installers, framework installers or
Debug runtime files are distributed. Microsoft's
[Visual Studio license terms](https://visualstudio.microsoft.com/license-terms/)
and [redistribution documentation](https://learn.microsoft.com/en-us/visualstudio/releases/2022/redistribution)
remain applicable to its tools and runtime code; they are outside our MIT grant.

Clarification of the uncovered source scopes and original game rights remains
open. This check does not audit every transitive source header or establish
clearance for public distribution.

## Tooling and local content

`tools/toolchain.ps1` downloads the official Windows CMake 3.31.8 and Ninja 1.13.1 archives into `.tools` and verifies pinned SHA-256 values. Visual Studio/LLVM and the Windows SDK are discovered from an existing installation. Python dependencies are installed into `.venv` from `requirements.txt`; Jinja2 is pinned to 3.1.6 and MarkupSafe to 3.0.4. This is a source-version lock, not a complete byte-reproducible toolchain. The launcher uses Windows' .NET Framework and its C# compiler; no .NET installer is bundled.

`tools/package.ps1` includes applicable notices and a separate archive of the
modified MPL-covered platform/runtime source. The build scripts and complete
patch stack remain in the source repository. SDL and the C/C++ runtime are
linked statically. The alpha package is unsigned and contains no retail discs,
extracted game content, or personal saves.

The normal host build does not run PsyZ's PS1 SDK bootstrap or require retail executable code at link time. The game still needs local Integral data to run. The importer records disc hashes and identities and preserves raw streams where necessary; those files are not included in source control. The imported disc executable is used for identity validation, not compiled into the host executable.

The controller and SPU compatibility code was checked against the [Sony Run-Time Library Reference 4.7](https://psx.arthus.net/sdk/Psy-Q/DOCS/LibRef47.pdf), including the reverb reservation contract on PDF page 1055 (printed section 15-76). This reference documents behavior; it does not change the license scopes above.
