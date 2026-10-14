#ifndef MGS_GODOT_TRANSPORT_H
#define MGS_GODOT_TRANSPORT_H

#include <stdbool.h>
#include <stdint.h>

#define MGS_GODOT_CAP_SCENE_MESHES 2u

enum MgsGodotCommand {
    MGS_GODOT_HELLO = 1,
    MGS_GODOT_DRAW = 2,
    MGS_GODOT_UPLOAD = 3,
    MGS_GODOT_MOVE = 4,
    MGS_GODOT_READ = 5,
    MGS_GODOT_SYNC = 6,
    MGS_GODOT_FRAME = 7,
    MGS_GODOT_CLEAR = 8,
    MGS_GODOT_SCENE_FRAME = 9,
    MGS_GODOT_WORLD = 10,
    MGS_GODOT_DEBUG_TEXT = 11,
    MGS_GODOT_CONTEXT = 12,
    MGS_GODOT_PALETTE = 13,
    MGS_GODOT_RETAINED_SCENE = 14,
    MGS_GODOT_MODEL_SOURCE = 15,
    MGS_GODOT_ACTOR = 16,
    MGS_GODOT_UI = 17,
    MGS_GODOT_BARS = 18,
    MGS_GODOT_SUBTITLES = 19,
    MGS_GODOT_RADAR = 20,
    MGS_GODOT_INVENTORY = 21,
    MGS_GODOT_CODEC = 22,
    MGS_GODOT_OPTIONS = 23,
    MGS_GODOT_SAVE_UI = 24,
    MGS_GODOT_TITLE = 25,
    MGS_GODOT_DISPLAY = 26,
    MGS_GODOT_SAVE_ACTION = 27,
    MGS_GODOT_OPTIONS_ACTION = 28,
    MGS_GODOT_TITLE_ACTION = 29,
    MGS_GODOT_CODEC_ACTION = 30,
    MGS_GODOT_INVENTORY_ACTION = 31
};

bool MgsGodotConnect(void);
bool MgsGodotHasCapability(unsigned capability);
unsigned MgsGodotSelectedMinor(void);
void MgsGodotClose(void);
void MgsGodotCopySessionId(unsigned char destination[16]);
void MgsGodotQueue(uint32_t operation, const void *header, uint32_t header_bytes,
                   const void *data, uint32_t data_bytes);
void MgsGodotExchange(uint32_t operation, const void *header, uint32_t header_bytes,
                      void *result, uint32_t result_bytes);
/* The next Exchange completes replies in order; callbacks must not use the transport. */
void MgsGodotRequest(uint32_t operation, const void *header, uint32_t header_bytes,
                     uint32_t result_bytes, void (*complete)(const void *));
unsigned MgsGodotButtons(void);
bool MgsGodotInputCaptured(void);
void MgsGodotFilterPad(unsigned port, unsigned char *frame);
double MgsGodotTakeExchangeTimeUs(void);
bool MgsGodotQuitRequested(void);
void MgsGodotWorldBegin(unsigned near_depth, unsigned far_depth);
void MgsGodotWaterEffect(int active);
void MgsGodotTextCard(int active);

#endif
