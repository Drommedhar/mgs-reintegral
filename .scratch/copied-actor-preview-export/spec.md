# Copied actor preview blocks ZIP export

Status: resolved

The user copied the water binding from gameplay docks to the cinematic. Its
temporary LocalModelReference was saved into d00a.tscn, and identical original
textures were recorded as material changes in s00a.tscn. The export guard
correctly rejected the embedded original data.

M3.13a in docs/GODOT_SDK_PROGRESS.md records the fix: adopt matching copied
previews into the save session, preserve custom children and actual edits,
compare original texture pixels, and continue excluding original content.
Live-copy and saved-copy regression tests plus both repaired user scenes pass.
Original inputs and detailed evidence are in
build/godot-sdk-m0/export-preview-20261014. SDK21 and docks-export-fixed.zip
are delivered; final archive audits pass. Reopen the project to load the plugin fix.
