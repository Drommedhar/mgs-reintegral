#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libgpu.h>
#include <psyz.h>

static void submit(void *primitive)
{
    termPrim((P_TAG *)primitive);
    DrawOTag((OT_TYPE *)primitive);
}

static void draw_area(int buffer, int origin, int left, int width)
{
    DRAWENV environment;
    SetDefDrawEnv(&environment, buffer + left, 0, width, 224);
    environment.ofs[0] = (short)(buffer + origin);
    environment.ofs[1] = 0;
    environment.dtd = 0;
    PutDrawEnv(&environment);
}

static void tile(int x, int y, int width, int height, int red, int green, int blue, int semi)
{
    TILE primitive = {0};
    setTile(&primitive);
    setSemiTrans(&primitive, semi);
    setXY0(&primitive, x, y);
    setWH(&primitive, width, height);
    setRGB0(&primitive, red, green, blue);
    submit(&primitive);
}

static unsigned short read_pixel(int x, int y)
{
    RECT area = {(short)x, (short)y, 2, 1};
    u_long data = 0;
    StoreImage(&area, &data);
    return (unsigned short)data;
}

static void pixel(int x, int y, unsigned short expected)
{
    unsigned short data = read_pixel(x, y);
    if (data != expected)
        fprintf(stderr, "widescreen pixel (%d,%d): expected %04x, got %04lx\n",
                x, y, expected, (unsigned long)data);
    assert(data == expected);
}

static void clear_frame(int buffer)
{
    RECT area = {(short)buffer, 0, 320, 224};
    assert(Psyz_GpuSetFrameTransform(1, 1, 0, 0) == 0);
    draw_area(buffer, 0, 0, 320);
    ClearImage(&area, 0, 0, 0);
}

static void check_world(int buffer, int origin)
{
    clear_frame(buffer);
    draw_area(buffer, origin, 0, 320);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 0) == 0);
    tile(-40-origin, 32, 8, 8, 248, 0, 0, 0);
    tile(0-origin, 32, 8, 8, 0, 248, 0, 0);
    for (int x = 8; x < 18; ++x)
        pixel(buffer+x, 34, x >= 10 && x < 16 ? 0x001f : 0);
    pixel(buffer+42, 34, 0x03e0);
    pixel(buffer+48, 34, 0);
}

static void check_hud_clip_and_restore(int buffer)
{
    clear_frame(buffer);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 0) == 0);
    tile(-40, 32, 8, 8, 248, 0, 0, 0);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 1) == 0);
    draw_area(buffer, 0, 20, 10);
    tile(0, 32, 64, 8, 0, 248, 0, 0);
    assert(Psyz_GpuSetFrameTransform(1, 1, 0, 0) == 0);
    draw_area(buffer, 0, 0, 320);
    tile(100, 32, 8, 8, 0, 0, 248, 0);
    pixel(buffer+12, 34, 0x001f);
    for (int x = 53; x < 65; ++x)
        pixel(buffer+x, 34, x >= 55 && x < 63 ? 0x03e0 : 0);
    pixel(buffer+102, 34, 0x7c00);
    pixel(buffer+115, 34, 0);
}

static void full_frame(int polygon, int semi)
{
    if (!polygon)
    {
        tile(0, 0, 320, 224, 0, 0, semi ? 64 : 128, semi);
        return;
    }
    POLY_F4 primitive = {0};
    setPolyF4(&primitive);
    setSemiTrans(&primitive, semi);
    setRGB0(&primitive, 0, 0, semi ? 64 : 128);
    setXY4(&primitive, 0, 0, 320, 0, 0, 224, 320, 224);
    submit(&primitive);
}

static void check_full_frame(int buffer, int polygon)
{
    clear_frame(buffer);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 1) == 0);
    full_frame(polygon, 0);
    pixel(buffer+2, 100, 0x4000);
    pixel(buffer+160, 100, 0x4000);
    pixel(buffer+317, 100, 0x4000);
    DR_TPAGE mode = {0};
    setDrawTPage(&mode, 0, 0, getTPage(2, 2, 0, 0));
    submit(&mode);
    full_frame(polygon, 1);
    pixel(buffer+2, 100, 0x2000);
    pixel(buffer+160, 100, 0x2000);
    pixel(buffer+317, 100, 0x2000);
    tile(0, 32, 16, 8, 0, 248, 0, 0);
    pixel(buffer+44, 34, 0x03e0);
    pixel(buffer+4, 34, 0x2000);
}

