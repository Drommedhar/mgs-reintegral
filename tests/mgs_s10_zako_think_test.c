#include "mgs_native.h"
#undef fprintf

#include "../vendor/mgs/source/overlays/s10a/animal/zako10/think.c"
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  int phase, mode, state, count, alert, vision, events, commander_alert,
      activated;
  int next, near, reach, inside, command, pad_time, noise, time, distance,
      chase, is_end;
} Input;

typedef struct {
  const char *name;
  Input input;
  int output[37];
  int trace_size;
  int trace[8];
} Fixture;

#include "mgs_s10_zako_think_fixtures.h"

Z10Commander Z10_Command;
int Z10_Activated, Z10_PlayerAddress, Z10_PlayerMap;
SVECTOR Z10_PlayerPosition;
CONTROL *GM_WhereList[96];
SVECTOR GM_NoisePosition;
int GM_NoisePower, GM_PlayerMap;
static Work actor;
static MAP map;
static HZD_HDL hzd;
static HZD_DEF definition;
static HZD_ZON zones[8];
static HZD_PAT route;
static HZD_PTP points[2];
static const Fixture *fixture;
static int trace[8], trace_size;

MAP *GM_GetMap(int where) {
  (void)where;
  return &map;
}

int HZD_GetAddress(HZD_HDL *handle, SVECTOR *position, int previous) {
  assert(handle == &hzd && position != NULL);
  (void)previous;
  return 0x0505;
}

int HZD_ReachTo(HZD_HDL *handle, int from, int to) {
  assert(handle == &hzd);
  (void)from;
  (void)to;
  return fixture->input.reach;
}

int HZD_Navigate(HZD_HDL *handle, int from, int to, SVECTOR *position) {
  assert(handle == &hzd && position == &actor.control.mov);
  (void)from;
  (void)to;
  return 2;
}

int HZD_InsideZone(HZD_HDL *handle, SVECTOR *position, int zone) {
  assert(handle == &hzd && position == &actor.control.mov && zone == 2);
  return fixture->input.inside;
}

int GV_RandU(int range) {
  assert(range == 100);
  return 0;
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

int NearAsiato(void) { return 7; }

void GM_SeSet(SVECTOR *position, int sound) {
  assert(position == &actor.control.mov && trace_size <= 6);
  trace[trace_size++] = 1;
  trace[trace_size++] = sound;
}

void Z10_PutMark(Work *work, int mark) {
  assert(work == &actor && trace_size <= 6);
  trace[trace_size++] = 2;
  trace[trace_size++] = mark;
}

void *NewEyeflash(MATRIX *world, SVECTOR *position, const char *texture,
                  int mode) {
  (void)world;
  assert(position == &actor.control.mov && strcmp(texture, "kirari01") == 0 &&
         mode == 0);
  assert(trace_size < 8);
  trace[trace_size++] = 3;
  return NULL;
}

int Z10_FindRoute(int map_id, int zone) {
  if (map_id != 1)
    return 0;
  return zone == 1 || zone == 2 ? zone : -1;
}

void Z10_TargetLast(void) {
  Z10_Command.target_addr = Z10_PlayerAddress;
  Z10_Command.target_map = Z10_PlayerMap;
  Z10_Command.target_pos = Z10_PlayerPosition;
}

void Z10_TargetNoise(void) {
  Z10_Command.target_addr = 0x0505;
  Z10_Command.target_map = GM_PlayerMap;
  Z10_Command.target_pos = GM_NoisePosition;
}

static void Initialize(void) {
  const Input *in = &fixture->input;
  memset(&actor, 0, sizeof(actor));
  memset(&Z10_Command, 0, sizeof(Z10_Command));
  trace_size = 0;
  map.index = 1;
  map.hzd = &hzd;
  hzd.def = &definition;
  definition.zones = zones;
  definition.routes = &route;
  route.n_points = 2;
  route.points = points;
  points[0] = (HZD_PTP){100, 300, 200, 0};
  points[1] = (HZD_PTP){400, 600, 500, 0};
  for (int index = 0; index < 8; index++) {
    zones[index].x = 1000 + index;
    zones[index].y = 200 + index;
    zones[index].z = 3000 + index;
  }
  actor.control.map = &map;
  actor.think1 = in->phase;
  actor.think2 = in->mode;
  actor.think3 = in->state;
  actor.count3 = in->count;
  actor.alert_level = in->alert;
  actor.vision.pad = in->vision;
  actor.modetime[6] = in->events;
  actor.param.next = in->next;
  actor.pad.time = in->pad_time;
  actor.pad.field_8 = 64;
  actor.body.is_end = in->is_end;
  actor.sn_dis = in->distance;
  actor.sn_dir = 1800;
  actor.chase_dis = in->chase;
  actor.n_nodes = 2;
  actor.nodes[0] = (SVECTOR){100, 200, 300, 0};
  actor.nodes[1] = (SVECTOR){400, 500, 600, 0};
  int position = in->near ? 100 : 600;
  actor.target_pos = (SVECTOR){position, 0, position, in->command};
  actor.start_pos = actor.nodes[0];
  actor.start_addr = actor.last_addr = actor.current_addr = actor.next_addr =
      0x0101;
  actor.start_map = actor.target_map = 1;
  actor.target_addr = 0x0202;
  actor.pad.sound = actor.control.radar_atr = 99;
  Z10_Command.alert_mode = in->commander_alert;
  Z10_Activated = in->activated;
  Z10_Command.time = in->time;
  Z10_PlayerAddress = 0x0303;
  Z10_PlayerMap = 1;
  Z10_PlayerPosition = (SVECTOR){250, 0, 250, 0};
  Z10_Command.target_addr = 0x0404;
  Z10_Command.target_map = 1;
  Z10_Command.target_pos = (SVECTOR){350, 0, 350, 0};
  GM_WhereList[0] = &actor.control;
  GM_NoisePower = in->noise;
  GM_NoisePosition = (SVECTOR){450, 0, 450, 0};
  GM_PlayerMap = 1;
}

static void Verify(void) {
  int actual[] = {actor.think1,
                  actor.think2,
                  actor.think3,
                  actor.think4,
                  actor.count3,
                  actor.next_node,
                  actor.pad.press,
                  actor.pad.field_4,
                  actor.pad.field_8,
                  actor.pad.time,
                  actor.pad.dir,
                  actor.pad.sound,
                  actor.route_action,
                  actor.alert_level,
                  actor.control.radar_atr,
                  actor.act.field_1E,
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
                  actor.modetime[4],
                  actor.modetime[2],
                  Z10_Command.target_addr,
                  Z10_Command.target_map,
                  Z10_Command.target_pos.vx,
                  Z10_Command.target_pos.vy,
                  Z10_Command.target_pos.vz,
                  Z10_Command.target_pos.pad};
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
    Z10_Think(&actor);
    Verify();
  }
  puts("Zako10 matches 71 original MIPS patrol, alert, chase and attack state "
       "traces.");
  return 0;
}
