#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libgpu.h>
#include <libetc.h>
#include <psyz.h>

enum { GRID_WIDTH = 256, GRID_HEIGHT = 80, TILE_COUNT = 20000 };
static const unsigned short colors[] = {0x001f, 0x03e0, 0x7c00, 0x7fff};

static void submit(void *primitive)
{
    termPrim((P_TAG *)primitive);
    DrawOTag((OT_TYPE *)primitive);
}

static unsigned short color_for(int index, int phase)
{
    return colors[(index / 257 + index * 3 + phase) & 3];
}

static void flush_batch(void)
{
    DR_OFFSET offset = {0};
    setlen(&offset, 1);
    offset.code[0] = 0xe5000000;
    submit(&offset);
}

static void draw_grid(int phase)
{
    for (int i = 0; i < TILE_COUNT; ++i) {
        unsigned short color = color_for(i, phase);
        TILE_1 tile = {0};
        setTile1(&tile);
        setXY0(&tile, 16 + i % GRID_WIDTH, 16 + i / GRID_WIDTH);
        setRGB0(&tile, (color & 31) * 8, ((color >> 5) & 31) * 8,
                ((color >> 10) & 31) * 8);
        submit(&tile);
        if ((i & 255) == 255)
            flush_batch();
        if ((i + 1) % 4000 == 0) {
            int patch = (i + 1) / 4000 - 1;
            RECT clear = {16, (short)(16 + patch), 16, 1};
            color = colors[(patch + phase + 1) & 3];
            ClearImage(&clear, (color & 31) * 8, ((color >> 5) & 31) * 8,
                       ((color >> 10) & 31) * 8);
        }
    }
    flush_batch();
}

static void verify_grid(int phase)
{
    RECT area = {16, 16, GRID_WIDTH, GRID_HEIGHT};
    u_long packed[GRID_WIDTH * GRID_HEIGHT / 2];
    StoreImage(&area, packed);
    for (int i = 0; i < GRID_WIDTH * GRID_HEIGHT; ++i) {
        unsigned short expected = i < TILE_COUNT ? color_for(i, phase) : 0;
        if (i / GRID_WIDTH < 5 && i % GRID_WIDTH < 16)
            expected = colors[(i / GRID_WIDTH + phase + 1) & 3];
        unsigned short actual = (unsigned short)(packed[i / 2] >> ((i & 1) * 16));
        if (actual != expected)
            fprintf(stderr, "phase=%d pixel=%d expected=%04x actual=%04x\n",
                    phase, i, expected, actual);
        assert(actual == expected);
    }
}

int main(int argc, char **argv)
{
    _set_error_mode(_OUT_TO_STDERR);
    if (argc > 1) {
        assert(argc == 2 && strcmp(argv[1], "scaled") == 0);
        assert(Psyz_VideoSetInternalResolution(2) == 0);
    }
    Psyz_VideoSetDitheringMode(PSYZ_DITHER_OFF);
    ResetGraph(0);
    DRAWENV draw;
    DISPENV display;
    SetDefDrawEnv(&draw, 0, 0, 1024, 512);
    draw.dtd = 0;
    SetDefDispEnv(&display, 0, 0, 320, 240);
    PutDispEnv(&display);
    PutDrawEnv(&draw);
    DrawSync(0);
    for (int phase = 0; phase < 2; ++phase) {
        RECT clear = {0, 0, 1023, 511};
        ClearImage(&clear, 0, 0, 0);
        draw_grid(phase);
        verify_grid(phase);
        VSync(0);
    }
    puts("GPU upload arena wrap, interleaved clears and next-frame reuse passed.");
    return 0;
}
