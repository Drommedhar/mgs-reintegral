#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/d18a/animal/snake18/native_04.c"
#include "../vendor/mgs/source/overlays/d18a/animal/snake18/native_05.c"
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  int action, time, status, press, player, game, alert, direction, wall;
  int wall_side, helper, end, stance, local, wall_ticks, y, motion, wall_vector;
} Input;
typedef struct {
  const char *name;
  Input input;
  int output[28];
  int trace_size;
  int trace[64];
} Fixture;
#include "mgs_snake18_state_fixtures.h"

int GM_PlayerStatus, GM_GameStatus, GM_AlertMode, GM_Photocode;
int Snake18PadDirection, Snake18WallDirection, Snake18WallSide;
SVECTOR *Snake18WallVector;
static Snake18Work actor;
static GV_PAD pad;
static MAP map;
static HZD_HDL hazard;
static char motion[112];
static Snake18Type pack;
static SVECTOR wall_vector;
static char wall_flags;
char *Snake18WallFlags = &wall_flags;
static const Fixture *fixture;
static int trace[64], trace_size;

static void Record(int count, ...) {
  va_list args;
  assert(trace_size + count <= 64);
  va_start(args, count);
  for (int i = 0; i < count; ++i)
    trace[trace_size++] = va_arg(args, int);
  va_end(args);
}
void GM_ConfigObjectAction(OBJECT *body, int action, int frame, int interp) {
  assert(body == &actor.body);
  Record(4, 1, action, frame, interp);
}
void GM_CheckBehindCamera(HZD_HDL *hzd, CONTROL *control) {
  assert(hzd == &hazard && control == &actor.control);
  Record(1, 2);
}
void GM_ExitBehindCamera(void) { Record(1, 3); }
void GM_SeSet(SVECTOR *position, int sound) {
  assert(position == &actor.control.mov);
  Record(2, 4, sound);
}
int d18a_snake18_800CAC68(int arg0, int arg1) {
  Record(2, 10, arg1);
  return fixture->input.helper;
}
int d18a_snake18_800CAEC0(Snake18Work *work, int state) {
  Record(2, 11, state);
  return fixture->input.helper;
}
int d18a_snake18_800CAF20(Snake18Work *work) {
  Record(1, 12);
  return fixture->input.helper;
}
int d18a_snake18_800CB134(Snake18Work *work) {
  Record(1, 13);
  return fixture->input.helper;
}
void d18a_snake18_800CB228(Snake18Work *work, int arg1) { Record(2, 14, arg1); }
void d18a_snake18_800CB3E8(Snake18Work *work) { Record(1, 15); }
void d18a_snake18_800CB42C(Snake18Work *work) { Record(1, 16); }
int d18a_snake18_800CBBC8(Snake18Work *work) {
  Record(1, 17);
  return fixture->input.helper;
}
void d18a_snake18_800CBD34(Snake18Work *work) { Record(1, 18); }
void d18a_snake18_800CBD80(Snake18Work *work) { Record(1, 19); }
void d18a_snake18_800CC8B0(Snake18Work *work, char arg1) {
  Record(2, 20, arg1);
}
void d18a_snake18_800CC8E0(Snake18Work *arg0) { Record(1, 21); }
void d18a_snake18_800CED2C(Snake18Work *work, int arg1) {
  assert(!"Unexpected callback execution in isolated state test");
}
void d18a_snake18_800CEDB0(Snake18Work *work, int time) {
  assert(!"Unexpected callback execution in isolated state test");
}
void d18a_snake18_800CEF0C(Snake18Work *work, int arg1) {
  assert(!"Unexpected callback execution in isolated state test");
}
void d18a_snake18_800D1424(Snake18Work *work, int time) {
  assert(!"Unexpected callback execution in isolated state test");
}
void d18a_snake18_800D1598(Snake18Work *work, int time) {
  assert(!"Unexpected callback execution in isolated state test");
}
void d18a_snake18_800D1A6C(Snake18Work *work, int arg1) {
  assert(!"Unexpected callback execution in isolated state test");
}
static const Snake18Fn actions[] = {
    d18a_snake18_800CD64C, d18a_snake18_800CD768, d18a_snake18_800CD808,
    d18a_snake18_800CD888, d18a_snake18_800CD930, d18a_snake18_800CD9A8,
    d18a_snake18_800CDB04, d18a_snake18_800CDC3C, d18a_snake18_800CDD4C,
    d18a_snake18_800CDE8C, d18a_snake18_800CDFC8, d18a_snake18_800CE09C,
    d18a_snake18_800CE210, d18a_snake18_800CE38C, d18a_snake18_800CE4E4,
    d18a_snake18_800CE6B0, d18a_snake18_800CE7BC, d18a_snake18_800CE7C4,
    d18a_snake18_800CE834, d18a_snake18_800CE8E0, d18a_snake18_800CE998,
    d18a_snake18_800CEA84};
