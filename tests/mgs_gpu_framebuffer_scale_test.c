#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <libgpu.h>
#include <psyz.h>

static int scale;
static unsigned comparisons;
static unsigned char presented_color[32];

static void submit(void *primitive)
{
    termPrim((P_TAG *)primitive);
    DrawOTag((OT_TYPE *)primitive);
}

static void mask(int flags)
{
    Psyz_GpuWriteGP0(0xe6000000u | (unsigned)flags);
    assert(Psyz_GpuExeque() == 0);
}

static void environment(int buffer)
{
    DRAWENV environment;
    SetDefDrawEnv(&environment, buffer, 0, 320, 224);
    environment.dtd = 0;
    PutDrawEnv(&environment);
}

static unsigned char *capture(int buffer)
{
    DrawSync(0);
    DISPENV display;
    SetDefDispEnv(&display, buffer, 0, 320, 240);
    PutDispEnv(&display);
    int width, height;
    unsigned char *pixels = Psyz_VideoAllocPresentedFrame(&width, &height);
    assert(pixels && width == 320 * scale && height == 224 * scale);
    return pixels;
}

static void seed_source(void)
{
    environment(320);
    TILE background = {0};
    setTile(&background);
    setXY0(&background, 0, 0);
    setWH(&background, 320, 224);
    setRGB0(&background, 0, 0, 64);
    submit(&background);
    POLY_F3 triangle = {0};
    setPolyF3(&triangle);
    setXY3(&triangle, 8, 8, 24, 8, 8, 24);
    setRGB0(&triangle, 248, 248, 248);
    mask(1);
    submit(&triangle);
    mask(0);
}

static void copy(int sprite, int x, int page, int semi)
{
    if (sprite) {
        DR_TPAGE mode = {0};
        setDrawTPage(&mode, 0, 0, getTPage(2, 0, page, 0));
        submit(&mode);
        SPRT primitive = {0};
        setSprt(&primitive);
        setShadeTex(&primitive, 1);
        setSemiTrans(&primitive, semi);
        setXY0(&primitive, x, 0);
        setUV0(&primitive, 0, 0);
        setWH(&primitive, 32, 32);
        submit(&primitive);
        return;
    }
    POLY_FT4 primitive = {0};
    setPolyFT4(&primitive);
    setShadeTex(&primitive, 1);
    setSemiTrans(&primitive, semi);
    setXY4(&primitive, x, 0, x + 32, 0, x, 32, x + 32, 32);
    setUV4(&primitive, 0, 0, 32, 0, 0, 32, 32, 32);
    primitive.tpage = getTPage(2, 0, page, 0);
    submit(&primitive);
}

static unsigned compare(const unsigned char *actual, const unsigned char *source, int x, int operation)
{
    unsigned different = 0;
    for (int row = scale; row < 31 * scale; ++row) {
        for (int column = scale; column < 31 * scale; ++column) {
            size_t from = ((size_t)row * 320 * scale + column) * 3;
            size_t to = from + x * scale * 3;
            int masked = source[from] == 255;
            for (int channel = 0; channel < 3; ++channel) {
                unsigned expected = source[from + channel];
                if (operation == 1 && masked) {
                    unsigned color = (31 + (channel == 0 ? 8 : 0)) / 2;
                    expected = (color * 255 + 15) / 31;
                }
                if (operation == 2 && !masked) expected = channel == 1 ? 255 : 0;
                if (actual[to + channel] != expected) {
                    ++different;
                }
                ++comparisons;
            }
        }
    }
    return different;
}

static void check_scaled_feedback(void)
{
    seed_source();
    unsigned char *source = capture(320);
    environment(0);
    RECT destination = {0, 0, 320, 224};
    ClearImage(&destination, 64, 0, 0);
    copy(0, 0, 320, 0);
    unsigned char *native_copy = capture(0);
    unsigned lost_detail = compare(native_copy, source, 0, 0);
    assert(scale == 1 ? lost_detail == 0 : lost_detail > 0);
    free(native_copy);
    ClearImage(&destination, 64, 0, 0);
    assert(Psyz_GpuSetFramebufferSampling(1) == 0);
    copy(0, 0, 320, 0);
    copy(1, 64, 320, 0);
    copy(0, 128, 0, 0);
    copy(0, 192, 320, 1);
    unsigned char *scaled_copy = capture(0);
    assert(compare(scaled_copy, source, 0, 0) == 0);
    assert(compare(scaled_copy, source, 64, 0) == 0);
    assert(compare(scaled_copy, source, 128, 0) == 0);
    assert(compare(scaled_copy, source, 192, 1) == 0);
    free(scaled_copy);
    TILE green = {0};
    setTile(&green);
    setXY0(&green, 0, 0);
    setWH(&green, 32, 32);
    setRGB0(&green, 0, 248, 0);
    mask(2);
    submit(&green);
    mask(0);
    scaled_copy = capture(0);
    assert(compare(scaled_copy, source, 0, 2) == 0);
    free(scaled_copy);
    assert(Psyz_GpuSetFramebufferSampling(0) == 0);
    copy(0, 256, 320, 0);
    native_copy = capture(0);
    assert(compare(native_copy, source, 256, 0) == lost_detail);
    free(native_copy);
    free(source);
    printf("Framebuffer %dx: %u channel comparisons; unscoped copy loses %u samples\n",
           scale, comparisons, lost_detail);
}

static void light_palette(int colored)
{
    uint16_t palette[256] = {0};
    palette[0] = 0x8000u | (colored ? 8u | (4u << 5) | (2u << 10) : 0);
    RECT area = {768, 480, 256, 1};
    LoadImage(&area, (u_long *)palette);
}

