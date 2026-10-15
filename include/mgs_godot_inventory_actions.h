#ifndef MGS_GODOT_INVENTORY_ACTIONS_H
#define MGS_GODOT_INVENTORY_ACTIONS_H

#include "mgs_inventory_actions.h"

int MgsGodotOwnsInventoryActions(void);
void MgsGodotInventoryActionsReset(void);
void MgsGodotInventoryActionsBegin(void);
void MgsGodotInventoryActionsEnd(void);
void MgsGodotInventoryActionsView(const MgsInventoryActionView *view);
void MgsGodotPublishInventoryActions(void);

#endif
