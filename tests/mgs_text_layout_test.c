#include "mgs_native.h"
#include "mgs_text_layout.h"
#include "mgs_godot_subtitles.h"
#include "../vendor/mgs/source/font/font.c"
#include <assert.h>

short linkvarbuf[MAX_LINKVARBUF];
static unsigned descriptors[96];
static unsigned char half_data[96 * 36], full_data[4][512 * 36], localized[12];
static RubiRes ruby_data[128];
static MgsTextLayout layout;
static const char *fixture_directory;
static unsigned fixture_index;

static void ExportFixture(const KCB *font)
{
    if (!fixture_directory) return;
    MgsGodotSubtitleHeader header = {.schema = 1, .epoch = 3, .revision = fixture_index + 1,
        .has_layout = 1, .frame = {.active = 1, .visible = 1, .timer = 3, .x = 20, .y = 20,
        .width = 256, .height = font->height, .text_width = (unsigned char)font->max_width},
        .width = layout.width, .height = layout.height, .count = (uint32_t)layout.count,
        .stride = sizeof(MgsTextGlyph)};
    memset(header.session, 7, sizeof(header.session));
    memcpy(header.palette, layout.palette, sizeof(header.palette));
    char path[1024];
    int length = snprintf(path, sizeof(path), "%s/case%03u.bin", fixture_directory, fixture_index);
    assert(length > 0 && length < sizeof(path));
    FILE *file = fopen(path, "wb");
    assert(file && fwrite(&header, sizeof(header), 1, file) == 1);
    assert(fwrite(layout.glyphs, sizeof(MgsTextGlyph), layout.count, file) == layout.count);
    assert(fclose(file) == 0);
    snprintf(path, sizeof(path), "%s/case%03u.pixels", fixture_directory, fixture_index++);
    file = fopen(path, "wb");
    size_t bytes = (size_t)font->row * font->height;
    assert(file && fwrite(font->buffer, 1, bytes, file) == bytes);
    assert(fclose(file) == 0);
}

int GV_CacheID(int root, int spec) { abort(); }
void *GV_GetCache(int id) { abort(); }
int LoadImage(RECT *rect, u_long *pixels) { abort(); }
const char *MgsLanguageText(const char *text) { return strcmp(text, "localized") == 0 ? "ABC" : text; }
const unsigned char *MgsLanguageGlyph(unsigned code, unsigned *descriptor)
{
    if (code != 128) return NULL;
    *descriptor = 0x04000000;
    return localized;
}

static void Fixtures(void)
{
    for (unsigned i = 0; i < 96; ++i)
        descriptors[i] = ((i % 3) << 28) | ((3 + i % 10) << 24) | (i * 36);
    for (unsigned i = 0; i < sizeof(half_data); ++i) half_data[i] = (unsigned char)(i * 37);
    for (unsigned bank = 0; bank < 4; ++bank) {
        for (unsigned i = 0; i < sizeof(full_data[bank]); ++i)
            full_data[bank][i] = (unsigned char)(i * 53 + bank * 17);
        zendata[bank] = (char *)full_data[bank];
    }
    for (unsigned i = 0; i < 128; ++i) {
        ruby_data[i].field_0 = (char)(3 + i % 4);
        for (unsigned j = 0; j < 9; ++j) ruby_data[i].field_1[j] = (char)(i * 53 + j * 17);
    }
    memset(localized, 0x1b, sizeof(localized));
    gFontBegin = (char *)descriptors;
    gFontEnd = (char *)half_data;
    gRubiRes_800AB6B4 = ruby_data;
    dword_800ABB28 = (char *)descriptors;
}

static unsigned Pixel(const MgsTextGlyph *glyph, unsigned x, unsigned y)
{
    if (glyph->kind == MGS_TEXT_CLEAR) return glyph->color << 2;
    if (glyph->kind == MGS_TEXT_EMPHASIS || glyph->kind == MGS_TEXT_DASH)
        return (glyph->color << 2) | 3;
    unsigned pitch = glyph->kind == MGS_TEXT_RUBY ? 6 : glyph->width;
    unsigned index = y * pitch + x;
    return (glyph->color << 2) | ((glyph->source[index / 4] >> (6 - (index % 4) * 2)) & 3);
}

static void ComparePixels(const KCB *font)
{
    unsigned char *pixels = calloc((size_t)font->row * 2 * font->height, 1);
    assert(pixels);
    for (size_t i = 0; i < layout.count; ++i) {
        const MgsTextGlyph *glyph = &layout.glyphs[i];
        for (unsigned y = 0; y < glyph->height; ++y) {
            for (unsigned x = 0; x < glyph->width; ++x) {
                if (glyph->kind == MGS_TEXT_DASH && glyph->code && x == 1) continue;
                int px = glyph->x + (int)x, py = glyph->y + (int)y;
                assert(px >= 0 && px < font->row * 2 && py >= 0 && py < font->height);
                unsigned char *dest = &pixels[py * font->row * 2 + px];
                if (glyph->kind == MGS_TEXT_CLEAR) *dest = (unsigned char)Pixel(glyph, x, y);
                else *dest |= (unsigned char)Pixel(glyph, x, y);
            }
        }
    }
    const unsigned char *native = font->buffer;
    for (int i = 0; i < font->row * 2 * font->height; ++i) {
        unsigned expected = (native[i / 2] >> ((i & 1) * 4)) & 15;
        if (pixels[i] != expected) {
            printf("Pixel mismatch %d,%d: semantic=%u native=%u\n", i % (font->row * 2), i / (font->row * 2), pixels[i], expected);
            abort();
        }
    }
    free(pixels);
}

