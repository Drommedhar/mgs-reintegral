#include <assert.h>
#include <stdbool.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <SDL3/SDL_gpu.h>

enum { VRAM_W = 1024, VRAM_H = 512 };
static unsigned internal_res, set_internal_res;
static bool window_configuration_requested, is_platform_init_successful;
static bool requested_fullscreen, is_fullscreen, allocation_ok, fullscreen_ok;
static int sdl3_window, device, allocations, blits, updates, errors;
static SDL_GPUTexture *scaled_vram_render, *vram_render;
static jmp_buf failure;
static Uint64 fake_counter, last_frame_time, finish_time;
static bool use_driver_vsync;
static int vsync_mode;
enum { PSYZ_VSYNC_LIMITLESS = 3 };
static double target_frame_time_us = 1000000.0 / 59.94;
static bool compensate_frame_time;
static double frame_lateness_us;
static struct {
    double last_frame_time_us, last_draw_time_us, target_frame_time_us;
    unsigned total_frames;
    int using_driver_vsync;
} gpu_stats;

static Uint64 TestCounter(void) { return fake_counter++; }
static void TestDelay(Uint64 ns) { fake_counter += ns / 1000; }
static double GetElapsedMicroseconds(Uint64 start, Uint64 end) { return (double)(end - start); }

static void RecordError(const char *message, ...)
{
    (void)message;
    ++errors;
}

#define ERRORF RecordError
#define WARNF(...) ((void)0)
#define INFOF(...) ((void)0)

static void TestExit(int status)
{
    assert(status == EXIT_FAILURE);
    longjmp(failure, 1);
}

static void Draw_FlushBuffer(void) {}
static void ResolveNativeVram(void) {}
static void UpdateScissor(void) { ++updates; }
static bool CreateScaledVramTarget(unsigned scale)
{
    assert(scale > 1);
    ++allocations;
    return allocation_ok;
}
static SDL_GPUCommandBuffer *AcquireCmd(void) { return (SDL_GPUCommandBuffer *)1; }
static void TestBlit(SDL_GPUCommandBuffer *command, const SDL_GPUBlitInfo *blit)
{
    assert(command && blit->destination.w == VRAM_W * set_internal_res);
    ++blits;
}
static void TestRelease(int unused, SDL_GPUTexture *texture)
{
    (void)unused;
    (void)texture;
}
static const char *TestError(void) { return "fixture SDL failure"; }
static void SetFullScreen(bool requested)
{
    if (fullscreen_ok) is_fullscreen = requested;
}

#define exit TestExit
#define SDL_BlitGPUTexture TestBlit
#define SDL_ReleaseGPUTexture TestRelease
#define SDL_GetError TestError
#define SDL_GetPerformanceCounter TestCounter
#define SDL_DelayNS TestDelay
#include "video_config_helpers.inc"
#undef exit

static void Reset(bool strict)
{
    window_configuration_requested = strict;
    is_platform_init_successful = true;
    sdl3_window = 1;
    internal_res = 1;
    set_internal_res = 8;
    allocation_ok = fullscreen_ok = true;
    requested_fullscreen = is_fullscreen = false;
    allocations = blits = updates = errors = 0;
}

static void CheckResolution(void)
{
    Reset(true);
    allocation_ok = false;
    if (!setjmp(failure)) {
        ApplyPendingInternalRes();
        assert(!"explicit allocation failure must terminate startup");
    }
    assert(errors == 1 && internal_res == 1 && allocations == 1 && !blits);
    Reset(false);
    allocation_ok = false;
    ApplyPendingInternalRes();
    assert(internal_res == 1 && set_internal_res == 1 && !errors);
    Reset(true);
    set_internal_res = 32;
    if (!setjmp(failure)) {
        ApplyPendingInternalRes();
        assert(!"explicit resolution clamp must terminate startup");
    }
    assert(errors == 1 && !allocations && !blits);
    Reset(true);
    ApplyPendingInternalRes();
    assert(internal_res == 8 && allocations == 1 && blits == 1 && updates == 1);
}

static void CheckFullscreen(void)
{
    Reset(true);
    requested_fullscreen = true;
    fullscreen_ok = false;
    if (!setjmp(failure)) {
        ApplyRequestedFullscreen();
        assert(!"explicit fullscreen failure must terminate startup");
    }
    assert(errors == 1 && !is_fullscreen);
    Reset(true);
    requested_fullscreen = true;
    ApplyRequestedFullscreen();
    assert(is_fullscreen && !errors);
    Reset(false);
    fullscreen_ok = false;
    ApplyRequestedFullscreen();
    assert(!errors && !is_fullscreen);
}

int main(void)
{
    CheckResolution();
    CheckFullscreen();
    fake_counter = finish_time = 60000;
    WaitForNextFrame();
    assert(gpu_stats.last_frame_time_us >= 60000);
    for (int i = 0; i < 60; ++i) {
        fake_counter += 4000;
        finish_time = fake_counter;
        WaitForNextFrame();
        assert(gpu_stats.last_frame_time_us >= target_frame_time_us);
        assert(gpu_stats.last_frame_time_us < target_frame_time_us + 10);
    }
    puts("A late frame resumes nominal pacing without shortened catch-up frames");
    compensate_frame_time = true;
    frame_lateness_us = 0;
    Uint64 started = last_frame_time;
    for (int i = 0; i < 120; ++i) {
        fake_counter += (i & 1) ? 2000 : 22000;
        finish_time = fake_counter;
        WaitForNextFrame();
    }
    assert((double)(last_frame_time - started) < target_frame_time_us * 120 + 500);
    fake_counter += 500000;
    finish_time = fake_counter;
    WaitForNextFrame();
    fake_counter += 2000;
    finish_time = fake_counter;
    WaitForNextFrame();
    assert(gpu_stats.last_frame_time_us >= target_frame_time_us - 10);
    puts("Godot paired busy/idle frames retain cadence; loading stalls reset the schedule");
    puts("Explicit output: allocation/clamp/fullscreen failures reject startup; defaults retain fallback");
    return 0;
}
