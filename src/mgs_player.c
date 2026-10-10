#include <stdio.h>
#include <stdlib.h>
#include "mgs_player.h"

static MgsPlayerPose last_pose;
static int pose_recorded;

void MgsNativeRememberPlayerPose(short x, short y, short z, short yaw)
{
    last_pose = (MgsPlayerPose){x, y, z, yaw};
    pose_recorded = 1;
}

MgsPlayerPose MgsNativeLastPlayerPose(void)
{
    if (!pose_recorded) {
        fprintf(stderr, "[native] func -s requested a player pose before any player was recorded.\n");
        exit(EXIT_FAILURE);
    }
    printf("[native] func -s before player creation uses last pose (%d,%d,%d), yaw=%d.\n",
           last_pose.x, last_pose.y, last_pose.z, last_pose.yaw);
    return last_pose;
}
