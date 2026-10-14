#include "mgs_godot_radar.h"
#include "mgs_radar.h"
#include "mgs_godot_scene.h"
#include "mgs_godot_context.h"
#include "transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint32_t epoch;
static unsigned char records[MGS_RADAR_CONTACT_LIMIT * (sizeof(MgsRadarContact) + sizeof(MgsRadarSight))
                             + MGS_RADAR_WALL_LIMIT * sizeof(MgsRadarWall)];

int MgsGodotOwnsRadar(void)
{
    return MgsGodotSceneEnabled() && MgsGodotHasCapability(MGS_GODOT_RADAR_CAPABILITY);
}

void MgsGodotResetRadar(void)
{
    epoch = MgsGodotSceneEpoch();
    int owns = MgsGodotOwnsRadar();
    MgsRadarBeginFrame(owns, owns);
}

void MgsGodotPublishRadar(void)
{
    if (!MgsGodotOwnsRadar()) return;
    if (epoch != MgsGodotSceneEpoch()) MgsGodotResetRadar();
    const MgsRadarView *view = MgsRadarGetView();
    if (view->frame.active && view->frame.mode == MGS_RADAR_CUSTOM) {
        fputs("Godot radar: custom native provider has no semantic adapter.\n", stderr);
        exit(EXIT_FAILURE);
    }
    struct {
        uint32_t schema, epoch, contacts, sights, walls, contact_stride, sight_stride, wall_stride;
        unsigned char session[16];
        MgsRadarFrame frame;
    } header = {1, epoch, view->contact_count, view->sight_count, view->wall_count, 152, 40, 24, {0}, view->frame};
    _Static_assert(sizeof(header) == 104, "Radar wire header");
    _Static_assert(sizeof(MgsRadarContact) == 152 && sizeof(MgsRadarSight) == 40 && sizeof(MgsRadarWall) == 24,
                   "Radar wire records");
    MgsGodotCopySessionId(header.session);
    uint32_t contacts = view->contact_count * sizeof(MgsRadarContact);
    uint32_t sights = view->sight_count * sizeof(MgsRadarSight);
    uint32_t walls = view->wall_count * sizeof(MgsRadarWall);
    memcpy(records, view->contacts, contacts);
    memcpy(records + contacts, view->sights, sights);
    memcpy(records + contacts + sights, view->walls, walls);
    MgsGodotQueue(MGS_GODOT_RADAR, &header, sizeof(header), records, contacts + sights + walls);
}
