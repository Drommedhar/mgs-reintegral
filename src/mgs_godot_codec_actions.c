#include "mgs_godot_codec_actions.h"
#include "mgs_godot_context.h"
#include "transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static MgsCodecActionView frame;
static uint32_t generation, epoch;
static uintptr_t current_item;

void MgsGodotCodecActionsReset(void)
{
    frame = (MgsCodecActionView){0};
    current_item = 0;
    epoch = MgsGodotSceneEpoch();
}

void MgsGodotCodecActionsEnd(void)
{
    MgsGodotCodecActionsReset();
    MgsCodecActionsView(frame, epoch, generation, 0);
}

void MgsGodotCodecActionsBegin(void)
{
    MgsGodotCodecActionsEnd();
    if (++generation == 0) ++generation;
}

void MgsGodotCodecActionsView(MgsCodecActionView view, uintptr_t item)
{
    frame = view;
    current_item = item;
    epoch = MgsGodotSceneEpoch();
    MgsCodecActionsView(frame, epoch, generation, item);
}

static void ReceiveAction(const void *data)
{
    MgsCodecAction action;
    memcpy(&action, data, sizeof(action));
    const MgsCodecAction empty = {.schema = 1};
    if (action.schema != 1 || (action.id ? !MgsCodecActionsSubmit(&action) : memcmp(&action, &empty, sizeof(action)))) {
        fputs("Invalid Godot Codec action sequence or identity.\n", stderr);
        exit(EXIT_FAILURE);
    }
}

void MgsGodotPublishCodecActions(void)
{
    if (!MgsGodotHasCapability(MGS_CODEC_ACTIONS_CAPABILITY)) return;
    if (epoch != MgsGodotSceneEpoch()) MgsGodotCodecActionsReset();
    uint32_t revision = MgsCodecActionsView(frame, epoch, generation, current_item);
    struct {
        uint32_t schema, epoch;
        unsigned char session[16];
        MgsCodecActionResult result;
        uint32_t generation, revision;
        MgsCodecActionView view;
    } state = {1, epoch, {0}, MgsCodecActionsResult(), generation,
        revision, frame};
    _Static_assert(sizeof(state) == 68 && sizeof(MgsCodecAction) == 28, "Codec actions wire layout");
    MgsGodotCopySessionId(state.session);
    MgsGodotRequest(MGS_GODOT_CODEC_ACTION, &state, sizeof(state), sizeof(MgsCodecAction), ReceiveAction);
}