static const Snake18Fn callbacks[] = {NULL,
                                      d18a_snake18_800CD64C,
                                      d18a_snake18_800CD768,
                                      d18a_snake18_800CD808,
                                      d18a_snake18_800CD888,
                                      d18a_snake18_800CD930,
                                      d18a_snake18_800CD9A8,
                                      d18a_snake18_800CDB04,
                                      d18a_snake18_800CDC3C,
                                      d18a_snake18_800CDD4C,
                                      d18a_snake18_800CDE8C,
                                      d18a_snake18_800CDFC8,
                                      d18a_snake18_800CE09C,
                                      d18a_snake18_800CE210,
                                      d18a_snake18_800CE38C,
                                      d18a_snake18_800CE4E4,
                                      d18a_snake18_800CE6B0,
                                      d18a_snake18_800CE7BC,
                                      d18a_snake18_800CE7C4,
                                      d18a_snake18_800CE834,
                                      d18a_snake18_800CE8E0,
                                      d18a_snake18_800CE998,
                                      d18a_snake18_800CEA84,
                                      d18a_snake18_800CED2C,
                                      d18a_snake18_800CEDB0,
                                      d18a_snake18_800CEF0C,
                                      d18a_snake18_800D1424,
                                      d18a_snake18_800D1598,
                                      d18a_snake18_800D1A6C};
static void Initialize(void) {
  const Input *in = &fixture->input;
  memset(&actor, 0, sizeof(actor));
  memset(&pad, 0, sizeof(pad));
  trace_size = 0;
  for (int i = 0; i < 112; ++i)
    motion[i] = i + 1;
  pack = (Snake18Type){motion,      motion + 16, motion + 32, motion + 48,
                       motion + 64, motion + 80, motion + 96};
  map.hzd = &hazard;
  actor.control.map = &map;
  actor.pad = &pad;
  actor.f8A8 = &pack;
  pad.status = in->status;
  pad.press = in->press;
  actor.control.mov = (SVECTOR){100, in->y, 200, 0};
  actor.control.rot = (SVECTOR){0, 1200, 0, 0};
  actor.control.step = (SVECTOR){10, 20, 30, 0};
  actor.control.turn = (SVECTOR){11, 1200, 22, 0};
  actor.body.action = in->motion;
  actor.body.is_end = in->end;
  actor.f7E4 = 0x40;
  actor.f858 = 9;
  actor.f8AC = callbacks[1];
  actor.f8B0 = 99;
  actor.f8B8 = 98;
  actor.f8FE = in->stance;
  actor.f900 = 450;
  actor.f906 = -32;
  actor.f910 = in->local;
  actor.f912 = in->wall_ticks;
  actor.f924 = 1700;
  actor.m_ctrl.info1.mask = 0x1234;
  actor.m_ctrl.info2.mask = 0x5678;
  GM_PlayerStatus = in->player;
  GM_GameStatus = in->game;
  GM_AlertMode = in->alert;
  GM_Photocode = 0;
  Snake18PadDirection = in->direction;
  Snake18WallDirection = in->wall;
  Snake18WallSide = in->wall_side;
  wall_vector = (SVECTOR){320, 0, -640, 0};
  Snake18WallVector = in->wall_vector ? &wall_vector : NULL;
  wall_flags = 0;
}
static int CallbackId(Snake18Fn callback) {
  for (unsigned i = 0; i < sizeof(callbacks) / sizeof(callbacks[0]); ++i)
    if (callbacks[i] == callback)
      return i;
  assert(!"Unknown Snake18 callback");
  return -1;
}
static void Verify(void) {
  int actual[] = {actor.control.mov.vx,
                  actor.control.mov.vy,
                  actor.control.mov.vz,
                  actor.control.rot.vy,
                  actor.control.turn.vx,
                  actor.control.turn.vy,
                  actor.control.turn.vz,
                  actor.control.step.vx,
                  actor.control.step.vy,
                  actor.control.step.vz,
                  actor.f7E4,
                  actor.f858,
                  actor.f8B0,
                  actor.f8B8,
                  actor.f8FE,
                  actor.f900,
                  actor.f902,
                  actor.f906,
                  actor.f910,
                  actor.f912,
                  actor.f924,
                  actor.m_ctrl.info1.mask,
                  actor.m_ctrl.info2.mask,
                  CallbackId(actor.f8AC),
                  CallbackId(actor.f8B4),
                  CallbackId(actor.f8BC),
                  CallbackId(actor.f8C0),
                  GM_PlayerStatus};
  for (unsigned i = 0; i < sizeof(actual) / sizeof(actual[0]); ++i) {
    if (actual[i] != fixture->output[i])
      fprintf(stderr, "%s field %u: got %d expected %d\n", fixture->name, i,
              actual[i], fixture->output[i]);
    assert(actual[i] == fixture->output[i]);
  }
  if (trace_size != fixture->trace_size ||
      memcmp(trace, fixture->trace, trace_size * sizeof(int))) {
    fprintf(stderr, "%s trace mismatch\nactual:", fixture->name);
    for (int i = 0; i < trace_size; ++i)
      fprintf(stderr, " %d", trace[i]);
    fprintf(stderr, "\nexpected:");
    for (int i = 0; i < fixture->trace_size; ++i)
      fprintf(stderr, " %d", fixture->trace[i]);
    fprintf(stderr, "\n");
    assert(0);
  }
}
int main(void) {
  _set_error_mode(_OUT_TO_STDERR);
  for (unsigned i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
    fixture = &fixtures[i];
    Initialize();
    actions[fixture->input.action](&actor, fixture->input.time);
    Verify();
  }
  puts("Snake18 matches 352 original MIPS stance, wall, movement and input "
       "state cases.");
  return 0;
}
