#ifndef MGS_CADENCE_H
#define MGS_CADENCE_H

typedef struct {
    int eye[3];
    int target[3];
} MgsCadenceCamera;

int MgsCadenceConfigure(const char *path, int overlay);
int MgsCadenceVSync(void);
int MgsCadenceClose(void);
void MgsCadenceMenuReady(void);
void MgsCadenceDemoStart(int total_frames);
void MgsCadenceDemoDesired(int frame);
void MgsCadenceDemoApplied(int frame, const MgsCadenceCamera *camera);
void MgsCadenceDemoEnd(void);

#endif
