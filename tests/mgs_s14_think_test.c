#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/s14e/animal/zako14/think_native.c"
#include <assert.h>
#include <stdio.h>
#include <string.h>

_Static_assert(sizeof(Work) == 3140, "Original Zako14 actor layout");
_Static_assert(offsetof(Work, target_pos) == 3040, "Original navigation state");

typedef struct {
  int phase, mode, state, count, vision, index, gameflag, next, reach, inside;
  int distance, stance, is_end, hit, random, player_flags, target_map,
      alert_mode;
} Input;
typedef struct {
  const char *name;
  Input input;
  int output[36];
  int trace_size, trace[8];
} Fixture;
#include "mgs_s14_think_fixtures.h"

COMMANDER ZAKO14Command;
int ZAKO14_GameFlag, ZAKO14_PlayerAddress, ZAKO14_PlayerMap, GM_PlayerStatus;
SVECTOR ZAKO14_PlayerPosition;
short linkvarbuf[MAX_LINKVARBUF];
static Work actor;
static MAP map;
static HZD_HDL hzd;
static HZD_DEF definition;
static HZD_ZON zones[256];
static struct {
  DG_OBJS header;
  DG_OBJ units[8];
} objects;
static const Fixture *fixture;
static int trace[8], trace_size;

static void Record(int value) {
  assert(trace_size < 8);
  trace[trace_size++] = value;
}

MAP *GM_GetMap(int where) {
  assert(where == 2);
  return &map;
}

int HZD_GetAddress(HZD_HDL *handle, SVECTOR *position, int previous) {
  assert(handle == &hzd && position == &actor.control.mov);
  (void)previous;
  return 0x0505;
}

int HZD_ReachTo(HZD_HDL *handle, int from, int to) {
  assert(handle == &hzd && from == 0x0505);
  (void)to;
  return fixture->input.reach;
}

int HZD_Navigate(HZD_HDL *handle, int from, int to, SVECTOR *position) {
  assert(handle == &hzd && from == 0x0505 && position == &actor.control.mov);
  (void)to;
  return 2;
}

int HZD_InsideZone(HZD_HDL *handle, SVECTOR *position, int zone) {
  assert(handle == &hzd && position == &actor.control.mov &&
         zone == actor.param.next);
  return fixture->input.inside;
}

int ZAKO14FindRoute(int from, int to) {
  Record(5);
  Record(from);
  Record(to);
  return 2;
}

int GV_RandU(int range) {
  Record(4);
  Record(range);
  return fixture->input.random;
}

int GV_VecDir2(SVECTOR *vector) {
  assert(vector != NULL);
  return 512;
}

void GV_SubVec3(SVECTOR *from, SVECTOR *to, SVECTOR *result) {
  result->vx = from->vx - to->vx;
  result->vy = from->vy - to->vy;
  result->vz = from->vz - to->vz;
}

void GM_SeSet(SVECTOR *position, int sound) {
  assert(position == &actor.control.mov);
  Record(1);
  Record(sound);
}

void ZAKO14_PutMark(Work *work, int mark) {
  assert(work == &actor);
  Record(2);
  Record(mark);
}

void *NewEyeflash(MATRIX *world, SVECTOR *position, const char *name, int arg) {
  assert(world == &objects.units[6].world && position == &actor.control.mov);
  assert(strcmp(name, "kirari01") == 0 && arg == 0);
  Record(3);
  return NULL;
}

void ZAKO14SetGopointLast(void) {
  ZAKO14Command.target_addr = ZAKO14_PlayerAddress;
  ZAKO14Command.target_map = ZAKO14_PlayerMap;
  ZAKO14Command.target_pos = ZAKO14_PlayerPosition;
}

static void Initialize(void) {
  const Input *in = &fixture->input;
  memset(&actor, 0, sizeof(actor));
  memset(&ZAKO14Command, 0, sizeof(ZAKO14Command));
  trace_size = 0;
  actor.control.map = &map;
  actor.body.objs = &objects.header;
  actor.think1 = in->phase;
  actor.think2 = in->mode;
  actor.think3 = in->state;
  actor.count3 = in->count;
  actor.vision.pad = in->vision;
  actor.param.index = in->index;
  actor.param.next = in->next;
  actor.body.is_end = in->is_end;
  actor.field_8FC = in->hit;
  actor.sn_dis = in->distance;
  actor.sn_dir = 1800;
  actor.target_pos = (SVECTOR){600, 0, 600, 0};
  actor.start_map = 1;
  actor.last_addr = 0x0101;
  actor.target_addr = 0x0202;
  actor.target_map = in->target_map;
  actor.current_addr = actor.next_addr = 0x0101;
  actor.pad.dir = actor.pad.sound = 99;
  actor.control.radar_atr = 99;
  ZAKO14Command.alert_mode = in->alert_mode;
  ZAKO14_GameFlag = in->gameflag;
  ZAKO14_PlayerAddress = 0x0303;
  ZAKO14_PlayerMap = 1;
  ZAKO14_PlayerPosition = (SVECTOR){250, 0, 250, 0};
  GM_PlayerStance = in->stance;
  GM_PlayerStatus = in->player_flags;
}

static void Verify(void) {
  int actual[] = {actor.think1,
                  actor.think2,
                  actor.think3,
                  actor.think4,
                  actor.count3,
                  actor.pad.press,
                  actor.pad.field_4,
                  actor.pad.dir,
                  actor.pad.sound,
                  actor.alert_level,
                  actor.control.radar_atr,
                  actor.act.field_1E,
                  (unsigned char)actor.param.next,
                  actor.target_addr,
                  actor.target_map,
                  actor.last_addr,
                  actor.current_addr,
                  actor.next_addr,
                  actor.target_pos.vx,
                  actor.target_pos.vy,
                  actor.target_pos.vz,
                  actor.target_pos.pad,
                  actor.next_pos.vx,
                  actor.next_pos.vy,
                  actor.next_pos.vz,
                  actor.next_pos.pad,
                  actor.field_C04.vx,
                  actor.field_C04.vy,
                  actor.field_C04.vz,
                  actor.field_C04.pad,
                  ZAKO14Command.target_addr,
                  ZAKO14Command.target_map,
                  ZAKO14Command.target_pos.vx,
                  ZAKO14Command.target_pos.vy,
                  ZAKO14Command.target_pos.vz,
                  ZAKO14Command.target_pos.pad};
  for (unsigned index = 0; index < sizeof(actual) / sizeof(actual[0]);
       ++index) {
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
  map.index = 1;
  map.hzd = &hzd;
  hzd.def = &definition;
  definition.zones = zones;
  for (int index = 0; index < 256; ++index) {
    zones[index].x = 1000 + index;
    zones[index].y = 200 + index;
    zones[index].z = 3000 + index;
  }
  for (unsigned index = 0; index < sizeof(fixtures) / sizeof(fixtures[0]);
       ++index) {
    fixture = &fixtures[index];
    Initialize();
    Zako14Think(&actor);
    Verify();
  }
  puts("Zako14 decisions match 264 original MIPS fixtures, including every "
       "authored phase table entry.");
  return 0;
}
