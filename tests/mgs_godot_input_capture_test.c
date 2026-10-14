#include "transport.h"
#include <psyz/input.h>
#include <assert.h>
#include <string.h>

static bool captured;
bool MgsGodotInputCaptured(void) { return captured; }

int main(void)
{
    unsigned char pad[8] = {0, PSYZ_CTRL_ANALOG_PAD, 0, 0, 1, 255, 0, 64};
    unsigned char original[8];
    memcpy(original, pad, sizeof(pad));
    MgsGodotFilterPad(0, pad);
    assert(!memcmp(original, pad, sizeof(pad)));
    captured = true;
    for (unsigned port = 0; port < 2; ++port) {
        memcpy(pad, original, sizeof(pad));
        MgsGodotFilterPad(port, pad);
        assert(pad[0] == 0 && pad[1] == PSYZ_CTRL_ANALOG_PAD);
        assert(pad[2] == 255 && pad[3] == 255);
        for (unsigned axis = 4; axis < 8; ++axis) assert(pad[axis] == 128);
    }
    captured = false;
    for (unsigned port = 0; port < 2; ++port) {
        memcpy(pad, original, sizeof(pad));
        MgsGodotFilterPad(port, pad);
        assert(pad[2] == 255 && pad[3] == 255 && pad[4] == 128);
        MgsGodotFilterPad(port, pad);
        memcpy(pad, original, sizeof(pad));
        MgsGodotFilterPad(port, pad);
        assert(!memcmp(original, pad, sizeof(pad)));
    }
    captured = true;
    unsigned char digital[8] = {0, PSYZ_CTRL_DIGITAL_PAD, 0, 0, 0, 0, 0, 0};
    MgsGodotFilterPad(0, digital);
    assert(digital[2] == 255 && digital[3] == 255 && digital[4] == 0);
    unsigned char disconnected[8];
    memset(disconnected, 255, sizeof(disconnected));
    MgsGodotFilterPad(0, disconnected);
    for (unsigned i = 0; i < 8; ++i) assert(disconnected[i] == 255);
    captured = false;
    unsigned char stick[8] = {0, PSYZ_CTRL_ANALOG_STICK, 255, 255, 255, 128, 128, 128};
    MgsGodotFilterPad(0, stick);
    assert(stick[4] == 128);
    MgsGodotFilterPad(0, stick);
    stick[4] = 240;
    MgsGodotFilterPad(0, stick);
    assert(stick[4] == 240);
    return 0;
}
