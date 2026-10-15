#ifndef MGS_SUBTITLES_H
#define MGS_SUBTITLES_H

#include <stddef.h>
#include <stdint.h>
#include "mgs_text_layout.h"

typedef struct {
    uint32_t active, visible, kind;
    int32_t timer, x, y, width, height, text_width;
    int32_t character_spacing, line_spacing;
} MgsSubtitleFrame;

typedef struct {
    MgsSubtitleFrame frame;
    uint32_t text_revision;
    size_t text_bytes;
    const char *text;
    const MgsTextLayout *layout;
} MgsSubtitleView;

void MgsSubtitlesReset(void);
void MgsSubtitlesBeginFrame(void);
MgsTextLayout *MgsSubtitlesPrepare(const char *native_text);
void MgsSubtitlesPresent(MgsSubtitleFrame frame);
/* Native encoded text; view/bytes are valid until the next BeginFrame or Reset. */
const MgsSubtitleView *MgsSubtitlesGetView(void);

#endif
