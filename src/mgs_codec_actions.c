#include "mgs_codec_actions.h"
#include <string.h>

static MgsCodecActionView current;
static uint32_t current_epoch, current_generation, revision;
static uintptr_t current_item;
static MgsCodecAction queued;
static MgsCodecActionResult result;

uint32_t MgsCodecActionsView(MgsCodecActionView view, uint32_t epoch, uint32_t generation, uintptr_t item)
{
    if (epoch != current_epoch || generation != current_generation || item != current_item ||
        memcmp(&current, &view, sizeof(view))) {
        if (++revision == 0) ++revision;
        current = view;
        current_epoch = epoch;
        current_generation = generation;
        current_item = item;
    }
    if (!view.active && result.status == MGS_CODEC_PENDING) result.status = MGS_CODEC_STALE;
    return revision;
}

static uint32_t Check(const MgsCodecAction *action)
{
    if (action->epoch != current_epoch || action->generation != current_generation ||
        action->revision != revision) return MGS_CODEC_STALE;
    if (!current.active) return MGS_CODEC_BUSY;
    if (action->kind < MGS_CODEC_OPEN || action->kind > MGS_CODEC_BACK ||
        !(current.allowed & (1u << action->kind))) return MGS_CODEC_INVALID;
    if (action->kind == MGS_CODEC_TUNE)
        return action->target >= 14000 && action->target <= 14199 ? MGS_CODEC_PENDING : MGS_CODEC_INVALID;
    if (action->kind == MGS_CODEC_SELECT || action->kind == MGS_CODEC_CONFIRM)
        return action->target < current.count ? MGS_CODEC_PENDING : MGS_CODEC_INVALID;
    return action->target ? MGS_CODEC_INVALID : MGS_CODEC_PENDING;
}

int MgsCodecActionsSubmit(const MgsCodecAction *action)
{
    if (action->schema != 1 || !action->id || action->id <= result.id || result.status == MGS_CODEC_PENDING) return 0;
    queued = *action;
    result = (MgsCodecActionResult){action->id, Check(action)};
    return 1;
}

int MgsCodecActionsTake(MgsCodecAction *action)
{
    if (result.status != MGS_CODEC_PENDING) return 0;
    result.status = Check(&queued);
    if (result.status != MGS_CODEC_PENDING) return 0;
    *action = queued;
    return 1;
}

void MgsCodecActionsComplete(void) { result.status = MGS_CODEC_APPLIED; }
MgsCodecActionResult MgsCodecActionsResult(void) { return result; }
