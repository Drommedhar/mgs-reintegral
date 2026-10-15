#include "mgs_godot_save.h"
#include "mgs_save_ui.h"
#include "mgs_save_actions.h"
#include "mgs_godot_context.h"
#include "transport.h"
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int MgsGodotOwnsSaveUi(void) { return MgsGodotHasCapability(MGS_GODOT_SAVE_CAPABILITY); }

static void ReceiveAction(const void *data)
{
    MgsSaveAction action;
    memcpy(&action, data, sizeof(action));
    const MgsSaveAction empty = {.schema = 1};
    if (action.id && action.epoch != MgsGodotSceneEpoch()) action.generation = 0;
    if (action.schema != 1 || (action.id ? !MgsSaveMenuSubmit(&action) : memcmp(&action, &empty, sizeof(action)) != 0)) {
        fputs("Invalid Godot save action sequence or identity.\n", stderr);
        exit(EXIT_FAILURE);
    }
}

void MgsGodotPublishSaveUi(void)
{
    if (!MgsGodotOwnsSaveUi()) return;
    struct { uint32_t schema, epoch; unsigned char session[16]; } header = {1, MgsGodotSceneEpoch(), {0}};
    _Static_assert(sizeof(header) == 24 && offsetof(MgsSaveView, entries) == 44 && sizeof(MgsSaveEntry) == 96,
                   "Save UI wire layout");
    MgsGodotCopySessionId(header.session);
    const MgsSaveView *view = MgsSaveUiGetView();
    MgsGodotQueue(MGS_GODOT_SAVE_UI, &header, sizeof(header), view,
                 offsetof(MgsSaveView, entries) + view->count * sizeof(MgsSaveEntry));
    if (MgsGodotHasCapability(134217728u)) {
        struct {
            uint32_t schema, epoch;
            unsigned char session[16];
            MgsSaveActionResult result;
        } state = {1, header.epoch, {0}, MgsSaveMenuActionStatus()};
        _Static_assert(sizeof(state) == 32 && sizeof(MgsSaveAction) == 40, "Save actions wire layout");
        MgsGodotCopySessionId(state.session);
        MgsGodotRequest(MGS_GODOT_SAVE_ACTION, &state, sizeof(state), sizeof(MgsSaveAction), ReceiveAction);
    }
}
