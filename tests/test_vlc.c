#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <libpress.h>
#include "vlc.h"

int main(void)
{
    static PsyzVlcTable table;
    static const unsigned char flat_macroblock[] = {
        6, 0, 0, 0x38, 1, 0, 2, 0,
        0x20, 0, 0, 2, 2, 0x20, 0x20, 0, 0, 2
    };
    static const unsigned char ac_block[] = {
        2, 0, 0, 0x38, 2, 0, 2, 0, 0x34, 2, 0x80, 0xff
    };
    static const unsigned char escape_block[] = {
        2, 0, 0, 0x38, 2, 0, 2, 0, 1, 2, 0xfe, 0x0f, 0xf0, 0x9f
    };
    uint32_t output[8];
    unsigned char malformed[sizeof(flat_macroblock)];
    static struct {
        DECDCTTAB table;
        uint32_t guard;
    } public_table;
    public_table.guard = 0x12345678;
    DecDCTvlcBuild(public_table.table);
    assert(public_table.guard == 0x12345678);
    assert(Psyz_DecDCTvlcBounded(flat_macroblock, sizeof(flat_macroblock),
                               (u_long *)output, 7, public_table.table) == 0);
    assert(output[0] == 0x38000006 && output[6] == 0xfe000400);
    Psyz_VlcBuild(&table);
    memset(output, 0xa5, sizeof(output));
    assert(Psyz_VlcDecode(flat_macroblock, sizeof(flat_macroblock), output, 7, &table) == 0);
    assert(output[0] == 0x38000006);
    for (unsigned i = 1; i < 7; ++i)
        assert(output[i] == 0xfe000400);
    assert(output[7] == 0xa5a5a5a5);
    assert(Psyz_VlcDecode(ac_block, sizeof(ac_block), output, 3, &table) == 0);
    assert(output[1] == 0x00010808 && output[2] == 0xfe00fe00);
    assert(Psyz_VlcDecode(escape_block, sizeof(escape_block), output, 3, &table) == 0);
    assert(output[1] == 0x0ffe0808 && output[2] == 0xfe00fe00);
    assert(Psyz_VlcDecode(flat_macroblock, sizeof(flat_macroblock), output, 6, &table) == -1);
    assert(Psyz_VlcDecode(flat_macroblock, 9, output, 7, &table) == -1);
    memcpy(malformed, flat_macroblock, sizeof(malformed));
    malformed[6] = 3;
    assert(Psyz_VlcDecode(malformed, sizeof(malformed), output, 7, &table) == -1);
    memset(malformed + 8, 0, sizeof(malformed) - 8);
    assert(Psyz_VlcDecode(malformed, sizeof(malformed), output, 7, &table) == -1);
    puts("Bounded VLC v2 decode, output guard and malformed input checks passed.");
    return 0;
}
