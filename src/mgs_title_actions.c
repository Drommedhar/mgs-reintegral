#include "mgs_title_actions.h"
#include <string.h>

static MgsTitleFrame current;
static uint32_t current_epoch, current_generation, revision;
static MgsTitleAction queued;
static MgsTitleActionResult result;

uint32_t MgsTitleActionsView(MgsTitleFrame view, unsigned ready, uint32_t epoch, uint32_t generation)
{
    view.active = ready;
    view.storage[0] = view.storage[1] = 0;
    if (epoch != current_epoch || generation != current_generation || memcmp(&current, &view, sizeof(view))) {
        if (++revision == 0) ++revision;
        current = view;
        current_epoch = epoch;
        current_generation = generation;
    }
    if (!ready && result.status == MGS_TITLE_PENDING) result.status = MGS_TITLE_STALE;
    return ready ? revision : 0;
}

static uint32_t Check(const MgsTitleAction *action)
{
    if (action->epoch != current_epoch || action->generation != current_generation ||
        action->revision != revision) return MGS_TITLE_STALE;
    if (!current.active) return MGS_TITLE_BUSY;
    if (action->kind < MGS_TITLE_SELECT || action->kind > MGS_TITLE_BACK) return MGS_TITLE_INVALID;
    if (current.mode <= 1 || (current.mode >= 4 && current.mode <= 6))
        return action->kind == MGS_TITLE_ACTIVATE && !action->target ? MGS_TITLE_PENDING : MGS_TITLE_INVALID;
    unsigned limit;
    switch (current.mode) {
    case 7: limit = 4; break;
    case 21: limit = current.extreme ? 4 : 3; break;
    case 18: case 19: limit = 1; break;
    default: return MGS_TITLE_INVALID;
    }
    if (action->kind == MGS_TITLE_BACK) return action->target ? MGS_TITLE_INVALID : MGS_TITLE_PENDING;
    return action->target <= limit ? MGS_TITLE_PENDING : MGS_TITLE_INVALID;
}

int MgsTitleActionsSubmit(const MgsTitleAction *action)
{
    if (action->schema != 1 || !action->id || action->id <= result.id || result.status == MGS_TITLE_PENDING) return 0;
    queued = *action;
    result = (MgsTitleActionResult){action->id, Check(action)};
    return 1;
}

int MgsTitleActionsTake(MgsTitleFrame view, unsigned ready, MgsTitleAction *action)
{
    MgsTitleActionsView(view, ready, current_epoch, current_generation);
    if (result.status != MGS_TITLE_PENDING) return 0;
    result.status = Check(&queued);
    if (result.status != MGS_TITLE_PENDING) return 0;
    *action = queued;
    return 1;
}

void MgsTitleActionsComplete(uint32_t status) { result.status = status; }
MgsTitleActionResult MgsTitleActionsResult(void) { return result; }
