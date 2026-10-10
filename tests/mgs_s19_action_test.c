#include "mgs_native.h"
#undef fprintf

#include "../vendor/mgs/source/libgv/near.c"
#include "../vendor/mgs/source/overlays/s19a/guard/action.c"
#include "../vendor/mgs/source/overlays/s19a/guard/damage.c"
#include "../vendor/mgs/source/overlays/s19a/guard/data.c"
#include "../vendor/mgs/source/overlays/s19a/guard/override.c"
#include "../vendor/mgs/source/overlays/s19a/guard/reaction.c"
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

_Static_assert(sizeof(S19Work) == 3136, "Original Garage guard actor layout");
_Static_assert(offsetof(S19Work, param.damage) == 2946,
               "Original health checkpoint");
_Static_assert(offsetof(S19Work, field_C38) == 3124,
               "Original action reset field");

typedef struct {
  int action, time, press, direction, difference, run, motion, touches, side,
      is_end;
  int grounded, damaged, damage_mode, health, previous_health, faint, hit_type;
  int x, y, z, floor, player_action, capture_time, game_status;
} Input;

typedef struct {
  const char *name;
  Input input;
  int output[46];
  int trace_size;
  int trace[32];
} Fixture;

#include "mgs_s19_action_fixtures.h"

SVECTOR DG_ZeroVector, GM_PlayerPosition, GM_NoisePosition;
int GM_NoisePower, GM_NoiseLength, GM_PlayerAction, GM_GameStatus,
    GM_PlayerStatus;
short linkvarbuf[MAX_LINKVARBUF];
CONTROL *GM_PlayerControl;
static CONTROL player_control;
OBJECT *GM_PlayerBody;
static OBJECT player_body;
static struct {
  DG_OBJS header;
  DG_OBJ units[8];
} objects, player_objects;
static S19Work actor;
static TARGET target;
static HOMING homing;
static const Fixture *fixture;
static int trace[32], trace_size;
static S19ACTION actions[] = {
    NULL,          s19a_800CE750, s19a_800CE8F8, s19a_800CEB90, s19a_800CEC20,
    s19a_800CED08, s19a_800CED10, s19a_800CEE84, s19a_800CEF34, s19a_800CF068,
    s19a_800CF1C0, s19a_800CF298, s19a_800CF340, s19a_800CF6B8, s19a_800CFA2C,
    s19a_800CFAA0, s19a_800CFBF0, s19a_800CFD68, s19a_800CFE30, s19a_800CFF34,
    s19a_800D0048, s19a_800D055C, s19a_800D073C, s19a_800D0838, s19a_800D0AB8,
    s19a_800D0B84, s19a_800D0C50, s19a_800D0CE8, s19a_800D0D80, s19a_800D0E34,
    s19a_800D0EFC, s19a_800D0FA0, s19a_800D1068, s19a_800D1280, s19a_800D13C8};

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

