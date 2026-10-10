#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libgpu.h>
#include <psyz.h>
typedef RECT PS1_RECT;
#include "platform/rasterizer.h"

enum { WIDTH = 64, HEIGHT = 64 };
typedef struct { short x, y; } Point;

static int software, failures, comparisons;
static u_long pixels[WIDTH * HEIGHT / 2];

static void packet(u_long *words, int count)
{
    if (software)
    {
        assert(software_rasterizer.push_prim(words, count) == count);
        return;
    }
    DR_ENV primitive = {0};
    assert(count <= 5);
    memcpy(primitive.code, words, count * sizeof(*words));
    setlen(&primitive, count);
    termPrim(&primitive);
    DrawOTag((OT_TYPE *)&primitive);
}

static void clear(void)
{
    RECT area = {0, 0, WIDTH, HEIGHT};
    if (software)
    {
        PS1_RECT rectangle = {0, 0, WIDTH, HEIGHT};
        software_rasterizer.clear_image(&rectangle, 0, 0, 0);
    }
    else
        ClearImage(&area, 0, 0, 0);
}

static void read_pixels(void)
{
    if (software)
    {
        PS1_RECT rectangle = {0, 0, WIDTH, HEIGHT};
        software_rasterizer.store_image(&rectangle, pixels);
    }
    else
    {
        RECT area = {0, 0, WIDTH, HEIGHT};
        StoreImage(&area, pixels);
    }
}

static void offset(int x, int y)
{
    u_long command = 0xe5000000u | ((unsigned)x & 0x7ffu) | (((unsigned)y & 0x7ffu) << 11);
    if (software)
        software_rasterizer.offset(x, y);
    else
        packet(&command, 1);
}

static u_long xy(Point point)
{
    return (u_short)point.x | (u_long)(u_short)point.y << 16;
}

static void polygon(const Point *points, int count, int semi)
{
    u_long words[5] = {0};
    words[0] = (count == 4 ? 0x28000000u : 0x20000000u) | 64u | (semi ? 0x02000000u : 0);
    for (int index = 0; index < count; ++index)
        words[index + 1] = xy(points[index]);
    packet(words, count + 1);
}

static void expect_pixel(const char *name, int x, int y, unsigned short expected)
{
    unsigned short actual = ((const unsigned short *)pixels)[y * WIDTH + x];
    ++comparisons;
    if (actual == expected)
        return;
    if (failures < 12)
        fprintf(stderr, "%s pixel (%d,%d): expected %04x, got %04x\n", name, x, y, expected, actual);
    ++failures;
}

static int triangle_contains(int shape, int x, int y)
{
    if (shape == 0)
        return x >= 8 && y >= 8 && x+y < 32;
    if (shape == 1)
        return y > 8 && y < 24 && 2*x >= 40-y && 2*x < 24+y;
    if (shape == 2)
        return x >= 8 && y >= 8 && 17*(x-8) + 21*(y-8) < 357;
    if (shape == 3)
        return y >= 8 && y < 25 && x < 29 && 17*(x-8) >= 21*(y-8);
    return x == 17 && y > 8 && y < 27;
}

static void check_triangle(int shifted, int shape)
{
    static const unsigned char permutations[6][3] = {{0,1,2},{0,2,1},{1,0,2},{1,2,0},{2,0,1},{2,1,0}};
    static const Point shapes[5][3] = {
        {{8,8},{24,8},{8,24}}, {{16,8},{24,24},{8,24}},
        {{8,8},{29,8},{8,25}}, {{8,8},{29,8},{29,25}},
        {{17,8},{18,27},{16,27}}
    };
    static const char *names[5] = {"right triangle", "thin triangle", "21:17 slope", "17:21 slope", "sliver"};
    int dx = shifted ? 19 : 0, dy = shifted ? 21 : 0;
    offset(dx, dy);
    for (int order = 0; order < 6; ++order)
    {
        Point triangle[3];
        for (int vertex = 0; vertex < 3; ++vertex)
        {
            triangle[vertex] = shapes[shape][permutations[order][vertex]];
            triangle[vertex].x -= (short)dx;
            triangle[vertex].y -= (short)dy;
        }
        clear();
        polygon(triangle, 3, 0);
        read_pixels();
        for (int y = 0; y < 32; ++y)
            for (int x = 0; x < 32; ++x)
            {
                int covered = triangle_contains(shape, x, y);
                expect_pixel(names[shape], x, y, covered ? 8 : 0);
            }
    }
    offset(0, 0);
}

static void check_shared_edge(int diagonal, int reverse, int quad)
{
    const Point corners[4] = {{7,9},{20,9},{7,26},{20,26}};
    static const unsigned char splits[2][2][3] = {{{0,1,2},{1,3,2}},{{0,1,3},{0,3,2}}};
    clear();
    if (quad)
        polygon(corners, 4, 1);
    else
        for (int part = 0; part < 2; ++part)
        {
            Point triangle[3];
            for (int vertex = 0; vertex < 3; ++vertex)
                triangle[vertex] = corners[splits[diagonal][part ^ (reverse & 1)][reverse & 2 ? 2-vertex : vertex]];
            polygon(triangle, 3, 1);
        }
    read_pixels();
    for (int y = 0; y < 32; ++y)
        for (int x = 0; x < 32; ++x)
            expect_pixel(quad ? "F4 once-only coverage" : "shared edge once-only coverage", x, y,
                         x >= 7 && x < 20 && y >= 9 && y < 26 ? 8 : 0);
}

static void initialize(int scaled)
{
    if (software)
    {
        SoftwareRasterizer_Reset();
        ParamDrawTexpageMode mode = {0};
        mode.semi_transparency = 1;
        software_rasterizer.texpage_mode(&mode);
        return;
    }
    if (scaled)
        assert(Psyz_VideoSetInternalResolution(2) == 0);
    Psyz_VideoSetDitheringMode(PSYZ_DITHER_OFF);
    ResetGraph(0);
    DRAWENV draw;
    DISPENV display;
    SetDefDrawEnv(&draw, 0, 0, 1024, 512);
    draw.dtd = 0;
    draw.tpage = getTPage(2, 1, 0, 0);
    SetDefDispEnv(&display, 0, 0, 320, 240);
    PutDispEnv(&display);
    PutDrawEnv(&draw);
    DrawSync(0);
}

int main(int argc, char **argv)
{
    _set_error_mode(_OUT_TO_STDERR);
    int scaled = argc == 2 && strcmp(argv[1], "scaled") == 0;
    software = argc == 2 && strcmp(argv[1], "software") == 0;
    assert(argc == 1 || (argc == 2 && (scaled || software)));
    initialize(scaled);
    if (!scaled)
        for (int shifted = 0; shifted < 2; ++shifted)
            for (int shape = 0; shape < 5; ++shape)
                check_triangle(shifted, shape);
    for (int diagonal = 0; diagonal < 2; ++diagonal)
        for (int reverse = 0; reverse < 4; ++reverse)
            check_shared_edge(diagonal, reverse, 0);
    check_shared_edge(0, 0, 1);
    printf("%s %s polygon coverage: %d pixel comparisons, %d failures\n",
           software ? "software" : "GPU", scaled ? "2x" : "1x", comparisons, failures);
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
