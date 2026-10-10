#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <libgpu.h>
#include <psyz.h>

static void submit(void *primitive)
{
    termPrim((P_TAG *)primitive);
    DrawOTag((OT_TYPE *)primitive);
}

static void draw_color(int x, int y, int red, int green, int blue)
{
    TILE tile = {0};
    setTile(&tile);
    setXY0(&tile, x, y);
    setWH(&tile, 8, 8);
    setRGB0(&tile, red, green, blue);
    submit(&tile);
}

static void copy_sprite(int x, int y, int u, int v, int tpage, int clut)
{
    DR_TPAGE page = {0};
    SPRT sprite = {0};
    setDrawTPage(&page, 0, 0, tpage);
    submit(&page);
    setSprt(&sprite);
    setShadeTex(&sprite, 1);
    setXY0(&sprite, x, y);
    setUV0(&sprite, u, v);
    setWH(&sprite, 8, 8);
    sprite.clut = (unsigned short)clut;
    submit(&sprite);
}

static void copy_polygon(int x, int gouraud)
{
    if (gouraud)
    {
        POLY_GT4 poly = {0};
        setPolyGT4(&poly);
        setShadeTex(&poly, 1);
        setXY4(&poly, x, 20, x + 8, 20, x, 28, x + 8, 28);
        setUV4(&poly, 16, 16, 24, 16, 16, 24, 24, 24);
        poly.tpage = getTPage(2, 0, 0, 0);
        submit(&poly);
    }
    else
    {
        POLY_FT4 poly = {0};
        setPolyFT4(&poly);
        setShadeTex(&poly, 1);
        setXY4(&poly, x, 20, x + 8, 20, x, 28, x + 8, 28);
        setUV4(&poly, 16, 16, 24, 16, 16, 24, 24, 24);
        poly.tpage = getTPage(2, 0, 0, 0);
        submit(&poly);
    }
}

static void check_pixel(int x, int y, unsigned short expected)
{
    RECT rect = {(short)x, (short)y, 2, 1};
    u_long pixels = 0;
    StoreImage(&rect, &pixels);
    assert((pixels & 0x7fff) == expected);
}

int main(void)
{
    DRAWENV draw;
    DISPENV display;
    RECT clear = {0, 0, 1023, 511};
    RECT indices_rect = {640, 256, 2, 8};
    u_long indices[8];
    for (unsigned int i = 0; i < sizeof(indices) / sizeof(indices[0]); ++i)
        indices[i] = 0x11111111;
    Psyz_VideoSetDitheringMode(PSYZ_DITHER_OFF);
    ResetGraph(0);
    SetDefDrawEnv(&draw, 0, 0, 1024, 512);
    draw.dtd = 0;
    SetDefDispEnv(&display, 0, 0, 320, 240);
    PutDispEnv(&display);
    PutDrawEnv(&draw);
    ClearImage(&clear, 0, 0, 0);
    LoadImage(&indices_rect, indices);
    DrawSync(0);

    draw_color(16, 16, 255, 0, 0);
    copy_sprite(80, 20, 16, 16, getTPage(2, 0, 0, 0), 0);
    copy_sprite(120, 20, 80, 20, getTPage(2, 0, 0, 0), 0);
    draw_color(16, 16, 0, 0, 255);
    copy_polygon(160, 0);
    draw_color(16, 16, 0, 255, 0);
    copy_polygon(200, 1);
    draw_color(513, 300, 0, 255, 0);
    copy_sprite(240, 20, 0, 0, getTPage(0, 0, 640, 256), getClut(512, 300));
    assert(BreakDraw() == NULL);

    check_pixel(82, 22, 0x001f);
    check_pixel(122, 22, 0x001f);
    check_pixel(162, 22, 0x7c00);
    check_pixel(202, 22, 0x03e0);
    check_pixel(242, 22, 0x03e0);
    puts("Framebuffer sprite chains, textured polygons, and palette feedback passed.");
    return 0;
}
