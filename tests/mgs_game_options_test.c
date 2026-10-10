#include "mgs_native.h"
#include "mgs_game_options.h"
#include "game/game.h"
#include "libgcl/libgcl.h"
#include <assert.h>

short linkvarbuf[MAX_LINKVARBUF];
unsigned long psyz_scratchpad[256];

char *GCL_GetNextValue(char *data, int *type, int *value)
{
    *type = (unsigned char)*data++;
    if (*type == (GCL_VAR | GCL_SHORT)) {
        assert((unsigned char)data[0] == 0x80);
        *value = linkvarbuf[(unsigned char)data[2] / 2];
        return data + 3;
    }
    assert(*type == GCL_BYTE);
    *value = (unsigned char)*data++;
    return data;
}

char *GCL_SetVar(char *data, int value)
{
    linkvarbuf[(unsigned char)data[3] / 2] = value;
    return data + 4;
}

static int compare_item(int item, int op, int reverse)
{
    char expression[] = {0x11, (char)0x80, 0, 0x1e, GCL_BYTE, (char)item,
                         GCL_OP, (char)op, GCL_OP, 0};
    if (reverse) {
        memmove(expression + 2, expression, 4);
        expression[0] = GCL_BYTE;
        expression[1] = (char)item;
    }
    return GCL_Expr(expression, NULL);
}

int main(void)
{
    MgsGameOptionsConfigure(0);
    GM_Item = IT_Stealth;
    GM_CardFlag = 6;
    assert(!compare_item(IT_Card, 9, 0));
    MgsGameOptionsConfigure(1);
    for (int reverse = 0; reverse < 2; ++reverse) {
        assert(compare_item(IT_Card, 9, reverse));
        assert(!compare_item(IT_Card, 10, reverse));
        assert(compare_item(IT_Stealth, 9, reverse));
        assert(!compare_item(IT_PalKey, 9, reverse));
    }
    assert(GM_Item == IT_Stealth && GM_CardFlag == 6);
    GM_CardFlag = 0;
    assert(!compare_item(IT_Card, 9, 0));
    GM_CardFlag = -1;
    assert(!compare_item(IT_Card, 9, 0));
    GM_CardFlag = 1;
    assert(compare_item(IT_Card, 9, 0));
    assert(GM_CardFlag < 2);
    const char unrelated[] = {0x11, 0, 0, 0x1e};
    assert(MgsAutoCardOperand(unrelated, 10, IT_Card) == 10);
    assert(MgsAutoCardOperand(NULL, 10, IT_Card) == 10);
    puts("Auto-card expressions preserve other equipment, ownership and card level.");
    return 0;
}
