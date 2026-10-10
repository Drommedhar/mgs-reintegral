#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <SDL3/SDL.h>
#include <libapi.h>
#include <libetc.h>
#include <libspu.h>
#include <psyz.h>
#include "../vendor/psyz/psyz/src/psyz/clock_internal.h"

extern void Psyz_KernelPoll(void);
extern void Psyz_KernelVBlank(void);

enum { CLOCK_BASE = 0x4000, CLOCK_BYTES = 512, TRACE_CAPACITY = 1024 };
typedef struct {
    uint32_t kind;
    uint32_t microseconds;
} Event;

static Event events[TRACE_CAPACITY];
static unsigned event_count, timer_irqs, sound_irqs, sound_tasks;
static int sound_pending;

static void RecordEvent(uint32_t kind) {
    assert(event_count < TRACE_CAPACITY);
    events[event_count++] = (Event){kind, Psyz_ClockNowUs()};
}

static long TimerInterrupt(void) {
    assert(CheckCallback());
    ++timer_irqs;
    RecordEvent('T');
    return 0;
}

static void SoundInterrupt(void) {
    assert(CheckCallback() && !sound_pending);
    sound_pending = 1;
    ++sound_irqs;
    RecordEvent('I');
    SpuSetIRQAddr(CLOCK_BASE + ((sound_irqs & 1) ? 256 : 0));
    SpuSetIRQ(SPU_RESET);
}

static void ServiceTasks(void) {
    assert(!CheckCallback());
    if (sound_pending) {
        sound_pending = 0;
        ++sound_tasks;
        RecordEvent('S');
    }
}

static void StartSoundClock(void) {
    unsigned char adpcm[CLOCK_BYTES] = {0};
    SpuVoiceAttr voice = {0};
    SpuSetIRQ(SPU_OFF);
    Psyz_SpuReset(0);
    adpcm[1] = 4;
    adpcm[sizeof(adpcm) - 15] = 3;
    Psyz_SpuMemWrite(CLOCK_BASE, adpcm, sizeof(adpcm));
    voice.mask = SPU_VOICE_VOLL | SPU_VOICE_VOLR | SPU_VOICE_PITCH |
                 SPU_VOICE_WDSA | SPU_VOICE_ADSR_AR | SPU_VOICE_ADSR_SL;
    voice.voice = SPU_23CH;
    voice.pitch = 4096;
    voice.addr = CLOCK_BASE;
    voice.sl = 15;
    SpuSetVoiceAttr(&voice);
    SpuSetIRQCallback(SoundInterrupt);
    SpuSetIRQAddr(CLOCK_BASE);
    SpuSetIRQ(SPU_ON);
    SpuSetKey(SPU_ON, SPU_23CH);
}

static void RenderTimeline(int jitter) {
    uint64_t ticks = 0, samples = 0;
    for (unsigned frame = 0; frame < 120; ++frame) {
        int pal = frame >= 60;
        ticks += pal ? 176400 : 147147;
        if (jitter) {
            SDL_Delay(frame == 25 ? 250 : frame % 3);
            if (frame == 12) Psyz_AudioPause();
            if (frame == 20) Psyz_AudioUnpause();
        }
        unsigned expected = (unsigned)(ticks / 200 - samples);
        assert(Psyz_ClockVBlanks() == frame);
        Psyz_ClockBeginFrame(pal);
        assert(Psyz_ClockAudioFramesDue() == expected);
        assert(Psyz_ClockSetDeterministic(1) == -1);
        Psyz_AudioPump();
        assert(Psyz_ClockAudioFramesDue() == 0);
        assert(Psyz_ClockNowUs() == (uint32_t)((ticks / 200 * 200) * 50 / 441));
        samples += expected;
        Psyz_ClockEndFrame();
        Psyz_KernelVBlank();
        assert(Psyz_ClockNowUs() == (uint32_t)(ticks * 50 / 441));
        assert(Psyz_ClockVBlanks() == frame + 1);
        assert(Psyz_ClockScanlines() == 0);
        unsigned before = sound_irqs;
        Psyz_AudioPump();
        assert(sound_irqs == before);
    }
    assert(samples == 97064);
    assert(timer_irqs == 220);
    assert(sound_irqs == 217 && sound_tasks == 217 && !sound_pending);
    assert(Psyz_ClockNowUs() == 2201000);
    assert(GetRCnt(RCntCNT2) > 4000 && GetRCnt(RCntCNT2) < 4300);
}

static unsigned RunTimeline(Event* result, int jitter) {
    assert(Psyz_ClockSetDeterministic(1) == 0);
    event_count = timer_irqs = sound_irqs = sound_tasks = 0;
    sound_pending = 0;
    memset(events, 0, sizeof(events));
    long event = OpenEvent(RCntCNT2, EvSpINT, EvMdINTR, TimerInterrupt);
    assert(event != -1 && EnableEvent(event));
    assert(SetRCnt(RCntCNT2, 42336, RCntMdINTR));
    assert(StartRCnt(RCntCNT2));
    StartSoundClock();
    Psyz_AudioSetServiceCallback(ServiceTasks);
    RenderTimeline(jitter);
    SpuSetIRQ(SPU_OFF);
    SpuSetIRQCallback(NULL);
    assert(StopRCnt(RCntCNT2));
    assert(CloseEvent(event));
    memcpy(result, events, sizeof(events));
    return event_count;
}

int main(void) {
    Event reference[TRACE_CAPACITY], jittered[TRACE_CAPACITY];
    assert(SDL_SetHintWithPriority(SDL_HINT_AUDIO_DRIVER, "dummy", SDL_HINT_OVERRIDE));
    assert(Psyz_AudioInit() == 0);
    SpuInit();
    unsigned reference_count = RunTimeline(reference, 0);
    unsigned jittered_count = RunTimeline(jittered, 1);
    assert(reference_count == jittered_count);
    assert(memcmp(reference, jittered, sizeof(reference)) == 0);
    Psyz_AudioDestroy();
    assert(Psyz_ClockSetDeterministic(0) == 0);
    uint32_t before = Psyz_ClockNowUs();
    SDL_Delay(3);
    assert((uint32_t)(Psyz_ClockNowUs() - before) >= 1000);
    SDL_Quit();
    printf("Deterministic timeline: %u identical timer/SPU/task events, 97064 samples; host jitter/pause ignored.\n", reference_count);
    return 0;
}
