#include "mgs_native.h"
#undef fprintf

#include "../vendor/mgs/source/libgv/near.c"
#include "../vendor/mgs/source/overlays/s10a/okajima/meryl10/action.c"
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  int state, action, is_end, health, damage0, damage1, damaged0, damaged1,
      mode0;
  int voice_state, hit_type, voice_cycle, hit_cycle, death_time, speed,
      grounded;
  int stream, choice, damage_proc;
} Input;

typedef struct {
  const char *name;
  Input input;
  int output[24];
  int trace_size;
  int trace[32];
} Fixture;

#include "mgs_s10_meryl_fixtures.h"

SVECTOR DG_ZeroVector;
static Meryl10Work actor;
static TARGET targets[2];
static struct {
  DG_OBJS header;
  DG_OBJ units[8];
} objects;
static int trace[64];
static int trace_size;
static const Fixture *fixture;

static void Record(int count, ...) {
  va_list values;
  assert(trace_size + count <= 64);
  va_start(values, count);
  for (int index = 0; index < count; index++)
    trace[trace_size++] = va_arg(values, int);
  va_end(values);
}

void GM_ConfigObjectAction(OBJECT *object, int action, int frame, int interp) {
  assert(object == &actor.body);
  Record(4, 1, action, frame, interp);
}

int GM_ConfigMotionAdjust(OBJECT *object, SVECTOR *adjust) {
  assert(object == &actor.body && adjust == actor.adjustments);
  Record(1, 2);
  return 0;
}

void *GM_VoxStream(int voice, int proc) {
  Record(3, 3, voice, proc);
  return NULL;
}

void GCL_ForceExecProc(int proc, GCL_ARGS *args) {
  assert(!args || args->argc == 1);
  Record(4, 4, proc, args ? args->argc : 0, args ? (int)args->argv[0] : 0);
}

void GM_SeSet2(int pan, int volume, int sound) {
  Record(4, 5, pan, volume, sound);
}

void GM_GameOver(void) { Record(1, 6); }

void DG_SetPos(MATRIX *world) {
  int unit;
  for (unit = 0; unit < 8; unit++)
    if (world == &objects.units[unit].world)
      break;
  assert(unit < 8);
  Record(2, 7, unit);
}

void DG_MovePos(SVECTOR *position) {
  Record(4, 8, position->vx, position->vy, position->vz);
}

void DG_RotatePos(SVECTOR *rotation) {
  Record(4, 9, rotation->vx, rotation->vy, rotation->vz);
}

MATRIX *ReadRotMatrix(MATRIX *matrix) {
  memset(matrix, 0, sizeof(*matrix));
  matrix->m[0][0] = matrix->m[1][1] = matrix->m[2][2] = 4096;
  matrix->t[0] = 123;
  matrix->t[1] = -200;
  matrix->t[2] = 456;
  return matrix;
}

void *NewBlood(MATRIX *world, int count) {
  assert(world->t[0] == 123 && world->t[2] == 456);
  Record(2, 10, count);
  return NULL;
}

void *NewKetchap_s(SVECTOR *position, int type, int size, int speed) {
  Record(7, 11, position->vx, position->vy, position->vz, type, size, speed);
  return NULL;
}

int GM_StreamStatus(void) { return fixture->input.stream; }

int GV_RandU(int range) {
  assert(range == 8 || range == 256 || range == 4);
  return range == 8 ? 3 : range == 256 ? 17 : fixture->input.choice;
}

int GV_RandS(int range) {
  assert(range == 128 || range == 512);
  return range == 128 ? 5 : -7;
}

static void Initialize(void) {
  const Input *in = &fixture->input;
  memset(&actor, 0, sizeof(actor));
  memset(targets, 0, sizeof(targets));
  trace_size = 0;
  blood_rotation = (SVECTOR){-1024, 0, 0, 0};
  actor.control.mov = (SVECTOR){1200, -30000, 17000, 0};
  actor.control.r_sphere = 100;
  actor.control.grounded = in->grounded;
  actor.body.objs = &objects.header;
  actor.body.height = 320;
  actor.body.is_end = in->is_end;
  actor.targets[0] = &targets[0];
  actor.targets[1] = &targets[1];
  actor.action = in->action;
  actor.vertical_speed = in->speed;
  actor.state = in->state;
  actor.death_time = in->death_time;
  actor.voice_state = in->voice_state;
  actor.hit_type = in->hit_type;
  actor.voice_cycle = in->voice_cycle;
  actor.hit_voice_cycle = in->hit_cycle;
  actor.damage_proc = in->damage_proc;
  actor.hit_proc = 34;
  actor.death_proc = 35;
  actor.health_fraction = in->health;
  for (int index = 0; index < 32; index++)
    actor.voices[index] = 100 + index;
  for (int index = 0; index < 16; index++)
    actor.adjustments[index] = (SVECTOR){99, 99, 99, 99};
  targets[0].damaged = in->damaged0;
  targets[1].damaged = in->damaged1;
  targets[0].damage = in->damage0;
  targets[1].damage = in->damage1;
  targets[0].a_mode = in->mode0;
}

static void Verify(void) {
  int actual[] = {actor.health_fraction, actor.state,
                  actor.action,          actor.voice_state,
                  actor.hit_type,        actor.voice_cycle,
                  actor.hit_voice_cycle, actor.death_time,
                  actor.vertical_speed,  actor.exit_state,
                  actor.control.height,  actor.control.r_sphere,
                  actor.control.step.vy, actor.adjustments[0].vx,
                  targets[0].class,      targets[0].damaged,
                  targets[0].vital,      targets[0].damage,
                  targets[0].a_mode,     targets[1].class,
                  targets[1].damaged,    targets[1].vital,
                  targets[1].damage,     targets[1].a_mode};
  assert(memcmp(&Meryl10Position, &actor.control.mov, sizeof(SVECTOR)) == 0);
  for (unsigned index = 0; index < sizeof(actual) / sizeof(actual[0]);
       index++) {
    if (actual[index] != fixture->output[index])
      fprintf(stderr, "%s: field %u got %d expected %d\n", fixture->name, index,
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
    Meryl10UpdateAction(&actor);
    Verify();
  }
  puts("Bloody Meryl matches 18 original MIPS damage, voice, animation and "
       "gravity traces.");
  return 0;
}
