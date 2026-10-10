#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <psyz.h>
#include "platform/rasterizer.h"

#include "gpu_extent_cases.h"

static void check_transfers(int mode)
{
    const DrawBackend *draw = &software_rasterizer;
    PS1_RECT           destination = {16, 16, 2, 1};
    PS1_RECT           source = {32, 16, 2, 1};
    u_long             initial = 0x00108010;
    u_long             color = 0x001f001f;
    u_long             output = 0;
    draw->mask(0, 0);
    draw->load_image(&destination, &initial);
    draw->load_image(&source, &color);
    draw->mask(mode & 1, mode & 2);
    draw->move_image(&source, destination.x, destination.y);
    draw->store_image(&destination, &output);
    assert((output & 0xffff) == (mode & 2 ? 0x8010 : mode & 1 ? 0x801f : 0x001f));
    assert((output >> 16) == (mode & 1 ? 0x801f : 0x001f));
    draw->mask(0, 0);
    draw->load_image(&destination, &initial);
    draw->mask(mode & 1, mode & 2);
    draw->load_image(&destination, &color);
    draw->store_image(&destination, &output);
    assert((output & 0xffff) == (mode & 2 ? 0x8010 : mode & 1 ? 0x801f : 0x001f));
    assert((output >> 16) == (mode & 1 ? 0x801f : 0x001f));
    draw->clear_image(&destination, 248, 0, 0);
    draw->store_image(&destination, &output);
    assert(output == 0x001f001f);
}

static void raw_primitive(u_long *words, int count)
{
    assert(software_rasterizer.push_prim(words, count) == count);
}

static void clear_extent_area(void)
{
    PS1_RECT area = {0, 0, 1024, 512};
    software_rasterizer.mask(0, 0);
    software_rasterizer.clear_image(&area, 0, 0, 0);
}

static void pixel(int x, int y, unsigned short expected)
{
    const u16 *vram = SoftwareRasterizer_GetVram();
    if (vram[y * 1024 + x] != expected)
        fprintf(stderr, "pixel %d,%d expected %04x got %04x\n", x, y, expected, vram[y * 1024 + x]);
    assert(vram[y * 1024 + x] == expected);
}

static int grid_source, grid_target, offset_x, offset_y;

static void grid_pixel(int x, int y, unsigned short expected)
{
    pixel(offset_x + x * grid_target / grid_source, offset_y + y, expected);
}

static void check_grid_extents(void)
{
    const int grids[][2] = {{320, 640}, {640, 320}, {320, 320}};
    for (size_t grid = 0; grid < sizeof(grids) / sizeof(grids[0]); ++grid)
    {
        grid_source = grids[grid][0];
        grid_target = grids[grid][1];
        assert(software_rasterizer.horizontal_grid(grid_source, grid_target) == 0);
        for (int shifted = 0; shifted < 2; ++shifted)
        {
            offset_x = shifted * 40;
            offset_y = shifted * 17;
            software_rasterizer.offset(offset_x, offset_y);
            check_extent_cases(raw_primitive, clear_extent_area, grid_pixel);
        }
    }
    software_rasterizer.horizontal_grid(1, 1);
    software_rasterizer.offset(0, 0);
}

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    SoftwareRasterizer_Reset();
    for (int mode = 0; mode < 4; ++mode)
        check_transfers(mode);
    check_extent_cases(raw_primitive, clear_extent_area, pixel);
    check_grid_extents();
    puts("Software transfer masking and fill bypass passed");
    return 0;
}
