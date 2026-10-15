#include "mgs_godot_cinematic.h"
#include "mgs_godot_context.h"
#include <stdio.h>
#include <stdlib.h>

static const void *current_owner;
static uint32_t source_disc, source_sector, source_epoch;
static MgsGodotCinematic current;

void MgsGodotCinematicSelect(unsigned kind, unsigned disc, unsigned sector)
{
    source_disc = kind == 5 && (disc == 1 || disc == 2) ? disc : 0;
    source_sector = sector;
}

void MgsGodotCinematicOpen(const void *owner, int streamed)
{
    if (current.generation == UINT32_MAX) {
        fputs("Godot cinematic generation exhausted.\n", stderr);
        exit(EXIT_FAILURE);
    }
    current = (MgsGodotCinematic){current.generation + 1,
        streamed ? source_disc : 0, source_sector, 0, -1, 0};
    source_disc = 0;
    source_epoch = MgsGodotSceneEpoch();
    current_owner = owner;
}

void MgsGodotCinematicStart(const void *owner, int total)
{
    if (owner != current_owner || total < 0) return;
    current.total = (uint32_t)total;
    current.active = current.disc != 0;
}

void MgsGodotCinematicApply(const void *owner, int frame)
{
    if (owner == current_owner && current.active && frame >= 0 && (uint32_t)frame <= current.total)
        current.frame = frame;
}

void MgsGodotCinematicEnd(const void *owner)
{
    if (owner != current_owner) return;
    current.active = 0;
    current_owner = NULL;
}

MgsGodotCinematic MgsGodotCinematicState(void)
{
    MgsGodotCinematic sample = current;
    if (source_epoch != MgsGodotSceneEpoch()) sample.active = 0;
    return sample;
}
