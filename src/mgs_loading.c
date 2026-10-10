#include "mgs_loading.h"
#include <SDL3/SDL_timer.h>
#include <psyz/audio.h>
#include <psyz/clock.h>
#include <psyz/video.h>
#include <stdio.h>
#include <stdlib.h>

static int accelerated, loading;
static PsyzVsyncMode previous_mode;
static Uint64 started;
static const char *loading_stage;

int MgsLoadingConfigure(int enabled)
{
    if (enabled && !Psyz_ClockDeterministic() && Psyz_ClockSetDeterministic(1) != 0)
        return 0;
    accelerated = enabled != 0;
    return 1;
}

void MgsLoadingBegin(const char *stage)
{
    if (loading) {
        fputs("Stage loading already active.\n", stderr);
        exit(EXIT_FAILURE);
    }
    loading = 1;
    loading_stage = stage;
    started = SDL_GetTicksNS();
    if (!accelerated)
        return;
    previous_mode = Psyz_VideoGetVsyncMode();
    if (Psyz_VideoSetVsyncMode(PSYZ_VSYNC_LIMITLESS) != 0 ||
        Psyz_AudioSetOutputSuppressed(1) != 0) {
        fputs("Cannot accelerate stage presentation.\n", stderr);
        exit(EXIT_FAILURE);
    }
}

void MgsLoadingEnd(void)
{
    if (!loading) {
        fputs("No active stage load to complete.\n", stderr);
        exit(EXIT_FAILURE);
    }
    double milliseconds = (SDL_GetTicksNS() - started) / 1000000.0;
    if (accelerated && (Psyz_VideoSetVsyncMode(previous_mode) != 0 ||
                        Psyz_AudioSetOutputSuppressed(0) != 0)) {
        fputs("Cannot restore stage presentation.\n", stderr);
        exit(EXIT_FAILURE);
    }
    printf("[loading] %s: %.1f ms (%s)\n", loading_stage, milliseconds,
           accelerated ? "accelerated" : "normal");
    loading = 0;
}
