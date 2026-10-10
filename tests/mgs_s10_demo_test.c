#include "mgs_native.h"
#undef fprintf

#include "../vendor/mgs/source/overlays/s10a/okajima/10a_demo.c"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

DG_CHANL DG_Chanls[3];
GV_PAD GV_PadData[4];
int GV_Time;
int GM_CurrentMap;
int GM_GameStatus;
SVECTOR GM_PlayerPosition;
GM_CameraSystemWork GM_Camera;
UnkCameraStruct2 gUnkCameraStruct2_800B7868;
short linkvarbuf[MAX_LINKVARBUF];

static Work actor;
static int destroy_calls, sound_calls, rifle_calls, callback;
static char option;
static SVECTOR camera_eye, camera_center;

typedef struct {
  int tick;
  short smoothed[3];
  short camera[3];
} Sample;

/* Captured by executing Integral's 800D5F78..800D66E8 MIPS code. */
static const Sample samples[] = {
    {0, {1200, -16000, 9000}, {121, -26509, -19000}},
    {1, {1200, -16625, 9000}, {121, -26584, -19000}},
    {19, {1200, -23060, 9000}, {145, -27379, -19000}},
    {20, {1200, -23427, 9000}, {144, -27425, -19000}},
    {99, {1200, -25993, 9000}, {164, -27731, -19000}},
    {100, {1175, -26368, 10437}, {163, -27780, -18821}},
    {189, {1000, -28993, 20493}, {109, -28133, -17564}},
    {190, {1000, -28993, 20493}, {111, -28132, -17564}},
};

void *GV_NewActor(int level, int size) {
  assert(level == GV_ACTOR_PREV && size == 96);
  memset(&actor, 0, sizeof(actor));
  return &actor;
}

void GV_SetNamedActor(void *work, void *act, void *die, const char *name) {
  assert(work == &actor && act == Act && die == Die);
  assert(strcmp(name, "10a_demo.c") == 0);
}

void GV_DestroyActor(void *work) {
  assert(work == &actor);
  destroy_calls++;
}

char *GCL_GetOption(char key) {
  assert(key == 'p');
  return &option;
}

int GCL_StrToInt(char *value) {
  assert(value == &option);
  return 0x4321;
}

void GCL_ForceExecProc(int proc, GCL_ARGS *args) {
  assert(args == NULL);
  callback = proc;
}

void GM_SeSet2(int pan, int volume, int sound) {
  assert(pan == 0 && volume == 63 && sound == 135);
  sound_calls++;
}

void *NewRifleSightFast(void) {
  rifle_calls++;
  return NULL;
}

void DG_MakeCameraMatrix(DG_CHANL *channel, SVECTOR *eye, SVECTOR *center,
                         int zoom) {
  assert(channel == DG_Chanl(0) && zoom == 5000);
  camera_eye = *eye;
  camera_center = *center;
}

int main(void) {
  _set_error_mode(_OUT_TO_STDERR);
  GM_PlayerPosition = (SVECTOR){1200, -26000, 9000, 0};
  GM_Item = 1;
  GM_Weapon = 9;
  GV_PadData[0].status = GV_PadData[1].status = 0xffff;
  assert(NewStage10Demo(0x1234, 2) == &actor);
  assert(GM_GameStatus == 0x104a0000 && rifle_calls == 1);

  unsigned sample = 0;
  for (int tick = 0; tick <= 190; tick++) {
    GV_Time = tick + 123;
    Act(&actor);
    assert(GM_Item == -1 && GM_Weapon == -1 && GM_CurrentMap == 2);
    assert(actor.time == tick + 1);
    assert(GM_Camera.zoom == 5000 && GM_Camera.interp_mode == 0);
    assert(camera_eye.vx == 0 && camera_eye.vy == -28000 &&
           camera_eye.vz == -23000);
    for (int port = 0; port < 2; port++) {
      assert(GV_PadData[port].status == 0xefff &&
             GV_PadData[port].press == 0xefff);
    }
    if (sample < sizeof(samples) / sizeof(samples[0]) &&
        tick == samples[sample].tick) {
      assert(memcmp(&actor.smoothed, samples[sample].smoothed, 6) == 0);
      assert(memcmp(&camera_center, samples[sample].camera, 6) == 0);
      assert(memcmp(&gUnkCameraStruct2_800B7868.target, samples[sample].camera,
                    6) == 0);
      sample++;
    }
  }
  Die(&actor);
  assert(sample == sizeof(samples) / sizeof(samples[0]));
  assert(destroy_calls == 1 && sound_calls == 3 && callback == 0x4321);
  assert(GM_Item == 1 && GM_Weapon == 9 && GM_GameStatus == 0x004a0000);
  puts("Underground Passage camera demo matches the original MIPS trace.");
  return 0;
}
