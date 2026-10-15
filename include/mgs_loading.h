#ifndef MGS_LOADING_H
#define MGS_LOADING_H

int MgsLoadingConfigure(int enabled);
void MgsLoadingBegin(const char *stage);
void MgsLoadingEnd(void);
int MgsLoadingActive(void);
const char *MgsLoadingStage(void);

#endif
