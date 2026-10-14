#include "mgs_ui_texts.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void Require(int valid)
{
    if (valid) return;
    fputs("Godot menu text exceeds its declared extent.\n", stderr);
    exit(EXIT_FAILURE);
}
void MgsUiTextsReset(MgsUiTexts *texts) { memset(texts->frames, 0, sizeof(texts->frames)); }
void MgsUiTextsFree(MgsUiTexts *texts)
{
    for (unsigned index = 0; index < MGS_UI_TEXT_LIMIT; ++index) MgsTextLayoutFree(&texts->layouts[index]);
    memset(texts, 0, sizeof(*texts));
}
void MgsUiTextsBegin(MgsUiTexts *texts, unsigned index, const void *buffer)
{
    Require(index < MGS_UI_TEXT_LIMIT);
    if (++texts->revision == 0) ++texts->revision;
    texts->revisions[index] = texts->revision;
    MgsTextLayoutBegin(&texts->layouts[index], buffer);
}
void MgsUiTextsSet(MgsUiTexts *texts, unsigned index, MgsSubtitleFrame frame, const void *palette)
{
    Require(index < MGS_UI_TEXT_LIMIT);
    texts->frames[index] = frame;
    memcpy(texts->palettes[index], palette, sizeof(texts->palettes[index]));
}
size_t MgsUiTextsWrite(MgsUiTexts *texts, unsigned char *data, size_t capacity,
                      MgsUiTextContext context, uint32_t *count)
{
    size_t bytes = 0, glyph_count = 0;
    *count = 0;
    if (context.resync) memset(texts->sent, 0, sizeof(texts->sent));
    for (uint32_t index = 0; index < MGS_UI_TEXT_LIMIT; ++index) {
        if (!texts->frames[index].active) continue;
        const MgsTextLayout *layout = &texts->layouts[index];
        int changed = context.resync || texts->sent[index] != texts->revisions[index] ||
                      memcmp(texts->sent_colors[index], texts->palettes[index], sizeof(texts->palettes[index]));
        MgsGodotSubtitleHeader header = {.schema = 1, .epoch = context.epoch,
            .revision = texts->revisions[index], .has_layout = changed != 0,
            .frame = texts->frames[index], .stride = sizeof(MgsTextGlyph)};
        memcpy(header.session, context.session, sizeof(header.session));
        if (changed) {
            header.width = layout->width;
            header.height = layout->height;
            header.count = (uint32_t)layout->count;
            memcpy(header.palette, texts->palettes[index], sizeof(header.palette));
        }
        glyph_count += header.count;
        size_t length = sizeof(index) + sizeof(header) + header.count * sizeof(MgsTextGlyph);
        Require(glyph_count <= MGS_UI_GLYPH_LIMIT && length <= capacity - bytes);
        memcpy(data + bytes, &index, sizeof(index));
        memcpy(data + bytes + sizeof(index), &header, sizeof(header));
        bytes += sizeof(index) + sizeof(header);
        if (header.count) memcpy(data + bytes, layout->glyphs, header.count * sizeof(MgsTextGlyph));
        bytes += header.count * sizeof(MgsTextGlyph);
        texts->sent[index] = texts->revisions[index];
        memcpy(texts->sent_colors[index], texts->palettes[index], sizeof(texts->palettes[index]));
        ++*count;
    }
    return bytes;
}
