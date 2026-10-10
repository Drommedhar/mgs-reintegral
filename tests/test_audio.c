#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <libapi.h>
#include <libetc.h>
#include <libspu.h>
#include <psyz.h>

extern void Psyz_KernelPoll(void);

static unsigned int dma_callbacks;
static unsigned int transfer_callbacks;
static unsigned int spu_interrupts;

static void dma_complete(void)
{
    assert(CheckCallback());
    ++dma_callbacks;
}

static void transfer_complete(void)
{
    assert(CheckCallback());
    ++transfer_callbacks;
}

static void spu_interrupt(void)
{
    assert(CheckCallback());
    ++spu_interrupts;
}

static void check_dma(void)
{
    unsigned char source[64];
    unsigned char received[64];
    void *previous = DMACallback(4, dma_complete);
    for (unsigned int i = 0; i < sizeof(source); ++i)
        source[i] = (unsigned char)(i * 3);
    Psyz_SpuWrite(0x1a6, 0x2000 / 8);
    Psyz_DmaWrite(DMA_CHANNEL_SPU, 0, (u_long)(uintptr_t)source);
    Psyz_DmaWrite(DMA_CHANNEL_SPU, 1, 0x10010);
    EnterCriticalSection();
    Psyz_DmaWrite(DMA_CHANNEL_SPU, 2, 0x01000201);
    assert(dma_callbacks == 0);
    ExitCriticalSection();
    assert(dma_callbacks == 1);
    Psyz_SpuMemRead(0x2000, received, sizeof(received));
    assert(memcmp(source, received, sizeof(source)) == 0);
    assert(DMACallback(4, (void (*)())previous) == (void *)dma_complete);
    assert(DMACallback(-1, dma_complete) == NULL);
    assert(DMACallback(7, dma_complete) == NULL);

    SpuSetTransferStartAddr(0x3000);
    assert(SpuWrite(source, sizeof(source)) == sizeof(source));
    assert(SpuIsTransferCompleted(SPU_TRANSFER_PEEK) == 1);
    assert(SpuIsTransferCompleted(SPU_TRANSFER_WAIT) == 1);
    assert(SpuRead(received, sizeof(received)) == sizeof(received));
    assert(SpuIsTransferCompleted(SPU_TRANSFER_WAIT) == 1);
    assert(memcmp(source, received, sizeof(source)) == 0);
    assert(SpuSetTransferCallback(transfer_complete) == NULL);
    assert(SpuWrite(source, sizeof(source)) == sizeof(source));
    assert(transfer_callbacks == 1);
    assert(SpuSetTransferCallback(NULL) == transfer_complete);
}

static void check_spu_irq(void)
{
    unsigned char adpcm[512];
    short output[1024 * 2];
    SpuVoiceAttr voice = {0};
    memset(adpcm, 0x11, sizeof(adpcm));
    for (unsigned int i = 0; i < sizeof(adpcm); i += 16)
    {
        adpcm[i] = 0;
        adpcm[i + 1] = 0;
    }
    adpcm[1] = 4;
    adpcm[497] = 3;
    SpuSetIRQ(SPU_OFF);
    Psyz_SpuMemWrite(0x4000, adpcm, sizeof(adpcm));
    SpuSetIRQAddr(0x4000);
    assert(SpuSetIRQCallback(spu_interrupt) == NULL);
    SpuSetIRQ(SPU_ON);
    voice.mask = SPU_VOICE_VOLL | SPU_VOICE_VOLR | SPU_VOICE_PITCH |
                 SPU_VOICE_WDSA | SPU_VOICE_ADSR_AR | SPU_VOICE_ADSR_SL;
    voice.voice = SPU_23CH;
    voice.volume.left = voice.volume.right = 0x3fff;
    voice.pitch = 4096;
    voice.addr = 0x4000;
    voice.ar = 0;
    voice.sl = 15;
    SpuSetVoiceAttr(&voice);
    Psyz_SpuWrite(0x180, 0x3fff);
    Psyz_SpuWrite(0x182, 0x3fff);
    SpuSetKey(SPU_ON, SPU_23CH);

    Psyz_SpuPullSamples(output, 1);
    assert(spu_interrupts == 0);
    Psyz_KernelPoll();
    assert(spu_interrupts == 1);
    assert(Psyz_SpuRead(0x1ae) & 0x40);
    Psyz_SpuPullSamples(output, 1024);
    Psyz_KernelPoll();
    assert(spu_interrupts == 1);
    int audible = 0;
    for (unsigned int i = 0; i < sizeof(output) / sizeof(output[0]); ++i)
        audible |= output[i] != 0;
    assert(audible);

    SpuSetIRQAddr(0x4100);
    SpuSetIRQ(SPU_RESET);
    assert(!(Psyz_SpuRead(0x1ae) & 0x40));
    Psyz_SpuPullSamples(output, 512);
    Psyz_KernelPoll();
    assert(spu_interrupts == 2);
    SpuSetIRQ(SPU_OFF);
    Psyz_SpuPullSamples(output, 1024);
    Psyz_KernelPoll();
    assert(spu_interrupts == 2);
    SpuSetIRQCallback(NULL);
}

