#include "mgs_godot_bars.h"
#include "mgs_godot_context.h"
#include "mgs_godot_scene.h"
#include "transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static MgsGodotBar bars[MGS_GODOT_BAR_LIMIT];
static uint32_t count, epoch;

int MgsGodotOwnsBars(void)
{
    return MgsGodotSceneEnabled() && MgsGodotHasCapability(MGS_GODOT_BARS_CAPABILITY);
}

void MgsGodotResetBars(void)
{
    count = 0;
    epoch = MgsGodotSceneEpoch();
}

void MgsGodotSubmitBar(const MgsGodotBar *bar)
{
    if (!MgsGodotOwnsBars()) return;
    if (epoch != MgsGodotSceneEpoch()) MgsGodotResetBars();
    if (count == MGS_GODOT_BAR_LIMIT || !memchr(bar->name, 0, sizeof(bar->name))) {
        fputs("Godot UI: status bar capacity or name limit exceeded.\n", stderr);
        exit(EXIT_FAILURE);
    }
    bars[count++] = *bar;
}

void MgsGodotPublishBars(void)
{
    if (!MgsGodotOwnsBars()) return;
    if (epoch != MgsGodotSceneEpoch()) MgsGodotResetBars();
    struct {
        uint32_t schema, epoch, count, stride;
        unsigned char session[16];
    } header = {1, epoch, count, sizeof(MgsGodotBar), {0}};
    _Static_assert(sizeof(header) == 32, "Status bar header wire layout");
    _Static_assert(sizeof(MgsGodotBar) == 72, "Status bar record wire layout");
    MgsGodotCopySessionId(header.session);
    MgsGodotQueue(MGS_GODOT_BARS, &header, sizeof(header), bars, count * sizeof(*bars));
}
