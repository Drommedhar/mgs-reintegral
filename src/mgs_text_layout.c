#include "mgs_text_layout.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static MgsTextLayout *active;
static const void *active_buffer;

static void InvalidLayout(void)
{
    fputs("Native text layout: invalid observer state or glyph extent.\n", stderr);
    exit(EXIT_FAILURE);
}

void MgsTextLayoutBegin(MgsTextLayout *layout, const void *buffer)
{
    if (active || !layout || !buffer) InvalidLayout();
    active = layout;
    active_buffer = buffer;
    layout->count = 0;
}

void MgsTextLayoutEnd(const void *palette, unsigned width, unsigned height)
{
    if (!active || !palette || !width || !height) InvalidLayout();
    memcpy(active->palette, palette, sizeof(active->palette));
    active->width = width;
    active->height = height;
    active = NULL;
    active_buffer = NULL;
}

void MgsTextLayoutFree(MgsTextLayout *layout)
{
    if (active == layout) InvalidLayout();
    free(layout->glyphs);
    memset(layout, 0, sizeof(*layout));
}

void MgsTextLayoutEmit(const void *buffer, MgsTextGlyph glyph, const void *source)
{
    if (!active || buffer != active_buffer) return;
    if (glyph.kind < MGS_TEXT_HALF || glyph.kind > MGS_TEXT_CLEAR ||
        !glyph.width || glyph.width > 20 || !glyph.height || glyph.height > 12 ||
        glyph.color > 3 || glyph.source_size > sizeof(glyph.source) ||
        (glyph.source_size && !source) || active->count == 4096) InvalidLayout();
    if (active->count == active->capacity) {
        size_t capacity = active->capacity ? active->capacity * 2 : 64;
        MgsTextGlyph *glyphs = realloc(active->glyphs, capacity * sizeof(*glyphs));
        if (!glyphs) {
            fputs("Native text layout: cannot retain glyphs.\n", stderr);
            exit(EXIT_FAILURE);
        }
        active->glyphs = glyphs;
        active->capacity = capacity;
    }
    if (glyph.source_size) memcpy(glyph.source, source, glyph.source_size);
    active->glyphs[active->count++] = glyph;
}
