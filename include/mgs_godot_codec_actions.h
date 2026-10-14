#ifndef MGS_GODOT_CODEC_ACTIONS_H
#define MGS_GODOT_CODEC_ACTIONS_H

#include "mgs_codec_actions.h"

void MgsGodotCodecActionsReset(void);
void MgsGodotCodecActionsBegin(void);
void MgsGodotCodecActionsEnd(void);
void MgsGodotCodecActionsView(MgsCodecActionView view, uintptr_t item);
void MgsGodotPublishCodecActions(void);

#endif
