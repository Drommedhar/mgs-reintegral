#include "mgs_native.h"

#include "overlays/s19b/escape.h"

#include "escape_snake_types.inc"
#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct Input {
  int kind, buttons, analog, dx, dy, dead, lock, first, timer, commands, aim_y,
      shot, reverse, homing, hp, damage, target_hp, game_status, blink, hidden,
      item, rations, level, gameover;
} Input;
typedef struct Fixture {
  Input input;
  int output[59];
  int trace_size;
  int trace[64];
} Fixture;
#include "mgs_escape_snake_fixtures.h"

EscapeSystem Takabe_JeepSystem;
GM_CameraSystemWork GM_Camera;
GM_SnakeCameraWork GM_SnakeCamera;
SVECTOR DG_ZeroVector, GM_PlayerPosition;
CONTROL *GM_PlayerControl;
OBJECT *GM_PlayerBody;
int GM_PlayerStatus, GM_GameStatus, GM_GameOverTimer, GM_CurrentMap;
short linkvarbuf[MAX_LINKVARBUF];
GV_PAD GV_PadData[4];
VECTOR s19b_dword_800C39E8 = {2048, 2048, 2048, 0};
SVECTOR s19b_dword_800C3A48 = {0, 1435, -925, 0};
SVECTOR s19b_dword_800C3A50 = {180, -932, -340, 0};
int s19b_dword_800C3A58, s19b_dword_800C3A14, s19b_dword_800C3A18;
static Work work;
static TARGET target;
static CONTROL root_control;
static MATRIX root_matrix;
static struct {
  DG_OBJS header;
  DG_OBJ joints[8];
} objects;
static DG_OBJS weapon;
static SVECTOR last_position;
static const Fixture *fixture;
static int trace[64], trace_size;

