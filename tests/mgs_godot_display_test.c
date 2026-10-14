#include "mgs_godot_display.h"
#include "mgs_video.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static MgsVideoOptions current = {640, 480, 0, 0};
static bool capable = true;
static unsigned exchanges, requests, failure, last_status, next_id;
static uint32_t desired[3] = {1280, 720, 1};

bool MgsGodotHasCapability(unsigned bit) { assert(bit == MGS_GODOT_DISPLAY_CAPABILITY); return capable; }
void MgsGodotCopySessionId(unsigned char session[16]) { memset(session, 7, 16); }
MgsVideoOptions MgsVideoGetOptions(void) { return current; }
int MgsVideoCapturesOutput(void) { return 1; }
int MgsVideoReferenceRequired(void) { return 1; }
int MgsVideoSetProjection(unsigned width, unsigned height, int wide)
{
    if (failure) return 0;
    current = (MgsVideoOptions){width, height, wide, 0};
    return 1;
}
void MgsGodotExchange(uint32_t op, const void *data, uint32_t size, void *reply, uint32_t rsize)
{
    uint32_t wire[12], result[5] = {1, 0, 0, 0, 0};
    assert(op == MGS_GODOT_DISPLAY && size == sizeof(wire) && rsize == sizeof(result));
    memcpy(wire, data, size);
    assert(wire[0] == 1 && wire[1] == next_id && wire[3] == 1 && wire[11] == 1);
    assert(wire[8] == current.width && wire[9] == current.height && wire[10] == (unsigned)current.widescreen);
    assert(wire[4] == 0x07070707 && wire[7] == 0x07070707);
    last_status = wire[2];
    if (requests) {
        --requests;
        result[1] = ++next_id;
        memcpy(result + 2, desired, sizeof(desired));
    }
    memcpy(reply, result, rsize);
    ++exchanges;
}
int main(void)
{
    capable = false;
    MgsGodotDisplayTick();
    assert(exchanges == 0);
    capable = true;
    MgsGodotDisplayTick();
    assert(exchanges == 1);
    requests = 1;
    MgsGodotDisplayTick();
    assert(exchanges == 3 && !last_status && current.width == 1280 && current.widescreen);
    failure = 1;
    desired[0] = 2560;
    requests = 1;
    MgsGodotDisplayTick();
    assert(exchanges == 5 && last_status == 1 && current.width == 1280);
    failure = 0;
    desired[0] = 640; desired[1] = 480; desired[2] = 0;
    requests = 1;
    MgsGodotDisplayTick();
    assert(exchanges == 7 && !last_status && current.width == 640 && !current.widescreen);
    puts("Display exchange: session, acknowledgement, rejection and restoration pass.");
    return 0;
}
