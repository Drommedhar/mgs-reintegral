#ifndef MGS_OPTIONS_ACTIONS_H
#define MGS_OPTIONS_ACTIONS_H

#include "mgs_godot_options.h"

#define MGS_OPTIONS_ACTIONS_CAPABILITY 268435456u

enum MgsOptionsActionKind {
    MGS_OPTIONS_SELECT = 1, MGS_OPTIONS_SET, MGS_OPTIONS_ACTIVATE, MGS_OPTIONS_BACK
};
enum MgsOptionsActionStatus {
    MGS_OPTIONS_NONE, MGS_OPTIONS_PENDING, MGS_OPTIONS_APPLIED,
    MGS_OPTIONS_STALE, MGS_OPTIONS_BUSY, MGS_OPTIONS_INVALID
};
typedef struct {
    uint32_t schema, id, epoch, generation, revision, kind, target, value;
} MgsOptionsAction;
typedef struct { uint32_t id, status; } MgsOptionsActionResult;

uint32_t MgsOptionsActionsView(MgsOptionsFrame view, uint32_t epoch, uint32_t generation);
int MgsOptionsActionsSubmit(const MgsOptionsAction *action);
int MgsOptionsActionsTake(MgsOptionsFrame view, MgsOptionsAction *action);
void MgsOptionsActionsComplete(uint32_t status);
MgsOptionsActionResult MgsOptionsActionsResult(void);

#endif
