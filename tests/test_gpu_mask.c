#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libgpu.h>
#include <psyz.h>

#include "gpu_extent_cases.h"

static void submit(void *primitive)
{
    termPrim((P_TAG *)primitive);
    DrawOTag((OT_TYPE *)primitive);
}

static void mask(int mode)
{
    DR_STP command = {0};
    setlen(&command, 1);
    command.code[0] = 0xe6000000u | (unsigned int)mode;
    submit(&command);
}

static void tile(int x, int y, int red, int semi)
{
    TILE primitive = {0};
    setTile(&primitive);
    setSemiTrans(&primitive, semi);
    setXY0(&primitive, x, y);
    setWH(&primitive, 8, 8);
    setRGB0(&primitive, red, 0, 0);
    submit(&primitive);
}

static void pixel(int x, int y, unsigned short expected)
{
    RECT   rect = {(short)x, (short)y, 2, 1};
    u_long data = 0;
    StoreImage(&rect, &data);
    if ((data & 0xffff) != expected)
        fprintf(stderr, "pixel %d,%d: expected %04x, got %04lx\n", x, y, expected, data & 0xffff);
    assert((data & 0xffff) == expected);
}

static void upload(int x, int y, unsigned short color)
{
    RECT   rect = {(short)x, (short)y, 2, 1};
    u_long data = (u_long)color | (u_long)color << 16;
    LoadImage(&rect, &data);
}

static void check_draw_modes(void)
{
    for (int mode = 0; mode < 4; ++mode)
    {
        int x = 32 + mode * 16;
        mask(0);
        upload(x, 32, 0x8010);
        upload(x + 2, 32, 0x0010);
        mask(mode);
        tile(x, 32, 248, 0);
        pixel(x, 32, mode & 2 ? 0x8010 : mode & 1 ? 0x801f : 0x001f);
        pixel(x + 2, 32, mode & 1 ? 0x801f : 0x001f);
    }
    mask(3);
    tile(128, 32, 64, 0);
    tile(128, 32, 248, 0);
    pixel(128, 32, 0x8008);
    mask(0);
    tile(128, 32, 248, 0);
    pixel(128, 32, 0x001f);
}

static void check_transfers(void)
{
    for (int mode = 0; mode < 4; ++mode)
    {
        int x = 32 + mode * 16;
        mask(0);
        upload(x, 64, 0x8010);
        upload(x + 2, 64, 0x0010);
        upload(256, 64, 0x001f);
        mask(mode);
        upload(x, 64, 0x03e0);
        upload(x + 2, 64, 0x03e0);
        pixel(x, 64, mode & 2 ? 0x8010 : mode & 1 ? 0x83e0 : 0x03e0);
        pixel(x + 2, 64, mode & 1 ? 0x83e0 : 0x03e0);
        RECT source = {256, 64, 2, 1};
        MoveImage(&source, x, 64);
        pixel(x, 64, mode & 2 ? 0x8010 : mode & 1 ? 0x801f : 0x001f);
    }
    mask(3);
    DR_ENV fill = {0};
    setlen(&fill, 3);
    fill.code[0] = 0x020000f8;
    fill.code[1] = 32u | 64u << 16;
    fill.code[2] = 64u | 1u << 16;
    submit(&fill);
    pixel(32, 64, 0x001f);
    tile(160, 64, 64, 0);
    pixel(160, 64, 0x8008);
    mask(0);
    upload(192, 64, 0x001f);
    mask(1);
    RECT same = {192, 64, 2, 1};
    MoveImage(&same, same.x, same.y);
    pixel(192, 64, 0x801f);
}

static void check_textures_and_blending(void)
{
    mask(0);
    upload(256, 96, 0x8008);
    upload(258, 96, 0x0008);
    upload(260, 96, 0x0000);
    for (int abr = 0; abr < 4; ++abr)
    {
        int      x = 32 + abr * 16;
        DR_TPAGE page = {0};
        setDrawTPage(&page, 0, 0, getTPage(2, abr, 256, 0));
        submit(&page);
        tile(x, 96, 128, 0);
        SPRT sprite = {0};
        setSprt(&sprite);
        setShadeTex(&sprite, 1);
        setSemiTrans(&sprite, 1);
        setXY0(&sprite, x, 96);
        setUV0(&sprite, 0, 96);
        setWH(&sprite, 6, 1);
        submit(&sprite);
        static const unsigned short results[] = {0x800c, 0x8018, 0x8008, 0x8012};
        pixel(x, 96, results[abr]);
        pixel(x + 2, 96, 0x0008);
        pixel(x + 4, 96, 0x0010);
    }
    DR_TPAGE page = {0};
    setDrawTPage(&page, 0, 0, getTPage(2, 1, 0, 0));
    submit(&page);
    tile(128, 96, 64, 0);
    tile(128, 96, 64, 1);
    tile(128, 96, 64, 1);
    pixel(128, 96, 0x0018);
}

static void raw_primitive(u_long *words, int count)
{
    DR_ENV primitive = {0};
    assert(count <= 5);
    memcpy(primitive.code, words, count * sizeof(*words));
    setlen(&primitive, count);
    submit(&primitive);
}

static void clear_extent_area(void)
{
    RECT area = {0, 0, 512, 512};
    mask(0);
    ClearImage(&area, 0, 0, 0);
}

int main(int argc, char **argv)
{
    _set_error_mode(_OUT_TO_STDERR);
    DRAWENV draw;
    DISPENV display;
    RECT    clear = {0, 0, 1023, 511};
    if (argc > 1)
    {
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
    ClearImage(&clear, 0, 0, 0);
    check_draw_modes();
    check_transfers();
    check_textures_and_blending();
    check_extent_cases(raw_primitive, clear_extent_area, pixel);
    puts("GPU masks, transfer protection, texture bit15 and ordered blending passed");
    return 0;
}
