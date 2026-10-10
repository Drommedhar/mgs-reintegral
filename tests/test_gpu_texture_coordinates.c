#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libgpu.h>
#include <psyz.h>

typedef struct {
    int u, v, ux, uy, vx, vy;
} Mapping;

static const Mapping mappings[] = {
    {64, 64, 4, 0, 0, 4},
    {128, 64, -4, 0, 0, 4},
    {128, 64, 0, -4, 4, 0},
    {64, 128, 1, 3, -2, 1},
    {128, 96, -3, -1, 2, -2},
};
static const unsigned permutations[6][3] = {
    {0, 1, 2}, {0, 2, 1}, {1, 0, 2},
    {1, 2, 0}, {2, 0, 1}, {2, 1, 0},
};

static void submit(void *primitive) {
    termPrim((P_TAG *)primitive);
    DrawOTag((OT_TYPE *)primitive);
}

static uint16_t palette_color(unsigned index) {
    return index == 0 ? 0 : (uint16_t)(0x8000 | (index & 31) |
                                       ((31 - (index & 31)) << 5) |
                                       ((index >> 3) << 10));
}

static unsigned texture_index(unsigned depth, int u, int v) {
    if (u >= 80 && u < 96 && v >= 80 && v < 96)
        return 7;
    if (u >= 96 && u < 112 && v >= 64 && v < 80)
        return 0;
    return depth == 0 ? (unsigned)((u / 4 + v / 4) & 15)
                      : (unsigned)((u + 17 * v) & 255);
}

static uint16_t texture_color(unsigned depth, int u, int v) {
    if (depth != 2)
        return palette_color(texture_index(depth, u, v));
    if (u >= 80 && u < 96 && v >= 80 && v < 96)
        return 0x9ce7;
    if (u >= 96 && u < 112 && v >= 64 && v < 80)
        return 0;
    if ((u & 15) == 0 || (v & 15) == 0)
        return 0;
    return (uint16_t)(0x8000 | (u & 31) | ((v & 31) << 5) |
                      (((u >> 5) + 8 * (v >> 5)) & 31) << 10);
}

static void upload_texture(unsigned depth) {
    static uint16_t pixels[256 * 256];
    static uint16_t palette[256];
    unsigned per_word = 4u >> depth;
    unsigned bits = 16u / per_word;
    unsigned width = 256u / per_word;
    RECT extent = {640, 256, (short)width, 256};
    RECT colors = {768, 0, 256, 1};
    memset(pixels, 0, sizeof(pixels));
    for (int v = 0; v < 256; ++v)
        for (unsigned u = 0; u < 256; ++u) {
            unsigned value = depth == 2 ? texture_color(depth, u, v)
                                        : texture_index(depth, u, v);
            pixels[v * width + u / per_word] |= (uint16_t)(value << ((u % per_word) * bits));
        }
    for (unsigned index = 0; index < 256; ++index)
        palette[index] = palette_color(index);
    LoadImage(&extent, (u_long *)pixels);
    LoadImage(&colors, (u_long *)palette);
}

static void triangle(unsigned depth, unsigned mapping, unsigned permutation) {
    static const int x[3] = {0, 64, 0};
    static const int y[3] = {0, 0, 64};
    const Mapping *map = &mappings[mapping];
    const unsigned *order = permutations[permutation];
    short screen_x[3], screen_y[3];
    unsigned char u[3], v[3];
    POLY_FT3 poly = {0};
    for (unsigned index = 0; index < 3; ++index) {
        int dx = x[order[index]], dy = y[order[index]];
        screen_x[index] = (short)(8 + permutation * 80 + dx);
        screen_y[index] = (short)(8 + mapping * 80 + dy);
        u[index] = (unsigned char)(map->u + (map->ux * dx + map->uy * dy) / 4);
        v[index] = (unsigned char)(map->v + (map->vx * dx + map->vy * dy) / 4);
    }
    setPolyFT3(&poly);
    setShadeTex(&poly, 1);
    setXY3(&poly, screen_x[0], screen_y[0], screen_x[1], screen_y[1], screen_x[2], screen_y[2]);
    setUV3(&poly, u[0], v[0], u[1], v[1], u[2], v[2]);
    poly.tpage = getTPage(depth, 0, 640, 256);
    poly.clut = getClut(768, 0);
    submit(&poly);
}

static unsigned check_mapping(unsigned depth, unsigned mapping, int scaled) {
    static uint16_t pixels[480 * 64];
    RECT extent = {8, (short)(8 + mapping * 80), 480, 64};
    const Mapping *map = &mappings[mapping];
    unsigned failures = 0;
    StoreImage(&extent, (u_long *)pixels);
    if (scaled && mapping == 0) {
        assert(pixels[20 * 480 + 20] == texture_color(depth, 84, 84));
        assert(pixels[8 * 480 + 36] == 0x4210);
    }
    for (int y = 4; y < 56; ++y)
        for (int x = 4; x + y < 60; ++x) {
            int u = (map->u * 4 + map->ux * x + map->uy * y + 2) / 4;
            int v = (map->v * 4 + map->vx * x + map->vy * y + 2) / 4;
            uint16_t expected = texture_color(depth, u & 255, v & 255);
            if (!expected)
                expected = 0x4210;
            if (scaled)
                expected = pixels[y * 480 + x];
            for (unsigned permutation = 0; permutation < 6; ++permutation) {
                uint16_t actual = pixels[y * 480 + permutation * 80 + x];
                if (actual != expected) {
                    if (failures < 4)
                        fprintf(stderr, "depth%u mapping%u permutation%u pixel%d,%d: expected%04x got%04x\n",
                                depth, mapping, permutation, x, y, expected, actual);
                    ++failures;
                }
            }
        }
    return failures;
}

