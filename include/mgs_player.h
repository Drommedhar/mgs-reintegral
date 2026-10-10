#ifndef MGS_PLAYER_H
#define MGS_PLAYER_H

typedef struct {
    short x, y, z, yaw;
} MgsPlayerPose;

void MgsNativeRememberPlayerPose(short x, short y, short z, short yaw);
MgsPlayerPose MgsNativeLastPlayerPose(void);

#endif