static void check_world_screen_tiles(int buffer, int origin)
{
    clear_frame(buffer);
    DRAWENV environment;
    SetDefDrawEnv(&environment, buffer, 16, 320, 192);
    environment.ofs[0] = (short)(buffer + origin);
    environment.ofs[1] = 112;
    environment.dtd = 0;
    PutDrawEnv(&environment);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 0) == 0);
    tile(-origin, -112, 320, 224, 0, 0, 128, 0);
    DR_TPAGE mode = {0};
    setDrawTPage(&mode, 0, 1, getTPage(0, 1, 0, 0));
    submit(&mode);
    tile(-origin, -112, 320, 224, 64, 16, 0, 1);
    for (int x = 2; x <= 318; x += 158) {
        pixel(buffer + x, 100, 0x4048);
        pixel(buffer + x, 14, 0);
        pixel(buffer + x, 210, 0);
    }
    tile(-origin, -80, 320, 1, 0, 0, 0, 0);
    pixel(buffer + 2, 32, 0);
    pixel(buffer + 317, 32, 0);
    pixel(buffer + 2, 33, 0x4048);
    tile(-origin, -64, 16, 8, 0, 248, 0, 0);
    pixel(buffer + 44, 50, 0x03e0);
    pixel(buffer + 4, 50, 0x4048);
    tile(-origin, 16, 319, 8, 0, 0, 0, 0);
    pixel(buffer + 160, 130, 0);
    pixel(buffer + 4, 130, 0x4048);
}

static void check_world_polygon_and_partial_area(int buffer)
{
    clear_frame(buffer);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 0) == 0);
    full_frame(1, 0);
    pixel(buffer + 2, 100, 0);
    pixel(buffer + 160, 100, 0x4000);
    pixel(buffer + 317, 100, 0);
    draw_area(buffer, 0, 0, 300);
    tile(0, 32, 320, 8, 0, 248, 0, 0);
    pixel(buffer + 2, 34, 0);
    pixel(buffer + 44, 34, 0x03e0);
    pixel(buffer + 290, 34, 0);
}

static void flat_band(int polygon, int y, int height, int blue, int semi)
{
    if (!polygon) {
        tile(0, y, 320, height, 0, 0, blue, semi);
        return;
    }
    POLY_F4 band = {0};
    setPolyF4(&band);
    setSemiTrans(&band, semi);
    setRGB0(&band, 0, 0, blue);
    setXY4(&band, 0, y, 320, y, 0, y + height, 320, y + height);
    submit(&band);
}

static void check_bands(int buffer, int polygon)
{
    clear_frame(buffer);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 1) == 0);
    full_frame(polygon, 0);
    flat_band(polygon, -8, 16, 0, 0);
    pixel(buffer + 2, 4, 0);
    pixel(buffer + 2, 12, 0x4000);
    flat_band(polygon, 0, 24, 0, 0);
    flat_band(polygon, 184, 40, 0, 0);
    DR_TPAGE mode = {0};
    setDrawTPage(&mode, 0, 0, getTPage(2, 2, 0, 0));
    submit(&mode);
    flat_band(polygon, 96, 16, 64, 1);
    for (int x = 2; x <= 318; x += 158) {
        pixel(buffer + x, 12, 0);
        pixel(buffer + x, 200, 0);
        pixel(buffer + x, 80, 0x4000);
        pixel(buffer + x, 104, 0x2000);
    }
    tile(0, 40, 16, 8, 0, 248, 0, 0);
    pixel(buffer + 44, 42, 0x03e0);
    pixel(buffer + 4, 42, 0x4000);
}

static void check_gradient_bands(int buffer)
{
    clear_frame(buffer);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 1) == 0);
    POLY_G4 band = {0};
    setPolyG4(&band);
    setXY4(&band, 0, 32, 320, 32, 0, 64, 320, 64);
    setRGB0(&band, 248, 0, 0);
    setRGB1(&band, 248, 0, 0);
    setRGB2(&band, 0, 0, 0);
    setRGB3(&band, 0, 0, 0);
    submit(&band);
    unsigned short upper = read_pixel(buffer + 160, 40);
    unsigned short lower = read_pixel(buffer + 160, 56);
    assert(upper > lower && lower > 0);
    pixel(buffer + 2, 40, upper);
    pixel(buffer + 317, 40, upper);
    pixel(buffer + 2, 56, lower);
    pixel(buffer + 317, 56, lower);
    pixel(buffer + 2, 30, 0);
    setXY4(&band, 0, 96, 320, 96, 0, 128, 320, 128);
    setRGB1(&band, 0, 0, 0);
    setRGB2(&band, 248, 0, 0);
    submit(&band);
    pixel(buffer + 2, 104, 0);
    assert(read_pixel(buffer + 160, 104) > 0);
}

