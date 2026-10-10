#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libapi.h>
#include <libetc.h>
#include "../vendor/psyz/psyz/src/psyz/clock_internal.h"

typedef struct {
    unsigned calls;
    unsigned observed_poll;
    int replace;
    char observed[2][PSYZ_PAD_BUF_LEN];
    PsyzControllerKind observed_kinds[2];
    char replacement[2][PSYZ_PAD_BUF_LEN];
    PsyzControllerKind replacement_kinds[2];
} HookState;

static unsigned backend_polls;
static int video_frames;
static char backend_frames[2][PSYZ_PAD_BUF_LEN];

void Psyz_PadsPoll(void) {
    ++backend_polls;
    for (int p = 0; p < 2; ++p) {
        for (int n = 0; n < PSYZ_PAD_BUF_LEN; ++n) {
            backend_frames[p][n] = (char)(backend_polls * 7 + p * 113 + n);
        }
        backend_frames[p][0] = 0;
        backend_frames[p][1] =
            (char)Psyz_PadsSetKind(p, 0, PSYZ_CTRL_QUERY_KIND);
        Psyz_PadsSet(p, backend_frames[p], PSYZ_PAD_BUF_LEN);
    }
}

static void PollHook(char frames[2][PSYZ_PAD_BUF_LEN],
                     PsyzControllerKind kinds[2], void* userdata) {
    HookState* state = userdata;
    assert(state);
    ++state->calls;
    state->observed_poll = backend_polls;
    memcpy(state->observed, frames, sizeof(state->observed));
    memcpy(state->observed_kinds, kinds, sizeof(state->observed_kinds));
    if (state->replace) {
        memcpy(frames, state->replacement, sizeof(state->replacement));
        memcpy(kinds, state->replacement_kinds, sizeof(state->replacement_kinds));
    }
}

static void CheckObserverAndCache(HookState* state) {
    char output[PSYZ_PAD_BUF_LEN + 4];
    Psyz_PadsSetKind(0, 0, PSYZ_CTRL_ANALOG_PAD);
    Psyz_PadsSetKind(1, 0, PSYZ_CTRL_DIGITAL_PAD);
    Psyz_PadsSetPollHook(PollHook, state);
    VSync(0);
    memset(output, 0x5a, sizeof(output));
    Psyz_PadsGet(-1, output, sizeof(output));
    Psyz_PadsGet(2, output, sizeof(output));
    Psyz_PadsGet(0, NULL, sizeof(output));
    Psyz_PadsGet(0, output, 0);
    Psyz_PadsGet(0, output, -1);
    assert(backend_polls == 0 && state->calls == 0);
    Psyz_PadsGet(0, output, 2);
    assert(backend_polls == 1 && state->calls == 1);
    assert(state->observed_poll == 1);
    assert(memcmp(state->observed, backend_frames, sizeof(backend_frames)) == 0);
    assert(state->observed_kinds[0] == PSYZ_CTRL_ANALOG_PAD);
    assert(state->observed_kinds[1] == PSYZ_CTRL_DIGITAL_PAD);
    assert(memcmp(output, backend_frames[0], 2) == 0);
    for (unsigned n = 2; n < sizeof(output); ++n) {
        assert(output[n] == 0x5a);
    }
    Psyz_PadsGet(1, output, sizeof(output));
    assert(memcmp(output, backend_frames[1], PSYZ_PAD_BUF_LEN) == 0);
    for (unsigned n = PSYZ_PAD_BUF_LEN; n < sizeof(output); ++n) {
        assert(output[n] == 0x5a);
    }
    Psyz_PadsGet(0, output, sizeof(output));
    assert(backend_polls == 1 && state->calls == 1);
}

static void CheckReplacement(HookState* state) {
    char output[PSYZ_PAD_BUF_LEN];
    state->replace = 1;
    state->replacement_kinds[0] = PSYZ_CTRL_ANALOG_STICK;
    state->replacement_kinds[1] = PSYZ_CTRL_DISCONNECTED;
    for (int p = 0; p < 2; ++p) {
        for (int n = 0; n < PSYZ_PAD_BUF_LEN; ++n) {
            state->replacement[p][n] = (char)(0xd7 - p * 73 - n);
        }
    }
    VSync(0);
    Psyz_PadsGet(1, output, sizeof(output));
    assert(backend_polls == 2 && state->calls == 2);
    assert(state->observed_poll == 2);
    assert(memcmp(state->observed, backend_frames, sizeof(backend_frames)) == 0);
    for (int p = 0; p < 2; ++p) {
        Psyz_PadsGet(p, output, sizeof(output));
        assert(memcmp(output, state->replacement[p], sizeof(output)) == 0);
        assert(Psyz_PadsSetKind(p, 0, PSYZ_CTRL_QUERY_KIND) ==
               state->replacement_kinds[p]);
        assert(Psyz_PadsSetKind(p, 1, PSYZ_CTRL_QUERY_KIND) == PSYZ_CTRL_DISCONNECTED);
    }
    assert(backend_polls == 2 && state->calls == 2);
}

