# Campaign code audit

Audit of the working tree on 2026-10-09, after briefing and camera-album integration. This checks native source selection and binding coverage for **Integral's main executable**, including campaign revisits and cinematics. VR missions are excluded. It does not establish campaign completion or gameplay fidelity.

## Coverage established

| Check | Result |
| --- | ---: |
| Configured stage identities | 92 |
| Campaign `s*` identities, including variants | 65 |
| Cinematic `d*` identities | 7 |
| Other identities: title, load, disc change, endings, menus and auxiliary stages | 20 |
| Distinct selected constructor tables | 72 |
| Selected game C translation units | 738 |
| Resident linker-selection units, before stage additions | 166 |
| Constructor entries across the 92 selected identities, excluding terminators | 1,715 |
| Unselected main-executable stage tables | 0 |
| Nonterminal null constructor bindings | 0 |
| Native-preprocessed active assembly inclusion pragmas | 0 |
| Original Disc 1/Disc 2 overlay class-ID lists and order matching native tables | 184 / 184 |

The generated `build/gpu-validation/mgs_sources.cmake` and compile database both select 738 game units; every corresponding object exists. Of these, 737 are generated vendor mirrors and one is the native safety-check override. Object presence is not a fresh-header or final-link assertion.

Fourteen selected source files retain 207 textual `INCLUDE_ASM` pragmas. Native preprocessing removes all of them; reporting these historical PS1 branches as missing native code would be incorrect. The source generator rejects missing selected C files and literal PS1 constructor addresses. Named functions must then resolve at native link time. All 184 original `.b` resource tables match the selected native class identifiers and ordering, including stage aliases. **This verifies table coverage, not behavioral equivalence of every constructor or aliased overlay.**

Evidence is recorded in [campaign_code_audit.json](data/campaign_code_audit.json). The read-only [audit tool](../tools/audit_campaign.py) preprocesses actual native branches, resolves the current configuration and can compare locally supplied retail archives. It emits metadata, not original executable bytes:

```powershell
$tc = & tools/toolchain.ps1
.venv/Scripts/python.exe tools/audit_campaign.py --clang $tc.Clang `
  --disc .local/content/disc1/MGS/STAGE.DIR `
  --disc .local/content/disc2/MGS/STAGE.DIR `
  --output docs/data/campaign_code_audit.json
```

## Concrete findings and actions

1. **Very Easy and tuxedo resource loads were rejected. Fixed during this audit.** Each disc has 95 resource directories. `init`, `init_ve` and `init_tux` are the three without `.b` executable resources, so they correctly need no actor table. However, the host selector recognized only `init`. The original title script loads `init_ve` when `$w:800002 == -1`; the original load-game script also selects `init_ve` or `init_tux` from difficulty/unlock state. These paths previously terminated as an unlinked stage. [mgs_stages.c](../src/mgs_stages.c) now recognizes exactly these three resource-only names. [The registry regression](../tests/mgs_stage_registry_test.c) checks empty resident tables, overlay state retention/reload and rejection of other names. Follow up with normal Very Easy New Game and an authored tuxedo save/load scenario.

2. **Equipped-camera capture used literal PS1 RAM addresses. Fixed during integration.** The selected resident `equip/jpegcam.c` assigned encoder scratch/output buffers to `0x801B1000` and `0x801A1000`; the native process uses relocated RAM arrays. Photograph capture could therefore fault even though the separate album stage had native C. The buffers now map to native `PACK_ADDR1` storage, and four complete synthetic images produce the same compressed streams and retry behavior as the original instructions. See [capture validation](EQUIPPED_CAMERA_CAPTURE.md). Controller-driven photograph-to-album/save acceptance remains open.

3. **SPU volume sweeps were an actual backend implementation gap. Fixed after this audit.** Voice sweep settings previously produced zero gain, and main volume had no sweep state. The backend now implements clocked state and current-level reads for all 50 volume channels. Signed phases, linear/exponential modes, all 128 rates, reset/reprogramming and real ADPCM mixer output pass the new regression suite; see [SPU sweep validation](NATIVE_SPU_SWEEPS.md). This audit did not establish which campaign assets exercise sweep registers, and two specification corner cases remain unverified on physical hardware.

4. **Remaining hardware features need scope-specific decisions.** Directory cards reject raw-sector operations; the host PocketStation provider reports no device unless one is installed; XA 8-bit sectors, monochrome MDEC and v3 VLC remain unsupported. They are concrete limits, but this audit found no evidence that they block ordinary campaign progression. Keep them distinct from missing stage actors. The selected game archive did not directly reference the inspected PsyZ public functions whose bodies contain `NOT_IMPLEMENTED`; transitive backend paths such as GPU reset remain separate fidelity work.

## What is still unproven

No missing main-stage C selection, active assembly body, constructor-table class entry or null actor binding was found in this snapshot. This extends the earlier stage inventory with native preprocessing and original overlay-table comparisons.

The largest remaining campaign risk is connected execution: completing encounters, moving through every authored transition, dying/retrying, revisiting rooms, saving/loading after progression, and completing both endings across the disc change. Unit comparisons and bounded scenario probes do not prove those paths. Original low-memory reads replaced by defined native behavior, data/BSS reset policy, converted GPU packets and shared overlay selections also require acceptance against the original. Report these as validation limits rather than a numerical campaign-completion percentage.
