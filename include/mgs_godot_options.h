#ifndef MGS_GODOT_OPTIONS_H
#define MGS_GODOT_OPTIONS_H

#include "mgs_godot_subtitles.h"

#define MGS_GODOT_OPTIONS_CAPABILITY 4194304u
#define MGS_OPTIONS_ELEMENTS 57u
#define MGS_OPTIONS_TEXTS 31u

typedef struct {
    uint32_t active, selection, animation, vibration, test;
    uint32_t controller_row, controller_type, reverse, values[8];
} MgsOptionsFrame;

typedef struct {
    uint32_t texture;
    int32_t x, y, width, height;
    uint32_t rgb, layer, blend;
} MgsOptionsElement;

int MgsGodotOwnsOptions(void);
void MgsGodotResetOptions(void);
void MgsGodotOptionsBegin(void);
void MgsGodotOptionsEnd(void);
void MgsGodotOptionsView(MgsOptionsFrame frame, const MgsOptionsElement *elements);
void MgsGodotOptionsBeginText(unsigned index, const void *buffer);
void MgsGodotOptionsText(unsigned index, MgsSubtitleFrame view, const void *palette);
void MgsGodotPublishOptions(void);

#endif
