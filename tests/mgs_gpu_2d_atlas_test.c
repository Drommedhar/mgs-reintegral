#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libgpu.h>
#include <psyz.h>

static int scale;
static unsigned comparisons;
static const char *phase;

static void submit(void *primitive)
{
    termPrim((P_TAG *)primitive);
    DrawOTag((OT_TYPE *)primitive);
}

static unsigned atlas_index(int x, int y)
{
    return 1u + (unsigned)((x / 3 + y / 5) & 1);
}

static void upload_half(int page, int half)
{
    uint16_t pixels[64 * 256];
    RECT rect = {(short)page, 256, 64, 256};
    for (int y = 0; y < 256; ++y)
        for (int word = 0; word < 64; ++word)
        {
            unsigned value = 0;
            for (int nibble = 0; nibble < 4; ++nibble)
            {
                int u = word * 4 + nibble;
                unsigned index = 15;
                if (u >= 64 && u < 224 && y < 224)
                    index = atlas_index(half * 160 + u - 64, y);
                value |= index << (4 * nibble);
            }
            pixels[y * 64 + word] = (uint16_t)value;
        }
    LoadImage(&rect, (u_long *)pixels);
}

static void quad(RECT screen, int u, int v, int page, int gouraud)
{
    if (gouraud)
    {
        POLY_GT4 poly = {0};
        setPolyGT4(&poly);
        setShadeTex(&poly, 1);
        setXYWH(&poly, screen.x, screen.y, screen.w, screen.h);
        setUVWH(&poly, u, v, screen.w, screen.h);
        poly.tpage = getTPage(0, 0, page, 256);
        poly.clut = getClut(960, 480);
        submit(&poly);
    }
    else
    {
        POLY_FT4 poly = {0};
        setPolyFT4(&poly);
        setShadeTex(&poly, 1);
        setXYWH(&poly, screen.x, screen.y, screen.w, screen.h);
        setUVWH(&poly, u, v, screen.w, screen.h);
        poly.tpage = getTPage(0, 0, page, 256);
        poly.clut = getClut(960, 480);
        submit(&poly);
    }
}

static unsigned char *capture(void)
{
    int width, height;
    unsigned char *pixels = Psyz_VideoAllocPresentedFrame(&width, &height);
    assert(pixels && width == 320 * scale && height == 224 * scale);
    return pixels;
}

static void pixel(const unsigned char *pixels, int x, int y, unsigned index)
{
    const unsigned char *actual = pixels + ((size_t)y * 320 * scale + x) * 3;
    unsigned red = index == 1 ? 255 : 0;
    unsigned green = index == 2 ? 255 : 0;
    if (actual[0] != red || actual[1] != green || actual[2] != 0)
    {
        fprintf(stderr, "2D atlas %dx %s at %d,%d: expected index%u, got RGB%u,%u,%u\n",
                scale, phase, x, y, index, actual[0], actual[1], actual[2]);
        exit(EXIT_FAILURE);
    }
    ++comparisons;
}

static void check_logo(void)
{
    phase = "paired halves";
    assert(Psyz_GpuSetTextureAlignment(0) == 0);
    quad((RECT){0, 0, 160, 224}, 64, 0, 640, 0);
    unsigned char *legacy = capture();
    const unsigned char *edge = legacy + ((size_t)(4 * scale) * 320 * scale + 160 * scale - 1) * 3;
    if (scale > 1)
        assert(edge[0] == 255 && edge[1] == 0 && edge[2] == 255);
    else
        pixel(legacy, 159, 4, atlas_index(159, 4));
    free(legacy);
    assert(Psyz_GpuSetTextureAlignment(1) == 0);
    quad((RECT){0, 0, 160, 224}, 64, 0, 640, 0);
    quad((RECT){160, 0, 160, 224}, 64, 0, 768, 1);
    unsigned char *pixels = capture();
    for (int y = scale; y < 224 * scale; ++y)
        for (int x = scale; x < 320 * scale; ++x)
            pixel(pixels, x, y, atlas_index(x / scale, y / scale));
    free(pixels);
}

static void check_hud(void)
{
    phase = "HUD";
    RECT background = {0, 0, 320, 224};
    ClearImage(&background, 0, 0, 64);
    quad((RECT){96, 96, 16, 8}, 192, 32, 640, 0);
    unsigned char *pixels = capture();
    for (int y = 0; y < 8 * scale; ++y)
        for (int x = 0; x < 16 * scale; ++x)
            pixel(pixels, 96 * scale + x, 96 * scale + y,
                  atlas_index(128 + x / scale, 32 + y / scale));
    free(pixels);
}