static void world_light(int abr)
{
    POLY_FT4 light = {0};
    setPolyFT4(&light);
    setShadeTex(&light, 1);
    setSemiTrans(&light, 1);
    setXY4(&light, 0, 0, 32, 0, 0, 32, 32, 32);
    setUV4(&light, 0, 0, 32, 0, 0, 32, 32, 32);
    light.tpage = getTPage(1, abr, 640, 256);
    light.clut = getClut(768, 480);
    submit(&light);
}

static void measure_presented_colors(void)
{
    environment(320);
    for (int value = 0; value < 32; ++value) {
        TILE tile = {0};
        setTile(&tile);
        setXY0(&tile, 64 + value * 4, 0);
        setWH(&tile, 4, 4);
        setRGB0(&tile, value * 8 + 4, value * 8 + 4, value * 8 + 4);
        submit(&tile);
    }
    unsigned char *pixels = capture(320);
    uint16_t words[128] = {0};
    RECT area = {384, 1, 128, 1};
    StoreImage(&area, (u_long *)words);
    for (int value = 0; value < 32; ++value) {
        assert((words[value * 4 + 1] & 0x7fff) == (value | value << 5 | value << 10));
        size_t offset = ((size_t)scale * 320 * scale + (65 + value * 4) * scale) * 3;
        assert(pixels[offset] == pixels[offset + 1] && pixels[offset] == pixels[offset + 2]);
        presented_color[value] = pixels[offset];
    }
    free(pixels);
}

static unsigned blend_color(unsigned background, int channel, int abr, int passes)
{
    static const int foreground[3] = {8, 4, 2};
    int value = (background * 31 + 127) / 255;
    for (int pass = 0; pass < passes; ++pass) {
        if (abr == 0) value = (value + foreground[channel]) / 2;
        else if (abr == 1) value += foreground[channel];
        else if (abr == 2) value -= foreground[channel];
        else value += foreground[channel] / 4;
        if (value < 0) value = 0;
        if (value > 31) value = 31;
    }
    return presented_color[value];
}

static void compare_blend(const unsigned char *actual, const unsigned char *source,
                          int abr, int passes)
{
    unsigned differences = 0;
    for (int row = scale; row < 31 * scale; ++row) {
        for (int column = scale; column < 31 * scale; ++column) {
            size_t offset = ((size_t)row * 320 * scale + column) * 3;
            for (int channel = 0; channel < 3; ++channel) {
                unsigned expected = blend_color(source[offset + channel], channel, abr, passes);
                if (actual[offset + channel] != expected && differences == 0)
                    fprintf(stderr, "First mismatch %d,%d channel%d: source%u expected%u actual%u\n",
                            column, row, channel, source[offset + channel], expected,
                            actual[offset + channel]);
                differences += actual[offset + channel] != expected;
                ++comparisons;
            }
        }
    }
    fprintf(stderr, "World blend %dx ABR%d x%d: %u mismatched channels\n",
            scale, abr, passes, differences);
    assert(differences == 0);
}

static void check_world_destination(void)
{
    uint16_t indices[16 * 32] = {0};
    RECT image = {640, 256, 16, 32};
    LoadImage(&image, (u_long *)indices);
    assert(Psyz_GpuSetFramebufferSampling(0) == 0);
    assert(Psyz_GpuSetTextureAlignment(0) == 0);
    measure_presented_colors();
    light_palette(0);
    seed_source();
    unsigned char *source = capture(320);
    world_light(1);
    unsigned char *actual = capture(320);
    unsigned differences = compare(actual, source, 0, 0);
    fprintf(stderr, "World additive-zero %dx: %u mismatched channels\n", scale, differences);
    assert(differences == 0);
    free(actual);
    light_palette(1);
    for (int abr = 0; abr < 4; ++abr) {
        seed_source();
        world_light(abr);
        actual = capture(320);
        compare_blend(actual, source, abr, 1);
        free(actual);
    }
    seed_source();
    world_light(1);
    world_light(1);
    actual = capture(320);
    compare_blend(actual, source, 1, 2);
    free(actual);
    seed_source();
    TILE green = {0};
    setTile(&green);
    setXY0(&green, 0, 0);
    setWH(&green, 32, 32);
    setRGB0(&green, 0, 248, 0);
    mask(2);
    submit(&green);
    mask(0);
    actual = capture(320);
    assert(compare(actual, source, 0, 2) == 0);
    free(actual);
    free(source);
    printf("Framebuffer/world %dx: %u total channel comparisons\n", scale, comparisons);
}

int main(int argc, char **argv)
{
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
    scale = argc == 2 ? atoi(argv[1]) : 1;
    assert(argc <= 2 && (scale == 1 || scale == 2 || scale == 8));
    assert(Psyz_VideoConfigureWindow(320 * scale, 224 * scale, 0) == 0);
    assert(Psyz_VideoSetPresentation(320, 224, 224) == 0);
    assert(Psyz_VideoSetInternalResolution((unsigned)scale) == 0);
    assert(Psyz_GpuSetFramebufferSampling(2) < 0);
    ResetGraph(0);
    Psyz_VideoSetDitheringMode(PSYZ_DITHER_OFF);
    DISPENV display;
    SetDefDispEnv(&display, 0, 0, 320, 240);
    PutDispEnv(&display);
    SetDispMask(1);
    DrawSync(0);
    check_scaled_feedback();
    check_world_destination();
    return 0;
}
