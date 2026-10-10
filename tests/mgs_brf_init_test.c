#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/brf/onoda/brf/select_init.c"
#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct Fixture {
  int input[2];
  unsigned int output[3];
} Fixture;
#include "mgs_brf_init_fixtures.h"
static Work test_work;
static GV_PAD pad;
static DG_PRIM prims[2];
GV_PAD *GM_CurrentPadData = &pad;
int GM_CurrentMap;
static int options, variant, selected, item, prim_count, trace_count;
static unsigned int trace_hash;
static unsigned int HashBytes(unsigned int hash, const void *data,
                              size_t count) {
  const unsigned char *bytes = data;
  for (size_t i = 0; i < count; ++i)
    hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}
static void Trace(int count, ...) {
  va_list args;
  va_start(args, count);
  trace_count += count;
  while (count--) {
    unsigned int v = va_arg(args, int);
    trace_hash = HashBytes(trace_hash, &v, 4);
  }
  va_end(args);
}
char *GCL_GetOption(char option) {
  selected = (int)(strchr("vlzfghe", option) - "vlzfghe");
  item = 0;
  Trace(2, 1, option);
  return options & (1 << selected) ? (char *)"value" : NULL;
}
int GCL_GetNextInt(void) {
  int result = selected == 1 || selected == 2 ? variant
                                              : selected * 100 + item + variant;
  ++item;
  Trace(2, 2, result);
  return result;
}
DG_PRIM *DG_MakePrim(int type, int count, int channel, SVECTOR *pos,
                     RECT *rect) {
  assert(!pos && !rect && prim_count < 2);
  Trace(4, 3, type, count, channel);
  return &prims[prim_count++];
}
int DG_QueuePrim(DG_PRIM *prim) {
  Trace(2, 4, (int)(prim - prims));
  return 0;
}
int GV_StrCode(const char *name) {
  unsigned int hash = HashBytes(2166136261u, name, strlen(name));
  Trace(2, 5, hash);
  return hash & 65535;
}
void brf_800C983C(Work *work, int texture, POLY_FT4 *poly, int x0, int y0,
                  int x1, int y1, int transparent, int orientation) {
  assert(work == &test_work);
  int index = (uintptr_t)poly < (uintptr_t)work->field_E60
                  ? (int)(poly - work->field_780)
                  : 44 + (int)(poly - work->field_E60);
  Trace(9, 6, texture, index, x0, y0, x1, y1, transparent, orientation);
  setRGB0(poly, 128, 128, 128);
}
void GM_SetSound(int sound, int mode) { Trace(3, 7, sound, mode); }
void brf_800C6634(Work *work) {
  assert(work == &test_work);
  Trace(1, 8);
}
void brf_800C6620(Work *work) {
  assert(work == &test_work);
  Trace(1, 9);
}
void brf_800C5F74(Work *work) {
  assert(work == &test_work);
  Trace(1, 10);
}
static int Check(int index) {
  const Fixture *test = &fixtures[index];
  options = test->input[0];
  variant = test->input[1];
  memset(&test_work, 0, sizeof(test_work));
  memset(prims, 0, sizeof(prims));
  prim_count = trace_count = 0;
  trace_hash = 2166136261u;
  assert(brf_800C99C0(&test_work, 0x1234 + variant) == 0);
  assert(test_work.field_28 == &pad && test_work.field_20 == &prims[0] &&
         test_work.field_24 == &prims[1]);
  assert(prims[0].group_id == 0x1234 + variant &&
         prims[1].group_id == 0x1234 + variant);
  unsigned int hash =
      HashBytes(2166136261u, (char *)&test_work + 0x2c, 0x780 - 0x2c);
  for (int i = 0; i < 53; ++i) {
    POLY_FT4 *poly =
        i < 44 ? &test_work.field_780[i] : &test_work.field_E60[i - 44];
    hash = HashBytes(hash, &poly->r0, 36);
  }
  hash = HashBytes(hash, &test_work.field_FC8, 32);
  if (hash != test->output[0] || trace_count != test->output[1] ||
      trace_hash != test->output[2]) {
    fprintf(stderr, "Briefing constructor case %d: %u/%u %d/%u %u/%u\n", index,
            hash, test->output[0], trace_count, test->output[1], trace_hash,
            test->output[2]);
    return 1;
  }
  return 0;
}
int main(void) {
  int count = sizeof(fixtures) / sizeof(fixtures[0]);
  for (int i = 0; i < count; ++i)
    if (Check(i))
      return 1;
  printf("Briefing constructor: %d original-MIPS cases passed\n", count);
  return 0;
}
