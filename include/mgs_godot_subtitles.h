#ifndef MGS_GODOT_SUBTITLES_H
#define MGS_GODOT_SUBTITLES_H

#include "mgs_subtitles.h"

#define MGS_GODOT_SUBTITLES_CAPABILITY 262144u

typedef struct {
    uint32_t schema, epoch, revision, has_layout;
    unsigned char session[16];
    MgsSubtitleFrame frame;
    uint32_t width, height, count, stride, reserved;
    uint16_t palette[16];
} MgsGodotSubtitleHeader;

int MgsGodotOwnsSubtitles(void);
void MgsGodotPublishSubtitles(void);

#endif
