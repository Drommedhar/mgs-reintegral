#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <libapi.h>
#include <libetc.h>
#include <libspu.h>
#include <psyz.h>
#include "mgs_threads.h"

extern void Psyz_KernelPoll(void);

enum { CLOCK_BASE = 0x4000, CLOCK_BYTES = 512, CLOCK_PERIOD = 448 };
static unsigned long sound_thread;
static unsigned interrupts;
static unsigned sound_ticks;
static int task_pending;
static int acknowledge;
static int change_volume;

static void clock_interrupt(void)
{
    assert(CheckCallback());
    assert(!task_pending);
    task_pending = 1;
    ++interrupts;
    if (acknowledge)
    {
        SpuSetIRQAddr(CLOCK_BASE + ((interrupts & 1) ? 256 : 0));
        SpuSetIRQ(SPU_RESET);
    }
}

static unsigned long sound_task(void)
{
    SwExitCriticalSection();
    for (;;)
    {
        assert(!CheckCallback() && task_pending);
        task_pending = 0;
        ++sound_ticks;
        if (change_volume)
        {
            Psyz_SpuWrite(0, (sound_ticks & 1) ? 0x3fff : 0);
            Psyz_SpuWrite(2, (sound_ticks & 1) ? 0x3fff : 0);
        }
        ChangeTh(0);
    }
}

static void service_tasks(void)
{
    assert(!CheckCallback());
    if (task_pending)
    {
        ChangeTh(sound_thread);
    }
}

static void start_clock(int reset_irq)
{
    unsigned char adpcm[CLOCK_BYTES];
    SpuVoiceAttr voice = {0};
    SpuSetIRQ(SPU_OFF);
    Psyz_KernelPoll();
    Psyz_SpuReset(0);
    memset(adpcm, 0, sizeof(adpcm));
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
    interrupts = sound_ticks = 0;
    task_pending = 0;
    acknowledge = reset_irq;
    SpuSetIRQCallback(clock_interrupt);
    SpuSetIRQAddr(CLOCK_BASE);
    SpuSetIRQ(SPU_ON);
    SpuSetKey(SPU_ON, SPU_23CH);
}

static void render_frames(unsigned frames, unsigned batch)
{
    short output[2048 * 2];
    while (frames)
    {
        unsigned count = frames < batch ? frames : batch;
        Psyz_SpuPullSamplesServiced(output, (int)count, service_tasks);
        frames -= count;
    }
}

static void check_sample_clock(void)
{
    static const unsigned batches[] = {1, 7, 448, 735, 2048};
    for (unsigned i = 0; i < sizeof(batches) / sizeof(batches[0]); ++i)
    {
        start_clock(1);
        render_frames(2048, batches[i]);
        assert(interrupts == 5 && sound_ticks == 5);
        render_frames(44100 - 2048, batches[i]);
        assert(interrupts == 99 && sound_ticks == 99);
        render_frames(CLOCK_PERIOD * 100 - 44100, batches[i]);
        assert(interrupts == 100 && sound_ticks == 100);
        render_frames(1, batches[i]);
        assert(interrupts == 101 && sound_ticks == 101);
    }
}

static void check_latch_and_deferred_path(void)
{
    short output[2048 * 2];
    start_clock(0);
    render_frames(2048, 2048);
    assert(interrupts == 1 && sound_ticks == 1);
    assert(Psyz_SpuRead(0x1ae) & 0x40);
    SpuSetIRQ(SPU_OFF);
    render_frames(2048, 2048);
    assert(interrupts == 1);

    start_clock(1);
    Psyz_SpuPullSamples(output, 2048);
    assert(interrupts == 0);
    Psyz_KernelPoll();
    service_tasks();
    assert(interrupts == 1 && sound_ticks == 1);

    start_clock(1);
    SwEnterCriticalSection();
    Psyz_SpuPullSamples(output, 1);
    Psyz_KernelPoll();
    assert(interrupts == 0);
    SwExitCriticalSection();
    assert(interrupts == 1);
    service_tasks();
    render_frames(447, 447);
    assert(sound_ticks == 1);
    render_frames(1, 1);
    assert(sound_ticks == 2);
}

static void check_scheduled_mixer_writes(void)
{
    unsigned char tone[16];
    short output[2048 * 2];
    start_clock(1);
    memset(tone, 0x11, sizeof(tone));
    tone[0] = 0;
    tone[1] = 7;
    Psyz_SpuMemWrite(0x6000, tone, sizeof(tone));
    Psyz_SpuWrite(4, 4096);
    Psyz_SpuWrite(6, 0x6000 / 8);
    Psyz_SpuWrite(8, 15);
    Psyz_SpuWrite(10, 0x1fc0);
    Psyz_SpuWrite(0x180, 0x3fff);
    Psyz_SpuWrite(0x182, 0x3fff);
    Psyz_SpuWrite(0x1aa, 0xc040);
    Psyz_SpuWrite(0x188, 1);
    change_volume = 1;
    Psyz_SpuPullSamplesServiced(output, 2048, service_tasks);
    change_volume = 0;
    assert(sound_ticks == 5);
    assert(output[64 * 2] != 0);
    assert(output[500 * 2] == 0);
    assert(output[960 * 2] != 0);
    assert(output[1400 * 2] == 0);
    assert(output[1900 * 2] != 0);
}

int main(void)
{
    SetConf(16, 12, 0);
    sound_thread = OpenTh(sound_task, 0, 0);
    Psyz_SpuInit();
    SpuInit();
    check_sample_clock();
    check_latch_and_deferred_path();
    check_scheduled_mixer_writes();
    SpuSetIRQ(SPU_OFF);
    SpuSetIRQCallback(NULL);
    CloseTh(sound_thread);
    MgsThreadsShutdown();
    puts("SPU sample clock: five IRQs/2048 frames, 99/44100; fibers, latch and masks passed.");
    return 0;
}
