# Optional English and German packs

Language packs use text, glyphs and matched speech from your own regional discs
while retaining Integral's stages, models, animation, collision and game scripts.
This is experimental, partial localization. Movies, unmatched dialogue and
Integral-only descriptions such as the Very Easy MP5 retain their original assets.

In the launcher's **Languages** tab, select a `.mgslang` file for either field:

- **Text pack** replaces inventory descriptions and unambiguously matched text.
  Leaving speech empty keeps Integral's English recordings and cue timing.
- **Speech pack** replaces matched recordings together with their timed subtitles.
  The speech pack's subtitles take precedence during those streams, including
  Codec. This is necessary where translations have different cue boundaries.
- Empty fields use Integral. **Use Integral** clears both selections.

The saved Japanese/English option does not disable an explicitly selected pack.
Independent subtitle/voice combinations are only available for matched text using
Integral's original recordings; arbitrary mixing of donor timed subtitles is not
implemented. A speech selection includes the donor's mixed audio track, which may
also contain music and effects; it is not an isolated voice stem.

## Import

Open **Languages → Import from discs…** in the launcher. The dialog reuses the
Integral paths from **Discs and display**; select **German** or **US English
v1.0**, then choose that release's Disc 1 and Disc 2. Click **Import and use**.
The bundled importer needs 64-bit Windows, but no Python installation or network
connection. It reads your images without changing them. Nothing is uploaded,
downloaded, or shared.

Progress and errors appear in the dialog, with a persistent import log under
`%LOCALAPPDATA%\RE-INTEGRAL\logs`. **Cancel import** stops the process and removes
unfinished files. Completed packs and receipts are stored in separate folders
under `%LOCALAPPDATA%\RE-INTEGRAL\languages`; existing packs are never overwritten.
The game checks the whole pack before the launcher selects it for text and
speech and saves the selection. Clear either field to keep Integral for that
part. Disc/revision errors leave the current selections intact.

The application download contains only the importer software and its runtime,
not language packs or extracted retail data. Keep your generated packs private.
An interrupted import caused by a system crash may leave a `.import-*` folder
in `languages`; it is never selected as a completed pack and can be removed
while the launcher is closed.

### Command line (source checkout)

Use Python 3.11 or later. No additional Python packages are required to run the
source importer. Select both
campaign discs from one supported release and both Integral campaign discs.
Single-track CUE files and raw MODE2/2352 BIN files are accepted, including the
German images without CUEs. Do not use the general Integral content importer on a
folder containing several editions.

```powershell
python tools/import_language.py --language de `
  --disc-one 'D:\discs\German Disc 1.bin' `
  --disc-two 'D:\discs\German Disc 2.bin' `
  --base-one 'D:\discs\Integral Disc 1.cue' `
  --base-two 'D:\discs\Integral Disc 2.cue' `
  --output .local/languages/german.mgslang
```

Use `--language en` with the US v1.0 pair for English. The importer checks boot
serials and pinned executable hashes listed in
[the resource audit](REGIONAL_LANGUAGE_RESOURCES.md). Unknown revisions fail
explicitly. Source images are opened read-only; existing packs and receipts are
never overwritten. Import needs several GiB of working memory and temporary disk
space. Keep extracted packs local; they contain retail assets.

Each pack has an adjacent JSON receipt with source SHA-256 hashes, a pack hash,
mapping version, matched counts, ambiguous text, rejected streams and every
Integral sector left on fallback, separately for each disc. Counts describe
structural mapping, not human verification of every translated conversation.

For the supplied revisions, the current mapping produces:

| Pack | Disc 1 VOX | Disc 2 VOX | Disc 1 DEMO | Disc 2 DEMO |
| --- | ---: | ---: | ---: | ---: |
| German | 449 / 1,108 | 311 / 754 | 79 / 79 | 40 / 40 |
| US English | 607 / 1,108 | 439 / 754 | 79 / 79 | 39 / 40 |

Both packs contain 37 inventory descriptions. VOX totals include sound-only
entries as well as dialogue. These are coverage counts for original stream
identities, not percentages of spoken words. The remaining US cinematic has a
different audio layout and retains Integral.

```powershell
build/windows-x86-modern/mgs-integral-native.exe --check-language .local/languages/german.mgslang
./tools/run.ps1 -BuildDirectory build/windows-x86-modern `
  -TextPack .local/languages/german.mgslang `
  -VoicePack .local/languages/german.mgslang
```

The engine validates pack structure and static resources at startup, then checks
each speech stream's CRC and framing before playback. `--check-language` also
checks every stream. Missing mappings print an explicit Integral fallback in the
log. Corruption of a mapped stream stops playback instead of silently substituting
an unrelated recording. The recording wrapper includes pack hashes in session
identity, restores selections for replay/resume and rejects changed packs.

## Mapping and boundaries

The importer matches GCL commands in the same stage/resource/procedure. Complete
procedures with equal normalized structure retain command position; otherwise
only unique matching command shapes are paired. Radio references additionally
require matching frequency and control structure; voice blocks require matching
speaker sequences. No donor script executes. Text substitutions are keyed by the
original byte string and reject conflicting translations and hash collisions.

Codec streams with differing caption counts are excluded because Integral uses
caption transitions to advance its own dialogue script. Briefing references come
from the briefing actor's explicit 19-entry voice list. Cinematics require equal
audio packet counts and lengths; all Integral animation packets and animation
commands are preserved. Donor sound and captions are inserted at their authored
audio boundaries. This does not establish perceptual lip sync for every scene.

German escaped glyphs are converted to a reserved two-byte font range and rendered
with donor glyph data. Integral's original font remains available for fallback.
The keycard description uses a level placeholder rather than a fixed byte offset.

Full German coverage still needs verified mappings for excluded Codec segments,
remaining actor speech and movie/XA tracks. UI textures and every menu string are
not covered. Human checks remain necessary for conversations, skipping, Disc 2,
ending branches and Integral-only scenes.

## Verification on 10 October 2026

The launcher importer passes its five relevant CTest suites in both builds,
including cancellation and incomplete/corrupt-output cleanup. The unpacked
player ZIP starts the importer without Python on PATH and rejects invalid discs.
UI smoke captures include the import dialog. A full German import through the
launcher service matches the CLI pack's SHA-256 and passes native validation;
an Integral briefing boot with that pack renders German captions.

Before launcher importer integration, reference Debug and modern RelWithDebInfo
builds passed all 164 and 168 CTest cases,
respectively, including the new asset-free language suite. Bootstrap verifies the
registered vendor patch. Full `--check-language` passes for both imported packs.

Real Integral-disc boots selected German opening DEMO sector 0, briefing VOX
sector 7 and the first dock Codec VOX sector 7982. Captures under ignored
`build/language-work/` show German briefing text with umlauts and ß and German
Codec text. Opening captures also show German captions over Integral animation.
The existing inventory probe reached the item menu and equipped Stealth, but its
1,800-frame run ended before completing both equipment checks; its captures do
not establish rendered description coverage. These are playback and rendering
checks, not a full regional
playthrough or a perceptual lip-sync/audio-quality assessment.
