#include "mgs_radar.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static MgsRadarView view;
static int enabled;
static int owns_drawing;

void MgsRadarBeginFrame(int collect, int owned)
{
    enabled = collect;
    owns_drawing = collect && owned;
    memset(&view.frame, 0, sizeof(view.frame));
    view.contact_count = view.sight_count = view.wall_count = 0;
}

int MgsRadarOwnsDrawing(void) { return owns_drawing; }

void MgsRadarPresent(MgsRadarFrame frame)
{
    if (enabled) view.frame = frame;
}

void MgsRadarShowMap(void)
{
    if (view.frame.active) view.frame.map_visible = 1;
}

void MgsRadarSetNoise(uint32_t seed)
{
    if (!view.frame.active) return;
    view.frame.has_noise = 1;
    view.frame.noise_seed = seed;
}

void MgsRadarSetCountdown(int ticks)
{
    if (!view.frame.active) return;
    view.frame.mode = MGS_RADAR_COUNTDOWN;
    view.frame.countdown = ticks;
}

static void CheckCapacity(uint32_t count, uint32_t limit)
{
    if (count < limit) return;
    fputs("Radar presentation capacity exceeded.\n", stderr);
    exit(EXIT_FAILURE);
}

void MgsRadarAddContact(const MgsRadarContact *contact)
{
    if (!view.frame.active) return;
    CheckCapacity(view.contact_count, MGS_RADAR_CONTACT_LIMIT);
    view.contacts[view.contact_count++] = *contact;
}

void MgsRadarAddSight(const MgsRadarSight *sight)
{
    if (!view.frame.active) return;
    CheckCapacity(view.sight_count, MGS_RADAR_CONTACT_LIMIT);
    view.sights[view.sight_count++] = *sight;
}

void MgsRadarAddWall(const MgsRadarWall *wall)
{
    if (!view.frame.active) return;
    CheckCapacity(view.wall_count, MGS_RADAR_WALL_LIMIT);
    view.walls[view.wall_count++] = *wall;
}

const MgsRadarView *MgsRadarGetView(void)
{
    return &view;
}
