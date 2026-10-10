#include "mgs_native.h"
#undef fprintf

#include "../vendor/mgs/source/libgv/near.c"
#include "../vendor/mgs/source/overlays/s10a/animal/zako10/action.c"
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  int action, action2, time, press, direction, difference, run, motion;
  int touches, side, is_end, vertical, grounded, disable_sphere;
} Input;

typedef struct {
  const char *name;
  Input input;
  int output[29];
  int trace_size;
  int trace[16];
} Fixture;

#include "mgs_s10_zako_action_fixtures.h"

Z10Commander Z10_Command;
int Z10_EyeLength = 4000;
OBJECT *GM_PlayerBody;
static OBJECT player_body;
static struct {
  DG_OBJS header;
  DG_OBJ units[8];
} objects, player_objects;
static Work actor;
static TARGET target;
static HOMING homing;
static const Fixture *fixture;
static int trace[32], trace_size;
static ACTION actions[] = {NULL,     Idle, Walk,          Turn,
                           ReadyGun, Fire, InactiveAction};

static void Record(int count, ...) {
  va_list values;
  assert(trace_size + count <= 32);
  va_start(values, count);
  for (int index = 0; index < count; index++)
    trace[trace_size++] = va_arg(values, int);
  va_end(values);
}

void GM_ConfigObjectAction(OBJECT *object, int action, int frame, int interp) {
  assert(object == &actor.body);
  Record(4, 11, action, frame, interp);
}

int GM_ConfigMotionAdjust(OBJECT *object, SVECTOR *adjust) {
  assert(object == &actor.body && (!adjust || adjust == actor.adjust));
  Record(2, 12, adjust != NULL);
  return 0;
}

void GM_ConfigObjectOverride(OBJECT *object, int action, int frame, int interp,
                             u_long mask) {
  assert(object == &actor.body);
  Record(5, 13, action, frame, interp, (int)mask);
}

void GM_SeSetMode(SVECTOR *position, int sound, int mode) {
  assert(position == &actor.control.mov);
  Record(3, 14, sound, mode);
}

int Z10_SetPutChar(Work *work, int index) {
  assert(work == &actor);
  Record(2, 15, index);
  return 1;
}

int GV_DiffDirS(int from, int to) {
  (void)from;
  (void)to;
  return fixture->input.side;
}

int GV_DiffDirAbs(int from, int to) {
  (void)from;
  (void)to;
  return fixture->input.difference;
}

int GV_VecDir2(SVECTOR *vector) { return vector->vx; }

int rsin(int angle) {
  (void)angle;
  return 1024;
}

int rcos(int angle) {
  (void)angle;
  return 2048;
}

long ratan2(long y, long x) {
  (void)y;
  (void)x;
  return 1500;
}

static void Initialize(void) {
  const Input *in = &fixture->input;
  memset(&actor, 0, sizeof(actor));
  memset(&target, 0, sizeof(target));
  memset(&homing, 0, sizeof(homing));
  trace_size = 0;
  actor.body.objs = &objects.header;
  GM_PlayerBody = &player_body;
  player_body.objs = &player_objects.header;
  objects.units[6].world.t[1] = 100;
  player_objects.units[6].world.t[1] = 500;
  actor.target = &target;
  actor.hom = &homing;
  actor.action = actions[in->action];
  actor.action2 = in->action2 ? InactiveAction : NULL;
  actor.time = in->time;
  actor.time2 = 7;
  actor.pad.press = in->press;
  actor.pad.field_4 = in->run;
  actor.pad.dir = in->direction;
  actor.act.motion1 = in->motion;
  actor.body.is_end = in->is_end;
  actor.act.field_04 = in->vertical;
  actor.act.field_1C = 450;
  actor.act.field_1E = in->disable_sphere;
  actor.control.grounded = in->grounded;
  actor.control.n_touches = in->touches;
  actor.control.vecs[0] = (SVECTOR){400, 0, 0, 0};
  actor.control.vecs[1] = (SVECTOR){900, 0, 0, 0};
  actor.body.height = 1000;
  actor.scale = 4096;
  actor.control.levels[0] = 200;
  actor.control.r_sphere = 100;
  actor.control.rot.vy = 1200;
  actor.sn_dir = 1800;
  actor.mark_time = 2;
  actor.trigger = actor.field_8FC = actor.suppress_step = 99;
}

static int ActionId(ACTION action) {
  for (int index = 0; index < 7; index++)
    if (actions[index] == action)
      return index;
  assert(0);
  return -1;
}

static void Verify(void) {
  int actual[] = {actor.time,
                  actor.time2,
                  ActionId(actor.action),
                  ActionId(actor.action2),
                  target.class,
                  actor.trigger,
                  actor.vision.length,
                  actor.act_status,
                  actor.field_8FC,
                  actor.suppress_step,
                  actor.control.height,
                  actor.control.hzd_height,
                  actor.control.r_sphere,
                  actor.act.field_04,
                  homing.flag,
                  actor.mark_time,
                  actor.act.motion1,
                  actor.act.motion2,
                  actor.control.turn.vx,
                  actor.control.turn.vy,
                  actor.control.turn.vz,
                  actor.control.step.vx,
                  actor.control.step.vy,
                  actor.control.step.vz,
                  actor.control.rot.vy,
                  actor.vision.facedir,
                  actor.adjust[2].vx,
                  actor.adjust[6].vx,
                  actor.adjust[7].vx};
  for (unsigned index = 0; index < sizeof(actual) / sizeof(actual[0]);
       index++) {
    if (actual[index] != fixture->output[index])
      fprintf(stderr, "%s field %u: got %d expected %d\n", fixture->name, index,
              actual[index], fixture->output[index]);
    assert(actual[index] == fixture->output[index]);
  }
  assert(trace_size == fixture->trace_size);
  assert(memcmp(trace, fixture->trace, trace_size * sizeof(int)) == 0);
}

int main(void) {
  _set_error_mode(_OUT_TO_STDERR);
  for (unsigned index = 0; index < sizeof(fixtures) / sizeof(fixtures[0]);
       index++) {
    fixture = &fixtures[index];
    Initialize();
    Z10_ActionUpdate(&actor);
    Verify();
  }
  puts("Zako10 matches 42 original MIPS action, input, movement and firing "
       "traces.");
  return 0;
}
