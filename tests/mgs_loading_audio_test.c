#include "mgs_loading.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <SDL3/SDL.h>
#include <libapi.h>
#include <libetc.h>
#include <libspu.h>
#include <psyz.h>
#include "../vendor/psyz/psyz/src/psyz/clock_internal.h"

static unsigned interrupts, serviced;
static SDL_ThreadID owner;

static void SoundInterrupt(void) {
    assert(CheckCallback());
    ++interrupts;
    SpuSetIRQ(SPU_RESET);
}

static void ServiceSound(void) {
    assert(!CheckCallback() && SDL_GetCurrentThreadID() == owner);
    serviced = interrupts;
}

static void StartTone(void) {
    unsigned char samples[16];
    memset(samples, 0x11, sizeof(samples));
    samples[0] = 0;
    samples[1] = 7;
    Psyz_SpuMemWrite(0x4000, samples, sizeof(samples));
    SpuVoiceAttr voice = {0};
    voice.voice = SPU_13CH;
    voice.mask = SPU_VOICE_VOLL | SPU_VOICE_VOLR | SPU_VOICE_PITCH |
                 SPU_VOICE_WDSA | SPU_VOICE_ADSR_AR | SPU_VOICE_ADSR_SL |
                 SPU_VOICE_ADSR_SR | SPU_VOICE_ADSR_RR;
    voice.volume.left = voice.volume.right = 0x3fff;
    voice.pitch = 4096;
    voice.addr = 0x4000;
    voice.sl = 15;
    voice.sr = 127;
    voice.rr = 0;
    SpuSetVoiceAttr(&voice);
    Psyz_SpuWrite(0x180, 0x3fff);
    Psyz_SpuWrite(0x182, 0x3fff);
    Psyz_SpuWrite(0x1aa, 0xc000);
    SpuSetKey(SPU_ON, SPU_13CH);
    SpuSetIRQCallback(SoundInterrupt);
    SpuSetIRQAddr(0);
    SpuSetIRQ(SPU_ON);
}

static void WaitWithAudio(unsigned milliseconds) {
    const Uint64 deadline = SDL_GetTicks() + milliseconds;
    do {
        SDL_Delay(2);
        Psyz_AudioPumpWait();
    } while (SDL_GetTicks() < deadline);
}

int main(void) {
    assert(SDL_SetHintWithPriority(SDL_HINT_AUDIO_DRIVER, "dummy", SDL_HINT_OVERRIDE));
    assert(Psyz_AudioInit() == 0);
    SpuInit();
    owner = SDL_GetCurrentThreadID();
    Psyz_AudioSetServiceCallback(ServiceSound);
    StartTone();
    assert(MgsLoadingConfigure(1));
    for (unsigned frame = 0; frame < 6; ++frame) {
        Psyz_ClockBeginFrame(0);
        Psyz_AudioPump();
        Psyz_ClockEndFrame();
    }
    PsyzAudioStats before, during, after;
    assert(Psyz_AudioStats(&before) == 0 && before.queued_frames > 0 && !before.paused);
    assert(Psyz_SpuRead(13 * 16 + 12) > 0);
    MgsLoadingBegin("opening");
    assert(Psyz_AudioStats(&during) == 0 && during.queued_frames > 0 && !during.paused);
    unsigned clock = Psyz_ClockNowUs(), blanks = Psyz_ClockVBlanks();
    unsigned previous_interrupts = interrupts;
    WaitWithAudio(180);
    assert(Psyz_ClockNowUs() == clock && Psyz_ClockVBlanks() == blanks);
    assert(interrupts > previous_interrupts && serviced == interrupts);
    assert(Psyz_AudioStats(&during) == 0 && during.wait_frames > 4096 && !during.backlog_clears);
    assert(Psyz_SpuRead(13 * 16 + 12) > 0 && during.wait_frames < 14000);
    MgsLoadingEnd();
    assert(Psyz_AudioStats(&after) == 0 && after.queued_frames > 0 && !after.paused);
    SpuSetKey(SPU_OFF, SPU_13CH);
    WaitWithAudio(180);
    assert(Psyz_SpuRead(13 * 16 + 12) == 0);
    Psyz_AudioPause();
    assert(Psyz_AudioStats(&before) == 0);
    WaitWithAudio(10);
    assert(Psyz_AudioStats(&after) == 0 && after.paused && after.wait_frames == before.wait_frames);
    Psyz_AudioDestroy();
    SDL_Quit();
    puts("Stage transitions preserve queued native audio.");
    return 0;
}
