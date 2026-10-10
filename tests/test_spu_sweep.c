#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <psyz.h>

static void advance(unsigned frames)
{
    short output[1024 * 2];
    while (frames) {
        unsigned count = frames > 1024 ? 1024 : frames;
        Psyz_SpuPullSamples(output, (int)count);
        frames -= count;
    }
}

static int current(unsigned offset)
{
    return (int16_t)Psyz_SpuRead(offset);
}

static void seed(unsigned offset, int level)
{
    assert(!(level & 1));
    Psyz_SpuWrite(offset, (unsigned short)((level / 2) & 0x7fff));
    advance(1);
}

static void check_channels(void)
{
    Psyz_SpuReset(0);
    for (unsigned voice = 0; voice < 24; ++voice) {
        Psyz_SpuWrite(voice * 16, (unsigned short)(voice + 1));
        Psyz_SpuWrite(voice * 16 + 2, (unsigned short)(0x7fff - voice));
        assert(current(0x200 + voice * 4) == 0);
        assert(current(0x202 + voice * 4) == 0);
    }
    Psyz_SpuWrite(0x180, 0x3fff);
    Psyz_SpuWrite(0x182, 0x4000);
    advance(1);
    for (unsigned voice = 0; voice < 24; ++voice) {
        assert(current(0x200 + voice * 4) == (int)(voice + 1) * 2);
        assert(current(0x202 + voice * 4) == -(int)(voice + 1) * 2);
        assert(Psyz_SpuRead(voice * 16 + 12) == 0);
        Psyz_SpuWrite(voice * 16, 0x802c);
        Psyz_SpuWrite(voice * 16 + 2, 0x902c);
    }
    assert(current(0x1b8) == 32766);
    assert(current(0x1ba) == -32768);
    advance(5);
    for (unsigned voice = 0; voice < 24; ++voice) {
        assert(current(0x200 + voice * 4) == (int)(voice + 1) * 2 + 35);
        assert(current(0x202 + voice * 4) == -(int)(voice + 1) * 2 - 40);
    }
}

typedef struct {
    unsigned short control;
    int initial;
    unsigned frames;
    int expected;
} SweepCase;

static const SweepCase cases[] = {
    {0x8000, 0, 1, 14336}, {0x8000, 0, 2, 28672},
    {0x8000, 0, 3, 32767}, {0x8003, 0, 4, 32767},
    {0x9000, 0, 1, -16384}, {0x9000, 0, 3, -32768},
    {0xa000, 32766, 1, 16382}, {0xa000, 32766, 2, 0},
    {0xb000, -32768, 1, -18432}, {0xb000, -32768, 2, -4096},
    {0xb000, -32768, 3, 0}, {0xa02c, -100, 1, 0},
    {0xb02c, 100, 1, 0}, {0x902c, 4, 2, -12},
    {0x802c, -4, 2, 10}, {0xc000, 24576, 1, 32767},
    {0xc000, 24578, 1, 28162}, {0xc000, 24578, 2, 31746},
    {0xc000, 24578, 3, 32767}, {0xd000, 24578, 1, 20482},
    {0xd000, 24578, 2, 4098}, {0xd000, 24578, 3, -12286},
    {0xd000, 24578, 5, -32768}, {0xe000, 32766, 1, 16383},
    {0xe000, 32766, 2, 8191}, {0xf000, 32766, 2, 8191},
    {0xe000, -32768, 1, 0}, {0xf000, -32768, 1, 0},
    {0xc028, 24578, 1, 24578}, {0xc028, 24578, 2, 24585},
    {0xc02c, 24578, 3, 24578}, {0xc02c, 24578, 4, 24585},
    {0xc024, 24578, 1, 24585}, {0xc024, 24576, 1, 24604},
    {0xc068, 24578, 32767, 24578}, {0xc068, 24578, 32768, 24585},
    {0xc07e, 24578, 32768, 24583}, {0xc07f, 24578, 65536, 24578},
    {0x907f, 100, 65536, 100}, {0xb07f, 100, 65536, 100},
    {0xa07f, -100, 65536, -100}, {0x9fac, 4, 2, -12}
};

static void check_sequences(void)
{
    static const unsigned controls[] = {0, 0x172, 0x180, 0x182};
    static const unsigned levels[] = {0x200, 0x25e, 0x1b8, 0x1ba};
    for (unsigned channel = 0; channel < 4; ++channel) {
        for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
            Psyz_SpuReset(0);
            seed(controls[channel], cases[i].initial);
            Psyz_SpuWrite(controls[channel], cases[i].control);
            advance(cases[i].frames);
            if (current(levels[channel]) != cases[i].expected) {
                fprintf(stderr, "Sweep %u channel %u: %d != %d\n", i, channel,
                        current(levels[channel]), cases[i].expected);
                assert(0);
            }
        }
    }
}