static void start_loop(unsigned channel, unsigned attack)
{
    unsigned char block[16];
    SpuVoiceAttr voice = {0};
    Psyz_SpuReset(0);
    memset(block, 0x11, sizeof(block));
    block[0] = 0;
    block[1] = 7;
    Psyz_SpuMemWrite(0x4000, block, sizeof(block));
    voice.voice = 1u << channel;
    voice.mask = SPU_VOICE_VOLL | SPU_VOICE_VOLR | SPU_VOICE_PITCH |
                 SPU_VOICE_WDSA | SPU_VOICE_ADSR_AR | SPU_VOICE_ADSR_SL |
                 SPU_VOICE_ADSR_SR | SPU_VOICE_ADSR_RR;
    voice.volume.left = voice.volume.right = 0x3fff;
    voice.pitch = 4096;
    voice.addr = 0x4000;
    voice.ar = attack;
    voice.sl = 15;
    voice.sr = 127;
    voice.rr = 31;
    SpuSetVoiceAttr(&voice);
    Psyz_SpuWrite(0x180, 0x3fff);
    Psyz_SpuWrite(0x182, 0x3fff);
    Psyz_SpuWrite(0x1aa, 0xc000);
    SpuSetKey(SPU_ON, voice.voice);
}

static void check_live_release(unsigned channel)
{
    short output[1024 * 2];
    SpuVoiceAttr voice = {0};
    start_loop(channel, 0);
    Psyz_SpuPullSamples(output, 1024);
    assert(output[2046] > 1000);
    SpuSetKey(SPU_OFF, 1u << channel);
    Psyz_SpuPullSamples(output, 1024);
    assert(Psyz_SpuRead(channel * 16 + 12) > 10000);
    voice.voice = 1u << channel;
    voice.mask = SPU_VOICE_ADSR_RMODE | SPU_VOICE_ADSR_RR;
    voice.r_mode = SPU_VOICE_LINEARDecN;
    voice.rr = 0;
    SpuSetVoiceAttr(&voice);
    Psyz_SpuPullSamples(output, 1024);
    assert(Psyz_SpuRead(channel * 16 + 12) == 0);
    for (unsigned i = 16; i < 2048; ++i)
        assert(output[i] == 0);
}

static void check_live_attack_and_sustain(void)
{
    short output[256 * 2];
    SpuVoiceAttr voice = {0};
    start_loop(0, 127);
    Psyz_SpuPullSamples(output, 256);
    assert(Psyz_SpuRead(12) == 0);
    voice.voice = SPU_0CH;
    voice.mask = SPU_VOICE_ADSR_AR;
    voice.ar = 0;
    SpuSetVoiceAttr(&voice);
    Psyz_SpuPullSamples(output, 64);
    unsigned level = Psyz_SpuRead(12);
    assert(level > 10000);
    voice.mask = SPU_VOICE_ADSR_SR | SPU_VOICE_ADSR_SMODE;
    voice.s_mode = SPU_VOICE_LINEARDecN;
    voice.sr = 44;
    SpuSetVoiceAttr(&voice);
    assert(Psyz_SpuRead(12) == level);
    Psyz_SpuPullSamples(output, 1);
    assert(Psyz_SpuRead(12) == level - 8);
}

int main(void)
{
    Psyz_SpuInit();
    SpuInit();
    check_dma();
    check_spu_irq();
    check_live_release(0);
    check_live_release(13);
    check_live_release(23);
    check_live_attack_and_sustain();
    puts("SPU DMA, mixer, IRQ and live ADSR updates passed.");
    return 0;
}
