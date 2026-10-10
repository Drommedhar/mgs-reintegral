#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_native.h"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_final0.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_final1.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_final2.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_final3.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_final4.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_final5.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_final6.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_final7.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_final8.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_final9.c"

#include "mgs_brf_graph_test_support.h"

#include "mgs_brf_graph_final_fixtures.h"

int brf_dword_800C39CC[6];
int brf_dword_800C39E4[30];
int brf_dword_800C3A5C[15];
int brf_dword_800C3A98[24];
int brf_dword_800C3AF8[6];
int brf_dword_800C3B10[24];
DVECTOR BrfPath5100[48];
DVECTOR BrfPath51C0[12];
DVECTOR BrfPath51F0[16];

static unsigned Normalize(uintptr_t value) {
  if (value == (uintptr_t)&test_work)
    return 0;
  if (value >= (uintptr_t)test_work.field_28C &&
      value < (uintptr_t)(test_work.field_28C + 840)) {
    assert((value - (uintptr_t)test_work.field_28C) % sizeof(POLY_FT4) == 0);
    return 1000 + (value - (uintptr_t)test_work.field_28C) / sizeof(POLY_FT4);
  }
#define TABLE(name, address)                                                   \
  if (value == (uintptr_t)name)                                                \
  return address
  TABLE(brf_dword_800C39CC, 0x800C39CCu);
  TABLE(brf_dword_800C39E4, 0x800C39E4u);
  TABLE(brf_dword_800C3A5C, 0x800C3A5Cu);
  TABLE(brf_dword_800C3A98, 0x800C3A98u);
  TABLE(brf_dword_800C3AF8, 0x800C3AF8u);
  TABLE(brf_dword_800C3B10, 0x800C3B10u);
#undef TABLE
  return value;
}

#include "mgs_brf_graph_final_stubs.h"

static void Run(int function) {
  switch (function) {
  case 0:
    brf_800D8A24(&test_work);
    break;
  case 1:
    brf_800D93F4(&test_work);
    break;
  case 2:
    brf_800DA04C(&test_work, 3, 5, 7, 9);
    break;
  case 3:
    brf_800DA4E8(&test_work, &test_work.field_28C[5]);
    break;
  case 4:
    brf_800DA700(&test_work);
    break;
  case 5:
    brf_800DBA7C(&test_work);
    break;
  case 6:
    brf_800DCB44(&test_work, &test_work.field_28C[5]);
    break;
  case 7:
    brf_800DCED4(&test_work, &test_work.field_28C[5]);
    break;
  case 8:
    brf_800DCFB4(&test_work);
    break;
  case 9:
    brf_800DD648(&test_work);
    break;
  }
}

static void InitPath(DVECTOR *path, int count, int group) {
  for (int i = 0; i < count; ++i) {
    path[i].vx = i * 37 + group * 113 - 710;
    path[i].vy = 510 - i * 23 - group * 19;
  }
}

int main(void) {
  InitPath(BrfPath5100, 48, 0);
  InitPath(BrfPath51C0, 12, 1);
  InitPath(BrfPath51F0, 16, 2);
  return RunFixtures(fixtures, sizeof(fixtures) / sizeof(fixtures[0]), Run, 40,
                     "Briefing final scenes");
}
