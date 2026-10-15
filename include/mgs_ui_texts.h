#ifndef MGS_UI_TEXTS_H
#define MGS_UI_TEXTS_H
#include "mgs_godot_subtitles.h"

enum { MGS_UI_TEXT_LIMIT = 31, MGS_UI_GLYPH_LIMIT = 4096 };
typedef struct {
    MgsTextLayout layouts[MGS_UI_TEXT_LIMIT];
    MgsSubtitleFrame frames[MGS_UI_TEXT_LIMIT];
    uint16_t palettes[MGS_UI_TEXT_LIMIT][16], sent_colors[MGS_UI_TEXT_LIMIT][16];
    uint32_t revisions[MGS_UI_TEXT_LIMIT], sent[MGS_UI_TEXT_LIMIT], revision;
} MgsUiTexts;
void MgsUiTextsReset(MgsUiTexts *texts);
void MgsUiTextsFree(MgsUiTexts *texts);
void MgsUiTextsBegin(MgsUiTexts *texts, unsigned index, const void *buffer);
void MgsUiTextsSet(MgsUiTexts *texts, unsigned index, MgsSubtitleFrame frame, const void *palette);
typedef struct {
    unsigned char session[16];
    uint32_t epoch;
    int resync;
} MgsUiTextContext;
size_t MgsUiTextsWrite(MgsUiTexts *texts, unsigned char *data, size_t capacity,
                      MgsUiTextContext context, uint32_t *count);
#endif
