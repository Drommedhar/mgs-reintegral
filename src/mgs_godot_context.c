#include "mgs_native.h"
#include "mgs_godot_context.h"
#include "mgs_godot_cinematic.h"
#include "mgs_safety.h"
#include "mgs_godot_scene.h"
#include "mgs_loading.h"
#include "game/game.h"
#include "libgv/libgv.h"
#include "transport.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint32_t epoch;
static uint64_t sequence;
static char stage[8];
static uint32_t published_disc;

uint32_t MgsGodotSceneEpoch(void) { return epoch; }

uint32_t MgsGodotVisionMode(void)
{
    return GM_GameStatus & STATE_THERMG ? 2u : GM_GameStatus & STATE_NVG ? 1u : 0u;
}

int MgsGodotOwnsNightVision(void)
{
    return MgsGodotSceneEnabled() && MgsGodotHasCapability(16384) && MgsGodotVisionMode() == 1;
}

int MgsGodotOwnsThermalVision(void)
{
    return MgsGodotSceneEnabled() && MgsGodotHasCapability(32768) && MgsGodotVisionMode() == 2;
}

void MgsGodotStageChanged(const char *name)
{
    size_t length = strlen(name);
    if (length > sizeof(stage) || epoch == UINT32_MAX) {
        fputs("Godot context: invalid stage or exhausted generation.\n", stderr);
        exit(EXIT_FAILURE);
    }
    ++epoch;
    memset(stage, 0, sizeof(stage));
    memcpy(stage, name, length);
}

void MgsGodotPublishContext(void)
{
    uint32_t disc = (uint32_t)MgsSafetyDiscNumber();
    if (published_disc && disc != published_disc) {
        char previous_stage[9] = {0};
        memcpy(previous_stage, stage, sizeof(stage));
        MgsGodotStageChanged(previous_stage);
    }
    published_disc = disc;
    if (sequence == INT64_MAX) {
        fputs("Godot context: exhausted sample sequence.\n", stderr);
        exit(EXIT_FAILURE);
    }
    ++sequence;
    const int disc_identity = MgsGodotHasCapability(256);
    const int cinematic = MgsGodotHasCapability(512);
    const int vision = MgsGodotHasCapability(16384);
    const int loading_context = vision && MgsGodotSelectedMinor() >= 35;
    const uint32_t words[] = {loading_context ? 6u : vision ? 5u : cinematic ? 4u : disc_identity ? 3u : 2u, epoch, (uint32_t)sequence, (uint32_t)(sequence >> 32),
        (uint32_t)GV_Time, (uint32_t)GV_PauseLevel, (uint32_t)GV_PassageTime};
    unsigned char tail[68] = {0};
    memcpy(tail, stage, sizeof(stage));
    MgsGodotCopySessionId(tail + sizeof(stage));
    memcpy(tail + 24, &disc, sizeof(disc));
    MgsGodotCinematic clip = MgsGodotCinematicState();
    _Static_assert(sizeof(clip) == 24, "Cinematic context layout");
    memcpy(tail + 28, &clip, sizeof(clip));
    const uint32_t mode = MgsGodotVisionMode();
    memcpy(tail + 52, &mode, sizeof(mode));
    const uint32_t loading = MgsLoadingActive();
    memcpy(tail + 56, &loading, sizeof(loading));
    const char *next_stage = MgsLoadingStage();
    size_t stage_length = strlen(next_stage);
    if (stage_length > 8) stage_length = 8;
    memcpy(tail + 60, next_stage, stage_length);
    MgsGodotQueue(MGS_GODOT_CONTEXT, words, sizeof(words), tail, loading_context ? 68 : vision ? 56 : cinematic ? 52 : disc_identity ? 28 : 24);
}