static void check_all_rates(void)
{
    for (unsigned rate = 0; rate < 128; ++rate) {
        unsigned shift = rate / 4;
        unsigned period = shift <= 11 ? 1 : 1u << (shift - 11);
        int amount = 7 - (rate & 3);
        if (period > 32768)
            period = 32768;
        if (shift < 11)
            amount *= 1 << (11 - shift);
        Psyz_SpuReset(0);
        Psyz_SpuWrite(0, (unsigned short)(0x8000 | rate));
        advance(period - 1);
        assert(current(0x200) == 0);
        advance(1);
        assert(current(0x200) == (rate == 127 ? 0 : amount));
    }
}

static void check_reprogramming(void)
{
    Psyz_SpuReset(0);
    seed(0, 100);
    Psyz_SpuWrite(0, 1000);
    Psyz_SpuWrite(0, 0x8034);
    advance(3);
    assert(current(0x200) == 100);
    Psyz_SpuWrite(0, 0x8034);
    advance(3);
    assert(current(0x200) == 100);
    advance(1);
    assert(current(0x200) == 107);
    Psyz_SpuWrite(0x188, 1);
    Psyz_SpuWrite(0x18c, 1);
    assert(current(0x200) == 107);
    advance(4);
    assert(current(0x200) == 114);
    Psyz_SpuWrite(0, 0x7fff);
    assert(current(0x200) == 114);
    advance(1);
    assert(current(0x200) == -2);
    Psyz_SpuWrite(0x180, 0x807f);
    Psyz_SpuWrite(0x1b8, 0x9234);
    advance(1);
    assert(current(0x1b8) == (int16_t)0x9234);
}

static void check_reset(void)
{
    unsigned char marker = 123;
    for (int hot = 0; hot < 2; ++hot) {
        Psyz_SpuMemWrite(0x4000, &marker, 1);
        seed(0, 200);
        seed(0x180, -200);
        Psyz_SpuWrite(0, 0x8034);
        advance(3);
        Psyz_SpuReset(hot);
        assert(current(0x200) == 0 && current(0x1b8) == 0);
        assert(Psyz_SpuRead(0) == 0 && Psyz_SpuRead(0x180) == 0);
        assert(Psyz_SpuGetRam()[0x4000] == (hot ? marker : 0));
        Psyz_SpuWrite(0, 0x8034);
        advance(3);
        assert(current(0x200) == 0);
        advance(1);
        assert(current(0x200) == 7);
    }
}

static void start_tone(unsigned short voice_volume, unsigned short main_volume)
{
    unsigned char block[16];
    Psyz_SpuReset(0);
    memset(block, 0x11, sizeof(block));
    block[0] = 0;
    block[1] = 7;
    Psyz_SpuMemWrite(0x4000, block, sizeof(block));
    Psyz_SpuWrite(0, voice_volume);
    Psyz_SpuWrite(2, voice_volume);
    Psyz_SpuWrite(4, 4096);
    Psyz_SpuWrite(6, 0x800);
    Psyz_SpuWrite(8, 15);
    Psyz_SpuWrite(10, 0x1fc0);
    Psyz_SpuWrite(0x180, main_volume);
    Psyz_SpuWrite(0x182, main_volume);
    Psyz_SpuWrite(0x1aa, 0xc000);
    Psyz_SpuWrite(0x188, 1);
}

static void check_mixer(void)
{
    short positive[128 * 2], negative[128 * 2], swept[128 * 2];
    start_tone(0x2000, 0x2000);
    Psyz_SpuPullSamples(positive, 128);
    start_tone(0x2000, 0x6000);
    Psyz_SpuPullSamples(negative, 128);
    assert(positive[250] > 500);
    for (unsigned i = 0; i < 256; ++i)
        assert(positive[i] + negative[i] >= -1 && positive[i] + negative[i] <= 0);
    start_tone(0x802c, 0x3fff);
    Psyz_SpuPullSamples(swept, 128);
    assert(swept[250] > 0 && swept[250] < positive[250]);
    assert(current(0x200) == 128 * 7);
    start_tone(0x3fff, 0x902c);
    Psyz_SpuPullSamples(swept, 128);
    assert(swept[250] < 0);
    assert(current(0x1b8) == -128 * 8);
}

int main(void)
{
    Psyz_SpuInit();
    check_channels();
    check_sequences();
    check_all_rates();
    check_reprogramming();
    check_reset();
    check_mixer();
    puts("SPU sweeps: 50 channels, 128 rates, 168 sequence cases, reset and mixer passed.");
    return 0;
}
