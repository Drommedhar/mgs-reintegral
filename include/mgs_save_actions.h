#ifndef MGS_SAVE_ACTIONS_H
#define MGS_SAVE_ACTIONS_H

#include <stdint.h>

enum {
    MGS_SAVE_SELECT = 1, MGS_SAVE_ACTIVATE, MGS_SAVE_NEW,
    MGS_SAVE_CONFIRM_ACTION, MGS_SAVE_BACK, MGS_SAVE_CONTINUE
};
enum {
    MGS_SAVE_ACTION_NONE, MGS_SAVE_ACTION_PENDING, MGS_SAVE_ACTION_APPLIED,
    MGS_SAVE_ACTION_STALE, MGS_SAVE_ACTION_BUSY, MGS_SAVE_ACTION_INVALID
};

typedef struct {
    uint32_t schema, id, epoch, generation, revision, state, message, selected_id;
    uint32_t action, target_id;
} MgsSaveAction;

typedef struct { uint32_t id, status; } MgsSaveActionResult;

int MgsSaveMenuSubmit(const MgsSaveAction *action);
MgsSaveActionResult MgsSaveMenuActionStatus(void);

#endif
