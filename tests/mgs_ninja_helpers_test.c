#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include "libgcl/libgcl.h"
#include "overlays/s08b/animal/ninja/ninja_native_work.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef uint32_t _DWORD;
int GV_Time;
static int random_value;

short linkvarbuf[MAX_LINKVARBUF];
int GM_GameOverTimer;
int GM_GameStatus;
int s08b_dword_800C3448;
static Work *hit_work;
static int hit_trace_count, hit_trace[4];
static Work *terminal_work;
static int terminal_stream, terminal_trace_count, terminal_trace[8][5];
static MAP terminal_map;
static HZD_HDL terminal_hazard;

static void TerminalEvent(int kind, int first, int second) {
  assert(terminal_trace_count < 8);
  int event[] = {kind, first, second, terminal_work->field_19D0,
                 terminal_work->field_19CC};
  memcpy(terminal_trace[terminal_trace_count++], event, sizeof(event));
}

int GM_StreamStatus(void) {
  TerminalEvent(1, terminal_stream, 0);
  return terminal_stream;
}

void GM_StreamPlayStop(void) {
  TerminalEvent(2, 0, 0);
}

void *GM_VoxStream(int code, int proc) {
  assert(proc == 0);
  TerminalEvent(3, code, proc);
  return NULL;
}

int GCL_ExecProc(int proc, GCL_ARGS *args) {
  assert(args == NULL);
  TerminalEvent(4, proc, args != NULL);
  return 0;
}

void *s08b_p_sphere_800D9834(void *parent, void *command) {
  assert(parent == &terminal_work->body.objs);
  assert(command == &terminal_work->field_1A04);
  TerminalEvent(5, 0x9C, 0x1A04);
  return NULL;
}

int HZD_GetAddress(HZD_HDL *hazard, SVECTOR *position, int previous) {
  assert(hazard == &terminal_hazard && previous == -1);
  assert(position == &terminal_work->field_1968);
  TerminalEvent(6, position->vx, position->vz);
  return 0x2345;
}

int GV_RandU(int limit) {
  assert(limit == 8);
  return random_value;
}

static void HitRouteEvent(Work *work, int helper) {
  assert(work == hit_work && hit_trace_count == 0);
  int event[] = {helper, s08b_dword_800C3448, work->field_19C8, work->field_19CC};
  memcpy(hit_trace, event, sizeof(event));
  ++hit_trace_count;
}

void s08b_bunsin2_800CDE74(Work *work) {
  HitRouteEvent(work, 0xDE74);
}

void s08b_bunsin2_800CE2E8(Work *work) {
  HitRouteEvent(work, 0xE2E8);
}

#include "ninja_helpers.inc"

typedef struct {
  int input[5];
  int result, hit_count, change_count;
  struct { unsigned offset; uint32_t value; } changes[3];
  int trace_count, trace[4];
} NinjaHitFixture;
#include "mgs_ninja_hit_fixtures.h"

static void VerifyHit(const NinjaHitFixture *fixture, size_t index) {
  static int (*const dispatch[])(Work *) = {
      s08b_bunsin2_800CF354, s08b_bunsin2_800CF464, s08b_bunsin2_800CF54C};
  Work work, expected;
  unsigned char *bytes = (unsigned char *)&work;
  for (size_t i = 0; i < sizeof(work); ++i)
    bytes[i] = (unsigned char)(i * 13 + 71);
  work.field_19C8 = 6;
  work.field_19CC = fixture->input[2];
  work.field_1A34 = fixture->input[1];
  GM_GameStatus = fixture->input[3];
  s08b_dword_800C3448 = fixture->input[4];
  hit_work = &work;
  hit_trace_count = 0;
  memset(hit_trace, 0, sizeof(hit_trace));
  memcpy(&expected, &work, sizeof(work));
  for (int i = 0; i < fixture->change_count; ++i) {
    assert(fixture->changes[i].offset <= sizeof(expected) - sizeof(uint32_t));
    memcpy((unsigned char *)&expected + fixture->changes[i].offset,
           &fixture->changes[i].value, sizeof(uint32_t));
  }
  int result = dispatch[fixture->input[0]](&work);
  if (result != fixture->result || memcmp(&work, &expected, sizeof(work)) ||
      s08b_dword_800C3448 != fixture->hit_count ||
      hit_trace_count != fixture->trace_count ||
      memcmp(hit_trace, fixture->trace, sizeof(hit_trace))) {
    fprintf(stderr, "Ninja hit fixture %zu failed: handler=%d hit=%d state=%d\n",
            index, fixture->input[0], fixture->input[1], fixture->input[2]);
    abort();
  }
}

typedef struct {
  int input[5];
  int output[6];
} NinjaFixture;
#include "mgs_ninja_fixtures.h"

typedef struct {
  int input[10];
  int result, change_count;
  struct { unsigned offset; uint32_t value; } changes[16];
  int trace_count, trace[8][5];
} NinjaTerminalFixture;
#include "mgs_ninja_terminal_fixtures.h"

