#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/s19a/props_data.c"
#include "garage_helpers.inc"
#include "overlays/s19a/props_native.h"
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct Input {
  int kind, action, tick, ended, flags, mode, damaged, dead, health,
      player_flags, angle;
} Input;
typedef struct Fixture {
  Input input;
  int count, output[23];
  int trace_size, trace[16];
} Fixture;
#include "mgs_garage_state_fixtures.h"

SVECTOR GM_PlayerPosition, DG_ZeroVector;
int GM_PlayerStatus, GM_GameOverTimer;
short linkvarbuf[MAX_LINKVARBUF];
static GarageCompanion companion;
static GarageSnake snake;
static TARGET target;
static struct {
  DG_OBJS header;
  DG_OBJ units[8];
} objects;
static const Fixture *fixture;
static int trace[16], trace_size;
static GarageCompanionAction companion_actions[] = {NULL,
                                                    Garage_800DBA10,
                                                    Garage_800DBA54,
                                                    Garage_800DBB44,
                                                    Garage_800DBC28,
                                                    Garage_800DBCF8,
                                                    Garage_800DBD6C,
                                                    Garage_800DBDE4,
                                                    Garage_800DBE58,
                                                    Garage_800DBECC,
                                                    Garage_800DBF44,
                                                    Garage_800DBFB8};
static GarageSnakeAction snake_actions[] = {
    NULL, Garage_800DA940, Garage_800DAA9C, Garage_800DABF0, Garage_800DACF4};

static void Record(int count, ...) {
  va_list args;
  assert(trace_size + count <= 16);
  va_start(args, count);
  while (count-- > 0)
    trace[trace_size++] = va_arg(args, int);
  va_end(args);
}
void GM_ConfigObjectAction(OBJECT *body, int action, int frame, int interp) {
  assert(body == &companion.body || body == &snake.body);
  Record(4, 1, action, frame, interp);
}
void GM_SeSet(SVECTOR *pos, int sound) {
  assert(pos);
  Record(5, 2, sound, pos->vx, pos->vy, pos->vz);
}
void GM_SeSetMode(SVECTOR *pos, int sound, int mode) {
  assert(pos == &snake.control.mov);
  Record(3, 3, sound, mode);
}
void *NewPadVibration(unsigned char *pattern, int port) {
  assert(pattern == GarageVibrationDamage1 ||
         pattern == GarageVibrationDamage2 || pattern == GarageVibrationFire1 ||
         pattern == GarageVibrationFire2);
  Record(2, 4, port);
  return NULL;
}
int GV_RandS(int range) {
  Record(2, 5, range);
  return -17;
}
void Garage_800DA728(GarageSnake *work, int joint, int count) {
  assert(work == &snake);
  Record(3, 6, joint, count);
}
void Garage_800DA8A0(GarageSnake *work) {
  assert(work == &snake);
  Record(1, 7);
}
void Voicesys_800CE310(void) { Record(1, 8); }
void Voicesys_800CE5F8(int index, int delay) { Record(3, 9, index, delay); }
void Voicesys_800CE734(void) { Record(1, 10); }
long ratan2(long y, long x) {
  (void)y;
  (void)x;
  return fixture->input.angle;
}
void GV_SubVec3(SVECTOR *a, SVECTOR *b, SVECTOR *out) {
  out->vx = a->vx - b->vx;
  out->vy = a->vy - b->vy;
  out->vz = a->vz - b->vz;
}

int GCL_ExecProc(int proc, GCL_ARGS *args) {
  (void)proc;
  (void)args;
  abort();
}

