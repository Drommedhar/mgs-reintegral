#ifndef MGS_GODOT_BARS_H
#define MGS_GODOT_BARS_H

#include <stdint.h>

#define MGS_GODOT_BARS_CAPABILITY 131072u
#define MGS_GODOT_BAR_LIMIT 16u

typedef struct {
    int32_t x, y, rest, value, maximum, height;
    uint32_t kind, flags, left, right;
    char name[32];
} MgsGodotBar;

int MgsGodotOwnsBars(void);
void MgsGodotResetBars(void);
void MgsGodotSubmitBar(const MgsGodotBar *bar);
void MgsGodotPublishBars(void);

#endif
