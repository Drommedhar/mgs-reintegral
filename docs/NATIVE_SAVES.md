# Native memory cards and save validation

The native backend supports the recovered game's file-based memory-card API.
Each process working directory contains `bu00` and `bu10`, representing the two
card slots. Use a separate working directory for experiments: the original game
can overwrite, delete, and format saves through its normal menus.

## Representation and completion

Each card has 15 blocks of 8,192 bytes. Creating a file reserves its requested
block count and fails if the card is full or the name already exists. File
operations enforce the allocated bounds and 128-byte transfer alignment.
The complete 20-byte PlayStation filename is preserved. Windows-invalid bytes,
reserved device names, and ambiguous trailing characters use reversible percent
encoding in host filenames. The game sees the original bytes.

Asynchronous file operations return the original API's accepted-operation result,
then report one hardware completion per 128 bytes and a final software completion.
Events are queued through the owner-thread kernel pump; they remain pending while
interrupts are disabled. Writes are committed before successful completion is
reported. One hardware completion per VSync is a native scheduling choice, not a
claim about physical memory-card timing.

The backend synthesizes the format-header sector required by the game's card
check and implements its status-clear handshake. Other raw sector reads and
writes fail explicitly. This is a directory-backed card implementation, not a
complete `.mcr` image emulator. Card-image import/export, hot removal, multitap
cards, and crash-atomic overwrite recovery are not implemented.

The vendor changes are in `patches/psyz-save.patch`. The recovered game's calls
use explicit PS1 `FCREAT` and `FWRITE` flags through `patches/mgs-entry.patch`;
Windows CRT `O_CREAT`/`O_WRONLY` values are different.

## Automated backend regression

CTest `native_saves` runs `tests/mgs_save_test.c` through
`tests/test_saves.py` in private temporary directories. It covers:

- Both slots, full 20-byte names, reserved characters, allocated capacity,
  overwrite/read, erase, and format.
- A second process reopening and verifying the first process's saved bytes.
- Hardware/software event counts, owner-thread callbacks, interrupt masking,
  bounds failures, and explicit rejection of unsupported raw-sector operations.
- The actual recovered `memcard_init`, `memcard_check`, `memcard_files`,
  `memcard_write`, `memcard_read`, and `memcard_delete` functions. The test advances
  their VSync clock; it does not replace their save or completion logic.

## Original save/load UI scenario

`tests/test_save_ui.py` uses private temporary cards, the user's supplied disc,
and SDL virtual-controller input. It starts a development `s02a` scenario, calls
Mei Ling at 140.96, and operates the original save menu. It checks the generated
8,192-byte file, card header, save versions, saved stage, story variable, and CRC.
A fresh process starts at the title screen and selects the original Load Game
menu. The input probe requires original load acceptance, the saved area hash,
a live controllable player after loading, and measured movement over multiple
game ticks. It also dismisses the original mission-log prompt with Cross.

This is an explicit scenario fixture, not a normal campaign playthrough.
Before the original `GCL_SaveVar` snapshot, a debugger sets the story-progress
short at variable descriptor `0x1100000A` to 1. No player coordinates, inventory,
file bytes, loading state, or success flags are written by the test. Saving and
the restarted load use ordinary virtual-controller input.

The fixture is necessary because development entry leaves story progress at zero.
The original `abst/ea54.g` procedure `DDE1` tests that variable first; zero follows
the new-game branch, assigns 1, and loads `d00a`. A valid development save with
story zero therefore reloads the intro rather than its named room. For nonzero
progress, the original mission-log exit procedure `8591` uses the saved stage.
The extracted script has SHA-256
`46dd99d657e7952116b0f60cb924d60b3c42557ef66a4d39bd91f821889ae128`.
This evidence was decoded locally from the supplied disc; extracted assets stay
outside version control.

Run the scenario with an x86 Windows SDK debugger and a build with symbols:

```powershell
.\.venv\Scripts\python.exe tests/test_save_ui.py `
  --exe build/renderer-contract/mgs-integral-native.exe `
  --debugger 'C:/Program Files (x86)/Windows Kits/10/Debuggers/x86/cdb.exe' `
  --disc '<your Integral disc 1 cue>' `
  --output build/save-roundtrip-fixture
```

Logs and screenshots remain in the output directory. The test's cards are removed
with its temporary working directory. The current validation does not establish
campaign progression, PS1 image interoperability, or manual playability.

The verified run completed both processes successfully: save at VSync 1,029,
load acceptance at 670, and a real `title` → `abst` → `s02a` loader sequence.
The restored player appeared at `(0,1104,0)`, matching the saved room's initial
position. After settling, Up moved it from `(0,1094,0)` to `(16,1093,-1635)`
over 24 movement ticks. No collision-contact ticks were observed in this probe.
The restarted process survived 6,000 VSyncs; after the probe released its controls,
guards killed the idle player, so the final load screenshot shows Game Over.
The log verifies earlier movement, not uninterrupted player survival.
