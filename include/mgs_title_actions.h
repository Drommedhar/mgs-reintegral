#ifndef MGS_TITLE_ACTIONS_H
#define MGS_TITLE_ACTIONS_H

#include "mgs_godot_title.h"

#define MGS_TITLE_ACTIONS_CAPABILITY 536870912u
enum MgsTitleActionKind { MGS_TITLE_SELECT = 1, MGS_TITLE_ACTIVATE, MGS_TITLE_BACK };
enum MgsTitleActionStatus {
    MGS_TITLE_NONE, MGS_TITLE_PENDING, MGS_TITLE_APPLIED,
    MGS_TITLE_STALE, MGS_TITLE_BUSY, MGS_TITLE_INVALID
};
typedef struct {
    uint32_t schema, id, epoch, generation, revision, kind, target;
} MgsTitleAction;
typedef struct { uint32_t id, status; } MgsTitleActionResult;

uint32_t MgsTitleActionsView(MgsTitleFrame view, unsigned ready, uint32_t epoch, uint32_t generation);
int MgsTitleActionsSubmit(const MgsTitleAction *action);
int MgsTitleActionsTake(MgsTitleFrame view, unsigned ready, MgsTitleAction *action);
void MgsTitleActionsComplete(uint32_t status);
MgsTitleActionResult MgsTitleActionsResult(void);

#endif