static void CheckRegistrationAndDirectWrite(HookState* state) {
    char output[PSYZ_PAD_BUF_LEN];
    char injected[PSYZ_PAD_BUF_LEN];
    memset(injected, 0x31, sizeof(injected));
    Psyz_PadsSetPollHook(NULL, NULL);
    Psyz_PadsGet(0, output, sizeof(output));
    assert(memcmp(output, state->replacement[0], sizeof(output)) == 0);
    assert(backend_polls == 2 && state->calls == 2);
    VSync(0);
    Psyz_PadsGet(0, output, sizeof(output));
    assert(backend_polls == 3 && state->calls == 2);
    assert(memcmp(output, backend_frames[0], sizeof(output)) == 0);
    Psyz_PadsSetPollHook(PollHook, state);
    Psyz_PadsGet(1, output, sizeof(output));
    assert(memcmp(output, backend_frames[1], sizeof(output)) == 0);
    assert(backend_polls == 3 && state->calls == 2);
    VSync(0);
    Psyz_PadsSet(0, injected, sizeof(injected));
    Psyz_PadsGet(0, output, sizeof(output));
    assert(memcmp(output, injected, sizeof(output)) == 0);
    assert(backend_polls == 3 && state->calls == 2);
}

static void CheckAutomaticBuffers(HookState* state) {
    char first[3], second[PSYZ_PAD_BUF_LEN];
    assert(InitPAD(first, sizeof(first), second, sizeof(second)));
    assert(StartPAD());
    VSync(0);
    assert(backend_polls == 4 && state->calls == 3);
    assert(state->observed_poll == 4);
    assert(memcmp(state->observed, backend_frames, sizeof(backend_frames)) == 0);
    assert(memcmp(first, state->replacement[0], sizeof(first)) == 0);
    assert(memcmp(second, state->replacement[1], sizeof(second)) == 0);
    Psyz_PadsSetPollHook(NULL, NULL);
    VSync(0);
    assert(backend_polls == 5 && state->calls == 3);
    assert(memcmp(first, backend_frames[0], sizeof(first)) == 0);
    assert(memcmp(second, backend_frames[1], sizeof(second)) == 0);
    StopPAD();
}

/* Deterministic platform endpoints for the real libapi.c under test. */
int Psyz_VideoVSync(int mode) { return mode == 0 ? ++video_frames : video_frames; }
void Psyz_KernelPoll(void) {}
void Psyz_KernelVBlank(void) {}
void Psyz_CdVBlank(void) {}
void Psyz_AudioPump(void) {
    while (Psyz_ClockAudioFramesDue()) {
        Psyz_ClockAdvanceAudioSample();
    }
}
uint32_t Psyz_OsNowUs(void) { return (uint32_t)video_frames * 19000; }
long GetVideoMode(void) { return MODE_NTSC; }
void PadInit(int mode) { assert(mode == 0); }
int Psyz_PadsSupportsRumble(int port) {
    assert(port >= 0 && port < 2);
    return 0;
}
int Psyz_PadsRumble(int port, unsigned short low, unsigned short high,
                    unsigned duration_ms) {
    (void)port;
    (void)low;
    (void)high;
    (void)duration_ms;
    abort();
}
struct DIRENTRY* my_firstfile(char* path, struct DIRENTRY* entry) {
    (void)path;
    (void)entry;
    abort();
}
struct DIRENTRY* my_nextfile(struct DIRENTRY* entry) {
    (void)entry;
    abort();
}
long my_erase(char* path) {
    (void)path;
    abort();
}
long my_format(char* path) {
    (void)path;
    abort();
}
void psyz_log(unsigned int level, const char* file, unsigned int line,
              const char* func, const char* fmt, ...) {
    (void)level;
    (void)file;
    (void)line;
    (void)func;
    (void)fmt;
    abort();
}

static void CheckVSyncTimeline(void) {
    assert(Psyz_ClockSetDeterministic(1) == 0);
    for (int frame = 0; frame < 60; ++frame) {
        video_frames += frame % 7;
        assert(VSync(-1) == frame);
        assert(VSync(1) == 0);
        VSync(0);
        assert(VSync(-1) == frame + 1);
        assert(Psyz_ClockNowUs() == (uint32_t)((uint64_t)(frame + 1) * 1001000 / 60));
    }
    assert(Psyz_ClockSetDeterministic(0) == 0);
    assert(VSync(-1) == video_frames);
}

int main(void) {
    HookState state = {0};
    CheckObserverAndCache(&state);
    CheckReplacement(&state);
    CheckRegistrationAndDirectWrite(&state);
    CheckAutomaticBuffers(&state);
    CheckVSyncTimeline();
    puts("Pad sample observation, replacement, caching, and unregister passed.");
    return 0;
}
