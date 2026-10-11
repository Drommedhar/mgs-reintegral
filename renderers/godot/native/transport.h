#ifndef MGS_GODOT_TRANSPORT_H
#define MGS_GODOT_TRANSPORT_H

#include <stdbool.h>
#include <stdint.h>

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
    MGS_GODOT_DEBUG_TEXT = 11
};

bool MgsGodotConnect(void);
void MgsGodotClose(void);
void MgsGodotQueue(uint32_t operation, const void *header, uint32_t header_bytes,
                   const void *data, uint32_t data_bytes);
void MgsGodotExchange(uint32_t operation, const void *header, uint32_t header_bytes,
                      void *result, uint32_t result_bytes);
unsigned MgsGodotButtons(void);
double MgsGodotTakeExchangeTimeUs(void);
bool MgsGodotQuitRequested(void);
void MgsGodotWorldBegin(unsigned near_depth, unsigned far_depth);

#endif