static void PrepareTerminal(Work *work, const int *input) {
  unsigned char *bytes = (unsigned char *)work;
  for (size_t i = 0; i < sizeof(*work); ++i)
    bytes[i] = (unsigned char)(i * 13 + 71);
  work->control.map = &terminal_map;
  terminal_map.hzd = &terminal_hazard;
  work->field_19CC = input[1];
  work->field_19D0 = input[2];
  work->field_19E0 = input[3];
  work->field_19A4 = input[4] & 1;
  work->field_19A8 = (input[4] >> 1) & 1;
  work->field_1A8C = work->field_1A90 = work->field_1A94 = input[5];
  terminal_stream = input[6];
  GM_GameOverTimer = input[7];
  GM_Vitality = input[8];
  work->field_1A28 = 2345;
  work->field_1A98[1] = 0x4501;
  work->field_1A98[18] = 0x4512;
  s08b_dword_800C3454 = 0x12;
  s08b_ninja_positions[0] = (SVECTOR){101, -202, 303, 0x55AA};
  for (int i = 0; i < 3; ++i)
    s08b_dword_800C34F8[i] = (SVECTOR){400 + i, -500 - i, 600 + i, 700 + i};
  terminal_work = work;
  terminal_trace_count = 0;
  memset(terminal_trace, 0, sizeof(terminal_trace));
}

static void VerifyTerminal(const NinjaTerminalFixture *fixture, size_t index) {
  Work work, expected;
  PrepareTerminal(&work, fixture->input);
  memcpy(&expected, &work, sizeof(work));
  for (int i = 0; i < fixture->change_count; ++i) {
    unsigned offset = fixture->changes[i].offset;
    assert(offset <= sizeof(expected) - sizeof(uint32_t));
    memcpy((unsigned char *)&expected + offset, &fixture->changes[i].value,
           sizeof(uint32_t));
  }
  int result = 0;
  for (int step = 0; step < fixture->input[9]; ++step) {
    switch (fixture->input[0]) {
    case 0: s08b_bunsin2_800D2DB0(&work); break;
    case 1: s08b_bunsin2_800D2158(&work); break;
    case 2: result = s08b_bunsin2_800D1738(&work); break;
    default: abort();
    }
  }
  if (result != fixture->result || memcmp(&work, &expected, sizeof(work)) ||
      terminal_trace_count != fixture->trace_count ||
      memcmp(terminal_trace, fixture->trace, sizeof(terminal_trace))) {
    fprintf(stderr, "Ninja terminal fixture %zu failed: operation=%d timer=%d\n",
            index, fixture->input[0], fixture->input[2]);
    abort();
  }
}

static void PrepareRoutes(Work *work, int ordinal) {
  static const int counts[] = {5, 7, 8, 9, 11};
  int route;
  int point;
  for (route = 0; route < 5; route++) {
    work->clones[route].field_0 = counts[route];
    for (point = 0; point < counts[route]; point++) {
      work->clones[route].field_4[point] = (SVECTOR){
          100 * route + point, 200 * route - point, -300 * route + point, 0};
    }
  }
  route = 0;
  while (ordinal >= counts[route]) {
    ordinal -= counts[route++];
  }
  work->field_1964 = route;
  work->field_1966 = ordinal;
  work->field_1968 = (SVECTOR){-2000, 400, -5000, 0};
}

static void VerifyFixture(const NinjaFixture *fixture) {
  Work work = {0};
  int out[6] = {0};
  const int *in = fixture->input;
  if (in[0] == 0) {
    SVECTOR position = {in[1], 0, in[2], 0};
    out[0] = s08b_bunsin2_800C9BF8(&position);
  } else {
    PrepareRoutes(&work, in[1]);
    GV_Time = in[2];
    random_value = in[3];
    out[0] = s08b_bunsin2_800CEFF4(&work);
    out[1] = work.field_1964;
    out[2] = work.field_1966;
    out[3] = work.field_1968.vx;
    out[4] = work.field_1968.vy;
    out[5] = work.field_1968.vz;
  }
  if (memcmp(out, fixture->output, sizeof(out)) != 0) {
    fprintf(stderr, "Ninja fixture failed: op=%d a=%d b=%d c=%d\n", in[0],
            in[1], in[2], in[3]);
    abort();
  }
}

int main(void) {
  size_t index;
  for (index = 0; index < sizeof(ninja_fixtures) / sizeof(ninja_fixtures[0]);
       index++) {
    VerifyFixture(&ninja_fixtures[index]);
  }
  printf("Ninja: %zu original MIPS boundary and route cases passed\n", index);
  for (index = 0; index < sizeof(ninja_terminal_fixtures) / sizeof(ninja_terminal_fixtures[0]);
       ++index)
    VerifyTerminal(&ninja_terminal_fixtures[index], index);
  printf("Ninja: %zu original MIPS terminal and callback cases passed\n", index);
  for (index = 0; index < sizeof(ninja_hit_fixtures) / sizeof(ninja_hit_fixtures[0]);
       ++index)
    VerifyHit(&ninja_hit_fixtures[index], index);
  printf("Ninja: %zu original MIPS hit-dispatch cases passed\n", index);
  return 0;
}