static unsigned char *draw_world(void)
{
    assert(Psyz_GpuSetTextureAlignment(0) == 0);
    RECT background = {0, 0, 320, 224};
    ClearImage(&background, 0, 0, 64);
    POLY_FT3 poly = {0};
    setPolyFT3(&poly);
    setShadeTex(&poly, 1);
    setXY3(&poly, 16, 16, 64, 16, 16, 64);
    setUV3(&poly, 64, 0, 112, 0, 64, 48);
    poly.tpage = getTPage(0, 0, 640, 256);
    poly.clut = getClut(960, 480);
    submit(&poly);
    return capture();
}

static void check_world_control(const unsigned char *baseline)
{
    phase = "3D control";
    unsigned char *pixels = draw_world();
    size_t count = (size_t)320 * 224 * scale * scale;
    assert(memcmp(pixels, baseline, count * 3) == 0);
    comparisons += (unsigned)count;
    for (int y = 4 * scale; y < 20 * scale; ++y)
        for (int x = 4 * scale; x < 20 * scale; ++x)
        {
            /* At exact texel ties, interpolation precision can select either neighbor. */
            if ((2 * x + scale) % (2 * scale) == 0 ||
                (2 * y + scale) % (2 * scale) == 0)
                continue;
            pixel(pixels, 16 * scale + x, 16 * scale + y,
                  atlas_index((2 * x + scale) / (2 * scale),
                              (2 * y + scale) / (2 * scale)));
        }
    free(pixels);
}

static unsigned panorama_edges(int aligned)
{
    assert(Psyz_GpuSetTextureAlignment(aligned) == 0);
    assert(Psyz_GpuSetFrameTransform(3, 4, 160, 0) == 0);
    for (int y = -16; y < 224; y += 32)
        for (int x = -64; x < 384; x += 32)
            quad((RECT){(short)x, (short)y, 32, 32}, 192, 192, 640, 0);
    unsigned char *pixels = capture();
    unsigned seams = 0;
    for (int y = scale; y < 223 * scale; ++y)
        for (int x = scale; x < 319 * scale; ++x) {
            const unsigned char *p = pixels + ((size_t)y * 320 * scale + x) * 3;
            seams += p[2] != 0 || (p[0] == 0 && p[1] == 0);
            ++comparisons;
        }
    free(pixels);
    assert(Psyz_GpuSetFrameTransform(1, 1, 0, 0) == 0);
    return seams;
}

static void check_panorama(void)
{
    unsigned original = panorama_edges(0);
    if (scale > 1) assert(original > 0);
    unsigned corrected = panorama_edges(1);
    if (corrected)
        fprintf(stderr, "Panorama %dx: %u pixels sampled outside their tiles\n", scale, corrected);
    assert(corrected == 0);
}

int main(int argc, char **argv)
{
#ifdef _WIN32
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif
    assert(argc == 2);
    scale = !strcmp(argv[1], "1") ? 1 : !strcmp(argv[1], "2") ? 2 : 8;
    assert(scale != 8 || !strcmp(argv[1], "8"));
    assert(Psyz_VideoConfigureWindow(320 * scale, 224 * scale, 0) == 0);
    assert(Psyz_VideoSetPresentation(320, 224, 224) == 0);
    assert(Psyz_VideoSetInternalResolution((unsigned)scale) == 0);
    ResetGraph(0);
    Psyz_VideoSetDitheringMode(PSYZ_DITHER_OFF);
    DRAWENV draw;
    DISPENV display;
    SetDefDrawEnv(&draw, 0, 0, 320, 224);
    draw.dtd = 0;
    SetDefDispEnv(&display, 0, 0, 320, 240);
    PutDispEnv(&display);
    PutDrawEnv(&draw);
    SetDispMask(1);
    DrawSync(0);
    uint16_t palette[16] = {0};
    palette[1] = 0x001f;
    palette[2] = 0x03e0;
    palette[15] = 0x7c1f;
    RECT colors = {960, 480, 16, 1};
    LoadImage(&colors, (u_long *)palette);
    upload_half(640, 0);
    upload_half(768, 1);
    unsigned char *world = draw_world();
    check_logo();
    check_hud();
    check_world_control(world);
    check_panorama();
    free(world);
    printf("Indexed 2D atlas %dx: %u pixels, logo/HUD/world/panorama passed\n",
           scale, comparisons);
    return 0;
}
