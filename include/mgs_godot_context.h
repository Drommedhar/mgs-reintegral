#ifndef MGS_GODOT_CONTEXT_H
#define MGS_GODOT_CONTEXT_H
#include <stdint.h>
uint32_t MgsGodotSceneEpoch(void);

void MgsGodotStageChanged(const char *name);
void MgsGodotPublishContext(void);
uint32_t MgsGodotVisionMode(void);
int MgsGodotOwnsNightVision(void);
int MgsGodotOwnsThermalVision(void);

#endif
