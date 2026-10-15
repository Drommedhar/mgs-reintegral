#include "mgs_options_actions.h"
#include <string.h>

static MgsOptionsFrame current;
static uint32_t current_epoch, current_generation, revision;
static MgsOptionsAction queued;
static MgsOptionsActionResult result;

uint32_t MgsOptionsActionsView(MgsOptionsFrame view, uint32_t epoch, uint32_t generation)
{
    view.animation = 0;
    view.test = 0;
    if (epoch != current_epoch || generation != current_generation || memcmp(&current, &view, sizeof(view))) {
        if (++revision == 0) ++revision;
        current = view;
        current_epoch = epoch;
        current_generation = generation;
    }
    if (!view.active && result.status == MGS_OPTIONS_PENDING) result.status = MGS_OPTIONS_STALE;
    return revision;
}

static uint32_t Check(const MgsOptionsAction *action)
{
    if (!current.active || action->epoch != current_epoch || action->generation != current_generation ||
        action->revision != revision) return MGS_OPTIONS_STALE;
    if (current.selection == 0 || current.selection == 11) return MGS_OPTIONS_BUSY;
    if (action->kind < MGS_OPTIONS_SELECT || action->kind > MGS_OPTIONS_BACK) return MGS_OPTIONS_INVALID;
    if (action->kind != MGS_OPTIONS_SET && action->value) return MGS_OPTIONS_INVALID;
    if (action->kind == MGS_OPTIONS_BACK) return action->target ? MGS_OPTIONS_INVALID : MGS_OPTIONS_PENDING;
    if (current.selection == 7) return MGS_OPTIONS_INVALID;
    if (current.selection == 9) {
        if (action->kind == MGS_OPTIONS_SELECT && action->target <= 2) return MGS_OPTIONS_PENDING;
        if (action->kind == MGS_OPTIONS_SET && action->target <= 1 &&
            action->value <= (action->target ? 1u : 2u)) return MGS_OPTIONS_PENDING;
        return MGS_OPTIONS_INVALID;
    }
    unsigned target = action->target;
    if (!(target >= 1 && target <= 6) && target != 8 && target != 10) return MGS_OPTIONS_INVALID;
    if ((target == 4 || target == 5) && !current.vibration) return MGS_OPTIONS_INVALID;
    if (action->kind == MGS_OPTIONS_SELECT) return MGS_OPTIONS_PENDING;
    if (action->kind == MGS_OPTIONS_ACTIVATE) return target == 6 || target == 8 || target == 10 ? MGS_OPTIONS_PENDING : MGS_OPTIONS_INVALID;
    if (target > 5 || action->value > 1 || (target == 5 && action->value && current.vibration != 1)) return MGS_OPTIONS_INVALID;
    return MGS_OPTIONS_PENDING;
}

int MgsOptionsActionsSubmit(const MgsOptionsAction *action)
{
    if (action->schema != 1 || action->id <= result.id || !action->id || result.status == MGS_OPTIONS_PENDING) return 0;
    queued = *action;
    result = (MgsOptionsActionResult){action->id, Check(action)};
    return 1;
}

int MgsOptionsActionsTake(MgsOptionsFrame view, MgsOptionsAction *action)
{
    MgsOptionsActionsView(view, current_epoch, current_generation);
    if (result.status != MGS_OPTIONS_PENDING) return 0;
    result.status = Check(&queued);
    if (result.status != MGS_OPTIONS_PENDING) return 0;
    *action = queued;
    return 1;
}

void MgsOptionsActionsComplete(uint32_t status) { result.status = status; }
MgsOptionsActionResult MgsOptionsActionsResult(void) { return result; }
