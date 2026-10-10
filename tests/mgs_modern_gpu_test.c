#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <libgpu.h>
#include <psyz.h>

static const void *addresses[4];
static PsyzProjectedVertex projected[4];
static int missing_vertex = -1;
static unsigned scale;

static int Geometry(const void *xy, PsyzProjectedVertex *vertex)
{
    for (int i = 0; i < 4; ++i)
        if (xy == addresses[i] && i != missing_vertex) {
            *vertex = projected[i];
            return 1;
        }
    return 0;
}

static void RegisterQuad(short *x0, short *x1, short *x2, short *x3, float left, float right, float offset)
{
    short *xy[4] = {x0, x1, x2, x3};
    for (int i = 0; i < 4; ++i) {
        addresses[i] = xy[i];
        projected[i] = (PsyzProjectedVertex){xy[i][0] + offset, xy[i][1], i & 1 ? right : left};
    }
}

static void Submit(void *packet)
{
    termPrim((P_TAG *)packet);
    DrawOTag((OT_TYPE *)packet);
}

static void Clear(void)
{
    RECT area = {0, 0, 320, 224};
    ClearImage(&area, 0, 0, 0);
    Psyz_GpuResetGeometryDepth();
}

static unsigned char *Capture(void)
{
    DrawSync(0);
    int width, height;
    unsigned char *image = Psyz_VideoAllocPresentedFrame(&width, &height);
    assert(image && width == 320 * scale && height == 224 * scale);
    return image;
}

static void Solid(float depth, int red, int green, int semi, float offset)
{
    POLY_F4 quad = {0};
    setPolyF4(&quad);
    setXYWH(&quad, 16, 16, 128, 128);
    setRGB0(&quad, red, green, 0);
    setSemiTrans(&quad, semi);
    RegisterQuad(&quad.x0, &quad.x1, &quad.x2, &quad.x3, depth, depth, offset);
    Submit(&quad);
}

static void CheckDepth(void)
{
    for (int enabled = 0; enabled < 2; ++enabled) {
        assert(Psyz_GpuConfigureGeometry(Geometry, 0, 0, enabled) == 0);
        Clear();
        Solid(100, 255, 0, 0, 0);
        Solid(400, 0, 255, 0, 0);
        unsigned char *image = Capture();
        const unsigned char *pixel = image + (80 * scale * 320 * scale + 80 * scale) * 3;
        assert(pixel[enabled ? 0 : 1] > 240 && pixel[enabled ? 1 : 0] == 0);
        free(image);
    }
    Solid(500, 0, 255, 1, 0);
    unsigned char *image = Capture();
    assert(image[(80 * scale * 320 * scale + 80 * scale) * 3] > 240);
    free(image);
    Clear();
    Solid(400, 0, 255, 0, 0);
    image = Capture();
    assert(image[(80 * scale * 320 * scale + 80 * scale) * 3 + 1] > 240);
    free(image);
}

static unsigned SampleTexture(int correction, int missing)
{
    assert(Psyz_GpuConfigureGeometry(Geometry, correction, 0, 0) == 0);
    Clear();
    POLY_FT4 quad = {0};
    setPolyFT4(&quad);
    setShadeTex(&quad, 1);
    setXYWH(&quad, 16, 16, 128, 128);
    setUVWH(&quad, 0, 0, 64, 64);
    quad.tpage = getTPage(2, 0, 640, 256);
    RegisterQuad(&quad.x0, &quad.x1, &quad.x2, &quad.x3, 100, 400, 0);
    missing_vertex = missing;
    Submit(&quad);
    missing_vertex = -1;
    unsigned char *image = Capture();
    unsigned value = image[(80 * scale * 320 * scale + 80 * scale) * 3 + 1];
    free(image);
    return value;
}

static void CheckTextures(void)
{
    uint16_t pixels[64 * 64];
    for (int y = 0; y < 64; ++y)
        for (int x = 0; x < 64; ++x)
            pixels[y * 64 + x] = (uint16_t)(1 | ((x / 2) << 5));
    RECT texture = {640, 256, 64, 64};
    LoadImage(&texture, (u_long *)pixels);
    unsigned affine = SampleTexture(0, -1);
    unsigned perspective = SampleTexture(1, -1);
    assert(affine >= 115 && affine <= 140);
    assert(perspective >= 40 && perspective <= 60);
    assert(SampleTexture(1, 2) == affine);
}

static void CheckCrossingDepth(void)
{
    assert(Psyz_GpuConfigureGeometry(Geometry, 1, 1, 1) == 0);
    Clear();
    POLY_F4 sloped = {0};
    setPolyF4(&sloped);
    setXYWH(&sloped, 16, 16, 128, 128);
    setRGB0(&sloped, 255, 0, 0);
    RegisterQuad(&sloped.x0, &sloped.x1, &sloped.x2, &sloped.x3, 100, 400, 0);
    Submit(&sloped);
    Solid(200, 0, 255, 0, 0);
    unsigned char *image = Capture();
    size_t row = 80 * scale * 320 * scale;
    assert(image[(row + 32 * scale) * 3] > 240);
    assert(image[(row + 128 * scale) * 3 + 1] > 240);
    free(image);
    assert(Psyz_GpuSetTextureAlignment(1) == 0);
    Solid(900, 0, 255, 0, 0);
    image = Capture();
    assert(image[(row + 32 * scale) * 3 + 1] > 240);
    free(image);
    assert(Psyz_GpuSetTextureAlignment(0) == 0);
}

static int LeftEdge(int precision)
{
    assert(Psyz_GpuConfigureGeometry(Geometry, 0, precision, 0) == 0);
    Clear();
    Solid(100, 255, 0, 0, 0.75f);
    unsigned char *image = Capture();
    int x;
    for (x = 0; x < 320 * (int)scale; ++x)
        if (image[(80 * scale * 320 * scale + x) * 3] > 200) break;
    free(image);
    return x;
}

int main(int argc, char **argv)
{
#ifdef _WIN32
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif
    assert(argc == 2);
    scale = (unsigned)atoi(argv[1]);
    assert(scale == 1 || scale == 4);
    assert(Psyz_VideoConfigureWindow(320 * scale, 224 * scale, 0) == 0);
    assert(Psyz_VideoSetPresentation(320, 224, 224) == 0);
    assert(Psyz_VideoSetInternalResolution(scale) == 0);
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
    CheckDepth();
    CheckTextures();
    CheckCrossingDepth();
    int legacy = LeftEdge(0), precise = LeftEdge(1);
    assert(precise - legacy == (int)(scale * 0.75f + 0.5f));
    printf("Modern GPU %ux: depth occlusion/reset, transparency, perspective UVs, missing depth and subpixel coverage passed.\n", scale);
    return 0;
}
