#ifndef MGS_TEXT_LAYOUT_H
#define MGS_TEXT_LAYOUT_H

#include <stddef.h>
#include <stdint.h>

enum {
    MGS_TEXT_HALF = 1, MGS_TEXT_FULL, MGS_TEXT_RUBY,
    MGS_TEXT_DASH, MGS_TEXT_EMPHASIS, MGS_TEXT_CLEAR
};

typedef struct {
    uint32_t kind, code;
    int32_t x, y;
    uint32_t width, height, color, source_size;
    unsigned char source[48];
} MgsTextGlyph;

typedef struct {
    MgsTextGlyph *glyphs;
    size_t count, capacity;
    uint32_t width, height;
    uint16_t palette[16];
} MgsTextLayout;

void MgsTextLayoutBegin(MgsTextLayout *layout, const void *buffer);
void MgsTextLayoutEnd(const void *palette, unsigned width, unsigned height);
void MgsTextLayoutFree(MgsTextLayout *layout);
void MgsTextLayoutEmit(const void *buffer, MgsTextGlyph glyph, const void *source);

#endif
