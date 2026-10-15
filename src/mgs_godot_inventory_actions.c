#include "mgs_godot_inventory_actions.h"
#include "mgs_godot_scene.h"
#include "mgs_godot_context.h"
#include "transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static MgsInventoryActionView frame;
static uint32_t generation, epoch;

int MgsGodotOwnsInventoryActions(void)
{
    return MgsGodotHasCapability(MGS_INVENTORY_ACTIONS_CAPABILITY);
}

void MgsGodotInventoryActionsReset(void)
{
    frame = (MgsInventoryActionView){0};
    epoch = MgsGodotSceneEpoch();
}

void MgsGodotInventoryActionsEnd(void)
{
    MgsGodotInventoryActionsReset();
    MgsInventoryActionsView(&frame, epoch, generation);
}

void MgsGodotInventoryActionsBegin(void)
{
    MgsGodotInventoryActionsEnd();
    if (++generation == 0) ++generation;
}

void MgsGodotInventoryActionsView(const MgsInventoryActionView *view)
{
    frame = *view;
    epoch = MgsGodotSceneEpoch();
    MgsInventoryActionsView(&frame, epoch, generation);
}

static void ReceiveAction(const void *data)
{
    MgsInventoryAction action;
    memcpy(&action, data, sizeof(action));
    const MgsInventoryAction empty = {.schema = 1};
    if (action.schema != 1 || (action.id ? !MgsInventoryActionsSubmit(&action) : memcmp(&action, &empty, sizeof(action)))) {
        fputs("Invalid Godot inventory action sequence or identity.\n", stderr);
        exit(EXIT_FAILURE);
    }
}

void MgsGodotPublishInventoryActions(void)
{
    if (!MgsGodotOwnsInventoryActions()) return;
    if (epoch != MgsGodotSceneEpoch()) MgsGodotInventoryActionsReset();
    uint32_t revision = MgsInventoryActionsView(&frame, epoch, generation);
    struct {
        uint32_t schema, epoch;
        unsigned char session[16];
        MgsInventoryActionResult result;
        uint32_t generation, revision;
        MgsInventoryActionView view;
    } state = {1, epoch, {0}, MgsInventoryActionsResult(), generation, revision, frame};
    _Static_assert(sizeof(state) == 652 && sizeof(MgsInventoryAction) == 32, "Inventory action wire layout");
    MgsGodotCopySessionId(state.session);
    MgsGodotRequest(MGS_GODOT_INVENTORY_ACTION, &state, sizeof(state), sizeof(MgsInventoryAction), ReceiveAction);
}
