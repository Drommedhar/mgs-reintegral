#include "mgs_native.h"
#undef fprintf
#include "libdg/libdg.h"
#include <assert.h>

static DVECTOR test_vxy[4][3];
static long test_vzp[4][3];
static int half_width, projection_distance, expand_calls;
static short initial_min, initial_max;
short DG_ClipMin[2], DG_ClipMax[2];

int MgsVideoHalfWidth(void)
{
    return half_width;
}

void MgsVideoExpandClip(short *minimum, short *maximum)
{
    initial_min = *minimum;
    initial_max = *maximum;
    ++expand_calls;
    *minimum -= 23;
    *maximum += 11;
}

static void set_projection_distance(int distance)
{
    projection_distance = distance;
}

#undef gte_SetGeomScreen
#define gte_SetGeomScreen set_projection_distance
#define VXY test_vxy
#define VZP test_vzp
#include "widescreen_clip_helpers.inc"

static void check_points(void)
{
    const int xs[] = {-286,-215,-214,-161,-160,0,160,161,214,215,286};
    const int ys[] = {-113,-112,0,112,113};
    for (size_t xi = 0; xi < sizeof(xs) / sizeof(xs[0]); ++xi)
        for (size_t yi = 0; yi < sizeof(ys) / sizeof(ys[0]); ++yi)
        {
            DVECTOR scratch[256] = {0};
            scratch[0] = (DVECTOR){(short)xs[xi], (short)ys[yi]};
            DVECTOR original = scratch[0];
            int expected = (xs[xi] < -half_width ? 1 : xs[xi] > half_width ? 2 : 0) |
                           (ys[yi] < -112 ? 4 : ys[yi] > 112 ? 8 : 0);
            DG_BoundCheck(scratch);
            assert(memcmp(&scratch[0], &original, sizeof(original)) == 0);
            assert(((unsigned char *)&scratch[128])[3] == expected);
            for (int depth = 0; depth < 2; ++depth)
            {
                RVECTOREX vertex = {0};
                vertex.sxy = original;
                vertex.sz = depth;
                DG_SetRVectorCode(&vertex);
                assert(memcmp(&vertex.sxy, &original, sizeof(original)) == 0);
                assert(vertex.sz == (unsigned)depth);
                assert(vertex.c.cd == (expected | (depth ? 0 : 16)));
            }
        }
}

static void check_box(int left, int top, int right, int bottom, int depth)
{
    DVECTOR *vertices = &test_vxy[1][0];
    for (int index = 0; index < 8; ++index)
    {
        vertices[index].vx = (short)(index & 1 ? left : right);
        vertices[index].vy = (short)(index & 2 ? top : bottom);
        (&test_vzp[1][0])[index] = depth && index == 7 ? 1 : 0;
    }
    int outside = left > half_width || right < -half_width || top > 112 || bottom < -112;
    int partial = right > half_width || left < -half_width || bottom > 112 || top < -112;
    int expected = outside || !depth ? 0 : partial ? 1 : 2;
    assert(BoundCheck(vertices) == expected);
}

static void check_boxes(void)
{
    const int centers[] = {-286,-215,-214,-161,-160,0,160,161,214,215,286};
    const int tops[] = {-116,-112,0,109,113};
    for (size_t x = 0; x < sizeof(centers) / sizeof(centers[0]); ++x)
        for (size_t y = 0; y < sizeof(tops) / sizeof(tops[0]); ++y)
            for (int depth = 0; depth < 2; ++depth)
                check_box(centers[x]-2, tops[y], centers[x]+2, tops[y]+3, depth);
    check_box(-160,-112,160,112,1);
    check_box(-half_width,-112,half_width,112,1);
}

static void check_clip_delegation(void)
{
    RECT rectangles[] = {{-160,-112,320,224},{-80,-56,160,112},{0,0,320,224}};
    for (size_t index = 0; index < sizeof(rectangles) / sizeof(rectangles[0]); ++index)
    {
        RECT original = rectangles[index];
        DG_Clip(&rectangles[index], 320 + (int)index);
        assert(memcmp(&original, &rectangles[index], sizeof(original)) == 0);
        assert(expand_calls == (int)index + 1);
        assert(initial_min == original.x && initial_max == original.x + original.w - 1);
        assert(DG_ClipMin[0] == original.x - 23);
        assert(DG_ClipMax[0] == original.x + original.w - 1 + 11);
        assert(DG_ClipMin[1] == original.y && DG_ClipMax[1] == original.y + original.h - 1);
        assert(projection_distance == 320 + (int)index);
    }
}

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    const int widths[] = {160,214,285};
    for (size_t index = 0; index < sizeof(widths) / sizeof(widths[0]); ++index)
    {
        half_width = widths[index];
        check_points();
        check_boxes();
    }
    check_clip_delegation();
    puts("Default/wide renderer bounds preserve projected coordinates, depth and vertical clipping");
    return 0;
}
