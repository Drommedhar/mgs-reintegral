#ifndef MGS_GODOT_INVENTORY_H
#define MGS_GODOT_INVENTORY_H

#include "mgs_godot_subtitles.h"

#define MGS_GODOT_INVENTORY_CAPABILITY 1048576u
#define MGS_INVENTORY_PANEL_LIMIT 32u
enum {
    MGS_INVENTORY_DISABLED = 1, MGS_INVENTORY_FROZEN = 2,
    MGS_INVENTORY_COUNT = 4, MGS_INVENTORY_LEVEL = 8,
    MGS_INVENTORY_TIMER = 16, MGS_INVENTORY_DIM = 32,
    MGS_INVENTORY_HIGHLIGHT = 64, MGS_INVENTORY_MAGAZINE = 128
};
typedef struct {
    uint32_t side;
    int32_t id, x, y;
    uint32_t icon, flags;
    int32_t quantity, maximum, level, magazine, magazine_max, burst;
    char name[32];
} MgsInventoryPanel;

int MgsGodotOwnsInventory(void);
void MgsGodotResetInventory(void);
void MgsGodotSubmitInventoryPanel(MgsInventoryPanel panel, const char *name);
MgsTextLayout *MgsGodotPrepareInventoryDescription(void);
void MgsGodotInventoryDescription(MgsSubtitleFrame frame);
void MgsGodotInventoryShape(unsigned shape);
void MgsGodotPublishInventory(void);

#endif
