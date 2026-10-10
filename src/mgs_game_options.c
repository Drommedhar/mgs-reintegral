#include "mgs_native.h"
#include "mgs_game_options.h"
#include "game/game.h"

static int automatic_card;

void MgsGameOptionsConfigure(int auto_card)
{
    automatic_card = auto_card != 0;
}

int MgsAutoCardOperand(const char *expression, int value, int compared_value)
{
    const unsigned char *token = (const unsigned char *)expression;
    if (automatic_card && GM_CardFlag > 0 && compared_value == IT_Card && token &&
        token[0] == 0x11 && token[1] == 0x80 && token[2] == 0 && token[3] == 0x1e)
        return IT_Card;
    return value;
}
