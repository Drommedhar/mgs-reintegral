#ifndef MGS_GPU_EXTENT_CASES_H
#define MGS_GPU_EXTENT_CASES_H

static u_long position(int x, int y)
{
    return (u_long)(unsigned short)x | (u_long)(unsigned short)y << 16;
}

static void check_extent_cases(void (*draw)(u_long *, int), void (*clear)(void),
                               void (*pixel)(int, int, unsigned short))
{
    for (int oversized = 0; oversized < 2; ++oversized)
    {
        u_long triangle[] = {0x200000f8, position(-512, 0), position(511 + oversized, 0), position(0, 400)};
        clear();
        draw(triangle, 4);
        pixel(0, 100, oversized ? 0 : 31);
        triangle[1] = position(0, -256);
        triangle[2] = position(400, 255 + oversized);
        triangle[3] = position(0, 255 + oversized);
        clear();
        draw(triangle, 4);
        pixel(10, 0, oversized ? 0 : 31);

        u_long line[] = {0x400000f8, position(-512, 96), position(511 + oversized, 96)};
        clear();
        draw(line, 3);
        pixel(20, 96, oversized ? 0 : 31);
        line[1] = position(96, -256);
        line[2] = position(96, 255 + oversized);
        clear();
        draw(line, 3);
        pixel(96, 20, oversized ? 0 : 31);
    }

    u_long quad[] = {0x280000f8, position(-1000, 0), position(32, 16), position(16, 32), position(32, 32)};
    clear();
    draw(quad, 5);
    pixel(17, 17, 0);
    pixel(25, 25, 31);
    quad[1] = position(16, 16);
    quad[4] = position(1000, 1000);
    clear();
    draw(quad, 5);
    pixel(20, 20, 31);
    pixel(40, 40, 0);
}

#endif
