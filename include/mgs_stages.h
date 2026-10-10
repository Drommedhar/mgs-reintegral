#ifndef MGS_STAGES_H
#define MGS_STAGES_H

int MgsNativeConfigureStart(const char *name, int map);
const char *MgsNativeBootStage(const char *requested);
int MgsNativeBootMap(int requested);
void *MgsNativeStageTable(void);
void MgsNativeSelectStage(const char *name);
void MgsNativeReloadOverlay(void);
int MgsNativeStageAvailable(const char *name);
const char *MgsNativeCurrentStage(void);
const char *MgsNativeResourceStage(void);

#endif
