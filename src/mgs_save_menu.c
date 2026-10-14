#include "mgs_save_menu.h"
#include "mgs_save_ui.h"
#include "mgs_save_actions.h"

static uint32_t generation, previous_request, selected, pending_id;
static unsigned cursor, choice;
static int pending, exiting, initialized;
static MgsSaveAction queued_action;
static MgsSaveActionResult action_result;

static unsigned ValidateAction(const MgsSaveAction *action)
{
    const MgsSaveView *view = MgsSaveUiGetView();
    if (!view->active || action->generation != view->generation || action->revision != view->revision ||
        action->state != view->state || action->message != view->message || action->selected_id != view->selected_id)
        return MGS_SAVE_ACTION_STALE;
    if (view->state == MGS_SAVE_CHECKING || view->state == MGS_SAVE_BUSY) return MGS_SAVE_ACTION_BUSY;
    if (action->action < MGS_SAVE_SELECT || action->action > MGS_SAVE_CONTINUE) return MGS_SAVE_ACTION_INVALID;
    if (action->action >= MGS_SAVE_NEW && action->target_id) return MGS_SAVE_ACTION_INVALID;
    if (action->action <= MGS_SAVE_NEW) {
        if (view->state != MGS_SAVE_BROWSE || pending || exiting) return MGS_SAVE_ACTION_BUSY;
        MgsSaveTarget target;
        int valid = action->target_id ? MgsSaveUiResolve(view->generation, view->revision, action->target_id, &target) :
            action->action != MGS_SAVE_ACTIVATE && MgsSaveUiResolveNew(view->generation, view->revision, &target);
        return valid ? MGS_SAVE_ACTION_PENDING : MGS_SAVE_ACTION_INVALID;
    }
    if (action->action == MGS_SAVE_CONFIRM_ACTION && view->state != MGS_SAVE_CONFIRM) return MGS_SAVE_ACTION_INVALID;
    if (action->action == MGS_SAVE_CONTINUE && view->state != MGS_SAVE_RESULT) return MGS_SAVE_ACTION_INVALID;
    return MGS_SAVE_ACTION_PENDING;
}

int MgsSaveMenuSubmit(const MgsSaveAction *action)
{
    if (!action || action->schema != 1 || !action->id || action->id <= action_result.id ||
        action_result.status == MGS_SAVE_ACTION_PENDING) return 0;
    queued_action = *action;
    action_result = (MgsSaveActionResult){action->id, ValidateAction(action)};
    return 1;
}

MgsSaveActionResult MgsSaveMenuActionStatus(void)
{
    if (action_result.status == MGS_SAVE_ACTION_PENDING) action_result.status = ValidateAction(&queued_action);
    return action_result;
}

static unsigned ConsumeAction(void)
{
    if (action_result.status != MGS_SAVE_ACTION_PENDING) return 0;
    action_result.status = ValidateAction(&queued_action);
    if (action_result.status != MGS_SAVE_ACTION_PENDING) return 0;
    unsigned action = queued_action.action;
    if (action <= MGS_SAVE_NEW) {
        const MgsSaveView *view = MgsSaveUiGetView();
        cursor = view->count;
        for (unsigned row = 0; row < view->count; ++row)
            if (view->entries[row].id == queued_action.target_id) cursor = row;
        selected = queued_action.target_id;
        initialized = 1;
        if (action != MGS_SAVE_SELECT) { pending = 1; pending_id = selected; }
    }
    action_result.status = MGS_SAVE_ACTION_APPLIED;
    return action;
}

static MgsSaveResponse Browse(uint32_t request, int storage, unsigned input)
{
    const MgsSaveView *view = MgsSaveUiGetView();
    unsigned count = view->count + view->can_create;
    MgsSaveResponse response = {0};
    if (!initialized) { cursor = view->can_create ? view->count : 0; initialized = 1; }
    if (selected) {
        for (unsigned row = 0; row < view->count; ++row)
            if (view->entries[row].id == selected) cursor = row;
    }
    if (cursor >= count) cursor = count ? count - 1 : 0;
    if (input & MGS_SAVE_UP && cursor) --cursor;
    if (input & MGS_SAVE_DOWN && cursor + 1 < count) ++cursor;
    selected = cursor < view->count ? view->entries[cursor].id : 0;
    if (input & MGS_SAVE_CANCEL) { exiting = 1; pending = 0; }
    if (exiting) return (MgsSaveResponse){1, -1};
    if (input & MGS_SAVE_ACCEPT && count) { pending = 1; pending_id = selected; }
    if (!pending) return response;
    MgsSaveTarget target;
    int valid = pending_id ? MgsSaveUiResolve(view->generation, view->revision, pending_id, &target) :
        MgsSaveUiResolveNew(view->generation, view->revision, &target);
    if (!valid) { pending = 0; return response; }
    if (request == 0x20000001) return (MgsSaveResponse){1, (int)target.storage};
    if ((int)target.storage != storage) return (MgsSaveResponse){1, -1};
    pending = 0;
    return (MgsSaveResponse){1, (int)target.file};
}

MgsSaveResponse MgsSaveMenuStep(uint32_t request, int storage, unsigned input)
{
    const MgsSaveView *view = MgsSaveUiGetView();
    if (generation != view->generation) {
        generation = view->generation;
        previous_request = selected = pending_id = cursor = 0;
        pending = exiting = initialized = 0;
        choice = 1;
    }
    unsigned phase = request & 0x40000000 ? 2 : request & 0x20000000 ? 3 : request & 0x10000000 ? 5 : 1;
    MgsSaveUiPresent(phase, request, storage, NULL);
    if (request != previous_request && phase == 5) choice = 1;
    previous_request = request;
    MgsSaveUiSelection(cursor, choice);
    unsigned action = ConsumeAction();
    if (action) input = 0;
    if (action == MGS_SAVE_BACK) input = MGS_SAVE_CANCEL;
    MgsSaveResponse response = {0};
    if (phase == 3) response = Browse(request, storage, input);
    else if (phase == 5) {
        if (input & (MGS_SAVE_UP | MGS_SAVE_DOWN)) choice ^= 1;
        if (input & MGS_SAVE_ACCEPT) response = (MgsSaveResponse){1, (int)choice};
        if (input & MGS_SAVE_CANCEL) response = (MgsSaveResponse){1, 1};
        if (action == MGS_SAVE_CONFIRM_ACTION) response = (MgsSaveResponse){1, 0};
    } else if (phase == 2) {
        if (input & (MGS_SAVE_ACCEPT | MGS_SAVE_CANCEL) || action == MGS_SAVE_CONTINUE) response.ready = 1;
    } else if (request) response.ready = 1;
    MgsSaveUiSelection(cursor, choice);
    return response;
}
