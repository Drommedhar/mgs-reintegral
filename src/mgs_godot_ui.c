#include "mgs_godot_ui.h"
#include "mgs_godot_context.h"
#include "mgs_godot_scene.h"
#include "transport.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    uint32_t schema, epoch, mode, flags, heading, timer, layers;
    int32_t offsets[6];
    unsigned char session[16];
} GogglesState;

static GogglesState current;
static const void *current_owner;

int MgsGodotOwnsGoggles(void)
{
    return MgsGodotSceneEnabled() && MgsGodotHasCapability(MGS_GODOT_UI_CAPABILITY);
}

static void ResetEpoch(void)
{
    if (current.epoch == MgsGodotSceneEpoch()) return;
    memset(&current, 0, sizeof(current));
    current.epoch = MgsGodotSceneEpoch();
    current_owner = NULL;
}

void MgsGodotGogglesUpdate(const void *owner, int mode, int timer, int scan, int heading)
{
    if (!MgsGodotOwnsGoggles()) return;
    ResetEpoch();
    if (current_owner && current_owner != owner) {
        fputs("Godot UI: simultaneous goggles owners are unsupported.\n", stderr);
        exit(EXIT_FAILURE);
    }
    current_owner = owner;
    current.mode = mode;
    current.flags = 1u | (timer >= 6 ? 2u : 0u) | (timer >= 6 && scan > 0 ? 4u : 0u);
    current.heading = (unsigned)heading & 4095u;
    current.timer = (unsigned)timer;
}

void MgsGodotGogglesRemove(const void *owner)
{
    if (current_owner != owner) return;
    current_owner = NULL;
    current.mode = current.flags = current.heading = current.timer = 0;
    current.layers = 0;
    memset(current.offsets, 0, sizeof(current.offsets));
}

int MgsGodotGogglesLayer(unsigned source)
{
    if (source >= 0x8504 && source <= 0x8506) return (int)(source - 0x8504);
    if (source >= 0x84db && source <= 0x84dd) return (int)(source - 0x84db) + 3;
    return -1;
}

void MgsGodotGogglesLayerUpdate(int layer, int visible, int x, int y)
{
    ResetEpoch();
    if (layer < 0 || layer >= 6 || current.mode != (unsigned)(layer / 3 + 1)) return;
    layer %= 3;
    if (visible) current.layers |= 1u << layer;
    else current.layers &= ~(1u << layer);
    current.offsets[layer * 2] = visible ? x : 0;
    current.offsets[layer * 2 + 1] = visible ? y : 0;
}

void MgsGodotPublishUi(void)
{
    if (!MgsGodotOwnsGoggles()) return;
    ResetEpoch();
    current.schema = 1;
    MgsGodotCopySessionId(current.session);
    _Static_assert(sizeof(current) == 68, "Goggles UI wire layout");
    MgsGodotQueue(MGS_GODOT_UI, &current, sizeof(current), NULL, 0);
}
