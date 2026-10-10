# Campaign completion snapshot — 10 October 2026

The user completed the main campaign through the credits. The last recording,
`run-20261010-014859-670.mgsinput`, contains 89,751 input samples / 89,755 VSyncs
and ends normally at the title. Earlier sessions preserve the playthrough's
crashes and retries. This is a completed human route, not a claim that every
recording passes replay on the current executable.

The local-only `native-replays.zip` preserves 337 files, including all 30 native recordings
from `.local/replays`, their complete session directories, timing and console
logs, all `.local/checkpoints`, and the current memory-card saves in
`.local/runtime`. Empty directories are retained because session identities
distinguish an empty card directory from an absent one. The original local
files remain untouched. No disc images or extracted game resources are included.

The replay archive and its entry manifest are retained in the original local
development checkout. They are omitted from the release repository; these
instructions document the local evidence archive.

`manifest.json` records every archive entry, its size and SHA-256, movie
identities, sample counts, footer status and executable hashes. Every archived
file was read back and compared with its original hash. Session identities,
initial card files and starting checkpoint hashes were also checked. The
recordings are byte-for-byte originals, including incomplete crash recordings
and intentional negative-test fixtures.

## Restore and use

From the project root, extract into a fresh directory to preserve active saves:

```powershell
$archive = 'test-data/campaign-completion-20261010/native-replays.zip'
$manifest = Get-Content 'test-data/campaign-completion-20261010/manifest.json' -Raw | ConvertFrom-Json
if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.archiveSha256) {
    throw 'Replay archive checksum mismatch.'
}
$restored = Join-Path $env:TEMP ('mgs-campaign-' + [Guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $archive -DestinationPath $restored
& ./tools/run.ps1 -ReplayInput "$restored/.local/replays/run-20261010-014859-670.mgsinput"
```

Use `-Disc` and `-DiscTwo` if the original Integral images have moved. The
launcher validates the images against the recorded hashes and replays with
isolated copies of the session's original saves. Recordings retain the original
machine's absolute paths as provenance; the archive layout preserves relative
movie/session relationships.

To resume human testing instead, use `-LoadCheckpoint` with an extracted
checkpoint, such as `.local/checkpoints/pal-hot-20261010/room-entry.mgssave`.
The correct cargo-encounter retry is `cargo-20261010/ambush-entry.mgssave`; its
older `recorded-restart.mgssave` is retained for provenance and skips the fight.
See [recording and checkpoint instructions](../../docs/INPUT_RECORDING.md).

## Source and build state

The milestone commit contains all first-party source, build tools, tests,
documentation, the dependency lock, and all 80 MGS / 21 PsyZ patches. A complete
comparison against the pinned patched vendor trees found no unexported source
changes. Run `./tools/bootstrap.ps1` and `./tools/build.ps1` to rebuild using the
dependencies and toolchain described in the project README.
Patch files retain LF line endings through `.gitattributes`, including on
Windows checkouts with automatic CRLF conversion enabled.

Fast loading and BGM continuation are removed. The original renderer is active;
the unfinished perspective prototype remains separate. The milestone also
contains the subsequent opt-in AutoCard feature and audio buffering adjustment.
Their focused tests passed, and the PAL checkpoint was rechecked at 2560x1440.
The current executable therefore differs from the exact playthrough executable;
both hashes are in the manifest. Replay compatibility is checked by the game's
recorded state assertions, not inferred from successful compilation.

The exact playthrough executable remains locally at
`build/post-credits-20261010/before.exe`, with its original PDB alongside it.
Build outputs and retail assets remain outside Git; the committed source and
patch stack are the rebuild path.
