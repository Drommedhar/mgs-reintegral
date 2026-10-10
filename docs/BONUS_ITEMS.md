# Optional bonus inventory

The native testing option grants ownership of Stealth Camouflage and Bandana. The player selects and removes either through the original item menu. It does not equip anything, grant weapons or ammunition, change health or difficulty, or change the separate completion/unlock flag. Only one item can be equipped at a time.

```powershell
./tools/run.ps1 -BonusItems
```

On Xbox, hold LT/L2 and use the D-pad to select an item, then release LT to equip
it. LB/L1 toggles the selected item. On the keyboard, use W/L2, the arrow keys
and Q/L1. The [input recorder](INPUT_RECORDING.md) captures these ordinary menu
actions, including when the player removes the item for a detection or ammo test.

The host calls `MgsBonusItemsConfigure(enabled)` before game initialization; `MgsBonusItemsEnabled()` exposes that option to input-recording metadata. The default is disabled. Implementation: [mgs_bonus_items.c](../src/mgs_bonus_items.c), [public interface](../include/mgs_bonus_items.h).

## Grant and persistence

The original `init` and title inventory initializer sets link variables `80005E` and `800060` to `-1`. These are item indices 10 and 11, corresponding to `GM_Items[IT_Stealth]` and `GM_Items[IT_Bandana]`: [item IDs](../vendor/mgs/source/game/g_define.h:271), [inventory aliases](../vendor/mgs/source/include/linkvar.h:75). Ordinary ownership is `1`; the inventory menu includes positive counts. Neither item uses the consumable capacity array.

The one-shot hook runs on entry to the first campaign `s##`/`d##` stage, after the original initial inventory exists and before that stage's checkpoint/script execution. It leaves title, opening and resource-loading stages alone. New-game variable initialization and a successful save load re-arm the grant. Later stage transitions do not regrant deliberately removed items. Existing owned or disabled bonus items are preserved; newly granted items inherit an existing equipment-disabled state.

The grant updates only the two corresponding checkpoint shorts through original `GCL_SaveLinkVar`. This matters because [GCL_MakeSaveFile](../vendor/mgs/source/libgcl/variable.c) serializes the saved checkpoint buffer, not the current inventory. Ordinary continue and save/load therefore retain the granted ownership. Turning the launch option off does not erase items already stored in a save. Scripted confiscation, menu restrictions and equip/unequip behavior remain in the original game code.

## Original effects and limits

- [Bandana](../vendor/mgs/source/equip/bandana.c:48) restores decreases in ammunition and magazine counts from Snake's current-ammo snapshots. It does not create a weapon or fill an empty inventory.
- Stealth uses the original `NewKogaku2` equipment actor. Detection checks depend on the equipped item and retain their original exceptions, including the explicit enemy parameter exception in [enemy.c](../vendor/mgs/source/enemy/enemy.c:346). The option adds no invulnerability or boss override.
- [Item-menu restrictions](../vendor/mgs/source/menu/item.c:287) and Snake's damage/reload equip timing still apply. There is no difficulty gate in the audited bonus-equipment paths.

## Validation

[mgs_bonus_items_test.c](../tests/mgs_bonus_items_test.c) links the actual recovered variable/save implementation. It verifies that only ownership changes across all five difficulty values, equipped item/weapon remain unchanged, continue and checksum-valid save/load retain the grant, existing disabled equipment stays disabled, and later stage transitions do not recreate a removed item. It also checks default-off behavior and a new game in the same process.

The touched save implementation had three unbounded stage-name copies flagged by Aislop. These now use bounded copies and explicit rejection of a nonterminated saved name. A checksum-valid malformed-name fixture verifies rejection before inventory mutation. Standalone x86 tests pass. Aislop reports no new-code findings; the existing long `gamed.c` actor function remains a nonfixable complexity warning, and `cppcheck` is unavailable.

The 2,400-VSync live `-Probe bonus -BonusItems` check passed through the original
L2 menu and L1 toggle. Each equip/unequip state persisted for eight unpaused game
ticks. It checked `GM_Item`, Snake's current item, actual `kogaku2.c`/`bandana.c`
actor creation/removal and restoration of Stealth's model flags. The final state
has neither item equipped. [Log](../build/bonus-items.log),
[capture](../build/bonus-items.bmp). Direct development entry already owns these
items in its initial inventory; a separate ordinary New Game route observed the
optional grant of exactly two items on entry to `d00a`.

This confirms menu selection and original effect activation, not a guard
detection encounter or ammunition consumption: Snake had no weapon in the dock
test. Those checks need gameplay recordings containing the relevant encounters.