static void Initialize(void) {
  const Input *in = &fixture->input;
  memset(&companion, 0, sizeof(companion));
  memset(&snake, 0, sizeof(snake));
  memset(&target, 0, sizeof(target));
  trace_size = 0;
  companion.body.objs = snake.body.objs = &objects.header;
  objects.units[4].world.t[0] = 700;
  objects.units[4].world.t[1] = 800;
  objects.units[4].world.t[2] = 900;
  companion.body.is_end = snake.body.is_end = in->ended;
  companion.control.mov = snake.control.mov = (SVECTOR){120, 230, 340, 0};
  companion.control.turn = snake.control.turn = (SVECTOR){11, 12, 13, 14};
  GarageIgnition = GarageHeadlightIntensity = 0;
  GarageCompanionFlags = in->flags;
  GM_PlayerPosition = (SVECTOR){800, 600, 900, 0};
  GM_GameOverTimer = 0;
  GM_PlayerStatus = in->player_flags;
  GM_Vitality = in->health;
  if (in->kind == 0) {
    companion.action = companion_actions[in->action];
    companion.tick = in->tick;
    companion.action_id = 99;
    companion.motions[0] = 130;
    companion.motions[1] = 131;
    companion.motions[2] = 132;
    companion.motions[3] = 130;
  } else {
    snake.target = &target;
    snake.action = snake_actions[in->action];
    snake.tick = in->tick;
    snake.field_928 = in->mode;
    snake.field_92C = in->flags;
    snake.field_950 = in->dead;
    snake.direction = 1000;
    snake.field_7E0 = (SVECTOR){10, 20, 30, 40};
    target.damaged = in->damaged;
    target.damage = 33;
    target.force = (SVECTOR){9, 8, 7, 6};
  }
}

static int CompanionAction(void) {
  for (unsigned i = 0;
       i < sizeof(companion_actions) / sizeof(companion_actions[0]); ++i)
    if (companion.action == companion_actions[i])
      return i;
  abort();
}
static int SnakeAction(void) {
  for (unsigned i = 0; i < sizeof(snake_actions) / sizeof(snake_actions[0]);
       ++i)
    if (snake.action == snake_actions[i])
      return i;
  abort();
}
static void Compare(const int *actual, int count) {
  assert(count == fixture->count);
  for (int i = 0; i < count; ++i) {
    if (actual[i] != fixture->output[i])
      fprintf(stderr, "kind%d action%d tick%d flags%x field%d: %d != %d\n",
              fixture->input.kind, fixture->input.action, fixture->input.tick,
              fixture->input.flags, i, actual[i], fixture->output[i]);
    assert(actual[i] == fixture->output[i]);
  }
  if (trace_size != fixture->trace_size ||
      memcmp(trace, fixture->trace, trace_size * sizeof(int))) {
    fprintf(stderr,
            "kind%d action%d tick%d flags%x trace:", fixture->input.kind,
            fixture->input.action, fixture->input.tick, fixture->input.flags);
    for (int i = 0; i < trace_size; ++i)
      fprintf(stderr, " %d", trace[i]);
    fprintf(stderr, " expected:");
    for (int i = 0; i < fixture->trace_size; ++i)
      fprintf(stderr, " %d", fixture->trace[i]);
    fprintf(stderr, "\n");
    abort();
  }
}
static void Verify(void) {
  if (fixture->input.kind == 0) {
    Garage_800DC0A0(&companion);
    int actual[] = {CompanionAction(),          companion.tick,
                    companion.action_id,        companion.flags,
                    companion.field_7E4,        companion.control.turn.vx,
                    companion.control.turn.vy,  companion.control.turn.vz,
                    companion.control.turn.pad, GarageIgnition,
                    GarageHeadlightIntensity,   GarageCompanionFlags};
    Compare(actual, sizeof(actual) / sizeof(actual[0]));
  } else {
    Garage_800DAD68(&snake);
    int actual[] = {SnakeAction(),         snake.tick,
                    snake.field_928,       snake.field_7E0.vx,
                    snake.field_7E0.vy,    snake.field_7E0.vz,
                    snake.field_7E0.pad,   snake.field_940,
                    snake.field_944,       snake.field_950,
                    target.class,          target.damaged,
                    target.damage,         target.force.vx,
                    target.force.vy,       target.force.vz,
                    target.force.pad,      snake.direction,
                    GM_GameOverTimer,      snake.control.turn.vx,
                    snake.control.turn.vy, snake.control.turn.vz,
                    snake.control.turn.pad};
    Compare(actual, sizeof(actual) / sizeof(actual[0]));
  }
}
int main(void) {
  _set_error_mode(_OUT_TO_STDERR);
  for (unsigned i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
    fixture = &fixtures[i];
    Initialize();
    Verify();
  }
  puts("Garage companion and parked-Snake states match 4453 original MIPS "
       "cases and effect traces.");
  return 0;
}
