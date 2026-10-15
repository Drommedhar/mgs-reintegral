#include "mgs_godot_display.h"
#include "mgs_video.h"
#include "transport.h"
#include <stdio.h>
#include <stdlib.h>

void MgsGodotDisplayTick(void)
{
    static uint32_t acknowledged, status;
    if (!MgsGodotHasCapability(MGS_GODOT_DISPLAY_CAPABILITY)) return;
    for (unsigned attempt = 0; attempt < 4; ++attempt) {
        MgsVideoOptions options = MgsVideoGetOptions();
        struct {
            uint32_t schema, acknowledged, status, supported;
            unsigned char session[16];
            uint32_t width, height, widescreen, reference;
        } state = {1, acknowledged, status, MgsVideoCapturesOutput(), {0},
                   options.width, options.height, options.widescreen, MgsVideoReferenceRequired()};
        uint32_t request[5];
        _Static_assert(sizeof(state) == 48, "Display state wire layout");
        MgsGodotCopySessionId(state.session);
        MgsGodotExchange(MGS_GODOT_DISPLAY, &state, sizeof(state), request, sizeof(request));
        if (request[0] != 1 || (request[1] && request[1] <= acknowledged) ||
            (!request[1] && (request[2] || request[3] || request[4]))) {
            fputs("Invalid Godot display request identity.\n", stderr);
            exit(EXIT_FAILURE);
        }
        if (!request[1]) return;
        acknowledged = request[1];
        status = MgsVideoSetProjection(request[2], request[3], (int)request[4]) ? 0 : 1;
    }
    fputs("Godot display transaction did not settle before the next actor update.\n", stderr);
    exit(EXIT_FAILURE);
}
