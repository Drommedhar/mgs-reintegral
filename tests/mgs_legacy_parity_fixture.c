#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <libgpu.h>
#include <psyz.h>
#include <SDL3/SDL.h>

#ifdef MGS_LEGACY_GPU_CAPTURE
unsigned char *MgsLegacyGpuCapture(int *width, int *height);
#endif

static void submit(void *packet)
{
    termPrim((P_TAG *)packet);
    DrawOTag((OT_TYPE *)packet);
}

static void tile(RECT region, int r, int g, int b, int semi)
{
    TILE packet = {0};
    setTile(&packet);
    setXY0(&packet, region.x, region.y);
    setWH(&packet, region.w, region.h);
    setRGB0(&packet, r, g, b);
    setSemiTrans(&packet, semi);
    submit(&packet);
}

static void blends(void)
{
    for (int abr = 0; abr < 4; ++abr) {
        DR_TPAGE page = {0};
        setDrawTPage(&page, 0, 0, getTPage(2, abr, 0, 0));
        submit(&page);
        for (int channel = 0; channel < 32; ++channel) {
            RECT region = {(short)(channel * 8), (short)(abr * 8), 8, 8};
            tile(region, channel * 8, (31 - channel) * 8, 136, 0);
            tile(region, 56, channel * 8, (31 - channel) * 8, 1);
        }
    }
}

static void gradient(void)
{
    DR_TPAGE page = {0};
    setDrawTPage(&page, 0, 1, getTPage(2, 0, 0, 0));
    submit(&page);
    POLY_G4 packet = {0};
    setPolyG4(&packet);
    setXY4(&packet, 8, 48, 128, 53, 12, 111, 132, 107);
    setRGB0(&packet, 125, 25, 81);
    setRGB1(&packet, 198, 143, 40);
    setRGB2(&packet, 25, 177, 125);
    setRGB3(&packet, 243, 61, 239);
    submit(&packet);
}

static void feedback(void)
{
    DR_TPAGE page = {0};
    setDrawTPage(&page, 0, 0, getTPage(2, 0, 0, 0));
    submit(&page);
    SPRT packet = {0};
    setSprt(&packet);
    setShadeTex(&packet, 1);
    setXY0(&packet, 160, 48);
    setUV0(&packet, 8, 48);
    setWH(&packet, 120, 64);
    submit(&packet);
    assert(Psyz_GpuSetFramebufferSampling(1) == 0);
    setXY0(&packet, 160, 128);
    submit(&packet);
    assert(Psyz_GpuSetFramebufferSampling(0) == 0);
    RECT region = {8, 48, 124, 64};
    MoveImage(&region, 8, 128);
    RECT overlap = {8, 128, 124, 32};
    MoveImage(&overlap, 9, 129);
    RECT patch = {20, 132, 2, 1};
    u_long pixels = 0x83e0801f;
    LoadImage(&patch, &pixels);
    RECT clear = {24, 132, 2, 2};
    ClearImage(&clear, 24, 80, 120);
}

static void palette_feedback(void)
{
    u_long indices[8];
    for (int i = 0; i < 8; ++i) indices[i] = 0x11111111;
    RECT region = {640, 256, 2, 8};
    LoadImage(&region, indices);
    DRAWENV draw;
    SetDefDrawEnv(&draw, 0, 0, 1024, 512);
    PutDrawEnv(&draw);
    tile((RECT){513, 300, 1, 1}, 125, 143, 177, 0);
    SetDefDrawEnv(&draw, 0, 0, 320, 240);
    PutDrawEnv(&draw);
    DR_TPAGE page = {0};
    setDrawTPage(&page, 0, 0, getTPage(0, 0, 640, 256));
    submit(&page);
    SPRT sprite = {0};
    setSprt(&sprite);
    setShadeTex(&sprite, 1);
    setXY0(&sprite, 288, 48);
    setUV0(&sprite, 0, 0);
    setWH(&sprite, 8, 8);
    sprite.clut = getClut(512, 300);
    submit(&sprite);
}

static void capture(const char *prefix, int remote)
{
    char path[2048];
    uint16_t *pixels = calloc(320 * 240, sizeof(*pixels));
    assert(pixels);
    RECT region = {0, 0, 320, 240};
    StoreImage(&region, (u_long *)pixels);
    assert(snprintf(path, sizeof(path), "%s-vram.bin", prefix) < (int)sizeof(path));
    SDL_IOStream *file = SDL_IOFromFile(path, "wb");
    assert(file && SDL_WriteIO(file, pixels, 320 * 240 * 2) == 320 * 240 * 2);
    assert(SDL_CloseIO(file));
    free(pixels);
    if (remote) return;
    int width, height;
#ifdef MGS_LEGACY_GPU_CAPTURE
    unsigned char *rgb = MgsLegacyGpuCapture(&width, &height);
#else
    unsigned char *rgb = Psyz_VideoAllocPresentedFrame(&width, &height);
#endif
    assert(rgb);
    SDL_Surface *surface = SDL_CreateSurfaceFrom(width, height, SDL_PIXELFORMAT_RGB24, rgb, width * 3);
    assert(surface);
    assert(snprintf(path, sizeof(path), "%s-output.bmp", prefix) < (int)sizeof(path));
    assert(SDL_SaveBMP(surface, path));
    SDL_DestroySurface(surface);
    free(rgb);
}

int main(int argc, char **argv)
{
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
    assert(argc == 7);
    unsigned width = (unsigned)atoi(argv[1]), height = (unsigned)atoi(argv[2]);
    int wide = atoi(argv[3]), remote = atoi(argv[4]);
    unsigned scale = (unsigned)atoi(argv[5]);
    assert(Psyz_VideoConfigureWindow(width, height, 0) == 0);
    assert(Psyz_VideoSetInternalResolution(remote ? 1 : scale) == 0);
    if (wide) assert(Psyz_VideoSetPresentation(width, height, 224) == 0);
    ResetGraph(0);
    Psyz_VideoSetDitheringMode(PSYZ_DITHER_AUTO);
    DISPENV display;
    DRAWENV draw;
    SetDefDispEnv(&display, 0, 0, 320, 240);
    display.screen.w = 256;
    display.screen.h = 224;
    SetDefDrawEnv(&draw, 0, 0, 320, 240);
    draw.dtd = 1;
    PutDispEnv(&display);
    PutDrawEnv(&draw);
    SetDispMask(1);
    DrawSync(0);
    RECT clear = {0, 0, 1024, 512};
    ClearImage(&clear, 24, 80, 120);
    blends();
    gradient();
    feedback();
    palette_feedback();
    tile((RECT){0, 224, 320, 16}, 248, 0, 248, 0);
    DrawSync(0);
    Psyz_VideoVSync(0);
    capture(argv[6], remote);
    printf("LEGACY_PARITY_FIXTURE width=%u height=%u wide=%d scale=%u remote=%d\n", width, height, wide, scale, remote);
    return 0;
}
