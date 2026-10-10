#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <libapi.h>
#include <libetc.h>
#include "mdec_decode.h"

static u_long dma_output[256];
static unsigned input_callbacks;
static unsigned output_callbacks;

static void InputComplete(void)
{
    assert(CheckCallback());
    ++input_callbacks;
}

static void OutputComplete(void)
{
    assert(CheckCallback());
    if (++output_callbacks == 1)
        DecDCTout(dma_output + 128, 128);
}

static void CheckDma(void)
{
    u_long runlevel[13];
    runlevel[0] = 0x3800000c;
    for (unsigned i = 1; i < 13; ++i)
        runlevel[i] = 0xfe000400;
    DecDCTReset(0);
    DecDCTinCallback(InputComplete);
    DecDCToutCallback(OutputComplete);
    DecDCTout(dma_output, 128);
    assert(DecDCToutSync(1) == 1 && output_callbacks == 0);
    DecDCTin(runlevel, 2);
    assert(input_callbacks == 1 && output_callbacks == 2);
    assert(DecDCTinSync(0) == 0 && DecDCToutSync(0) == 0);
    for (unsigned i = 0; i < 256; ++i)
        assert(dma_output[i] == 0xc210c210);
    DecDCTinCallback(NULL);
    DecDCToutCallback(NULL);
}

static void FillMacroblock(uint16_t codes[12], unsigned luma)
{
    for (unsigned i = 0; i < 6; ++i) {
        codes[i * 2] = (uint16_t)(0x400 | (i < 2 ? 0 : luma));
        codes[i * 2 + 1] = 0xfe00;
    }
}

int main(void)
{
    DECDCTENV env;
    uint16_t codes[12];
    unsigned char output[769];
    DecDCTGetEnv(&env);
    FillMacroblock(codes, 0);
    PsyzMdecInput input = {codes, codes + 12};
    memset(output, 0xa5, sizeof(output));
    assert(Psyz_MdecDecodeMacroblock(&input, &env, 0x38000000, output, 512) == 1);
    assert(input.next == input.end);
    for (unsigned i = 0; i < 512; i += 2)
        assert(output[i] == 0x10 && output[i + 1] == 0x42);
    assert(output[512] == 0xa5);
    assert(Psyz_MdecDecodeMacroblock(&input, &env, 0x38000000, output, 512) == 0);

    input.next = codes;
    assert(Psyz_MdecDecodeMacroblock(&input, &env, 0x3a000000, output, 512) == 1);
    assert(output[0] == 0x10 && output[1] == 0xc2);
    input.next = codes;
    assert(Psyz_MdecDecodeMacroblock(&input, &env, 0x30000000, output, 768) == 1);
    for (unsigned i = 0; i < 768; ++i)
        assert(output[i] == 128);
    assert(output[768] == 0xa5);

    FillMacroblock(codes, 511);
    input.next = codes;
    assert(Psyz_MdecDecodeMacroblock(&input, &env, 0x38000000, output, 512) == 1);
    assert(output[0] == 0xff && output[1] == 0x7f);
    FillMacroblock(codes, 512);
    input.next = codes;
    assert(Psyz_MdecDecodeMacroblock(&input, &env, 0x38000000, output, 512) == 1);
    assert(output[0] == 0 && output[1] == 0);

    input.next = codes;
    assert(Psyz_MdecDecodeMacroblock(&input, &env, 0x38000000, output, 511) == -1);
    input.end = codes + 11;
    assert(Psyz_MdecDecodeMacroblock(&input, &env, 0x38000000, output, 512) == -1);
    CheckDma();
    puts("Bounded MDEC color output, signed DC, bit15 and truncation checks passed.");
    return 0;
}