static unsigned check_sprite_wrap(unsigned depth) {
    SPRT sprite = {0};
    DR_TPAGE page = {0};
    uint16_t pixels[16 * 16];
    RECT extent = {16, 432, 16, 16};
    unsigned failures = 0;
    setDrawTPage(&page, 0, 0, getTPage(depth, 0, 640, 256));
    submit(&page);
    setSprt(&sprite);
    setShadeTex(&sprite, 1);
    setXY0(&sprite, extent.x, extent.y);
    setWH(&sprite, extent.w, extent.h);
    setUV0(&sprite, 250, 250);
    sprite.clut = getClut(768, 0);
    submit(&sprite);
    StoreImage(&extent, (u_long *)pixels);
    for (int y = 0; y < 16; ++y)
        for (int x = 0; x < 16; ++x) {
            uint16_t expected = texture_color(depth, (250 + x) & 255, (250 + y) & 255);
            if (!expected)
                expected = 0x4210;
            if (pixels[y * 16 + x] != expected)
                ++failures;
        }
    if (failures)
        fprintf(stderr, "depth%u sprite wrap: %u mismatched pixels\n", depth, failures);
    return failures;
}

static void upload_solid(int x, int y, int width, int height, uint16_t value) {
    uint16_t data[256];
    RECT extent = {(short)x, (short)y, (short)width, (short)height};
    assert(width * height <= 256);
    for (int index = 0; index < width * height; ++index)
        data[index] = value;
    LoadImage(&extent, (u_long *)data);
}

typedef struct {
    unsigned depth;
    int page_x, u, v, clut_x, split;
    uint16_t left, right;
} BorderCase;

static unsigned border_sprite(const BorderCase *test) {
    DR_TPAGE page = {0};
    SPRT sprite = {0};
    RECT extent = {520, 432, 16, 4};
    uint16_t data[16 * 4];
    unsigned failures = 0;
    setDrawTPage(&page, 0, 0, getTPage(test->depth, 0, test->page_x, 256));
    submit(&page);
    setSprt(&sprite);
    setShadeTex(&sprite, 1);
    setXY0(&sprite, extent.x, extent.y);
    setWH(&sprite, extent.w, extent.h);
    setUV0(&sprite, test->u, test->v);
    sprite.clut = getClut(test->clut_x, 495);
    submit(&sprite);
    StoreImage(&extent, (u_long *)data);
    for (int y = 0; y < 4; ++y)
        for (int x = 0; x < 16; ++x)
            failures += data[y * 16 + x] != (x < test->split ? test->left : test->right);
    return failures;
}

static unsigned check_vram_wrap(void) {
    static const BorderCase direct = {2, 960, 60, 240, 0, 4, 0x801f, 0xfc00};
    static const BorderCase indexed = {1, 960, 120, 240, 768, 8, 0x83ff, 0xfc1f};
    static const BorderCase palette = {1, 640, 0, 5, 1008, 16, 0x9ce7, 0x9ce7};
    unsigned failures = 0;
    upload_solid(1020, 496, 4, 4, 0x801f);
    upload_solid(0, 496, 12, 4, 0xfc00);
    failures += border_sprite(&direct);
    upload_solid(785, 495, 2, 1, 0x83ff);
    upload_solid(802, 495, 2, 1, 0xfc1f);
    upload_solid(1020, 496, 4, 4, 0x1111);
    upload_solid(0, 496, 4, 4, 0x2222);
    failures += border_sprite(&indexed);
    upload_solid(640, 261, 8, 4, 0x4040);
    upload_solid(48, 495, 2, 1, 0x9ce7);
    failures += border_sprite(&palette);
    if (failures)
        fprintf(stderr, "VRAM page/CLUT wrap: %u mismatched pixels\n", failures);
    return failures;
}

int main(int argc, char **argv) {
    DRAWENV draw;
    DISPENV display;
    RECT clear = {0, 0, 640, 512};
    unsigned failures = 0;
    _set_error_mode(_OUT_TO_STDERR);
    int scaled = argc > 1;
    if (scaled) {
        assert(argc == 2 && strcmp(argv[1], "scaled") == 0);
        assert(Psyz_VideoSetInternalResolution(2) == 0);
    }
    Psyz_VideoSetDitheringMode(PSYZ_DITHER_OFF);
    ResetGraph(0);
    SetDefDrawEnv(&draw, 0, 0, 1024, 512);
    draw.dtd = 0;
    SetDefDispEnv(&display, 0, 0, 320, 240);
    PutDispEnv(&display);
    PutDrawEnv(&draw);
    for (unsigned depth = 0; depth < 3; ++depth) {
        ClearImage(&clear, 128, 128, 128);
        upload_texture(depth);
        for (unsigned mapping = 0; mapping < sizeof(mappings) / sizeof(mappings[0]); ++mapping)
            for (unsigned permutation = 0; permutation < 6; ++permutation)
                triangle(depth, mapping, permutation);
        DrawSync(0);
        for (unsigned mapping = 0; mapping < sizeof(mappings) / sizeof(mappings[0]); ++mapping)
            failures += check_mapping(depth, mapping, scaled);
        failures += check_sprite_wrap(depth);
    }
    failures += check_vram_wrap();
    fprintf(stderr, "Texture-coordinate reference: %u mismatched pixels at%ux\n", failures, scaled ? 2u : 1u);
    assert(failures == 0);
    return 0;
}
