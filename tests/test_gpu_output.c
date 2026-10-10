#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <libgpu.h>
#include <psyz.h>

static void submit(void *primitive) {
    termPrim((P_TAG *)primitive);
    DrawOTag((OT_TYPE *)primitive);
}

static void draw_area(int buffer, int width, int height) {
    DRAWENV environment;
    SetDefDrawEnv(&environment, buffer, 0, width, height);
    environment.dtd = 0;
    PutDrawEnv(&environment);
}

static void clear_frame(int buffer) {
    RECT area = {(short)buffer, 0, 320, 224};
    assert(Psyz_GpuSetFrameTransform(1, 1, 0, 0) == 0);
    draw_area(buffer, 320, 224);
    ClearImage(&area, 0, 0, 0);
}

static void check_capture(void) {
    POLY_F3 triangle = {0};
    clear_frame(0);
    setPolyF3(&triangle);
    setXY3(&triangle, 10, 10, 12, 10, 10, 12);
    setRGB0(&triangle, 255, 255, 255);
    submit(&triangle);
    int width = 0, height = 0;
    unsigned char *image = Psyz_VideoAllocPresentedFrame(&width, &height);
    assert(image && width == 2560 && height == 1440);
    assert(image[(73 * width + 81) * 3] > 200);
    assert(image[(73 * width + 87) * 3] < 20);
    free(image);
    image = Psyz_VideoAllocCapturedFrame(&width, &height);
    assert(image && width == 320 && height == 240);
    free(image);
    assert(Psyz_VideoSetPresentation(0, 0, 0) == 0);
    image = Psyz_VideoAllocPresentedFrame(&width, &height);
    assert(image && width == 2560 && height == 1440);
    free(image);
}

static void check_movie_capture(void) {
    TILE white = {0};
    clear_frame(0);
    setTile(&white);
    setXY0(&white, 0, 0);
    setWH(&white, 320, 224);
    setRGB0(&white, 255, 255, 255);
    submit(&white);
    assert(Psyz_VideoSetPresentation(4, 3, 224) == 0);
    int width, height;
    unsigned char *image = Psyz_VideoAllocPresentedFrame(&width, &height);
    assert(image && width == 2560 && height == 1440);
    assert(image[(720 * width + 160) * 3] == 0);
    assert(image[(720 * width + 400) * 3] == 255);
    assert(image[(720 * width + 2160) * 3] == 255);
    assert(image[(720 * width + 2400) * 3] == 0);
    free(image);
}

static void check_display_blanking(void) {
    SetDispMask(0);
    int width, height;
    unsigned char *image = Psyz_VideoAllocPresentedFrame(&width, &height);
    assert(image && width == 2560 && height == 1440);
    for (size_t i = 0; i < (size_t)width * height * 3; ++i)
        assert(image[i] == 0);
    free(image);
    SetDispMask(1);
    image = Psyz_VideoAllocPresentedFrame(&width, &height);
    assert(image && width == 2560 && height == 1440);
    assert(image[(720 * width + 1280) * 3] == 255);
    free(image);
}

int main(void) {
    _set_error_mode(_OUT_TO_STDERR);
    assert(Psyz_VideoConfigureWindow(0, 1440, 0) < 0);
    assert(Psyz_VideoConfigureWindow(2560, 1440, 2) < 0);
    assert(Psyz_VideoConfigureWindow(2560, 1440, 0) == 0);
    assert(Psyz_VideoSetPresentation(2560, 1440, 224) == 0);
    assert(Psyz_VideoSetPresentation(2560, 0, 224) < 0);
    assert(Psyz_VideoSetPresentation(2560, 1440, 513) < 0);
    assert(Psyz_VideoSetInternalResolution(8) == 0);
    assert(Psyz_GpuSetFrameTransform(0, 4, 160, 0) < 0);
    assert(Psyz_GpuSetFrameTransform(3, 0, 160, 0) < 0);
    assert(Psyz_GpuSetFrameTransform(3, 4, 160, 2) < 0);
    ResetGraph(0);
    Psyz_VideoSetDitheringMode(PSYZ_DITHER_OFF);
    DISPENV display;
    SetDefDispEnv(&display, 0, 0, 320, 240);
    PutDispEnv(&display);
    SetDispMask(1);
    DrawSync(0);
    assert(Psyz_VideoGetInternalResolution() == 8);
    check_capture();
    check_movie_capture();
    check_display_blanking();
    puts("Output 2560x1440: 8x capture retains subpixel geometry, "
         "native capture unchanged, 4:3 movie pillarboxed");
    return 0;
}
