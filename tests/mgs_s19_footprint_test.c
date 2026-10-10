#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/s19a/guard/navigation.c"
#undef fprintf
#include <assert.h>
#include <stdio.h>
#include <string.h>

S19COMMANDER S19_Command;
int S19_PlayerAddress, S19_PlayerMap, GM_PlayerStatus, GM_NoisePower;
SVECTOR S19_PlayerPosition;
short linkvarbuf[MAX_LINKVARBUF];
CONTROL *GM_WhereList[96];
SVECTOR GM_NoisePosition;
unsigned short S19AttackChance[4], S19AttackDelay[8];
int S19AttackFlags[32];
static S19Work actor;
static MAP map;
static HZD_HDL hzd;
static int next_result, expected_index, calls;

int NextAsiato(HZD_HDL *handle, int previous, SVECTOR *current) {
  assert(handle == &hzd && previous == expected_index);
  assert(current == &actor.control.mov);
  assert(current->vx == 1200 && current->vy == -500 && current->vz == 350);
  ++calls;
  return next_result;
}
void AsiatoPos(int index, SVECTOR *position) {
  (void)index;
  (void)position;
  abort();
}
int NearAsiato(void) { abort(); }
MAP *GM_GetMap(int name) {
  (void)name;
  abort();
}
int GV_RandU(int range) {
  (void)range;
  abort();
}
void GV_SubVec3(SVECTOR *a, SVECTOR *b, SVECTOR *c) {
  (void)a;
  (void)b;
  (void)c;
  abort();
}
int GV_VecDir2(SVECTOR *vector) {
  (void)vector;
  abort();
}
int HZD_GetAddress(HZD_HDL *handle, SVECTOR *position, int previous) {
  (void)handle;
  (void)position;
  (void)previous;
  abort();
}
int HZD_InsideZone(HZD_HDL *handle, SVECTOR *position, int zone) {
  (void)handle;
  (void)position;
  (void)zone;
  abort();
}
int HZD_Navigate(HZD_HDL *handle, int from, int to, SVECTOR *position) {
  (void)handle;
  (void)from;
  (void)to;
  (void)position;
  abort();
}
int HZD_ReachTo(HZD_HDL *handle, int from, int to) {
  (void)handle;
  (void)from;
  (void)to;
  abort();
}
void s19a_800D17B4(S19Work *work, int mark) {
  (void)work;
  (void)mark;
  abort();
}
int s19a_800D6620(void) { abort(); }
int s19a_800D6698(int from, int to) {
  (void)from;
  (void)to;
  abort();
}
int mgs_fprintf(int stream, const char *format, ...) {
  (void)stream;
  (void)format;
  abort();
}

int main(void) {
  const int previous[] = {-1, 0, 17, 47};
  const int following[] = {-1, 0, 18, 47};
  _set_error_mode(_OUT_TO_STDERR);
  map.hzd = &hzd;
  actor.control.map = &map;
  actor.control.mov = (SVECTOR){1200, -500, 350, 0};
  for (unsigned i = 0; i < sizeof(previous) / sizeof(previous[0]); ++i)
    for (unsigned j = 0; j < sizeof(following) / sizeof(following[0]); ++j) {
      expected_index = previous[i];
      next_result = following[j];
      actor.modetime[4] = expected_index;
      assert(s19a_800D4AF8(&actor) == (next_result >= 0));
      assert(actor.modetime[4] == next_result);
    }
  assert(calls == 16);
  puts("Garage footprint compatibility uses the live guard pose and preserves "
       "found/missing index transitions.");
  return 0;
}
