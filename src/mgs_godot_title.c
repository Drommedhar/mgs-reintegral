#include "mgs_godot_title.h"
#include "mgs_godot_context.h"
#include "mgs_ui_texts.h"
#include "transport.h"
#include "mgs_title_actions.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static MgsTitleFrame frame;
static MgsTitleElement elements[MGS_TITLE_ELEMENTS];
static MgsUiTexts texts;
static uint32_t generation, epoch;
static unsigned ready;

int MgsGodotOwnsTitle(void) { return MgsGodotHasCapability(MGS_GODOT_TITLE_CAPABILITY); }
void MgsGodotResetTitle(void)
{
    ready = 0;
    memset(&frame, 0, sizeof(frame));
    MgsUiTextsReset(&texts);
    epoch = MgsGodotSceneEpoch();
}
void MgsGodotTitleEnd(void)
{
    MgsGodotResetTitle();
    MgsTitleActionsView(frame, 0, epoch, generation);
    MgsUiTextsFree(&texts);
}
void MgsGodotTitleBegin(void) { MgsGodotTitleEnd(); if (++generation == 0) ++generation; }
void MgsGodotTitleView(MgsTitleFrame value, const MgsTitleElement *source, unsigned input_ready)
{
    frame = value;
    ready = input_ready;
    memcpy(elements, source, sizeof(elements));
    epoch = MgsGodotSceneEpoch();
}
void MgsGodotTitleBeginText(unsigned index, const void *buffer) { MgsUiTextsBegin(&texts, index, buffer); }
void MgsGodotTitleText(unsigned index, MgsSubtitleFrame value, const void *palette) { MgsUiTextsSet(&texts, index, value, palette); }
static void ReceiveAction(const void *data)
{
    MgsTitleAction action;
    memcpy(&action, data, sizeof(action));
    const MgsTitleAction empty = {.schema = 1};
    if (action.schema != 1 || (action.id ? !MgsTitleActionsSubmit(&action) : memcmp(&action, &empty, sizeof(action)))) {
        fputs("Invalid Godot Title action sequence or identity.\n", stderr);
        exit(EXIT_FAILURE);
    }
}

static void PublishActions(void)
{
    struct {
        uint32_t schema, epoch;
        unsigned char session[16];
        MgsTitleActionResult result;
    } state = {1, epoch, {0}, MgsTitleActionsResult()};
    _Static_assert(sizeof(state) == 32 && sizeof(MgsTitleAction) == 28, "Title actions wire layout");
    MgsGodotCopySessionId(state.session);
    MgsGodotRequest(MGS_GODOT_TITLE_ACTION, &state, sizeof(state), sizeof(MgsTitleAction), ReceiveAction);
}

void MgsGodotPublishTitle(void)
{
    static unsigned char data[sizeof(elements) + MGS_TITLE_TEXTS * 132 + MGS_UI_GLYPH_LIMIT * sizeof(MgsTextGlyph)];
    static unsigned char last_session[16];
    static uint32_t last_epoch, last_generation;
    if (!MgsGodotOwnsTitle()) return;
    if (epoch != MgsGodotSceneEpoch()) MgsGodotResetTitle();
    const uint32_t revision = MgsTitleActionsView(frame, ready, epoch, generation);
    const int actions = MgsGodotHasCapability(MGS_TITLE_ACTIONS_CAPABILITY);
    struct {
        uint32_t schema, epoch, generation, reserved;
        unsigned char session[16];
        MgsTitleFrame frame;
        uint32_t elements, texts;
    } header = {.schema = 1, .epoch = epoch, .generation = generation, .reserved = actions ? revision : 0, .frame = frame,
                .elements = frame.active ? MGS_TITLE_ELEMENTS : 0};
    _Static_assert(sizeof(header) == 72 && sizeof(MgsTitleElement) == 52, "Title wire layout");
    MgsGodotCopySessionId(header.session);
    int resync = last_epoch != epoch || last_generation != generation || memcmp(last_session, header.session, 16);
    MgsUiTextContext context = {.epoch = epoch, .resync = resync};
    memcpy(context.session, header.session, 16);
    size_t bytes = header.elements * sizeof(MgsTitleElement);
    memcpy(data, elements, bytes);
    if (frame.active) bytes += MgsUiTextsWrite(&texts, data + bytes, sizeof(data) - bytes, context, &header.texts);
    MgsGodotQueue(MGS_GODOT_TITLE, &header, sizeof(header), data, (uint32_t)bytes);
    if (actions) PublishActions();
    if (!frame.active) return;
    memcpy(last_session, header.session, 16);
    last_epoch = epoch;
    last_generation = generation;
}
