#ifndef MGS_CODEC_ACTIONS_H
#define MGS_CODEC_ACTIONS_H

#include <stdint.h>

#define MGS_CODEC_ACTIONS_CAPABILITY 1073741824u
enum MgsCodecActionKind {
    MGS_CODEC_OPEN = 1, MGS_CODEC_TUNE, MGS_CODEC_CALL, MGS_CODEC_MEMORY,
    MGS_CODEC_SELECT, MGS_CODEC_CONFIRM, MGS_CODEC_ADVANCE, MGS_CODEC_SKIP, MGS_CODEC_BACK
};
enum MgsCodecActionStatus {
    MGS_CODEC_NONE, MGS_CODEC_PENDING, MGS_CODEC_APPLIED,
    MGS_CODEC_STALE, MGS_CODEC_BUSY, MGS_CODEC_INVALID
};
typedef struct {
    uint32_t active, opened, mode, frequency, allowed, selection, count;
} MgsCodecActionView;
typedef struct {
    uint32_t schema, id, epoch, generation, revision, kind, target;
} MgsCodecAction;
typedef struct { uint32_t id, status; } MgsCodecActionResult;

uint32_t MgsCodecActionsView(MgsCodecActionView view, uint32_t epoch, uint32_t generation, uintptr_t item);
int MgsCodecActionsSubmit(const MgsCodecAction *action);
int MgsCodecActionsTake(MgsCodecAction *action);
void MgsCodecActionsComplete(void);
MgsCodecActionResult MgsCodecActionsResult(void);

#endif
