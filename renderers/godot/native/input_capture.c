#include "transport.h"
#include <psyz/input.h>

void MgsGodotFilterPad(unsigned port, unsigned char *frame)
{
    static bool released[2] = {true, true};
    if (port >= 2) return;
    bool capture = MgsGodotInputCaptured();
    if (capture) released[port] = false;
    if (frame[0] != 0 || (frame[1] != PSYZ_CTRL_DIGITAL_PAD &&
        frame[1] != PSYZ_CTRL_ANALOG_PAD && frame[1] != PSYZ_CTRL_ANALOG_STICK)) return;
    bool analog = frame[1] != PSYZ_CTRL_DIGITAL_PAD;
    bool neutral = frame[2] == 255 && frame[3] == 255;
    if (analog) {
        for (unsigned axis = 4; axis < 8; ++axis)
            if (frame[axis] < 112 || frame[axis] > 144) neutral = false;
    }
    if (!capture && neutral) released[port] = true;
    if (released[port]) return;
    frame[2] = frame[3] = 255;
    if (analog) {
        for (unsigned axis = 4; axis < 8; ++axis) frame[axis] = 128;
    }
}