int s19a_800D1BA8(S19Work *work, int index) {
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

void GM_SeSet(SVECTOR *position, int sound) {
  assert(position == &actor.control.mov);
  Record(2, 14, sound);
}
void s19a_800D1564(S19Work *work, int unit, int count) {
  assert(work == &actor);
  Record(3, 16, unit, count);
}
void s19a_800D15D4(S19Work *work) {
  assert(work == &actor);
  Record(1, 17);
}
void s19a_800D1638(S19Work *work) {
  assert(work == &actor);
  Record(1, 18);
}
void *NewPadVibration(unsigned char *pattern, int port) {
  assert(pattern == S19Vibration1 || pattern == S19Vibration2);
  Record(2, 19, port);
  return NULL;
}
void GM_ConfigControlAttribute(CONTROL *control, int flags) {
  assert(control == &actor.control);
  Record(2, 20, flags);
}
void *NewGrenadeEnemy(CONTROL *control, OBJECT *parent, int unit, u_long *flags,
                      SVECTOR *position, int side) {
  assert(control == &actor.control && parent == &actor.body && unit == 9);
  assert(flags == &actor.trigger && position == &GM_PlayerPosition &&
         side == ENEMY_SIDE);
  Record(1, 21);
  return &actor;
}
void GV_DestroyActor(void *work) {
  assert(work == &actor);
  Record(1, 22);
}
void DG_SetPos2(SVECTOR *position, SVECTOR *rotation) {
  assert(position && rotation);
}
void DG_SetPos(MATRIX *matrix) { assert(matrix); }
void DG_MovePos(SVECTOR *position) { assert(position); }
void DG_PutVector(SVECTOR *from, SVECTOR *to, int count) {
  assert(from && count == 1);
  *to = DG_ZeroVector;
}
void DG_RotVector(SVECTOR *from, SVECTOR *to, int count) {
  assert(from && count == 1);
  *to = DG_ZeroVector;
}
void GV_SubVec3(SVECTOR *from, SVECTOR *to, SVECTOR *result) {
  result->vx = from->vx - to->vx;
  result->vy = from->vy - to->vy;
  result->vz = from->vz - to->vz;
}
void GM_SetTarget(TARGET *value, int class, int side, SVECTOR *size) {
  assert(value && size);
  (void)class;
  (void)side;
}
void GM_SetPowerTarget(TARGET *value, int mode, int knock, int health,
                       int faint, SVECTOR *force) {
  assert(value && force);
  (void)mode;
  (void)knock;
  (void)health;
  (void)faint;
}
int GM_PowerTarget(TARGET *value) {
  assert(value);
  return 0;
}
void GM_MoveTarget(TARGET *value, SVECTOR *position) {
  assert(value && position);
  value->center = *position;
}
int GV_RandU(int range) {
  assert(range > 0);
  return 0;
}
MATRIX *ReadRotMatrix(MATRIX *matrix) {
  memset(matrix, 0, sizeof(*matrix));
  return matrix;
}
void AN_Sleep(SVECTOR *position) { assert(position); }
void AN_Unknown_800C3B7C(MATRIX *matrix) {
  assert(matrix);
  Record(1, 23);
}

void s19a_800D1850(S19Work *work) {
  (void)work;
  abort();
}
void s19a_800D18E8(S19Work *work) {
  (void)work;
  abort();
}
void s19a_800D1A30(S19Work *work) {
  (void)work;
  abort();
}
void s19a_800D1A6C(S19Work *work) {
  (void)work;
  abort();
}
MAP *GM_GetMap(int name) {
  (void)name;
  abort();
}
int HZD_BoundOutZone(HZD_HDL *hzd, int from, int to, int distance) {
  (void)hzd;
  (void)from;
  (void)to;
  (void)distance;
  abort();
}
void GM_SetCaptureTarget(TARGET *target, int mode, int faint, int *extra,
                         SVECTOR *position) {
  (void)target;
  (void)mode;
  (void)faint;
  (void)extra;
  (void)position;
  abort();
}
void GM_SetC4Target(TARGET *target, MATRIX *body) {
  (void)target;
  (void)body;
  abort();
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
  actor.action2 = NULL;
  actor.time = in->time;
  actor.time2 = 7;
  actor.pad.press = in->press;
  actor.pad.field_4 = in->run;
  actor.pad.dir = in->direction;
  actor.act.motion1 = in->motion;
  actor.body.is_end = in->is_end;
  actor.act.field_04 = 0;
  actor.act.field_1C = 450;
  actor.act.field_1E = 0;
  actor.control.grounded = in->grounded;
  actor.control.n_touches = in->touches;
  actor.control.vecs[0] = (SVECTOR){400, 0, 0, 0};
  actor.control.vecs[1] = (SVECTOR){900, 0, 0, 0};
  actor.body.height = 1000;
  actor.scale = 4096;
  actor.control.levels[0] = in->floor;
  actor.control.r_sphere = 100;
  actor.control.rot.vy = 1200;
  actor.sn_dir = 1800;
  actor.mark_time = 2;
  actor.trigger = actor.field_8FC = actor.field_C38 = 99;
  target.field_1C = &player_control.rot;
  GM_PlayerControl = &player_control;
  target.damaged = in->damaged;
  target.a_mode = in->damage_mode;
  target.vital = in->health;
  target.damage = 123;
  target.faint = in->faint;
  target.captured = 1;
  actor.param.damage = in->previous_health;
  actor.param.faint = 7;
  actor.act.field_14 = in->hit_type;
  actor.field_B5A = 17;
  actor.field_B5C = in->capture_time;
  actor.control.mov = (SVECTOR){in->x, in->y, in->z, 0};
  actor.sn_dis = 1000;
  GM_PlayerAction = in->player_action;
  GM_GameStatus = in->game_status;
  GM_NoisePower = GM_NoiseLength = 0;
  GM_NoisePosition = DG_ZeroVector;
}

static int ActionId(S19ACTION action) {
  for (unsigned index = 0; index < sizeof(actions) / sizeof(actions[0]);
       index++)
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
                  actor.field_C38,
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
                  actor.adjust[7].vx,
                  target.vital,
                  target.damage,
                  target.faint,
                  target.damaged,
                  target.captured,
                  actor.param.damage,
                  actor.act.field_14,
                  actor.act.field_1E,
                  actor.field_B5A,
                  actor.field_B5C,
                  actor.field_9E4,
                  GM_NoisePower,
                  GM_NoiseLength,
                  GM_NoisePosition.vx,
                  GM_NoisePosition.vy,
                  GM_NoisePosition.vz,
                  GM_NoisePosition.pad};
  for (unsigned index = 0; index < sizeof(actual) / sizeof(actual[0]);
       index++) {
    if (actual[index] != fixture->output[index])
      fprintf(stderr, "%s field %u: got %d expected %d\n", fixture->name, index,
              actual[index], fixture->output[index]);
    assert(actual[index] == fixture->output[index]);
  }
  if (trace_size != fixture->trace_size ||
      memcmp(trace, fixture->trace, trace_size * sizeof(int))) {
    fprintf(stderr, "%s trace:", fixture->name);
    for (int i = 0; i < trace_size; i++)
      fprintf(stderr, " %d", trace[i]);
    fprintf(stderr, " expected:");
    for (int i = 0; i < fixture->trace_size; i++)
      fprintf(stderr, " %d", fixture->trace[i]);
    fprintf(stderr, "\n");
    assert(0);
  }
}

int main(void) {
  _set_error_mode(_OUT_TO_STDERR);
  for (unsigned index = 0; index < sizeof(fixtures) / sizeof(fixtures[0]);
       index++) {
    fixture = &fixtures[index];
    Initialize();
    s19a_800D092C(&actor);
    Verify();
  }
  puts("Garage guard matches 322 original MIPS damage, input, movement, fall "
       "and "
       "firing "
       "traces.");
  return 0;
}
