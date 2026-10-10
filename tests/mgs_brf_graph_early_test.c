#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_native.h"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scene_helpers.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_early0.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_early1.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_early2.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_early3.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_early4.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_early5.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_early6.c"

#include "mgs_brf_graph_test_support.h"

#include "mgs_brf_graph_early_fixtures.h"

int brf_dword_800C3744[9];
int brf_dword_800C3768[12];
int brf_dword_800C3798[3];
int brf_dword_800C37A4[12];
int brf_dword_800C381C[21];
int brf_dword_800C3870[6];
int brf_dword_800C3888[6];
int brf_dword_800C38A0[18];

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
  TABLE(brf_dword_800C3744, 0x800C3744u);
  TABLE(brf_dword_800C3768, 0x800C3768u);
  TABLE(brf_dword_800C3798, 0x800C3798u);
  TABLE(brf_dword_800C37A4, 0x800C37A4u);
  TABLE(brf_dword_800C381C, 0x800C381Cu);
  TABLE(brf_dword_800C3870, 0x800C3870u);
  TABLE(brf_dword_800C3888, 0x800C3888u);
  TABLE(brf_dword_800C38A0, 0x800C38A0u);
#undef TABLE
  return value;
}

#include "mgs_brf_graph_early_stubs.h"

static void Run(int function) {
  switch (function) {
  case 0:
    brf_800CF984(&test_work);
    break;
  case 1:
    brf_800D00C4(&test_work);
    break;
  case 2:
    brf_800D3220(&test_work);
    break;
  case 3:
    brf_800D41A4(&test_work);
    break;
  case 4:
    brf_800D4A34(&test_work);
    break;
  case 5:
    brf_800D52F0(&test_work);
    break;
  case 6:
    brf_800D5780(&test_work);
    break;
  case 7:
    brf_800D30A0(&test_work);
    break;
  case 8:
    brf_800D49B8(&test_work);
    break;
  case 9:
    brf_800D4664(&test_work);
    break;
  case 10:
    brf_800D3D8C(&test_work);
    break;
  }
}

int main(void) {
  return RunFixtures(fixtures, sizeof(fixtures) / sizeof(fixtures[0]), Run, 840,
                     "Briefing early scenes");
}