static void copy_framebuffer_half(int sprite, int x, int page, int u)
{
    if (sprite) {
        DR_TPAGE mode = {0};
        setDrawTPage(&mode, 0, 0, getTPage(2, 0, page, 256));
        submit(&mode);
        SPRT copy = {0};
        setSprt(&copy);
        setShadeTex(&copy, 1);
        setXY0(&copy, x, 32);
        setWH(&copy, 160, 64);
        setUV0(&copy, u, 0);
        submit(&copy);
        return;
    }
    POLY_FT4 copy = {0};
    setPolyFT4(&copy);
    setShadeTex(&copy, 1);
    setXY4(&copy, x, 32, x + 160, 32, x, 96, x + 160, 96);
    setUV4(&copy, u, 0, u + 160, 0, u, 64, u + 160, 64);
    copy.tpage = getTPage(2, 0, page, 256);
    submit(&copy);
}

static void check_framebuffer_copy(int buffer, int sprite)
{
    clear_frame(buffer);
    DRAWENV source;
    SetDefDrawEnv(&source, 640, 256, 320, 64);
    source.dtd = 0;
    PutDrawEnv(&source);
    tile(0, 0, 160, 64, 248, 0, 0, 0);
    tile(160, 0, 160, 64, 0, 248, 0, 0);
    draw_area(buffer, 0, 0, 320);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 1) == 0);
    assert(Psyz_GpuSetFrameTransform(1, 1, 0, 0) == 0);
    copy_framebuffer_half(sprite, 0, 640, 0);
    copy_framebuffer_half(sprite, 160, 768, 32);
    pixel(buffer + 2, 40, 0x001f);
    pixel(buffer + 150, 40, 0x001f);
    pixel(buffer + 170, 40, 0x03e0);
    pixel(buffer + 317, 40, 0x03e0);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 0) == 0);
    tile(-40, 112, 8, 8, 248, 0, 0, 0);
    pixel(buffer + 12, 114, 0x001f);
    assert(Psyz_GpuSetFrameTransform(3, 4, buffer + 160, 1) == 0);
    tile(0, 128, 16, 8, 0, 0, 248, 0);
    pixel(buffer + 44, 130, 0x7c00);
    pixel(buffer + 4, 130, 0);
}

static void check_grid_and_transfers(void)
{
    clear_frame(0);
    assert(Psyz_GpuSetHorizontalGrid(2, 1) == 0);
    assert(Psyz_GpuSetFrameTransform(3, 4, 160, 0) == 0);
    tile(80, 80, 32, 8, 248, 0, 0, 0);
    pixel(72, 82, 0x001f);
    pixel(83, 82, 0);
    RECT transfer = {900, 300, 2, 1};
    u_long colors = 0x03e0801f;
    LoadImage(&transfer, &colors);
    pixel(900, 300, 0x801f);
    pixel(901, 300, 0x03e0);
    assert(Psyz_GpuSetHorizontalGrid(1, 1) == 0);
    assert(Psyz_GpuSetFrameTransform(1, 1, 0, 0) == 0);
    DRAWENV offscreen;
    SetDefDrawEnv(&offscreen, 800, 300, 32, 32);
    PutDrawEnv(&offscreen);
    tile(4, 4, 8, 8, 0, 248, 0, 0);
    pixel(806, 306, 0x03e0);
}

int main(int argc, char **argv)
{
#ifdef _WIN32
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif
    int scale = argc == 1 ? 1 : strcmp(argv[1], "scaled") == 0 ? 2 :
                strcmp(argv[1], "8x") == 0 ? 8 : 0;
    assert(argc <= 2 && scale != 0);
    assert(Psyz_VideoConfigureWindow(800, 450, 0) == 0);
    assert(Psyz_VideoSetPresentation(16, 9, 224) == 0);
    assert(Psyz_VideoSetInternalResolution(scale) == 0);
    Psyz_VideoSetDitheringMode(PSYZ_DITHER_OFF);
    ResetGraph(0);
    DISPENV display;
    SetDefDispEnv(&display, 0, 0, 320, 240);
    PutDispEnv(&display);
    SetDispMask(1);
    DrawSync(0);
    for (int buffer = 0; buffer <= 320; buffer += 320)
    {
        check_world(buffer, 0);
        check_world(buffer, 160);
        check_hud_clip_and_restore(buffer);
        check_full_frame(buffer, 0);
        check_full_frame(buffer, 1);
        check_world_screen_tiles(buffer, 0);
        check_world_screen_tiles(buffer, 160);
        check_world_polygon_and_partial_area(buffer);
        check_bands(buffer, 0);
        check_bands(buffer, 1);
        check_gradient_bands(buffer);
        check_framebuffer_copy(buffer, 0);
        check_framebuffer_copy(buffer, 1);
    }
    check_grid_and_transfers();
    printf("Widescreen GPU %dx: wider world, HUD clipping, both buffers, fades and raw transfers passed\n",
           scale);
    return 0;
}
