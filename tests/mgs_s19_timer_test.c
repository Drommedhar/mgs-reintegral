#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/s19a/timer.c"
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct Fixture {
  int ticks, clock, tick_proc, end_proc;
  int output[87];
  int trace_size, trace[6];
} Fixture;
#include "mgs_s19_timer_fixtures.h"

int GV_Clock, GM_CurrentMap;
static S19Timer actor;
static DG_PRIM primitive;
static POLY_FT4 packets[2][5];
static int trace[6], trace_size;
static DG_TEX numbers, colon;
static int fail_alloc, missing_texture;

int GCL_ExecProc(int id, GCL_ARGS *args) {
  assert(trace_size <= 3);
  trace[trace_size++] = id;
  trace[trace_size++] = args ? args->argc : 0;
  trace[trace_size++] = args ? args->argv[0] : 0;
  return 0;
}
char *GCL_GetOption(char option) {
  (void)option;
  return NULL;
}
char *GCL_NextStr(void) { abort(); }
int GCL_StrToInt(char *value) {
  (void)value;
  abort();
}
int GV_StrCode(const char *name) { return strcmp(name, "0123") == 0 ? 1 : 2; }
DG_TEX *DG_GetTexture(int id) {
  return missing_texture ? NULL : id == 1 ? &numbers : &colon;
}
DG_PRIM *DG_MakePrim(int type, int count, int channel, SVECTOR *vertices,
                     RECT *rect) {
  assert(type == (DG_PRIM_SORTONLY | DG_PRIM_POLY_FT4) && count == 5 &&
         channel == 0);
  assert(vertices == NULL && rect == NULL);
  return fail_alloc ? NULL : &primitive;
}
int DG_QueuePrim(DG_PRIM *prim) {
  assert(prim == &primitive);
  return 0;
}
void DG_DequeuePrim(DG_PRIM *prim) { assert(prim == &primitive); }
void DG_FreePrim(DG_PRIM *prim) { assert(prim == &primitive); }
void *GV_NewActor(int level, int size) {
  assert(level == 5 && size == sizeof(actor));
  return &actor;
}
void GV_SetNamedActor(void *work, void *act, void *die, const char *name) {
  assert(work == &actor && act == TimerAct && die == TimerDie &&
         strcmp(name, "timer.c") == 0);
}
void GV_DestroyActor(void *work) {
  assert(work == &actor);
  TimerDie(&actor);
}

static void Verify(const Fixture *fixture) {
  int actual[87], count = 0;
  memset(&actor, 0, sizeof(actor));
  memset(packets, 0, sizeof(packets));
  actor.prim = &primitive;
  actor.depth = 123;
  actor.u = 11;
  actor.width = 153;
  actor.v = 77;
  actor.height = 19;
  actor.ticks = fixture->ticks;
  actor.tick_proc = fixture->tick_proc;
  actor.end_proc = fixture->end_proc;
  GV_Clock = fixture->clock;
  trace_size = 0;
  TimerAct(&actor);
  actual[count++] = actor.ticks;
  actual[count++] = actor.end_proc;
  for (int buffer = 0; buffer < 2; ++buffer)
    for (int i = 0; i < 5; ++i) {
      POLY_FT4 *p = &packets[buffer][i];
      actual[count++] = p->u0;
      actual[count++] = p->v0;
      actual[count++] = p->u1;
      actual[count++] = p->v1;
      actual[count++] = p->u2;
      actual[count++] = p->v2;
      actual[count++] = p->u3;
      actual[count++] = p->v3;
    }
  for (int i = 0; i < 5; ++i)
    actual[count++] = (unsigned short)getaddr(&packets[GV_Clock][i]);
  assert(count == 87 && memcmp(actual, fixture->output, sizeof(actual)) == 0);
  assert(trace_size == fixture->trace_size &&
         memcmp(trace, fixture->trace, trace_size * sizeof(int)) == 0);
}

int main(void) {
  _set_error_mode(_OUT_TO_STDERR);
  primitive.packs[0] = packets[0];
  primitive.packs[1] = packets[1];
  for (unsigned i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i)
    Verify(&fixtures[i]);
  numbers = (DG_TEX){0};
  colon = (DG_TEX){0};
  numbers.off_x = 11;
  numbers.off_y = 77;
  numbers.w = 152;
  numbers.h = 18;
  colon.off_x = 3;
  colon.off_y = 8;
  colon.w = 7;
  colon.h = 17;
  assert(NewS19Timer() == &actor && actor.ticks == 5429);
  assert(packets[0][0].x0 == 134 && packets[1][4].x0 == 70);
  assert(packets[0][2].u1 == 10 && packets[0][2].v3 == 25);
  assert(getlen(&packets[0][0]) == 9 && packets[0][0].code == 0x2e);
  fail_alloc = 1;
  assert(NewS19Timer() == NULL);
  fail_alloc = 0;
  missing_texture = 1;
  assert(NewS19Timer() == NULL);
  puts("Garage timer matches 80 original MIPS cases; callbacks, native packets "
       "and resource failures verified.");
  return 0;
}
