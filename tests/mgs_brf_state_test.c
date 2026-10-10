#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/brf/onoda/brf/select_state.c"
#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct Fixture {
  int input[4];
  unsigned int hash;
  int trace_count;
  unsigned int trace_hash;
} Fixture;
#include "mgs_brf_state_fixtures.h"
static Work test_work;
static GV_PAD pad;
static GV_ACT actors[2];
static unsigned int trace_hash;
static int trace_count;
static void Trace(int count, ...) {
  va_list args;
  va_start(args, count);
  trace_count += count;
  while (count--) {
    unsigned int value = va_arg(args, int);
    for (int i = 0; i < 4; ++i)
      trace_hash = (trace_hash ^ ((value >> (8 * i)) & 255)) * 16777619u;
  }
  va_end(args);
}
#include "mgs_brf_state_stubs.h"
void GM_SeSet2(int channel, int volume, int sound) {
  Trace(4, 1, channel, volume, sound);
}
void GM_SetSound(int sound, int mode) { Trace(3, 2, sound, mode); }
void GM_StreamPlayStop(void) { Trace(1, 3); }
void GV_DestroyActor(void *actor) {
  assert(actor == &test_work || actor == &actors[0] || actor == &actors[1]);
  Trace(2, 4, actor == &test_work ? 0 : actor == &actors[0] ? 1 : 2);
}
int GCL_ExecProc(int procedure, GCL_ARGS *args) {
  Trace(3, 5, procedure, args->argc);
  for (int i = 0; i < args->argc; ++i)
    Trace(1, args->argv[i]);
  return 0;
}
static unsigned int HashBytes(unsigned int hash, const void *data,
                              size_t count) {
  const unsigned char *bytes = data;
  for (size_t i = 0; i < count; ++i)
    hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}
static void Initialize(const int *in) {
  int variant = in[3];
  memset(&test_work, 0, sizeof(test_work));
  memset(&pad, 0, sizeof(pad));
  pad.press = in[2];
  test_work.field_28 = &pad;
  for (int i = 0; i < 19; ++i)
    test_work.field_80[i] = (variant >> (i % 2)) & 1;
  for (int i = 0; i < 53; ++i) {
    POLY_FT4 *poly =
        i < 44 ? &test_work.field_780[i] : &test_work.field_E60[i - 44];
    for (int j = 0; j < 36; ++j)
      ((unsigned char *)&poly->r0)[j] = j * 13 + i * 7 + variant * 17;
  }
  test_work.field_64 = 9;
  test_work.field_68 = 11;
  test_work.field_6C = 16;
  test_work.field_70 = in[0];
  test_work.field_74 = 5;
  test_work.field_78 = variant & 1;
  test_work.field_7C = variant >> 1;
  const int scene[] = {0, 16, 18, 7};
  test_work.field_CC = scene[variant];
  test_work.field_D0 = in[1];
  test_work.field_D4 = variant & 1;
  test_work.field_D8 = &actors[0];
  test_work.field_DC = &actors[1];
  test_work.field_77C = 200;
  test_work.field_FC8 = 101;
  test_work.field_FCC = 102;
  test_work.field_FD0 = 103;
  test_work.field_FD4 = variant >> 1;
  test_work.field_FD8 = 5;
  test_work.field_FDC = 6;
  test_work.field_FE0 = 3;
  test_work.field_FE4 = variant & 1;
  trace_hash = 2166136261u;
  trace_count = 0;
}
static unsigned int Run(const int *in) {
  Initialize(in);
  brf_800C829C(&test_work);
  test_work.field_D8 = (void *)1;
  test_work.field_DC = (void *)2;
  unsigned int hash =
      HashBytes(2166136261u, (char *)&test_work + 0x2c, 0x780 - 0x2c);
  for (int i = 0; i < 53; ++i) {
    POLY_FT4 *poly =
        i < 44 ? &test_work.field_780[i] : &test_work.field_E60[i - 44];
    hash = HashBytes(hash, &poly->r0, 36);
  }
  return HashBytes(hash, &test_work.field_FC8, 32);
}
int main(void) {
  int count = sizeof(fixtures) / sizeof(fixtures[0]);
  for (int i = 0; i < count; ++i) {
    unsigned int hash = Run(fixtures[i].input);
    if (hash != fixtures[i].hash || trace_count != fixtures[i].trace_count ||
        trace_hash != fixtures[i].trace_hash) {
      fprintf(stderr,
              "Briefing state case %d: output %u/%u, trace %d/%d %u/%u\n", i,
              hash, fixtures[i].hash, trace_count, fixtures[i].trace_count,
              trace_hash, fixtures[i].trace_hash);
      return 1;
    }
  }
  printf("Briefing state: %d original-MIPS cases passed\n", count);
  return 0;
}
