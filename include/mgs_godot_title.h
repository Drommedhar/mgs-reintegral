#ifndef MGS_GODOT_TITLE_H
#define MGS_GODOT_TITLE_H
#include "mgs_godot_subtitles.h"

enum { MGS_GODOT_TITLE_CAPABILITY = 16777216, MGS_TITLE_ELEMENTS = 55, MGS_TITLE_TEXTS = 24 };
typedef struct {
    uint32_t active, mode, selection, difficulty, extreme, storage_choice, storage[2];
} MgsTitleFrame;
typedef struct {
    uint32_t texture;
    int32_t x, y, width, height, source_x, source_y, source_width, source_height;
    uint32_t top_rgb, bottom_rgb, layer, blend;
} MgsTitleElement;
int MgsGodotOwnsTitle(void);
void MgsGodotResetTitle(void);
void MgsGodotTitleBegin(void);
void MgsGodotTitleEnd(void);
void MgsGodotTitleView(MgsTitleFrame frame, const MgsTitleElement *elements, unsigned ready);
void MgsGodotTitleBeginText(unsigned index, const void *buffer);
void MgsGodotTitleText(unsigned index, MgsSubtitleFrame frame, const void *palette);
void MgsGodotPublishTitle(void);
#endif
