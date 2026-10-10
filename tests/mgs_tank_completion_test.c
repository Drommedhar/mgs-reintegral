#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include "libgcl/libgcl.h"
void s05a_ClearTankCameraCallbacks(void);
#include "tank_completion_helpers.inc"
#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  uint32_t hash;
  unsigned words;
} Expected;
#include "mgs_tank_completion_fixtures.h"

_Static_assert(sizeof(Work) == 0x139c, "Original Tank actor size");
_Static_assert(offsetof(Work, field_E1C) == 0xe1c, "Script restore callback");
_Static_assert(offsetof(Work, field_E20) == 0xe20, "Victory callback");
_Static_assert(offsetof(Work, hzd) == 0xfec, "Dynamic collision records");

int (*GM_lpfnPlayerActControl)(GV_ACT *);
int (*GM_lpfnPlayerActObject2)(GV_ACT *);
int (*GM_lpfnBombHoming)(CONTROL *, int, int *);
int (*GM_lpfnBombBound)(int, CONTROL *, int *);
int (*GM_lpfnBombExplosion)(TARGET *, int);
short GM_uTenageMotion;
Work *s05a_dword_800C362C;

static Work actor;
static MAP map;
static HZD_HDL hazard;
static TARGET targets[10];
static GV_ACT effect;
static Gunner gunner;
static uint32_t trace_hash;
static unsigned trace_words;
static int camera_released;

void s05a_ClearTankCameraCallbacks(void) {
  assert(!camera_released && s05a_dword_800C362C == &actor);
  camera_released = 1;
}

static void Word(uint32_t value) {
  trace_hash = (trace_hash ^ value) * 16777619u;
  ++trace_words;
}

static void Globals(void) {
  unsigned flags = (GM_lpfnPlayerActControl != NULL) |
                   ((GM_lpfnPlayerActObject2 != NULL) << 1) |
                   ((GM_lpfnBombHoming != NULL) << 2) |
                   ((GM_lpfnBombBound != NULL) << 3) |
                   ((GM_lpfnBombExplosion != NULL) << 4) |
                   ((s05a_dword_800C362C != NULL) << 5);
  Word(flags);
  Word((uint32_t)GM_uTenageMotion);
}

static void OffsetEvent(unsigned event, const void *field) {
  uintptr_t pointer = (uintptr_t)field, base = (uintptr_t)&actor;
  assert(pointer >= base && pointer < base + sizeof(actor));
  Word(event);
  Word((uint32_t)(pointer - base));
  Globals();
}

void GV_DestroyActor(void *work) {
  assert(work == &effect || work == &gunner);
  Word(1);
  Word(work == &effect ? 1 : 2);
  Globals();
}

void GCL_ForceExecProc(int proc, GCL_ARGS *args) {
  assert(camera_released);
  assert(args != NULL && args->argc == 5);
  Word(2);
  Word(proc);
  Word(args->argc);
  for (int index = 0; index < args->argc; ++index)
    Word(args->argv[index]);
  Globals();
}

void HZD_DequeueDynamicSegment(HZD_HDL *handle, HZD_SEG *segment) {
  assert(handle == &hazard);
  OffsetEvent(3, segment);
}

void HZD_DequeueDynamicFloor(HZD_HDL *handle, HZD_FLR *floor) {
  assert(handle == &hazard);
  OffsetEvent(4, floor);
}

void GM_FreeObject(OBJECT *body) {
  assert(camera_released);
  OffsetEvent(5, body);
}

void GM_FreeTarget(TARGET *target) {
  assert(target >= targets && target < targets + 10);
  Word(6);
  Word((uint32_t)(target - targets));
  Globals();
}

void GM_FreeControl(CONTROL *control) { OffsetEvent(7, control); }

int GCL_ExecProc(int proc, GCL_ARGS *args) {
  assert(args == NULL);
  Word(8);
  Word(proc);
  Globals();
  return 0;
}

static int PlayerHook(GV_ACT *work) {
  (void)work;
  abort();
}

static int HomingHook(CONTROL *control, int kind, int *value) {
  (void)control;
  (void)kind;
  (void)value;
  abort();
}

static int BoundHook(int kind, CONTROL *control, int *value) {
  (void)kind;
  (void)control;
  (void)value;
  abort();
}

static int ExplosionHook(TARGET *target, int kind) {
  (void)target;
  (void)kind;
  abort();
}

static void Seed(int mode, int restore, int victory, int children, int accel) {
  camera_released = 0;
  memset(&actor, 0, sizeof(actor));
  actor.control.map = &map;
  map.hzd = &hazard;
  actor.field_D54 = mode;
  actor.field_D64 = accel;
  actor.field_D68 = accel / 7;
  actor.field_E08 = children - 2;
  actor.field_E0C = 1234;
  actor.field_E10 = -42;
  actor.field_E1C = restore;
  actor.field_E20 = victory;
  actor.field_EDC = (children & 1) ? &effect : NULL;
  actor.field_EB0 = (children & 2) ? &gunner : NULL;
  for (int index = 0; index < 10; ++index)
    actor.field_718[index] = &targets[index];
  GM_lpfnPlayerActControl = PlayerHook;
  GM_lpfnPlayerActObject2 = PlayerHook;
  GM_lpfnBombHoming = HomingHook;
  GM_lpfnBombBound = BoundHook;
  GM_lpfnBombExplosion = ExplosionHook;
  GM_uTenageMotion = 42;
  s05a_dword_800C362C = &actor;
  trace_hash = 2166136261u;
  trace_words = 0;
}

static void Check(unsigned index) {
  Work initial = actor;
  s05a_800D5E30(&actor);
  assert(memcmp(&actor, &initial, sizeof(actor)) == 0);
  assert(GM_uTenageMotion == -1 && s05a_dword_800C362C == NULL);
  assert(GM_lpfnPlayerActControl == NULL && GM_lpfnPlayerActObject2 == NULL);
  assert(GM_lpfnBombHoming == NULL && GM_lpfnBombBound == NULL);
  assert(GM_lpfnBombExplosion == NULL);
  if (trace_hash != expected[index].hash || trace_words != expected[index].words) {
    fprintf(stderr, "Tank completion fixture %u: got %08x/%u, expected %08x/%u\n",
            index, trace_hash, trace_words, expected[index].hash,
            expected[index].words);
    abort();
  }
}

int main(void) {
  static const int modes[] = {0, 1, 4, 5, 6};
  static const int restore[] = {-1, 0, 0x5678};
  static const int victory[] = {-1, 0, 0xabcd};
  static const int accel[] = {-100001, -1000, -1, 0, 999, 10000, 100000};
  unsigned index = 0;
  _set_error_mode(_OUT_TO_STDERR);
  for (unsigned mode = 0; mode < 5; ++mode)
    for (unsigned save = 0; save < 3; ++save)
      for (unsigned end = 0; end < 3; ++end)
        for (int children = 0; children < 4; ++children)
          for (unsigned acceleration = 0; acceleration < 7; ++acceleration) {
            Seed(modes[mode], restore[save], victory[end], children,
                 accel[acceleration]);
            Check(index++);
          }
  assert(index == sizeof(expected) / sizeof(expected[0]));
  printf("Tank completion: %u original-MIPS call-trace comparisons passed\n", index);
  return 0;
}