static void Record(int count, ...) {
  va_list args;
  assert(trace_size + count <= 64);
  va_start(args, count);
  while (count-- > 0)
    trace[trace_size++] = va_arg(args, int);
  va_end(args);
}
static int Near(int id, int a, int b) {
  Record(3, id, a, b);
  return a + ((b - a) >> 2);
}
int GV_NearExp4P(int a, int b) { return Near(1, a, b); }
int GV_NearExp4(int a, int b) { return Near(2, a, b); }
void DG_SetPos2(SVECTOR *pos, SVECTOR *rot) {
  last_position = *pos;
  Record(7, 3, pos->vx, pos->vy, pos->vz, rot->vx, rot->vy, rot->vz);
}
static MATRIX *SetMatrix(MATRIX *out) {
  *out = (MATRIX){{{4096, 0, 300}, {0, -200, 0}, {0, 0, 4000}},
                  {last_position.vx, last_position.vy, last_position.vz}};
  return out;
}
MATRIX *RotMatrixZYX(SVECTOR *rot, MATRIX *out) {
  Record(4, 4, rot->vx, rot->vy, rot->vz);
  return SetMatrix(out);
}
MATRIX *CompMatrix(MATRIX *left, MATRIX *right, MATRIX *out) {
  assert(left == &root_matrix);
  *out = *right;
  out->t[0] += 100;
  out->t[1] += 200;
  out->t[2] += 300;
  return out;
}
MATRIX *ReadRotMatrix(MATRIX *out) { return SetMatrix(out); }
void GM_ActObject2(OBJECT *obj) {
  assert(obj == &work.weapon);
  Record(1, 5);
}
int GV_VecLen3(SVECTOR *vec) {
  Record(4, 6, vec->vx, vec->vy, vec->vz);
  return 1200;
}
long ratan2(long y, long x) {
  Record(3, 7, (int)y, (int)x);
  return 123;
}
void GV_AddVec3(SVECTOR *a, SVECTOR *b, SVECTOR *out) {
  out->vx = a->vx + b->vx;
  out->vy = a->vy + b->vy;
  out->vz = a->vz + b->vz;
}
void GV_SubVec3(SVECTOR *a, SVECTOR *b, SVECTOR *out) {
  out->vx = a->vx - b->vx;
  out->vy = a->vy - b->vy;
  out->vz = a->vz - b->vz;
}
void DG_RotVector(SVECTOR *a, SVECTOR *out, int count) {
  assert(count == 1);
  Record(4, 8, a->vx, a->vy, a->vz);
  out->vx = a->vx + 2;
  out->vy = a->vy + 2;
  out->vz = a->vz + 2;
}
void GM_GetHomingTarget2(MATRIX *world, int angle, int *yaw, int *pitch,
                         int map, int distance, int range) {
  assert(world == &weapon.world && distance == 6000 && range == 128 &&
         map == GM_CurrentMap);
  Record(2, 9, angle);
  *yaw = fixture->input.homing;
  *pitch = 222;
}
VECTOR *Square0(VECTOR *a, VECTOR *out) {
  out->vx = a->vx * a->vx;
  out->vy = a->vy * a->vy;
  out->vz = a->vz * a->vz;
  return out;
}
long MgsSquareRoot0(long value) {
  Record(2, 10, value);
  return 4011;
}
void GM_CheckShukanReverse(unsigned short *status) { *status ^= 0x5000; }
void GM_CheckShukanReverseAnalog(unsigned char *axis) { *axis = 255 - *axis; }
void *NewPadVibration(unsigned char *pattern, int port) {
  assert(pattern == (unsigned char *)&s19b_dword_800C3A14 ||
         pattern == (unsigned char *)&s19b_dword_800C3A18);
  Record(2, 11, port);
  return NULL;
}
int GV_RandS(int range) {
  Record(2, 12, range);
  return -17;
}
void sna_act_helper2_helper2_80033054(int voice, SVECTOR *rot) {
  assert(rot == &work.adjust[6]);
  Record(2, 13, voice);
}
void GM_SeSet(SVECTOR *pos, int sound) {
  assert(pos == NULL);
  Record(2, 14, sound);
}
void GM_SeSet2(int channel, int volume, int sound) {
  Record(4, 15, channel, volume, sound);
}
void GM_GameOver(void) { Record(1, 16); }
void s19b_jlamp2_800D613C(void *actor) { assert(actor == &work); }
void s19b_jlamp2_800D5484(Work *actor, int tick) {
  (void)actor;
  (void)tick;
  abort();
}
void s19b_jlamp2_800D55E8(Work *actor, int tick) {
  (void)actor;
  (void)tick;
  abort();
}
void GM_ActMotion(OBJECT *body) { assert(body == &work.body); }
void GM_ActControl(CONTROL *control) { assert(control == &work.control); }
void GM_ActObject(OBJECT *body) { assert(body == &work.body); }
MATRIX *ScaleMatrix(MATRIX *mat, VECTOR *scale) {
  assert(mat == &objects.header.world && scale == &s19b_dword_800C39E8);
  return mat;
}
int DG_GetLightMatrix(SVECTOR *pos, MATRIX *light) {
  assert(pos == &work.control.mov && light == work.light);
  return 0;
}
void GM_MoveTarget(TARGET *value, SVECTOR *pos) {
  assert(value == &target && pos == &work.control.mov);
}
void MgsProbeEscapeAim(int yaw, int locked) { (void)yaw; (void)locked; }
#include "escape_snake_helpers.inc"

static void Initialize(void) {
  const Input *i = &fixture->input;
  memset(&work, 0, sizeof(work));
  memset(&target, 0, sizeof(target));
  memset(&objects, 0, sizeof(objects));
  memset(&weapon, 0, sizeof(weapon));
  memset(&Takabe_JeepSystem, 0, sizeof(Takabe_JeepSystem));
  memset(&GM_SnakeCamera, 0, sizeof(GM_SnakeCamera));
  trace_size = 0;
  last_position = DG_ZeroVector;
  root_control.mov = (SVECTOR){500, 600, 700, 0};
  root_control.rot = (SVECTOR){20, 80, 40, 0};
  work.root_ctrl = &root_control;
  work.root_mat = &root_matrix;
  work.body.objs = &objects.header;
  work.weapon.objs = &weapon;
  work.target = &target;
  work.control.mov = (SVECTOR){120, 230, 340, 0};
  work.control.rot = (SVECTOR){10, 20, 30, 0};
  work.control.step = (SVECTOR){4, 5, 6, 0};
  work.control.turn = (SVECTOR){11, 12, 13, 14};
  work.body.height = 600;
  objects.joints[6].world =
      (MATRIX){{{4096, 0, 111}, {0, 0, 222}, {0, 0, 333}}, {700, 800, 900}};
  work.field_7E0 = (SVECTOR){10, 20, 30, 40};
  work.field_8CC = (SVECTOR){11, 12, 13, 14};
  work.aim = (SVECTOR){200, i->aim_y, 0, 0};
  work.field_904 = i->shot;
  work.field_908 = 1000;
  work.field_90C = 100;
  work.field_920 = 9;
  work.field_92C = i->commands;
  work.hp = i->hp;
  work.field_940 = i->lock;
  work.field_944 = i->blink;
  work.field_948 = i->hidden;
  work.field_950 = i->dead;
  work.pos = (SVECTOR){100, 200, 300, 0};
  target.class = 20;
  target.damaged = i->damage;
  target.vital = i->target_hp;
  target.damage = 33;
  target.force = (SVECTOR){9, 8, 7, 6};
  Takabe_JeepSystem.control = &root_control;
  Takabe_JeepSystem.field_4C = i->commands;
  GM_PlayerControl = &work.control;
  GM_PlayerBody = &work.body;
  GM_PlayerStatus = i->reverse;
  GM_Camera.first_person = i->first;
  s19b_dword_800C3A58 = i->timer;
  GV_PadData[0].status = i->buttons;
  GV_PadData[0].analog = i->analog;
  GV_PadData[0].left_dx = i->dx;
  GV_PadData[0].left_dy = i->dy;
  GM_GameLevel = i->level;
  GM_Vitality = 768;
  GM_VitalityMax = 1024;
  GM_Item = i->item;
  GM_RationFlag = i->rations;
  GM_RationUseCount = 7;
  GM_GameStatus = i->game_status;
  GM_GameOverTimer = i->gameover;
}