static void Render(const char *text, int column_count)
{
    RECT rect = {0, 0, 64, 128};
    KCB font;
    font_init_kcb(&font, &rect, 0, 0);
    font_set_kcb(&font, column_count, -1, 0, 6, 2, 0);
    size_t size = (size_t)font_get_buffer_size(&font);
    unsigned char *buffer = calloc(size, 1), *baseline = malloc(size);
    assert(buffer && baseline);
    font_set_buffer(&font, buffer);
    for (int color = 0; color < 4; ++color) font_set_color(&font, color, 0x6739 - color, 0);
    r_flag = rubi_flag = 0;
    font_print_string(&font, text);
    unsigned width = (unsigned char)font.max_width, height = font.max_height;
    memcpy(baseline, buffer, size);
    r_flag = rubi_flag = 0;
    MgsTextLayoutBegin(&layout, font.buffer);
    font_print_string(&font, text);
    MgsTextLayoutEnd(font.cbuffer, font.row * 2, font.height);
    assert(memcmp(buffer, baseline, size) == 0);
    assert(width == (unsigned char)font.max_width && height == (unsigned)font.max_height);
    assert(layout.width == (unsigned)font.row * 2 && layout.height == (unsigned)font.height);
    assert(memcmp(layout.palette, font.cbuffer, 32) == 0);
    ComparePixels(&font);
    ExportFixture(&font);
    free(buffer);
    free(baseline);
}

static void Formatting(void)
{
    const char *cases[] = {"ABC", "localized", "A!?()B", "A#NB", "A|B", "A#SB", "A\f2B\f0C",
        "#1#2#-", "I#-", "ABCDEFGHIJKLMN OPQRSTUVWXYZ 0123456789", "A#WBC",
        "\x81\x01\x96\x01\x9a\x01\x9c\x01", "\x80\x80",
        "#{A\x90\x02" "B}#", "#TxxA}#", "#Txx\x81\x01}#",
        "\x81\x01\xa1\x01\x81\x01\x81\x01", "\x81\x01\x81\x01\xc1\x01\x81\x01"};
    for (unsigned i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        printf("Layout case %u\n", i);
        Render(cases[i], 3);
        unsigned kinds = 0;
        for (size_t j = 0; j < layout.count; ++j) kinds |= 1u << layout.glyphs[j].kind;
        if (i == 13) assert(kinds & (1u << MGS_TEXT_RUBY));
        if (i == 14 || i == 15) assert(kinds & (1u << MGS_TEXT_EMPHASIS));
        if (i == 16) assert(kinds & (1u << MGS_TEXT_CLEAR));
        if (i == 12) assert(layout.glyphs[0].code == 128 && memcmp(layout.glyphs[0].source, localized, 12) == 0);
    }
    for (unsigned config = 0; config < 3; ++config) {
        GM_Configuration = config * GM_CONFIG_BUTTON_TYPE_B;
        Render("#\x90\x1d#\x90\x1e#\x90\x24", -1);
        assert(layout.count == 3);
        unsigned first = config == 2 ? 0x9024 : 0x901d;
        unsigned second = config == 0 ? 0x901e : config == 1 ? 0x9018 : 0x901d;
        unsigned third = config == 0 ? 0x9024 : second;
        assert(layout.glyphs[0].code == (unsigned)get_zen_font_data(first));
        assert(layout.glyphs[1].code == (unsigned)get_zen_font_data(second));
        assert(layout.glyphs[2].code == (unsigned)get_zen_font_data(third));
    }
}

int main(int argc, char **argv)
{
    assert(argc <= 2);
    fixture_directory = argc == 2 ? argv[1] : NULL;
    Fixtures();
    Formatting();
    Render("\x81\x01\x96\x01\x9a\x01\x9c\x01", -1);
    assert(layout.count == 4);
    for (unsigned bank = 0; bank < 4; ++bank) {
        assert(layout.glyphs[bank].code == bank * 4096 + 1);
        assert(memcmp(layout.glyphs[bank].source, full_data[bank], 36) == 0);
    }
    memset(full_data, 0, sizeof(full_data));
    assert(layout.glyphs[1].source[0] == 17);
    MgsTextLayoutFree(&layout);
    assert(!layout.glyphs && !layout.count);
    puts("Text layout: formatting, palettes, font banks and native pixel parity passed");
    return 0;
}
