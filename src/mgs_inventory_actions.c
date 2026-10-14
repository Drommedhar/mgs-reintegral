#include "mgs_inventory_actions.h"
#include <string.h>

static MgsInventoryActionView current;
static uint32_t current_epoch, current_generation, revision;
static MgsInventoryAction queued;
static MgsInventoryActionResult result;

uint32_t MgsInventoryActionsView(const MgsInventoryActionView *view, uint32_t epoch, uint32_t generation)
{
    if (epoch != current_epoch || generation != current_generation || memcmp(&current, view, sizeof(current))) {
        if (++revision == 0) ++revision;
        current = *view;
        current_epoch = epoch;
        current_generation = generation;
    }
    if (!view->active && result.status == MGS_INV_PENDING) result.status = MGS_INV_STALE;
    return revision;
}

static uint32_t Check(const MgsInventoryAction *action)
{
    if (action->epoch != current_epoch || action->generation != current_generation || action->revision != revision)
        return MGS_INV_STALE;
    if (!current.active) return MGS_INV_BUSY;
    if (action->side > 1 || action->kind < MGS_INV_OPEN || action->kind > MGS_INV_CLOSE) return MGS_INV_INVALID;
    if (action->kind == MGS_INV_OPEN)
        return !action->target && !current.mode && (current.open_mask & (1u << action->side)) ? MGS_INV_PENDING : MGS_INV_INVALID;
    if (current.mode != action->side + 1 || !(current.allowed & (1u << action->kind))) return MGS_INV_INVALID;
    if (action->kind == MGS_INV_CLOSE) return action->target ? MGS_INV_INVALID : MGS_INV_PENDING;
    for (unsigned i = 0; i < current.count; ++i) {
        const MgsInventoryEntry *entry = &current.entries[i];
        if (entry->side != action->side || entry->id != action->target) continue;
        if (action->kind == MGS_INV_SELECT) return MGS_INV_PENDING;
        if (action->kind == MGS_INV_EQUIP && (entry->flags & MGS_INV_EQUIPPABLE)) return MGS_INV_PENDING;
        if (action->kind == MGS_INV_USE && action->side == 0 && action->target == current.selection &&
            (entry->flags & MGS_INV_USABLE)) return MGS_INV_PENDING;
    }
    return MGS_INV_INVALID;
}

int MgsInventoryActionsSubmit(const MgsInventoryAction *action)
{
    if (action->schema != 1 || !action->id || action->id <= result.id || result.status == MGS_INV_PENDING) return 0;
    queued = *action;
    result = (MgsInventoryActionResult){action->id, Check(action)};
    return 1;
}

int MgsInventoryActionsTake(MgsInventoryAction *action)
{
    if (result.status != MGS_INV_PENDING) return 0;
    result.status = Check(&queued);
    if (result.status != MGS_INV_PENDING) return 0;
    *action = queued;
    return 1;
}

void MgsInventoryActionsComplete(uint32_t status) { result.status = status; }
MgsInventoryActionResult MgsInventoryActionsResult(void) { return result; }
