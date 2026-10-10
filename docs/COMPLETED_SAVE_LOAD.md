# Loading completed-mission saves

Completed saves start another round through the original Load Game menu. Their
stored stage is `rank`, with story progress and saved area both zero. The original
`abst/ea54.g` procedure `DDE1` recognizes story zero, sets it to one and loads
`d00a`; that intro then loads the dock. Loading does not return to ranking.

The load uses [loadFile_80049CE8](../vendor/mgs/source/menu/datasave.c), which reads
the card file and passes its payload to
[GCL_SetLoadFile](../vendor/mgs/source/libgcl/variable.c). The latter verifies the
CRC and restores both live and checkpoint variables. Completion count, clear
flag and item ownership are ordinary saved link variables, defined in
[linkvar.h](../vendor/mgs/source/include/linkvar.h).

The two inputs for this check were produced by the original final save menu after
the ending-chain fixtures. Both are one-block 8,192-byte saves with valid CRCs,
Normal difficulty and one completion:

| Ending | Clear flag | Bandana | Stealth | Source SHA-256 |
|---|---:|---:|---:|---|
| Meryl | 1 | 1 | -1 | `fbfd4489955e627bdb6b51e30bf7dd169425a85b4600dfe97089faa04c2d0934` |
| Otacon | 2 | -1 | 1 | `267df308ddb1f055c8d0041aa2c540ff073071caf50b4ca6fe8996708fab5eaa` |

The `completed-load` probe is implemented in
[mgs_completed_load_probe.c](../src/mgs_completed_load_probe.c). It operates the
existing SDL virtual controller, observes original menu success, then checks the
ordered `title → abst → d00a → s00a` sequence. It requires a stable neutral player
baseline followed by at least 128 units of movement over eight game ticks with
the requested direction actually present in the game's pad state. Completion,
difficulty and both bonus-item values must survive unchanged. The optional bonus
loadout must be disabled.

This probe uses the original Start/Cross skip controls for the intro and Codec.
It tests load acceptance and new-round gameplay, not unskipped cinematic timing,
equipment activation, a second campaign completion or human play.

[test_completed_save_load.py](../tests/test_completed_save_load.py) validates the
input save independently, copies it into an isolated card directory, launches a
fresh process and verifies the exact stage sequence and acceptance result. It
records controller input, a manifest and a screenshot, and checks that neither
the original nor the copied card file changed. No save bytes or gameplay state
are injected.

```powershell
.\.venv\Scripts\python.exe tests/test_completed_save_load.py `
  --exe build/windows-x86-debug/mgs-integral-native.exe `
  --disc '<Integral disc 1 cue>' `
  --save '<completed-game save file>' --ending meryl `
  --output build/completed-load-meryl
```

Repeat with the Otacon save and `--ending otacon`. The output directory must be
new. Optional `--debugger '<x86 cdb.exe>'` uncaps presentation while the recording
clock preserves the emulated frame sequence; it does not write gameplay state.

The initial diagnostic with the existing ordinary `load-menu` probe accepted the
Meryl save at VSync 669 and followed all four stages with its earned Bandana
intact. That older probe then failed its room-restoration assertion: its expected
saved area was zero, while the new round correctly entered dock area `469b`.
This is why completed saves have a separate acceptance mode.

Both completed-load scenarios now pass on the default Debug build. In each fresh
process the original load succeeds at VSync 669, `d00a` is ready at 908, and `s00a`
at 1187. Ordinary Up input moves Snake 453 units over 24 game ticks. Both runs
finish 4,000 VSyncs with their respective earned item, completion count and clear
flag intact; screenshots show the rendered dock and player. Source and copied
save hashes remain unchanged.

Evidence is under `build/completed-load-audit/meryl/` and
`build/completed-load-audit/otacon/`: `load.log`, `load.mgsinput`, `loaded.bmp` and
`manifest.json`. Both runs used executable SHA-256
`694a1a3dba3a5dfe2ab5e3a67b6a351b8f0541f64437304ad2a994de549d6c31`.
No game implementation repair was needed. The new C module compiles with Win32
`-Wall -Wextra -Werror`; scoped Aislop checks of it and the Python driver score
100 with no findings. The installed scan lacks cppcheck and clang-tidy.

The later [connected Normal ending](ESCAPE_RECOVERY.md#normal-ending-strict-replay-and-earned-save-reload)
also produced and reloaded its own earned Bandana save. That save derives from
the completed Normal garage/escape checkpoint, rather than a new ending-entry
fixture. The same 4,000-VSync acceptance passes with 453 units / 24 moving ticks,
the earned item and completion count preserved, and both save copies unchanged.
Its evidence is `.local/recovery/s20a/connected-normal01/completed-load/`.