static void Check(size_t index) {
  int action = work.field_918 == (void *)s19b_jlamp2_800D5484   ? 1
               : work.field_918 == (void *)s19b_jlamp2_800D55E8 ? 2
                                                                : 0;
  int out[] = {work.field_8CC.vx,
               work.field_8CC.vy,
               work.field_8CC.vz,
               work.aim.vx,
               work.aim.vy,
               work.aim.vz,
               work.field_904,
               work.field_908,
               work.field_90C,
               work.field_92C,
               work.hp,
               work.field_940,
               work.field_944,
               work.field_948,
               work.field_94C,
               work.field_950,
               work.control.mov.vx,
               work.control.mov.vy,
               work.control.mov.vz,
               work.control.rot.vx,
               work.control.rot.vy,
               work.control.rot.vz,
               work.control.turn.vx,
               work.control.turn.vy,
               work.control.turn.vz,
               work.field_7E0.vx,
               work.field_7E0.vy,
               work.field_7E0.vz,
               work.pos.vx,
               work.pos.vy,
               work.pos.vz,
               target.class,
               target.damaged,
               target.vital,
               target.damage,
               target.force.vx,
               target.force.vy,
               target.force.vz,
               action,
               work.field_920,
               s19b_dword_800C3A58,
               GM_Camera.first_person,
               GM_PlayerStatus,
               Takabe_JeepSystem.field_5C,
               GM_SnakeCamera.rotate2.vx,
               GM_SnakeCamera.rotate2.vy,
               GM_SnakeCamera.position.vx,
               GM_SnakeCamera.position.vy,
               GM_SnakeCamera.position.vz,
               GM_SnakeCamera.target.vx,
               GM_SnakeCamera.target.vy,
               GM_SnakeCamera.target.vz,
               objects.header.flag,
               GM_Vitality,
               GM_Item,
               GM_RationFlag,
               GM_RationUseCount,
               GM_GameStatus,
               GM_GameOverTimer};
  assert(sizeof(out) == sizeof(fixture->output));
  for (size_t j = 0; j < 59; j++)
    if (out[j] != fixture->output[j]) {
      fprintf(stderr, "case%zu kind%d output%zu native%d original%d\n", index,
              fixture->input.kind, j, out[j], fixture->output[j]);
      abort();
    }
  assert(trace_size == fixture->trace_size);
  for (int j = 0; j < trace_size; j++)
    if (trace[j] != fixture->trace[j]) {
      fprintf(stderr, "case%zu trace%d native%d original%d\n", index, j,
              trace[j], fixture->trace[j]);
      abort();
    }
}
int main(void) {
  for (size_t i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); i++) {
    fixture = &fixtures[i];
    Initialize();
    if (fixture->input.kind == 0)
      s19b_jlamp2_800D596C(&work);
    else if (fixture->input.kind == 1)
      s19b_jlamp2_800D519C(&work);
    else
      s19b_jeep_sne_800D47F8(&work);
    Check(i);
  }
  printf("Escape Snake: %zu original-MIPS cases passed\n",
         sizeof(fixtures) / sizeof(fixtures[0]));
  return 0;
}
