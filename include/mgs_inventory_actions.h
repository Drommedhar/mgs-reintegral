#ifndef MGS_INVENTORY_ACTIONS_H
#define MGS_INVENTORY_ACTIONS_H

#include <stdint.h>

#define MGS_INVENTORY_ACTIONS_CAPABILITY 2147483648u
#define MGS_INVENTORY_ENTRY_LIMIT 36u
enum MgsInventoryActionKind {
    MGS_INV_OPEN = 1, MGS_INV_SELECT, MGS_INV_EQUIP, MGS_INV_USE, MGS_INV_CLOSE
};
enum MgsInventoryActionStatus {
    MGS_INV_NONE, MGS_INV_PENDING, MGS_INV_APPLIED, MGS_INV_STALE, MGS_INV_BUSY, MGS_INV_INVALID
};
enum MgsInventoryEntryFlags { MGS_INV_EQUIPPABLE = 1, MGS_INV_USABLE = 2 };
typedef struct {
    uint32_t side;
    int32_t id, quantity;
    uint32_t flags;
} MgsInventoryEntry;
typedef struct {
    uint32_t active, mode, owned, open_mask, allowed, count;
    int32_t selection, equipped[2];
    MgsInventoryEntry entries[MGS_INVENTORY_ENTRY_LIMIT];
} MgsInventoryActionView;
typedef struct {
    uint32_t schema, id, epoch, generation, revision, kind, side;
    int32_t target;
} MgsInventoryAction;
typedef struct { uint32_t id, status; } MgsInventoryActionResult;

uint32_t MgsInventoryActionsView(const MgsInventoryActionView *view, uint32_t epoch, uint32_t generation);
int MgsInventoryActionsSubmit(const MgsInventoryAction *action);
int MgsInventoryActionsTake(MgsInventoryAction *action);
void MgsInventoryActionsComplete(uint32_t status);
MgsInventoryActionResult MgsInventoryActionsResult(void);

#endif
