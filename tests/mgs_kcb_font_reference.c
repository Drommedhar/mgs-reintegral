#include "mgs_native.h"
#include "../vendor/mgs/source/font/font.c"
#include <assert.h>

static unsigned char *source;
short linkvarbuf[MAX_LINKVARBUF];

const char *MgsLanguageText(const char *text) { abort(); }
int LoadImage(RECT *rect, u_long *pixels) { abort(); }

int GV_CacheID(int root_id, int spec)
{
    assert(spec == 'r');
    return root_id;
}

void *GV_GetCache(int identity)
{
    assert(identity == HASH_font || identity == HASH_rubi);
    return identity == HASH_font ? source : NULL;
}

const unsigned char *MgsLanguageGlyph(unsigned code, unsigned *descriptor)
{
    assert(code >= 32 && code < 128);
    return NULL;
}

static uint32_t big_endian(const unsigned char *data)
{
    return ((uint32_t)data[0] << 24) | ((uint32_t)data[1] << 16) |
           ((uint32_t)data[2] << 8) | data[3];
}

static unsigned load_source(const char *path)
{
    FILE *file = fopen(path, "rb");
    assert(file && fseek(file, 0, SEEK_END) == 0);
    long length = ftell(file);
    assert(length >= 392 && length <= 1024 * 1024);
    source = calloc((size_t)length + 1, 1);
    assert(source && fseek(file, 0, SEEK_SET) == 0);
    assert(fread(source, 1, (size_t)length, file) == (size_t)length);
    assert(fclose(file) == 0);
    unsigned bank = big_endian(source + 4);
    assert(big_endian(source) == 392 && bank >= 392 && bank < (unsigned)length);
    unsigned bank_bytes = (unsigned)length - bank - ((0u - bank) % 4);
    assert(length % 4 == 0 && bank_bytes % 36 == 0);
    for (unsigned i = 0; i < 96; ++i)
    {
        unsigned descriptor = big_endian(source + 8 + i * 4);
        unsigned width = (descriptor >> 24) & 15;
        assert(width > 0 && width <= 12 && (descriptor >> 28) <= 2);
        assert(392 + (descriptor & 0xffffff) + width * 3 <= bank);
    }
    font_load();
    return bank_bytes / 36;
}

static void emit_glyph(FILE *file, unsigned code, const char *packed, unsigned advance)
{
    uint32_t header[2] = {code, advance};
    unsigned char pixels[24 * 16];
    for (unsigned i = 0; i < sizeof(pixels); ++i)
        pixels[i] = ((unsigned char)packed[i / 2] >> ((i & 1) * 4)) & 15;
    assert(fwrite(header, sizeof(header), 1, file) == 1);
    assert(fwrite(pixels, sizeof(pixels), 1, file) == 1);
}

int main(int argc, char **argv)
{
    assert(argc == 3);
    unsigned bank_size = load_source(argv[1]);
    FILE *output = fopen(argv[2], "wb");
    assert(output);
    unsigned short palette[16] = {0};
    KCB kcb = {0};
    kcb.cbuffer = palette;
    font_set_color(&kcb, 0, 0x6739, 0);
    assert(fwrite(palette, 8, 1, output) == 1);
    char pixels[24 * 16 / 2];
    for (unsigned code = 32; code < 128; ++code)
    {
        memset(pixels, 0, sizeof(pixels));
        unsigned advance = put_hankaku_4bpp(pixels, 0, 0, 12, (unsigned char)code);
        emit_glyph(output, code, pixels, advance);
    }
    for (unsigned index = 0; index < bank_size; ++index)
    {
        memset(pixels, 0, sizeof(pixels));
        put_zenkaku_4bpp(pixels, 0, 0, 12, zendata[0] + index * 36);
        emit_glyph(output, 0xF0001 + index, pixels, 12);
    }
    memset(pixels, 0, sizeof(pixels));
    unsigned advance = put_hankaku_4bpp(pixels, 0, 0, 12, 0);
    emit_glyph(output, 0xF4000, pixels, advance);
    assert(fclose(output) == 0);
    free(source);
    return 0;
}
