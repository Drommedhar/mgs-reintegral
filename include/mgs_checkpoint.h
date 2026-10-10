#ifndef MGS_CHECKPOINT_H
#define MGS_CHECKPOINT_H

int MgsCheckpointConfigure(const char *load_path);
int MgsCheckpointWrite(const char *save_path);
int MgsCheckpointDisc(void);
const char *MgsCheckpointInitialStage(const char *fallback);
int MgsCheckpointBoot(const char *requested);

#endif
