#include "mgs_loading.h"
#include <SDL3/SDL_timer.h>
#include <psyz/audio.h>
#include <psyz/clock.h>
#include <psyz/video.h>
#include <assert.h>

static int deterministic, clock_failure, clock_changes, suppressed;
static unsigned pacing_changes;
static PsyzVsyncMode pacing = PSYZ_VSYNC_AUTO;

Uint64 SDLCALL SDL_GetTicksNS(void) { return 123456789; }
int Psyz_ClockDeterministic(void) { return deterministic; }
int Psyz_ClockSetDeterministic(int enabled)
{
    ++clock_changes;
    if (clock_failure)
        return -1;
    deterministic = enabled;
    return 0;
}
PsyzVsyncMode Psyz_VideoGetVsyncMode(void) { return pacing; }
int Psyz_VideoSetVsyncMode(PsyzVsyncMode mode)
{
    ++pacing_changes;
    pacing = mode;
    return 0;
}
int Psyz_AudioSetOutputSuppressed(int value)
{
    assert(deterministic);
    suppressed = value;
    return 0;
}

int main(void)
{
    assert(MgsLoadingConfigure(0));
    MgsLoadingBegin("s16d");
    MgsLoadingEnd();
    assert(!clock_changes && !pacing_changes && !suppressed);
    clock_failure = 1;
    assert(!MgsLoadingConfigure(1) && !deterministic);
    clock_failure = 0;
    assert(MgsLoadingConfigure(1) && deterministic && clock_changes == 2);
    assert(MgsLoadingConfigure(1) && clock_changes == 2);
    for (int mode = PSYZ_VSYNC_AUTO; mode <= PSYZ_VSYNC_LIMITLESS; ++mode) {
        pacing = (PsyzVsyncMode)mode;
        for (int load = 0; load < 2; ++load) {
            MgsLoadingBegin("s16d");
            assert(pacing == PSYZ_VSYNC_LIMITLESS && suppressed);
            MgsLoadingEnd();
            assert(pacing == mode && !suppressed && clock_changes == 2);
        }
    }
    assert(pacing_changes == 16);
    return 0;
}
