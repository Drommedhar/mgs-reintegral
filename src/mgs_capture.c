#include "mgs_capture.h"
#include "mgs_video.h"
#include <libgpu.h>
#include <psyz.h>
#include <SDL3/SDL.h>
#include <stdio.h>
#include <stdlib.h>

static int CaptureOutput(const char *path)
{
    int width = 0, height = 0;
    unsigned char *pixels = Psyz_VideoAllocPresentedFrame(&width, &height);
    if (!pixels) {
        fprintf(stderr, "Cannot capture the rendered video output.\n");
        return 0;
    }
    SDL_Surface *surface = SDL_CreateSurfaceFrom(width, height, SDL_PIXELFORMAT_RGB24,
                                                pixels, width * 3);
    int saved = surface && SDL_SaveBMP(surface, path);
    if (!saved)
        fprintf(stderr, "Output capture failed: %s\n", SDL_GetError());
    SDL_DestroySurface(surface);
    free(pixels);
    return saved;
}

int MgsCaptureFrame(const char *path)
{
    if (MgsVideoCapturesOutput())
        return CaptureOutput(path);
    DISPENV display;
    GetDispEnv(&display);
    RECT rect = display.disp;
    if (rect.w <= 0 || rect.h <= 0 || rect.w > 1024 || rect.h > 512 || display.isrgb24)
    {
        fprintf(stderr, "Unsupported display for diagnostic capture.\n");
        return 0;
    }
    size_t count = (size_t)rect.w * rect.h;
    unsigned short *pixels = calloc(count, sizeof(*pixels));
    SDL_Surface *surface = SDL_CreateSurface(rect.w, rect.h, SDL_PIXELFORMAT_RGB24);
    if (!pixels || !surface)
    {
        fprintf(stderr, "Cannot allocate frame capture.\n");
        free(pixels);
        SDL_DestroySurface(surface);
        return 0;
    }
    StoreImage(&rect, (u_long *)pixels);
    for (int y = 0; y < rect.h; ++y)
    {
        unsigned char *row = (unsigned char *)surface->pixels + y * surface->pitch;
        for (int x = 0; x < rect.w; ++x)
        {
            unsigned int pixel = pixels[y * rect.w + x];
            for (int component = 0; component < 3; ++component)
            {
                unsigned int value = (pixel >> (component * 5)) & 31;
                row[x * 3 + component] = (unsigned char)((value << 3) | (value >> 2));
            }
        }
    }
    int saved = SDL_SaveBMP(surface, path);
    if (!saved) fprintf(stderr, "Frame capture failed: %s\n", SDL_GetError());
    SDL_DestroySurface(surface);
    free(pixels);
    return saved;
}
