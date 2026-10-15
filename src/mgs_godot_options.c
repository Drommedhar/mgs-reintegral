#include "mgs_godot_options.h"
#include "mgs_godot_context.h"
#include "transport.h"
#include "mgs_ui_texts.h"
#include "mgs_options_actions.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static MgsOptionsFrame frame;
static MgsOptionsElement elements[MGS_OPTIONS_ELEMENTS];
static MgsUiTexts texts;
static uint32_t generation, epoch;

int MgsGodotOwnsOptions(void) { return MgsGodotHasCapability(MGS_GODOT_OPTIONS_CAPABILITY); }

void MgsGodotResetOptions(void)
{
    memset(&frame, 0, sizeof(frame));
    MgsUiTextsReset(&texts);
    epoch = MgsGodotSceneEpoch();
}

void MgsGodotOptionsEnd(void)
{
    MgsGodotResetOptions();
    MgsOptionsActionsView(frame, epoch, generation);
    MgsUiTextsFree(&texts);
}

void MgsGodotOptionsBegin(void)
{
    MgsGodotOptionsEnd();
    if (++generation == 0) ++generation;
}

void MgsGodotOptionsView(MgsOptionsFrame view, const MgsOptionsElement *source)
{
    frame = view;
    memcpy(elements, source, sizeof(elements));
    epoch = MgsGodotSceneEpoch();
}

void MgsGodotOptionsBeginText(unsigned index, const void *buffer)
{
    MgsUiTextsBegin(&texts, index, buffer);
}

void MgsGodotOptionsText(unsigned index, MgsSubtitleFrame view, const void *palette)
{
    MgsUiTextsSet(&texts, index, view, palette);
}

static void ReceiveAction(const void *data)
{
    MgsOptionsAction action;
    memcpy(&action, data, sizeof(action));
    const MgsOptionsAction empty = {.schema = 1};
    if (action.schema != 1 || (action.id ? !MgsOptionsActionsSubmit(&action) : memcmp(&action, &empty, sizeof(action)))) {
        fputs("Invalid Godot Options action sequence or identity.\n", stderr);
        exit(EXIT_FAILURE);
    }
}

static void PublishActions(void)
{
    struct {
        uint32_t schema, epoch;
        unsigned char session[16];
        MgsOptionsActionResult result;
    } state = {1, epoch, {0}, MgsOptionsActionsResult()};
    _Static_assert(sizeof(state) == 32 && sizeof(MgsOptionsAction) == 32, "Options actions wire layout");
    MgsGodotCopySessionId(state.session);
    MgsGodotRequest(MGS_GODOT_OPTIONS_ACTION, &state, sizeof(state), sizeof(MgsOptionsAction), ReceiveAction);
}

void MgsGodotPublishOptions(void)
{
    static unsigned char data[sizeof(elements) + MGS_OPTIONS_TEXTS * 132 + 4096 * sizeof(MgsTextGlyph)];
    static unsigned char last_session[16];
    static uint32_t last_epoch, last_generation;
    if (!MgsGodotOwnsOptions()) return;
    if (epoch != MgsGodotSceneEpoch()) MgsGodotResetOptions();
    const uint32_t revision = MgsOptionsActionsView(frame, epoch, generation);
    const int actions = MgsGodotHasCapability(MGS_OPTIONS_ACTIONS_CAPABILITY);
    struct {
        uint32_t schema, epoch, generation, reserved;
        unsigned char session[16];
        MgsOptionsFrame frame;
        uint32_t elements, texts;
    } header = {.schema = 1, .epoch = epoch, .generation = generation, .reserved = actions ? revision : 0, .frame = frame,
                .elements = frame.active ? MGS_OPTIONS_ELEMENTS : 0};
    _Static_assert(sizeof(header) == 104 && sizeof(MgsOptionsElement) == 32, "Options wire layout");
    MgsGodotCopySessionId(header.session);
    int resync = last_epoch != epoch || last_generation != generation || memcmp(last_session, header.session, 16);
    MgsUiTextContext context = {.epoch = epoch, .resync = resync};
    memcpy(context.session, header.session, 16);
    size_t bytes = header.elements * sizeof(MgsOptionsElement);
    memcpy(data, elements, bytes);
    if (frame.active) bytes += MgsUiTextsWrite(&texts, data + bytes, sizeof(data) - bytes, context, &header.texts);
    MgsGodotQueue(MGS_GODOT_OPTIONS, &header, sizeof(header), data, (uint32_t)bytes);
    if (actions) PublishActions();
    if (!frame.active) return;
    memcpy(last_session, header.session, 16);
    last_epoch = epoch;
    last_generation = generation;
}
