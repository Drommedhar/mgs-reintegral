# Full native stage recreation — progress ledger

Scene-code handoff: Integral's main campaign is present in the native Windows
build, with modifiable resources and a replaceable renderer. Gameplay acceptance
is assigned to the user's playthrough. Original project files and disc images
remain preserved.

The user completed the campaign through the credits on 10 October. The final
recording is `.local/replays/run-20261010-014859-670.mgsinput`: 89,751 input
samples / 89,755 VSyncs, ending normally at the title. This is human completion
of that campaign route, not validation of every branch or optional mode.

The [campaign completion snapshot](test-data/campaign-completion-20261010/README.md)
preserves all 30 native recordings, their initial saves and session metadata,
retry checkpoints and timing/log data in the original local repository history.
The archive and its personal-path manifest are excluded from the release
repository. Its local manifest records per-file hashes and restore instructions.

Latest preserved retry checkpoint:
`.local/checkpoints/pal-hot-20261010/room-entry.mgssave`, on the stairs outside
the PAL room before detection, with the hot PAL key equipped and reheated.
The first two PAL steps remain complete; the final insertion remains pending.
[Launch and record](docs/INPUT_RECORDING.md#hot-pal-key-retry-disc-2).
The cargo-elevator crash is fixed; its earlier retry checkpoint remains at
`.local/checkpoints/cargo-20261010/ambush-entry.mgssave`.
The earlier cargo `recorded-restart.mgssave` is unsuitable for an encounter
retry: it captured post-fight story 207 and skips the guards. It remains only
as provenance for existing recordings; use the corrected checkpoint above.
The earlier Disc 2 entry checkpoint remains preserved at
`.local/checkpoints/disc2-20261009/recorded-entry.mgssave` (`s13a`, map `0x4986`).
Its export matched all 26,559 inputs / 26,563 VSyncs of the previous recording,
and its 600-VSync reload reached the Disc 2 entry corridor. Checkpoints restore
map entries, not exact process snapshots. Original recordings and cards remain
preserved; each checkpoint has adjacent provenance and validation JSON.

## Map loading pacing — 10 October 2026

Added opt-in **Faster map loading (experimental)** on the launcher's Gameplay
tab, `-FastLoading` in the run wrapper and `--fast-loading 0|1` in the engine.
It defaults off. The previous failed sector-batching loader remains removed.
The new host adapter removes presentation waits during the original stage-load
lifetime while retaining every loader/CD frame, texture allocation and cleanup.
The deterministic clock is selected before startup; normal pacing resumes at
load completion. A separate audio-output suppression flag preserves all SPU
samples/interrupts and independent caller pause state, then primes fresh output.
BGM behavior is unchanged. Replay records this as presentation metadata.

PAL `s16d` load: **3720.3 → 32.7 ms**; Ninja `s08b`: **2836.1 → 27.0 ms** at
2560x1440 with all modern geometry options. Both matched every recorded state
and produced byte-identical final captures. A PAL launch without recording
also matches the image. The existing New Game-to-dock and unattended opening
replays pass (4996 / 2496 inputs); the opening capture also remains identical.
One older `s11e` recording diverges at the same VSync 648 with the option off
and on, so it does not validate the later transitions in that recording.

Both x86 game/launcher builds compile; all **167 modern / 163 reference** CTests
pass, including loading-mode restoration, audio timing/pause, settings,
recording metadata and CLI checks. Bootstrap verifies **85 MGS / 24 PsyZ**
patches, including `mgs-loading-pacing.patch` and
`psyz-audio-output-suppression.patch`. Scoped first-party/audio scans score 100.
The original 142-line `SetupNextFile` retains one nonfixable complexity warning;
cppcheck/clang-tidy remain unavailable. Source files and the archive loader's
resource dispatch are preserved. Details and limits are in
[performance diagnostics](docs/PERFORMANCE_DIAGNOSTICS.md#map-loading), with
local evidence in `build/map-loading/`. Whole-campaign testing remains pending.

## Character joint seams and PBR removal — 10 October 2026

Removed the experimental PBR material/light/shadow implementation, its launcher
controls, F9 toggle, authoring tools and vendor hooks at the user's request.
The local dock launch script now uses original lighting with the three geometry
options. The removed experiment is archived in ignored
`build/pbr-removed-backup.zip`; existing local assets, recordings and saves remain
preserved.

The joint regression exercises the real `libdg` transform and packet writer:
integer face culling drops a subpixel-wide face that the precise renderer can
draw. Precision mode now evaluates face area from the same projected positions
used by the renderer. Nonzero areas retain their sign when converted for the
original ordering/subdivision metadata. Disabled precision and incomplete
projection data keep the original decision. Exact parent-vertex copying remains
unchanged. The integration is exported as `mgs-precise-face-culling.patch`.

The user's intro screenshot reproduced a second cause on the character's back
and arm in `opening`: subdivision projected rounded integer model midpoints,
moving split vertices away from shared edges. It now copies precise endpoints
through the subdivision scratchpad and computes depth-weighted fractional
midpoints, including recursive splits. Invalid source metadata propagates as
invalid. Original integer packets and subdivision decisions remain intact.
This integration is exported as `mgs-precise-subdivision.patch`.

Validation: both x86 builds compile. The culling/PBR changes passed all **166
modern** and **162 reference** CTests; after the subdivision fix, all **166 modern**
tests and the two relevant reference adapter/CLI tests pass. The 1x/4x pixel
tests cover thin faces, winding, double-sided faces, stale metadata, parent-joint
coordinates and identical coverage before/after recursive subdivision. Both
pixel regressions failed before their respective fixes. Adapter tests cover
unequal-depth midpoints, reversed edges and invalid metadata propagation.
The 1500-VSync real-disc dock probe retains matching player movement counters.
A 2500-VSync real-disc intro recording replays all 2496 inputs successfully;
the reproduced back/arm slits are closed in the matching updated frame with
all three geometry options enabled at 2560x1440. Captures are
`build/intro-seams/baseline.bmp` and `build/intro-seams/after.bmp`; earlier dock
evidence is `build/geometry-seams-*`. Bootstrap verifies **84 MGS / 23 PsyZ**
patches. Scoped source/vendor aislop scans score 100 with no findings;
`cppcheck` and `clang-tidy` remain unavailable. This confirms the reported intro
shot, not whole-campaign visual acceptance of the modern renderer.

## Modern renderer — 10 October 2026

The user requested correction of affine texture warping, then expanded the
scope to stable geometry and per-pixel depth as the foundation of our renderer.
The [experimental modern module](renderers/modern/README.md) builds in
`build/windows-x86-modern`; its launcher has independent, persisted switches
for perspective-correct textures, subpixel geometry and depth testing.
The normal build keeps the original renderer and rejects unsupported enhanced
rendering requests explicitly. All three enhancements default off.

Model vertices, including attached parent vertices and subdivided surfaces,
carry float projected geometry alongside unchanged PS1 packets. Opaque models
write reversed D32 depth; semitransparent models test without writing. HUD,
framebuffer effects and untracked primitives retain their original drawing.
This is an experimental model path, not a floating-point gameplay rewrite or
a completed modern material/mesh engine. Whole-campaign visual acceptance of
this new renderer remains outstanding.

Validation: the modern build passes all 164 CTests; the reference build passes
all 162. New tests check actual pixels at 1x and 4x for occlusion, depth reset,
transparent depth reads, perspective UVs, missing metadata and subpixel edges.
The metadata tests cover copied vertices, changed XY words, frame isolation,
table growth and invalid projection inputs. CLI and launcher tests cover all
three switches. The original 32-bit build guard is unchanged.

With all three options enabled at 1280x720, real-disc checks reached the dock
Codec and loaded the hot-PAL checkpoint after 600 VSyncs each. Captures show
the frequency and PAL-room surfaces intact. The unskipped 5000-VSync New Game
probe passed all three stage transitions and reached the dock Codec. Strict
replay passed `native-clock-boot01` (596 samples / 600 VSyncs) and the recorded
campaign segment `run-20261010-005349-602` (2804 samples / 2808 VSyncs, ending
in `s14e`). An older `native-dock-01` recording fails at its first sample on
both renderers (recorded VSync 5 versus current VSync 4); it is not evidence of
a new renderer divergence. Local artifacts: `build/modern-validation/`.

The vendor integration is exported as `mgs-projected-geometry.patch` and
`psyz-projected-geometry.patch`; bootstrap verifies all 82 MGS and 23 PsyZ
patches. Scoped aislop finds no errors or fixable warnings. It retains inherited
renderer size/complexity warnings, the inherited `SetParam` parameter-count
warning, a false positive for reachable `goto found` code in `chanl.c`, and a
generated shader-array size warning. `cppcheck` and `clang-tidy` are unavailable.

The user deferred x64 work. The audit script, detailed findings and compiler
report remain local and excluded from Git. Production pointer guards remain
active; no x64 executable has been linked or validated.

## Agreed prerelease scope — 10 October 2026

The native project's release name is **Metal Gear Solid Re:Integral**, with
[`Drommedhar/mgs-reintegral`](https://github.com/Drommedhar/mgs-reintegral)
as its private GitHub repository. Its
visual identity is **RE:INTEGRAL**, with an original symbol based on an integral
sign inside code brackets, `[ ∫ ]`, suggesting code, reconstruction and stealth.
The user-supplied generated [logo](assets/branding/re-integral-logo.png) is stored
under `assets/branding/` for the setup UI and project presentation, and appears
in the README. Its original PNG bytes are preserved. Branding should present an independent technical
project: do not trace or modify the official wordmark,
use extracted character art or faction emblems, add console branding, or
recreate an exact in-game interface around the title. Include a visible notice:
"Unofficial project; not affiliated with or endorsed by Konami" in the setup UI
and public project/release presentation. Original artwork and this notice do
not establish trademark permission or resolve code, binary or asset rights.

The user accepted the following release requirements:

- Simple clone/prerequisite setup with pinned dependencies downloaded from
  official upstream sources. Required runtime libraries may accompany releases.
- A documented Debug build path using the same build chain as CI.
- GitHub Actions build/test/package workflow and a versioned runnable Windows
  release ZIP, with checksums and matching debug symbols retained separately.
- One small setup/settings UI shared by developer and release builds: validate
  supported Integral BIN/CUE discs, remember their paths, select resolution,
  fullscreen/windowed and aspect ratio, launch the game, and open logs.
- Stable writable save/settings storage that survives application replacement;
  players need no development tools or Python installation.
- Fresh-clone and clean-machine acceptance checks; public CI tests use no
  retail content. Document requirements, controls, known limits and bug reports.
- Main-campaign setup should request Discs 1 and 2; requiring Disc 3 depends on
  actual VR support. Existing importer assumptions must not define the UI scope.

Completed: [upstream license check](docs/THIRD_PARTY.md#prerelease-license-check--10-october-2026).
The user selected MIT for original project contributions, credited to
Drommedhar and RE:INTEGRAL contributors. The scoped [project license](LICENSE),
README licensing summary, and a licensing/attribution issue template are now
present. Documentation invites authors and rights holders to provide
corrections while retaining the known upstream license facts and uncertainties.
FoxdieTeam's missing grant and uncovered PsyZ scopes remain unresolved for
public distribution. The repository and first alpha remain private.

## First native alpha preparation — 10 October 2026

- Added official-source prerequisite setup, pinned Python requirements, and
  Debug/RelWithDebInfo builds with a statically linked C/C++ runtime.
  Both configurations compile successfully with the shared launcher.
- Added the shared Windows launcher with both-disc validation, display and
  gameplay settings, developer switches, additional command-line arguments,
  versioned logs, restart handling, and persistent per-user settings/cards.
- Added manual-only GitHub Actions: one Windows job builds and tests, verifies
  the unpacked ZIP, uploads a draft, then publishes the complete prerelease.
  Pushes consume no Actions minutes. Dependencies are cached; failure/test
  artifacts expire after three days.
- Added player instructions, license notices and source access, SHA-256 sums,
  separate debugging symbols, issue templates, and the [roadmap](docs/ROADMAP.md).
- Optimized local build: all 161 CTests pass, including local GPU checks.
  The package passes synthetic-disc identity/rejection checks, Unicode paths,
  read-only input checks, version/commit checks, and launcher startup.
- A real-disc packaged boot at 1280x720 reached the dock's opening English
  Codec and exited normally after 600 VSyncs. This is a boot check, not a new
  campaign playthrough. Local evidence: `build/alpha-boot/boot.log` and `boot.bmp`.
- An isolated launcher integration check validated both real discs, saved
  settings, launched the game, captured its output, and returned to the ready
  state after 600 VSyncs. Evidence: `build/alpha-launcher-profile/logs/`.
- Bootstrap verifies every pinned source and patch; workflow syntax passes
  actionlint. Scoped aislop reports 100 with no findings; `cppcheck` and
  `clang-tidy` are unavailable to that scan.

The first hosted build compiled successfully and passed 141 of 142 hosted
tests. The remaining audit test exposed Windows short-path normalization in
`compile_evidence`; the helper now resolves its source root. The regression
passes with long and short temp paths under Python 3.11 and 3.12. Python 3.12
also passes the unpacked ZIP and UI checks using the shortened temp path.
The workflow now saves verified dependencies before tests and uses pinned
Node 24 Actions. Release/tag reuse is rejected before a publishing build.
The corrected [hosted run](https://github.com/Drommedhar/mgs-reintegral/actions/runs/38058089785)
passed all **142 hosted CTests**, unpacked-package checks and UI startup, then
published [**v0.1.0-alpha.1**](https://github.com/Drommedhar/mgs-reintegral/releases/tag/v0.1.0-alpha.1)
from `0219c04da14c6e98b928ca736a08ea66ec851378`. The tag, package metadata and
executable version agree. All four downloaded asset digests and all three ZIP
checksums match. Dependency and Python caches are present for subsequent runs.

The downloaded player ZIP also passed local Python 3.12 package/UI checks.
Its executable reached the dock's English Codec and exited normally after
600 VSyncs at 1280x720. Its import table contains only Windows system DLLs.
Local download/boot evidence is under `build/github-alpha-1/`; no retail data,
personal saves or replay archive was uploaded. Existing local history remains
on `godot`, `native-main-before-alpha` and the other preserved branches; `main`
tracks the new private repository's source-only history.

Broader hardware and clean Windows installation acceptance remain user testing.

## Current handoff scope

On 9 October the user assigned playthrough testing to themselves and requested
scene implementation and compilation only. Automated encounter tuning is stopped.
The fresh source audit selects all **92 main-game stage identities**, **738 C
translation units** and **1,715 constructor entries**. All **184 disc overlay
class-ID lists** match; no main-stage table, nonterminal constructor binding,
selected source file or active assembly implementation is missing. The Windows
x86 Debug executable builds. This establishes source/build coverage; campaign
completion is now confirmed by the user's playthrough above. VR uses a separate executable
and is outside this main-campaign source audit.

## Verified in this work session (8–10 October 2026)

- Removed the experimental fast stage loader at the user's request after it
  caused missing surfaces at the PAL checkpoint. The CD reader, stage loader,
  texture staging and BGM reset are restored to their previously pinned code;
  `-FastLoading` / `--fast-loading` are removed. BGM continuation is cancelled.
  A rebuilt 600-VSync PAL checkpoint load at 2560x1440 shows the stairs,
  railings and surrounding textures again. The checkpoint itself is unchanged.
  Evidence: `build/post-credits-20261010/rollback-pal.bmp` and adjacent log/movie.
  The unbuilt perspective-rendering prototype is saved only in that evidence
  directory's `baseline/` diffs and `vertex_depth.c.prototype`; the active
  renderer remains unchanged. That prototype was not shipped; the new opt-in
  modern renderer described above now supplies the geometry enhancements.

- Added opt-in `-AutoCard` (`--auto-card 1`) with record/replay identity support.
  Original card comparisons can use an owned access card without equipping it;
  the original card-level checks still apply. Other equipment and PAL-key
  checks retain their original behavior. Tests exercise the actual GCL
  expression evaluator and session inheritance/rejection rules.

- Added an initial host audio buffer and bounded device-clock correction for
  deterministic recording/replay. Emulated SPU timing is unchanged. Seven
  focused tests pass: auto-card, input sessions, CD, audio, SPU IRQ/sweep and
  replay clock. The PAL load still reports one empty audio refill; occasional
  cutscene/video crackles are not established as resolved. Aislop reports no
  findings across the six changed C/header files, including vendor files copied
  outside ignored directories; cppcheck and a C formatter are unavailable.

- Recovered the PAL room entry before the user's detection lockout from
  `run-20261010-010306-651.mgsinput`: all 122,441 prefix inputs / 122,445 VSyncs
  match. The original Continue bank has stage `s16d`, story 246, selector
  `0x2aa8`, and spawn `(-6800,1900,7900)`. Only PAL temperature changes from
  7560 to 9000, plus the save checksum; the key was already hot. A separate
  600-VSync reload confirms story 246, hot key equipped, temperature 8970,
  alert zero, game status zero, and Snake on the entry stairs outside the room.
  Original recordings and saves are preserved. No game code or executable
  changed. Evidence and exporter: `build/pal-reset-20261010/`.

- Corrected the cargo retry checkpoint after the user reported a skipped
  encounter. The previous crash-time snapshot already contained story 207;
  the original script uses that value to bypass the ambush. Recovered story
  206 and entry selector `0x2e90` from the original recording's transition,
  after 12,001 verified inputs / 12,005 VSyncs, without editing gameplay flags.
  A separate 600-VSync reload now shows all three guards fighting: three live
  actor pointers, health 768 each, retired count zero and the original end
  procedure still registered. The original save bank instead retains selector
  `0x2190`, which returns to the upper landing. The corrected direct checkpoint
  is `ambush-entry.mgssave`; old files and source recordings remain preserved.
  No game code or executable changed. Exporter Aislop scan has no findings.
  Evidence: `build/cargo-checkpoint-20261010/`, including the active-combat
  capture and debugger inspection. [Corrected command](docs/INPUT_RECORDING.md#cargo-elevator-restart-disc-2).

- Fixed the Disc 2 cargo-elevator crash in `run-20261010-004229-177.mgsinput`.
  `zako14com.c::ChangePrio` dereferenced a retired guard after all three ambush
  actors were removed (`n_watchers=3`, retired count 3, game flag 15). Empty
  slots now sort last and receive no writes, matching the earlier elevator's
  fix. Configured slot counts and the completion state machine are unchanged.
  Both builds match all 13,989 complete inputs / 13,993 VSyncs; the old build
  then faults at address `0xC2C`, while the fixed build survives a bounded
  600-VSync held-input continuation. The diagnostic limit intentionally reports
  failure rather than successful movie completion. Three focused commander
  CTests pass, including all cargo-ambush retirement combinations and empty
  registries. The first checkpoint reload only verified arrival in `s14e` and
  missed the post-fight flags; the corrected ambush check is recorded above.
  The 79 MGS / 20 PSYZ patch stack verifies. Aislop reports no new findings,
  errors or fixable warnings; the existing 175-line `UpdateGameFlag` warning
  remains and `cppcheck` is unavailable. Evidence: `build/cargo-crash-20261010/`;
  executable SHA-256
  `57b7926c263bd276193d9923c74eebfc3d271a7217975a43897c6146e1c19d08`.

- Fixed the elevator ambush crash from `run-20261009-191445-721.mgsinput`.
  The commander dereferenced guard slots that had been cleared by actor
  retirement. Empty slots now sort last and receive no writes, preserving the
  encounter's slot counts and completion logic. The old build reproduces the
  access violation after all 123,202 recorded inputs / 123,206 VSyncs match;
  the fixed build matches the same prefix at 2560×1440, survives a bounded
  600-VSync diagnostic continuation and begins loading `s11c`. The continuation
  deliberately returns failure at its limit; it is not recording completion.
  A direct elevator restart loads active combat in a 600-VSync native check:
  [retry command](docs/INPUT_RECORDING.md#elevator-ambush-restart).
- Removed the sky's visible texture grid. Both panorama actors now use a
  scoped background drawing mode with 2D texel alignment and the wider scene
  transform. World sampling is restored afterwards. Before/after captures from
  the same recorded rooftop frame at 2560×1440 show the repair; opaque floor
  and HUD control regions are pixel-identical. [Details](docs/WIDESCREEN.md#sky-texture-seams).
  All 23 focused CTests pass, including 256 guard-retirement masks and GPU
  atlas-edge checks at 1×/2×/8×. The 78 MGS / 20 PSYZ patch stack verifies.
  Scoped Aislop has no new findings, errors or fixable warnings. Four inherited
  long-function warnings and one existing `goto`-label false positive remain;
  `cppcheck` is unavailable. Evidence: ignored `build/tower-report-20261009/`;
  executable SHA-256
  `df38a0a024db4e56632f4c8649d50ed33dd1dd7d86e520e53eeb8c8cc86e9658`.

- Fixed the torture-area crash from `run-20261009-183217-163.mgsinput`:
  the persistent item box dereferenced `GM_PlayerControl` after the player
  actor retired while the cutscene camera remained in first person. Its label
  and proximity pickup now require a live player. Both builds reproduce all
  74,909 complete input samples / 74,913 VSyncs; the old build then crashes,
  while the fixed build survives a bounded 600-VSync diagnostic tail. This tail
  deliberately ends with failure status and is not recording completion.
  A direct torture-area restart is available at
  `.local/checkpoints/torture-20261009/recorded-restart.mgssave`; a 1,200-VSync
  native load check reaches the torture introduction without earlier bosses.
  Original movies/cards remain intact. [Retry command](docs/INPUT_RECORDING.md#torture-area-restart).
- Extended both tiled sky actors to cover the requested widescreen viewport
  without rescaling tiles. The vignette keeps its original gradient and fills
  beyond the outer ring using the same animated edge color/blend mode.
  Coverage checks exercise both buffers, yaw/wrapping and multiple aspect ratios.
  [Rendering details](docs/WIDESCREEN.md#sky-and-vignette-coverage).
- Fixed ignored live SPU ADSR writes: the game's sound-effect stop path changes
  the release rate after key-off, but the mixer retained the key-on value.
  Active voices now receive both envelope registers without restarting playback.
  Tests verify release to silence on looping samples in voices 0/13/23 and live
  attack/sustain changes. This fixes a shared cause of lingering detection/alert
  sounds; listening acceptance for the reported artifact remains with the user.
  Debug builds and 17 focused CTests pass. The 76 MGS / 20 PSYZ patch stack
  verifies. Scoped Aislop has no errors/fixable warnings or new diagnostics;
  three inherited long-function warnings remain and `cppcheck` is unavailable.
  Evidence: ignored `build/wolf-report-20261009/`; executable SHA-256
  `3f702155f99ac45d6ad116f82dd1936f4bd6c566cf81378c6c074fa78afef314`.

- Fixed Mantis's misplaced HIDEO blackout by restoring the original overlay
  channel. Widescreen captures confirm the full black screen and large/small
  lettering. Added SDL port exchange on F2 or L3 + R3, with a visible prompt,
  analog/keyboard/rumble routing and replay support. SDK checks pass; a direct
  Mantis checkpoint test records/replays 1,596 inputs across 1,600 VSyncs and
  moves Snake using the original second-controller flag. User's full encounter
  playthrough remains outstanding. [Evidence](docs/MANTIS_RECOVERY.md#hideo-and-controller-ports-9-october).
- Added opt-in `-MantisMemory random` / numeric seed. Mantis receives a temporary
  synthetic list drawn from Integral's original recognized titles, honoring the
  English dialogue masks. Real cards and play statistics are unchanged; the
  seed is part of recording identity and inherited by replay/resume. Matcher and
  session tests pass. Voiced intro acceptance remains for the user's playthrough.
- Recovered a direct Mantis battle restart from the latest user's recording:
  `.local/checkpoints/mantis-20261009/recorded-entry.mgssave`. Original story 129,
  map, spawn, saved encounter health and bonus items are retained. This avoids
  repeating earlier bosses; it starts after the memory-reading introduction.
  Vendor changes are reproducible through 74 MGS and 19 PSYZ patches.

- Recovered a direct Ninja retry checkpoint from the recorded live encounter
  entry, after the original script assigns story 77 and its spawn. The existing
  Integral save loader accepts it and a 1,400-VSync check visibly reaches active
  Ninja combat; stealth/bandana inventory is preserved. Use
  `.local/checkpoints/ninja-20261009/recorded-entry.mgssave` with `-LoadCheckpoint`.
  This is separate from the older Continue save bank that blocked the earlier
  export, and does not require replaying the earlier bosses. No gameplay code,
  original recording or existing checkpoint was changed. The local exporter
  passes Aislop without findings. [Evidence](docs/NINJA_RECOVERY.md#direct-ninja-retry-checkpoint).
- Fixed the Ninja phase stall reported in `run-20261009-171125-195.mgsinput`.
  A strict replay reproduces all 47,087 inputs and reaches phase 3 with zero
  boss health. Three recovered hit dispatchers were missing their original
  switch bodies, preventing phase/counter updates independently of invulnerability.
  Restored the original MIPS behavior; 960 new reference cases pass, and the
  old code fails the regression test. Ninja now has 3,478 reference comparisons.
  Debug builds, five focused CTests pass, and the 72-patch MGS stack verifies.
  Full boss completion remains for the user's playthrough. Aislop retains one
  inherited vendor size warning; no errors/fixable findings, `cppcheck` absent.
  The fixed build strictly replays the 39,701-input pre-combat prefix. Ninja
  checkpoint export is unavailable because the original stored save still names
  another stage; no new checkpoint was created and existing ones are preserved.
  [Evidence](docs/NINJA_RECOVERY.md#hit-driven-phase-transitions--9-october-2026).
- Fixed the user's Tank victory crash in `run-20261009-165718-122.mgsinput`.
  The main camera ran before the retiring Tank camera and called an already
  removed director. Tank destruction now unregisters its camera callbacks
  before resource/script cleanup, preserving foreign callbacks and deferred
  actor freeing. All 5,823 recorded inputs match; a bounded 600-VSync tail
  enters the post-fight cinematic without a crash. Five focused CTests pass,
  including actual scheduler ordering and the existing 1,260 cleanup traces.
  Debug builds; the change is exported in the 71-patch MGS stack. The old
  snowfield checkpoint is unchanged. The remaining cinematic/next stage are
  for the user's playthrough. Aislop retains nine inherited vendor complexity
  warnings, with no errors/fixable warnings; `cppcheck` remains unavailable.
  [Evidence](docs/TANK_COMPLETION_AUDIT.md#camera-teardown-crash-9-october-2026).
- Fixed the next Tank crash: the dying gunner retains an actor but has already
  released its target. Aim and blast hooks now handle that retirement window.
  All 10,487 recorded inputs match with cheats disabled; a further bounded
  600-VSync continuation passes the crash. This does not establish victory.
  Added opt-in `-Invulnerable` health protection with recorded session identity,
  replay inheritance and original-setting checkpoint recovery. A real-disc
  checkpoint start strictly records/replays 596 inputs / 600 VSyncs. The old
  snowfield entry remains available. Twelve focused CTests pass, Debug builds,
  and both vendor changes are exported in the 70-patch MGS stack.
  Scoped Aislop reports no errors/fixable warnings; 33 existing vendor size/
  complexity warnings remain. `cppcheck` is unavailable; PowerShell is not a
  supported Aislop language and is covered by the session tests instead.
  [Tank evidence](docs/TANK_COMPLETION_AUDIT.md#gunner-retirement-crash-9-october-2026),
  [invulnerability behavior and limits](docs/INPUT_RECORDING.md#invulnerability).
- Fixed the user's next crash in `s05a`: claymore trajectory initialization
  wrote two vectors into a one-vector local, corrupting the native stack.
  An explicit two-element array restores the original stack-buffer contract.
  All 55,657 recorded input checks match and 600 further VSyncs pass the mine
  explosion without a crash. Four focused CTests pass, and the old helper
  fails the new capacity regression. The Debug build and 68-patch MGS stack
  verify. The authentic snowfield entry is cached after a separate strict
  54,470-input recovery replay, ready for immediate resume.
  [Evidence](docs/STAGE_RECOVERY.md#snowfield-claymore-crash).
- Clarified Integral's English setting: dialogue/subtitles switch language,
  while item/weapon descriptions use Japanese tables. The user approved
  future US/EU disc language-resource imports, including German, with
  independently modifiable language packs. This remains future work;
  [scope and plan](docs/ENGLISH_TEXT.md#scope-of-the-original-language-setting).
- Fixed the user's prison encounter crash after the final guards are removed.
  The commander sorted cleared actor pointers; native sorting now places empty
  slots last and updates only surviving actors. All 45,533 recorded input
  checkpoints match, and a bounded 1,800-VSync continuation completes cleanup
  and reaches `s03b` without an access violation. Five focused CTests pass;
  the 67-patch MGS stack verifies. The original recording is preserved and its
  `s03d` entry checkpoint is cached for immediate resume. This verifies the
  reported failure, not the remainder of the campaign.
  [Crash evidence and limits](docs/STAGE_RECOVERY.md#prison-encounter-cleanup-crash).
- Follow-up: overlay MAX now arms at the title actor's ready/menu states,
  excluding startup and the transition frame, then retains later peaks. Direct
  campaign/checkpoint starts arm it after loading. The corrected full-run
  command includes `-BonusItems` for Stealth and Bandana. The 415-input / 419-VSync
  title replay passes and observes the readiness hook; all four relevant timing,
  analysis, input-session and bonus-item suites pass. Diagnostic startup rows
  remain available for replay investigation.
- The user's dock puddle report reproduced 40 ms GPU submission stalls with
  audio queue depletion at 2560×1440. Deferred native framebuffer resolves
  reduce slow intro frames from 191 to two in the same 5,000-VSync replay;
  the puddle burst drops from 77 slow frames to zero. The user confirmed the
  running fix works. Two isolated later intro spikes remain logged. The limiter
  resumes nominal 16.683 ms intervals after stalls without accelerated catch-up.
  The top-right overlay shows FPS, frame time and MAX since menu readiness; recording and
  replay automatically retain only slow-frame timing rows next to input data.
  Strict replay passes all 4,996 input samples; all 148 CTest suites pass.
  [Diagnostics, command and remaining limits](docs/PERFORMANCE_DIAGNOSTICS.md).
- The authentic post-REX checkpoint now follows the original rooftop scenes
  into Liquid's first Normal encounter, with attempt count zero and the original
  768/768 versus 255 health contract. The initial failed fight strictly replays
  all 59,996 samples / 60,000 VSyncs and exports a CRC-valid story 277 map-entry
  checkpoint. A controller-only get-up-kick avoidance change reaches Liquid
  at 4 HP before Snake dies; the first encounter is still incomplete. The new
  checkpoint removes the need to repeat the incoming cinematics while testing.
  [First-encounter evidence](docs/LIQUID_RECOVERY.md#first-encounter-reached-from-completed-rex).
- The full Normal REX encounter now completes from its finite, declared entry
  fixture: both 1,800-HP weakpoints destroyed, 24 Stinger rounds and eight Chaff
  consumed, Snake alive at 640/768, then original `d18a` → `s18a` rooftop
  cinematics. Strict replay passes **17,996 samples / 18,000 VSyncs** with an
  identical final screenshot. The original serializer exports a CRC-valid
  story259 rooftop entry for the next connected check. The controller now
  respects the Stinger pitch limit and uses Chaff against missile tracking in
  both phases; no REX gameplay source was changed. This proves a supplied
  encounter, not a complete New Game campaign or the following Liquid fight.
  [REX completion evidence](docs/REX_ENCOUNTER_CONTRACT.md#completed-normal-encounter-and-strict-replay).
- The dock lamp flash exposed a world-channel 2D screen-fill gap. The shared
  renderer classifier now expands full-width `TILE` overlays in both world and
  HUD channels. New 1×/2×/8× pixel checks reproduce the old failure and verify
  blending, clipping, both buffers and transform restoration, while projected
  world polygons and smaller rectangles retain their existing behavior.
  Matching 2560×1440 dock captures show the flash covering both outer strips
  with every central 4:3 pixel unchanged. Before/after unskipped intro runs
  both reach the dock Codec at 5,000 VSyncs.
  [Shared 2D policy](docs/WIDESCREEN.md#shared-rules-for-original-43-elements).
- The authentic Normal escape checkpoint now completes its full outgoing
  cinematics, Codec, ending, credits, ranking, original Bandana award/save and
  return to title. A separate strict replay passes **79,996 samples / 80,000
  VSyncs**. All three earned-save payload CRCs pass. Loading a copy through the
  original menu starts the next round and reaches the dock with the Bandana and
  completion count preserved; ordinary input moves Snake 453 units over 24
  ticks. No new gameplay fixture or code repair was needed. This extends the
  supplied Normal Liquid retry lineage, not a New Game campaign playthrough.
  [Normal ending evidence](docs/ESCAPE_RECOVERY.md#normal-ending-strict-replay-and-earned-save-reload).
- Optional native widescreen and output resolution now support
  `-Widescreen -Resolution 2560x1440 -Fullscreen`. The 3D view expands while
  logos, menus and Codec retain their 4:3 canvas. Corrected high-resolution 2D
  texel alignment removes the reproduced Konami logo seam. Water/blur/focus
  copies preserve scaled framebuffer detail; translucent lights and mask tests
  now also preserve fine destination detail. Original textures and actor
  effect shapes remain unchanged. Cold startup captures and strict menu/Codec
  recording prefixes were inspected. The unskipped intro completes 5,000
  VSyncs to the dock Codec. These checks do not establish every scene's visual
  fidelity or performance. [Widescreen evidence](docs/WIDESCREEN.md),
  [light diagnosis](docs/WIDESCREEN_LIGHTS.md).
- Wider rendering initially changed a guard's gameplay visibility. Normal and
  fog bounds now retain the original actor-visible values after rendering.
  The previously failing strict garage prefix passes 1,997 samples / 2,001
  VSyncs in 2560×1440 widescreen fullscreen. The full recording then passes all
  **6,496 samples / 6,500 VSyncs** and loads `s19b`. Original-aspect and
  resolution-only playback of that prefix also pass.
  [Visibility evidence](docs/WIDESCREEN_VISIBILITY.md).
- The rebuilt default passes **146 CTest suites**, including 1×/2×/8× atlas,
  framebuffer and world-blending tests. Bootstrap verifies **65 MGS / 17 PsyZ
  patches**. First-party scans have no findings; touched vendor scopes retain
  inherited nonfixable size/complexity findings and a `goto`-label false positive,
  with no errors or fixable warnings. cppcheck and clang-tidy remain unavailable.
- The reported mesh-edge/transparent-border artifacts prompted a renderer repair:
  polygon pixel-centre alignment, vertex-order-independent UV sampling, sprite
  UV wrapping and VRAM texture/palette wrapping. Negative controls reproduce the
  old defects; the new tests pass 70,656 native coverage comparisons and 124,980
  texture comparisons at each tested resolution. The same authentic garage
  recording passes all 6,496 samples / 6,500 VSyncs before and after the change;
  matching scene captures were inspected. Mod-resource and renderer boundaries
  are preserved. This verifies specific renderer contracts, not every reported
  scene or a complete campaign. [Renderer evidence](docs/GPU_RASTER_EDGES.md).
- Garage completion exposed an incorrect recovered gun rotation call. Restoring
  the original `RotMatrixZYX` order now lets normal gunfire explode the drums,
  break the gate and follow the authored jeep exit into `s19b`, alive at 408/768.
  The authentic garage checkpoint route and all 6,496 recorded samples replay
  successfully. Tests cover 520 original-MIPS matrices and 1,560 independently
  composed bullet paths; the old call fails. The original exit deliberately
  retains the garage retry snapshot, so no standalone escape checkpoint was
  fabricated. [Garage evidence](docs/GARAGE_ROUTE.md).
- The completed Liquid retry encounter now continues through the original
  post-fight movies and Codec into the garage, with no post-fight inputs or new
  gameplay fixture. A 25,165-sample prefix replays and exports a CRC-valid
  Normal/story283 garage checkpoint. [Connected handoff](docs/LIQUID_RECOVERY.md#connected-garage-handoff).
- From that authentic checkpoint, the combined `garage-escape` controller run
  now completes garage → both escape checkpoints → five Liquid damage releases
  → `s20a` on Normal. Snake survives with **30/768** health, no rations used and
  no Stealth/Bandana. All **17,996 samples / 18,000 VSyncs** replay with matching
  state, and the original serializer exports a CRC-valid Normal/story286 ending
  entry. This connects supplied late-game scenarios; it is not a New Game campaign.
  [Connected Normal escape](docs/ESCAPE_RECOVERY.md).
- The reused torture actor passes **2,432 original-MIPS comparisons** for round
  handoff, controller recovery and surrender. These checks found no discrepancy;
  a complete live torture session remains unverified.
  [Torture evidence](docs/BOSS_TERMINAL_VALIDATION.md#torture-round-recovery-and-surrender).
- Earlier encounter completion audits add **2,135 Ninja** and **1,260 Tank**
  original-MIPS comparisons. Victory callback conditions, arguments and ordered
  side effects match; no additional gameplay repair was justified. Complete
  live fights remain open. [Ninja evidence](docs/NINJA_RECOVERY.md#terminal-callback-verification),
  [Tank evidence](docs/TANK_COMPLETION_AUDIT.md).
- Both full escape variants now clear the two checkpoints, five guards and five
  Liquid damage thresholds, then load their authored `s20a`/`s20ar` destinations.
  Rival-jeep wall contact exposed an undersized hazard-output buffer; the native
  caller now supplies both original vectors. Its 256 new original-MIPS cases
  reject the old buffer. The base route replays all 14,996 inputs with matching
  state and supplies an authentic next-map checkpoint.
  [Escape evidence](docs/ESCAPE_RECOVERY.md).
- That real escape checkpoint now completes `s20a` cinematics and Codec,
  ending, all credits phases, ranking, Bandana award, original completed-game
  save, and title. The inherited difficulty is Easy. No input is sent before
  ranking; no new gameplay fixture is supplied. All three save payload copies
  pass their original CRC checks. [Connected finale](docs/ESCAPE_RECOVERY.md#connected-ending-from-the-escape-checkpoint).
- The full Normal Liquid fight exposed and repaired lost primary/secondary
  action-timer arguments. Original MIPS confirms both callbacks receive their
  pre-increment tick. The supplied retry encounter now completes 54 damage events,
  reduces Liquid 255→0, and follows the original victory into `d18a`; Snake
  survives with 14/768 health. No combat state is forced after the incoming
  fixture. [Liquid evidence](docs/LIQUID_RECOVERY.md).
- A follow-up [hazard-output audit](docs/HZD_OUTPUT_AUDIT.md) corrected the same
  two-vector allocation in Liquid's climb action. All six selected callers now
  provide sufficient output storage. The dispatcher and climb tests add 864 and
  840 original-MIPS cases, respectively. With both repairs, the full retry fight
  records and replays 7,196 inputs with matching state and final pixels.
- Before the widescreen changes, the default build passed all **119 CTest suites**. The source stack had
  **64 MGS / 16 PsyZ patches**. New first-party checks have no Aislop findings;
  nine inherited nonfixable size/length warnings remain in Liquid's recovered
  action file, two in the garage actor and five in the touched renderer scope.
  The C/C++ scan lacks cppcheck and clang-tidy.
- Both original completed-mission saves now load through title → `abst` →
  `d00a` → dock, preserve the respective earned Bandana/Stealth, and allow
  453 units of movement over 24 moving ticks. Both source and copied saves remain
  byte-identical. [Completed-save load evidence](docs/COMPLETED_SAVE_LOAD.md).

- Work has returned to systematic stage-behavior completion at the user's request.
  The new human crash report is deferred. A fresh audit found no omitted active
  main-stage body: all 92 selected stages still resolve to the existing 738 C
  units. Reused constructor layouts and inspected variant data agree with the
  supplied overlays; this does not establish complete campaign playability.
- REX phase-completion and Liquid victory now have **964 additional original-MIPS
  state/callback comparisons**. The escape finale adds **614 comparisons**,
  including a continuous 74-step sequence, bringing its road suite to 3,174.
  These checks found no recovered-behavior discrepancy and do not claim completed
  live boss fights or a completed chase. [Boss evidence](docs/BOSS_TERMINAL_VALIDATION.md),
  [escape evidence](docs/ESCAPE_RECOVERY.md).
- The full ending checks exposed an unused PS1 low-memory read in the footprint
  actor. Native C now checks movement eligibility before looking up the player's
  map; **3,446 cases** verify inactive cinematic players and active footprints.
  Restoring the old ordering reproduces the fault. Both companion scenarios now
  complete story 293/294, all five credits phases, ranking, original completed-
  mission saves and return to title through the PocketStation decline option.
  Both saves pass original CRC checks and contain the appropriate earned item:
  Bandana for Meryl's branch, Stealth for Otacon's. These are supplied late-game
  scenarios, not completed campaign playthroughs. [Ending evidence](docs/CINEMATIC_STAGES.md#complete-ending-scenarios).
  The rebuilt default passes **108 CTest suites**; **60 MGS / 15 PsyZ** patches
  verify. [Native compatibility](docs/NATIVE_COMPATIBILITY.md#cinematic-footprint-eligibility).

- The next human recording, `xbox-02`, reproduces a Chaff Grenade explosion crash:
  its 64-particle effect passes a null drawing rectangle into the native renderer.
  The native actor now provides an explicit zero-offset rectangle; exact original
  PS1 low-memory offsets remain unverified. All 3,752 retained inputs match;
  a 720-VSync diagnostic tail observes the burst, normal effect expiry/primitive
  release and health 256 afterward. The original recording is unchanged and its
  heliport entry is cached for resume. The actor/packet regression passes 6,953
  checks and rejects the old null argument. All **106 CTest suites** pass and
  **59 MGS / 15 PsyZ** patches verify. One inherited Chaff `Act` length warning
  remains; the new tests have no Aislop findings.
  [Chaff repair and evidence](docs/NATIVE_COMPATIBILITY.md#chaff-particle-drawing-offset).

- `-ResumeInput` recovers the last loaded campaign map's original entry snapshot
  once and caches it for direct future boots. The user's crash recording yields
  heliport `s01a`: a fresh process loads `init_ve` → `s01a`, preserving the recorded
  entry position, health, equipped Stealth and inventory checksum. New recordings
  snapshot this checkpoint and replay independently. A 3,000-VSync SDL probe skips
  the original entry dialogue, verifies 63 units of movement over 13 moving ticks
  with collision contact, and replays with matching checkpoints and final pixels.
  This establishes checkpoint restart and limited input movement, not a full
  heliport playthrough. All **105 CTest suites** pass and **58 MGS / 15 PsyZ**
  patches verify. Source recording remains unchanged. Scoped first-party Aislop
  scans report no findings; four inherited vendor complexity warnings remain.
  [Resume usage](docs/INPUT_RECORDING.md#resume-at-the-last-map-entry).

- The user's Xbox recording reaches the authored dock → `d00a` → `d01a` → heliport
  transition with Stealth on Very Easy. All 15,675 complete samples replay with
  matching checkpoints. A heliport Chaff pickup then exposed an unported PS1
  address-sign test in the item destructor. The old dispatch crashes; the fixed
  build executes the inline pickup script and survives a separately labeled
  diagnostic tail. The original recording is preserved. The 104-case destructor
  regression rejects the old implementation. The rebuilt default passes all
  **103 CTest suites**; **57 MGS / 15 PsyZ** patches verify through bootstrap.
  [Crash evidence](docs/HELIPORT_PICKUP_CRASH.md).

- Optional Stealth/Bandana ownership and original save/continue behavior have
  passing tests. A 2,400-VSync live inventory check equips and removes both through
  normal SDL input, verifies their actual actors and Stealth model flags, and
  finishes unequipped. A separate 6,000-VSync New Game route grants exactly two
  items and reaches dock movement. Guard detection and ammunition consumption
  remain untested in these fixtures. [Bonus evidence](docs/BONUS_ITEMS.md).
- Both gamepad ports now initialize in analog mode. Two virtual SDL controllers
  pass stick endpoint/center/quantization, keyboard and rumble checks. SDL detects
  the user's Xbox One Elite 2 Controller; human controller play remains pending.
- Native input recording captures both ports and game checkpoints, with initial
  card snapshots and isolated replay saves. A deterministic movie clock fixes
  host timing differences while retaining strict checkpoints. A 2,400-VSync
  bonus-menu recording replays with matching state and identical final pixels;
  an unbounded recording closed normally replays to its saved endpoint. The
  default build also replays 3,000 VSyncs through title/New Game/`d00a`/dock with
  the probe's normal skip controls, 431 movement units and identical final pixels.
  An intentionally wrong health checkpoint is rejected with failure status. The
  default Debug build passes **103 CTest suites**. All **57 MGS / 15 PsyZ** patches
  verify through bootstrap. This is not yet a full campaign replay.
  [Recording details](docs/INPUT_RECORDING.md).

- User-reported intro stalls were reproduced and traced to lost SPU interrupts
  and per-batch GPU buffer allocation. The corrected optimized run plays the
  complete 1,981-frame New Game cinematic in 66.10 seconds and reaches the dock
  Codec with no input after the title. Maximum measured draw time drops from
  701.73 ms to 5.59 ms, with no animation-update gaps above 250 ms or audio queue
  starvation. Underwater packet-layout, scratchpad and lifetime defects are
  corrected against original MIPS traces. GPU extent limits are covered by
  native, scaled and software pixel tests. The default Debug build also completes
  the unskipped intro: about 66 seconds, maximum measured draw 7.23 ms, no long
  animation gaps and no audio starvation. All 94 CTest suites pass in Debug and
  the optimized external-renderer build; the 55/13 vendor patch stacks validate.
  [Intro evidence](docs/INTRO_TIMING.md), [renderer fix](docs/GPU_UPLOAD_ARENA.md).
- Fresh default startup completes all three submarine-opening parts and returns
  to the original title without input. The maximum animation-update gap is
  **33.603 ms**, with no gaps above 250 ms. New Game starts the separate underwater
  infiltration cinematic. This verifies the native startup route, not retail
  audiovisual fidelity. [Startup evidence](docs/NORMAL_STARTUP.md).

- Auxiliary theater, selector and sound stages now reuse complete vendor C; the
  vibration editor has tested native host file I/O. Theater/select1/sound startup
  checks completed 900/600/600 VSyncs. `s03dr` shares 468 instruction-identical
  functions with `s03d`; its original story=27 fixture completed 1,800 VSyncs
  and observed 2,589 units of SDL-input movement over 25 movement ticks.
  [Auxiliary evidence](docs/NATIVE_AUXILIARY_STAGES.md).

- The stage registry selects recovered constructor tables without callable PS1
  addresses. Shared sources compile once. The selected stages are authoritative
  in [config/stages.json](config/stages.json); selection alone is not runtime evidence.
- The current optimized build compiles **738 game translation units** across all
  **92 configured campaign and menu stages**, including one native disc-safety
  replacement. The full Debug build passes **94 CTest suites**. These are source/build counts,
  not a claim of complete campaign playability.
- A 6,000-VSync run followed **title → New Game → `d00a` → `s00a`** using an SDL
  virtual controller. Normal difficulty, opening Codec advancement, 431 horizontal
  movement units, 21 movement ticks and 21 collision-contact ticks were observed.
  That older probe deliberately skipped cinematics and did not validate intro playback.
  The external renderer-module build repeated this route successfully after the
  overlay-lifetime changes. A separate 393-unit build completed the New Game
  regression with the new GPU mask implementation. [Log](build/renderer-contract-new-game.log),
  [capture](build/renderer-contract-new-game.bmp).
- A 7,200-VSync Debug run entered `s01a`, completed the authored `d01a` cinematic
  camera stream and reached Mei Ling's Codec conversation at 140.85.
  [Log](build/intro-audit/heliport-7200.log),
  [capture](build/heliport-complete-frame.bmp).
- Thirteen early-stage direct-entry smoke checks ran for 900 VSyncs. Their visual
  results and missing scenario prerequisites are recorded in
  [early-stage validation](docs/EARLY_STAGE_VALIDATION.md). These are entry checks,
  not boss or stage completion.
- Forty-five constructor bindings for `s05a` and `s11a` were checked against the
  original overlays. Both stages compile and finish bounded entry checks.
  `s11a` requires its original incoming map `a9d5`. A separate `s05a` story=65
  debugger fixture ran the original intro callback, which initialized the boss
  state and called the tank constructor. Virtual input moved Snake 3,658 units
  and the run completed 2,400 VSyncs. The tank was outside the final camera view;
  this establishes scenario/constructor execution, not combat completion.
- `s03d` now has 28 verified constructor bindings and 32 functions recovered from
  21 missing assembly blocks. A debugger scenario fixture supplied only original
  story value 27, after which the original script advanced to 28 and instantiated
  Meryl, the commander and three guards. Virtual input moved Snake 1,690 units;
  the run survived 2,400 VSyncs and later displayed Game Over after guard attacks.
  This fixture does not establish the normal campaign route into that encounter.
  [Recovery evidence](docs/data/s03d_recovery.json).
- The original Mei Ling save UI, entered from development stage `s02a`, displayed
  completion and wrote an 8,192-byte save. Its original header, `s02a` stage name
  and CRC were independently verified. A separate, explicitly documented story=1
  debugger fixture then completed **save → fresh process → title Load Game →
  `abst` → restored `s02a`**. Original menu callbacks accepted the save, and normal
  controller input moved the restored player 1,651 units over 24 movement ticks.
  This is a scenario-fixture round trip, not normal campaign progression.
  [Save evidence](docs/NATIVE_SAVES.md).
- Overlay initialized data and BSS now reset on actual `.b` loads, including cached
  loads, while resident state and restarts that skip the overlay remain intact.
  EUC-JP string bytes used for original identifiers are preserved in generated C.
- The missing Codec frequency is fixed by correcting GPU texture/palette ordering.
  A pixel regression reproduces the old failure and passes with the fix.
- Disc 2's furnace (`s13a`) now loads with the original incoming map and position
  from `s12c`'s `sub_DECC`. An explicit debugger fixture ran 900 VSyncs and moved
  Snake 3,112 units down the stairway. The default development spawn had dropped
  him into the furnace and reached Game Over. This corrected fixture is not yet
  evidence of the campaign disc-change route.
- A separate run now executes **`change` → Disc 2 → `s13a`** through the original
  disc UI and script, using virtual Start and no debugger changes to game state.
  The game identifies Disc 2, sets the incoming position and loads the furnace;
  input again moves Snake 3,112 units. The run completes 2,400 VSyncs. It starts
  at `change`, so the full route into that screen remains unverified.
  [Disc-change evidence](docs/DISC_CHANGE.md).

- Mantis (`s07b`/`s07br`) now compiles from recovered native Meryl/Mantis code.
  Original story fixtures instantiate both actors, execute HIDEO and return,
  projectiles, chairs and pots. The 3,600-frame fight check passes movement after
  blackout; this is not boss completion. [Evidence](docs/MANTIS_RECOVERY.md).
- First Sniper Wolf stages (`s10a`/`s10ar`) complete their original introduction
  and pass controller movement. A separate story149 fixture observes the original
  script constructing both Wolf and wounded Meryl. Guard actions/AI/commander have
  133 original-MIPS comparisons. [Evidence](docs/NATIVE_S10_RECOVERY.md).
- The recovered Ninja and effects compile in `s08b`/`s08br`, with 383 original-MIPS
  spatial/route comparisons passing. The original `s08b` introduction releases
  control, Ninja attacks and throws Snake, and virtual input passes 1,049 units
  over 26 movement ticks in an 1,800-VSync check. This is not fight completion.
  [Evidence and native clone-lighting correction](docs/NINJA_RECOVERY.md).
- Container geometry and behavior pass eight and 133 original-MIPS fixtures;
  Raven navigation/damage adds 352 comparisons. `s15c` story242 runs 900 VSyncs,
  renders the warehouse and moves Snake 2,996 units. Story219 paired with this
  revisit resource set requests an absent model and fails; that failed fixture
  is retained separately. [Recovery and limits](docs/CONTAINER_RECOVERY.md).
- A second `s15c` fixture restores maximum serialized container damage and passes
  the same 900-VSync movement check. `s15a` story211 creates Raven and intact
  containers through the original script and completes 1,800 VSyncs with movement.
  The fixture does not establish a completed Raven fight. [Evidence](docs/S15A_RECOVERY.md).
- Original Options and Previous Operations render their menus. The opening runs
  7,200 VSyncs into the submarine scene; tower, underground-base and ending
  fixtures render their original cinematics. Credits run 6,000 VSyncs with
  scrolling text over decoded video. [Evidence](docs/CINEMATIC_STAGES.md).
- The tower helicopter stage `s11g` has 1,008 original-MIPS comparisons. Its
  story177 fixture executes the Hind actor and aiming code, returns control and
  passes 665 movement units over 19 movement ticks in 1,800 VSyncs. The fight is
  not completed. [Evidence](docs/HIND_RECOVERY.md).
- The elevator encounter `s14e` now selects native guard, commander, and elevator
  code. Its original arrival and ambush scripts run in separate story fixtures;
  the ambush spawns three guards and can kill the fixture's low-health Snake.
  The guard implementation passes 586 original-MIPS comparisons.
  [Evidence](docs/NATIVE_S14_RECOVERY.md).
- Hind variants now have 1,456 original-MIPS helper comparisons. `s11h` enters
  its original boss branch and returns control with 2,888 movement units.
  `s11b` adds 833 comparisons for its distinct cinematic and smoke actor. A
  documented trigger-volume fixture follows the authored cinematic and restart
  into `s11g`, returns control, and later reaches normal Game Over under idle input.
  [Variants](docs/HIND_VARIANTS.md), [tower transition](docs/S11B_RECOVERY.md).
- The shared countdown matches 252 original-MIPS timer, callback, digit-call,
  and GPU-packet cases. Liquid's 227 recovered routines now link with Snake18
  and LensFlare. The original story277 introduction completes and releases
  control; a retry fixture moves Snake and reaches rooftop climbing. The hazard
  query now receives its required two-vector output buffer, fixing the climb
  stack overwrite. The 1,800-frame retry run is exception-free but ends hanging,
  so its generic movement probe reports incomplete. Liquid has 7,680 state
  comparisons and Snake18 has 1,134 movement/input comparisons. The later
  dedicated Liquid scenario above completes the fight.
  [Countdown](docs/COUNTDOWN_RECOVERY.md),
  [Liquid](docs/LIQUID_RECOVERY.md), [Snake18](docs/NATIVE_SNAKE18_RECOVERY.md).
- Both REX stage variants now compile with 40 named constructor bindings and
  13 recovered actor/effect units. The helpers pass 1,823 original-MIPS cases;
  the original story255 first-phase script now runs for 1,800 frames, creates
  REX and its drums, accepts movement, and shows laser attacks and damage
  reactions. Neither REX fight completion nor the alternate variant is validated.
- Rappel (`s11d`) runs its authored story178 arrival and Codec, then accepts
  normal lateral input on the rope. Its 2,816 MIPS comparisons pass; the complete
  descent remains unvalidated. [Evidence](docs/RAPPEL_RECOVERY.md).
- A 7,200-frame no-input fixture follows the original `d18a` story275 cinematic
  callback into `s18a` and constructs Liquid, Snake18 and the countdown.
  [Evidence](docs/D18_CINEMATIC_VALIDATION.md).
- Garage (`s19a`) now compiles its guard, commander, timer, drums, gate, jeep,
  Snake and companion code. It has 666 original-MIPS guard/timer comparisons,
  16 footprint-interface cases and 4,453 original-MIPS passenger/controller
  comparisons. The authored story284 entry runs for 1,800 frames and normal
  input moves Snake 1,286 units. Driving and encounter completion remain untested.
  [Evidence](docs/GARAGE_PROPS_RECOVERY.md).
- Escape (`s19b`/`s19br`) now links all recovered road, vehicle and character
  code. The original four helper suites passed 7,449 original-MIPS cases. Both variants run
  their authored introduction; a normal SDL input probe changes mounted aim in
  both directions and creates 15 player bullets. The 3,600-frame run reaches
  original Game Over after input stops. A newer full chase now completes the
  original outgoing transition. [Evidence](docs/ESCAPE_RECOVERY.md).
- Ranking and its PocketStation menus now compile from native C, replacing all
  97 missing game assembly blocks. The suites cover 39,970 original-instruction
  comparisons and explicitly identified repair cases. A live 1,800-VSync run
  renders the score screen, counters and award. Later supplied ending scenarios
  complete ranking, save and title; both saves also reload into a new round.
  Reaching them from full campaign play remains open. [Evidence](docs/RANKING_RECOVERY.md).
- Briefing now has all 43 missing assembly blocks replaced by C and passes
  109,348 original-instruction comparisons. An SDL input run follows intro
  cancellation into the original selector and starts another topic, which
  advances 383 actor ticks. [Briefing evidence](docs/NATIVE_BRIEFING.md).
- The photo album has all 16 missing blocks recovered and passes 11,404 original
  comparisons. A native drawing-order fix restores its missing menu labels.
  Initial UI rendering is verified; a full photo editing/save/reload session is
  still open. [Album evidence](docs/CAMERA_ALBUM_RECOVERY.md).
- Equipped-camera compression now uses native packet memory; four complete
  synthetic images produce the same encoded streams and retry behavior as the
  original instructions. [Capture evidence](docs/EQUIPPED_CAMERA_CAPTURE.md).
- Native startup now selects original English text. The dock Codec displays
  English dialogue and the corrected 140.85 frequency.
- The earlier frozen stack contained 57 MGS patches and fifteen PsyZ patches.
  Full bootstrap verification passes for both stacks. The renderer module contract and resource
  override boundaries are preserved through these additions.

These are **automated runtime checks**, not a human dock playthrough or campaign
completion. Direct stage entry does not supply missing story initialization.
Debugger scenario fixtures are recorded separately from normal game flow.

## Work in progress

The user-supplied Integral all-bosses TAS input movie (BizHawk 1.11.4) is now
downloaded and inspected. A reusable inspector validates all 313,202 input frames
and exports attributed CSV segments with both controllers and disc commands;
14 parser tests pass. A 415-frame initial dock/pipe segment is exported for the
next playback integration. The native game has not replayed this movie, and its
Extreme-difficulty save-RAM setup needs an explicit compatible starting state.
[Replay research and tooling](docs/TAS_REPLAY_RESEARCH.md).

The hand-authored automated dock navigator remains incomplete. Analog SDL steering now
keeps the pipe/crossing route clear of static collision, but guard avoidance
still fails. The latest normal-New-Game run waits safely at the spawn, observes
the original elevator descending and its guard leaving, then dies after the
central crossing. The log is `build/dock-route/arrival18000.log`; it was stopped
after the recorded player death. This verifies elevator arrival behavior, not
boarding, ascent, or a connected heliport transition by that navigator. The user's
later Xbox recording does establish the authored transition with Stealth on Very
Easy, and its complete prefix replays with matching state. It now provides a
recorded route independent of the navigator's guessed patrol timing.

All configured main-stage source selections are now present in the native build.
The current priority is stage behavior: boss completion, revisits and authored
campaign transitions. Individual new human crash recordings are deferred at the
user's request. A clean source-coverage audit does not establish that every actor
and campaign transition behaves correctly.

The encounter and acceptance items below are retained as test history and future
user-playthrough coverage, not an autonomous work queue. Do not resume automated
fight tuning or hold the source handoff for a passing automated campaign run.
Implementation work should address demonstrated missing scene code or user-reported
defects within the requested scope.

1. User playthrough: connected REX/Liquid and garage/escape through the original
   damage, input and script systems. The supplied Liquid retry fight and full
   escape chase now complete their authored handoffs. Liquid also reaches the
   garage through the original post-fight script. The authentic garage checkpoint
   route now completes the garage and full Normal escape continuously, reaching
   a verified original `s20a` entry. Complete endings have separate validation;
   the Normal checkpoint now also completes credits, save, title and a verified
   next-round save load. REX now completes both damage phases, strictly replays,
   and exports the original story259 rooftop handoff. The first Liquid encounter
   remains unverified from that checkpoint. No REX gameplay defect was demonstrated by these
   runs. See the [REX contract](docs/REX_ENCOUNTER_CONTRACT.md) and
   [campaign code audit](docs/CAMPAIGN_CODE_AUDIT.md).
2. User playthrough: save/load after normal progression, overwrite and error UI.
   Both completed-mission saves already reload through the original menus.
3. User playthrough: remaining authored movie transitions and audiovisual timing. The bounded native
   VLC/MDEC/STR/XA implementation now completes an original 414-frame clip in a
   diagnostic scenario. [Movie evidence](docs/MOVIE_VALIDATION.md).
4. Make SDK, graphics, sound or resource-lifetime corrections when a concrete
   scene implementation defect requires them. GPU masking and 5-bit blending pass native/scaled pixel checks
   and software transfer tests. [Graphics evidence](docs/GPU_MASKING.md).

## Modding and remaining limits

The loose-resource interface supports exact-length original-format assets under
`mods/stages/<stage>/<hash>.<extension>`, excluding executable PS1 `.b` overlays.
A verified replacement selected original texture bytes; custom artwork and
resized assets have not yet been demonstrated. Models, textures, sounds and
scripts remain external resources with explicit loading boundaries.

A working [renderer module interface](docs/RENDERER_MODULES.md) can replace the
current renderer at build time. Its present contract receives PS1 primitives and
VRAM operations. A modern mesh/material interface and standard-format asset
imports need further work; the current boundary is not a stable binary plugin API.

Remaining work includes runtime defects, connected campaign progression,
revisits, bosses, save/load acceptance, movies and sound fidelity, disc switching,
reaching the verified endings from connected campaign play. VR missions need separate recovery and validation. See the
[stage inventory](docs/STAGE_RECOVERY.md) and [backend gaps](docs/BACKEND_GAPS.md).
