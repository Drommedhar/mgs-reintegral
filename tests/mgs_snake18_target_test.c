#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/d18a/animal/snake18/native_target.c"
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  int mode, status, press, player, weapon, ammo, weapon_flags, animation;
  int power, target_class, faint;
} Input;
typedef struct {
  Input input;
  int output[13];
  int trace_size;
  int trace[64];
} Fixture;
#include "mgs_snake18_target_fixtures.h"

int GM_PlayerStatus;
static Snake18Work actor;
static GV_PAD pad;
static TARGET target;
static Snake18Type pack;
static char motion[16];
static short ammo;
static PUNCH punch;
static const Fixture *fixture;
static unsigned fixture_index;
static int trace[64], trace_size;

void d18a_snake18_800D3774(Snake18Work *work, int time) { assert(0); }
void d18a_snake18_800D1A6C(Snake18Work *work, int time) { assert(0); }
void d18a_snake18_800D1B3C(Snake18Work *work, int time) { assert(0); }
void d18a_snake18_800CEB78(Snake18Work *work, int time) { assert(0); }
static const Snake18Fn callbacks[] = {
    NULL, d18a_snake18_800D3774, d18a_snake18_800D1A6C, d18a_snake18_800D1B3C,
    d18a_snake18_800CEB78};

static void Record(int count, ...) {
  va_list args;
  assert(trace_size + count <= 64);
  va_start(args, count);
  for (int i = 0; i < count; ++i)
    trace[trace_size++] = va_arg(args, int);
  va_end(args);
}
void GM_SetTarget(TARGET *out, int flags, int side, SVECTOR *size) {
  assert(out == &actor.f7EC);
  Record(6, 1, flags, side, size->vx, size->vy, size->vz);
}
void GM_SetPowerTarget(TARGET *out, int flags, int mode, int life, int faint,
                       SVECTOR *force) {
  assert(out == &actor.f7EC);
  Record(8, 2, flags, mode, life, faint, force->vx, force->vy, force->vz);
}
void GM_SetCaptureTarget(TARGET *out, int life, int faint, int *flags,
                         SVECTOR *position) {
  assert(out == &actor.f7EC && flags == &actor.f840 && position == &actor.f848);
  Record(3, 3, life, faint);
}
void DG_RotVector(SVECTOR *from, SVECTOR *to, int count) {
  assert(count == 1);
  Record(4, 4, from->vx, from->vy, from->vz);
  *to = *from;
}
void DG_PutVector(SVECTOR *from, SVECTOR *to, int count) {
  assert(count == 1);
  Record(4, 5, from->vx, from->vy, from->vz);
  *to = *from;
}
void GM_MoveTarget(TARGET *out, SVECTOR *position) {
  assert(out == &actor.f7EC);
  Record(4, 6, position->vx, position->vy, position->vz);
}
int GM_PowerTarget(TARGET *out) {
  assert(out == &actor.f7EC);
  Record(1, 7);
  return fixture->input.power;
}
TARGET *GM_CaptureTarget(TARGET *out) {
  assert(out == &actor.f7EC);
  Record(1, 8);
  return fixture->input.power ? &target : NULL;
}
TARGET *GM_C4Target(TARGET *out) {
  assert(out == &actor.f7EC);
  Record(1, 9);
  return fixture->input.power ? &target : NULL;
}

static void Initialize(void) {
  const Input *in = &fixture->input;
  memset(&actor, 0, sizeof(actor));
  memset(&target, 0, sizeof(target));
  memset(&pad, 0, sizeof(pad));
  memset(&pack, 0, sizeof(pack));
  trace_size = 0;
  actor.pad = &pad;
  actor.f8A8 = &pack;
  actor.f860 = &ammo;
  actor.f854 = callbacks[4];
  actor.f864 = in->weapon;
  actor.f868 = in->weapon_flags;
  actor.f858 = 9;
  actor.f7E4 = 0x20;
  actor.f8AC = callbacks[4];
  actor.f8B0 = 99;
  actor.f910 = 3;
  actor.f912 = 5;
  actor.control.turn = (SVECTOR){11, 1200, 22, 0};
  actor.f930 = 2;
  pad.status = in->status;
  pad.press = in->press;
  ammo = in->ammo;
  pack.field_10 = motion;
  motion[2] = in->animation;
  target.class = in->target_class;
  target.damaged = 0xffff;
  punch = (PUNCH){{100, 200, 300, 0},
                  {400, 500, 600, 0},
                  {700, -800, 900, 0},
                  50,
                  in->faint};
  GM_PlayerStatus = in->player;
}
static int CallbackId(Snake18Fn callback) {
  for (unsigned i = 0; i < sizeof(callbacks) / sizeof(callbacks[0]); ++i)
    if (callback == callbacks[i])
      return i;
  assert(0);
  return -1;
}
static void Verify(int result) {
  int actual[] = {result,
                  CallbackId(actor.f8AC),
                  actor.f8B0,
                  actor.f7E4,
                  actor.f858,
                  actor.f910,
                  actor.f912,
                  actor.control.turn.vx,
                  actor.control.turn.vy,
                  actor.control.turn.vz,
                  GM_PlayerStatus,
                  actor.f834 == &target,
                  target.damaged};
  for (unsigned i = 0; i < sizeof(actual) / sizeof(actual[0]); ++i) {
    if (actual[i] != fixture->output[i])
      fprintf(stderr, "Fixture %u field %u: got %d expected %d\n",
              fixture_index, i, actual[i], fixture->output[i]);
    assert(actual[i] == fixture->output[i]);
  }
  if (trace_size != fixture->trace_size ||
      memcmp(trace, fixture->trace, trace_size * sizeof(int))) {
    fprintf(stderr, "Fixture %u target call sequence mismatch\n",
            fixture_index);
    assert(0);
  }
}
int main(void) {
  _set_error_mode(_OUT_TO_STDERR);
  for (fixture_index = 0;
       fixture_index < sizeof(fixtures) / sizeof(fixtures[0]);
       ++fixture_index) {
    int result;
    fixture = &fixtures[fixture_index];
    Initialize();
    switch (fixture->input.mode) {
    case 0:
      result = d18a_snake18_800CBBC8(&actor);
      break;
    case 1:
      result = d18a_snake18_800CB908(&actor, &punch);
      break;
    case 2:
      result = d18a_snake18_800CB9CC(&actor, &punch);
      break;
    case 3:
      result = d18a_snake18_800CBA64(&actor, &punch);
      break;
    default:
      assert(0);
      return 1;
    }
    Verify(result);
  }
  puts("Snake18 matches 632 original MIPS input, punch, capture and C4 target "
       "cases.");
  return 0;
}
