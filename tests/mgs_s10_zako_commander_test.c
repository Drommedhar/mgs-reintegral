#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/s10a/animal/zako10/zk10com.c"
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  int activated, message, stream, time2, mode, level, external, alert_time,
      address, state, phase, next, flags, watcher_alert, ticks;
} Input;
typedef struct {
  const char *name;
  Input input;
  int output[28];
  int trace_size;
  int trace[32];
} Fixture;
#include "mgs_s10_zako_commander_fixtures.h"

int GM_PlayerAddress, GM_PlayerMap, GM_AlertMax;
SVECTOR GM_PlayerPosition, GM_NoisePosition;
CONTROL *GM_WhereList[96];
static Work actors[3];
static MAP map;
static HZD_HDL hzd;
static HZD_DEF definition;
static HZD_ZON zones[3];
static const Fixture *fixture;
static int trace[32], trace_size;
static void Record(int count, ...) {
  va_list values;
  assert(trace_size + count <= 32);
  va_start(values, count);
  while (count--)
    trace[trace_size++] = va_arg(values, int);
  va_end(values);
}
int GV_ReceiveMessage(int address, GV_MSG **messages) {
  static GV_MSG message;
  assert(address == 1234);
  message.message[0] = fixture->input.message;
  *messages = &message;
  return fixture->input.message >= 0;
}
int GM_StreamStatus(void) { return fixture->input.stream; }
void GM_StreamPlayStart(void) { Record(1, 3); }
void *GM_VoxStream(int voice, int proc) {
  Record(3, 2, voice, proc);
  return NULL;
}
void *NewPadVibration(unsigned char *data, int mode) {
  Record(6, 1, mode, data[0], data[1], data[2], data[3]);
  return NULL;
}
void GM_SeSet2(int pan, int volume, int sound) {
  Record(4, 4, pan, volume, sound);
}
int GV_DiffVec3(SVECTOR *from, SVECTOR *to) {
  assert(to == &GM_PlayerPosition);
  return from->vx;
}
int HZD_GetAddress(HZD_HDL *handle, SVECTOR *position, int previous) {
  (void)handle;
  (void)position;
  (void)previous;
  assert(!"unexpected constructor dependency");
  return 0;
}
char *GCL_GetOption(char option) {
  (void)option;
  assert(!"unexpected constructor dependency");
  return NULL;
}
int GCL_StrToInt(char *value) {
  (void)value;
  assert(!"unexpected constructor dependency");
  return 0;
}
char *GCL_NextStr(void) {
  assert(!"unexpected constructor dependency");
  return NULL;
}
int GCL_ExecProc(int proc, GCL_ARGS *args) {
  (void)proc;
  (void)args;
  assert(!"unexpected constructor dependency");
  return 0;
}
MAP *GM_GetMap(int where) {
  (void)where;
  assert(!"unexpected constructor dependency");
  return NULL;
}
void *NewAsiato(int name, int where, int argc, char **argv) {
  (void)name;
  (void)where;
  (void)argc;
  (void)argv;
  assert(!"unexpected constructor dependency");
  return NULL;
}
void *GV_NewActor(int level, int size) {
  (void)level;
  (void)size;
  assert(!"unexpected constructor dependency");
  return NULL;
}
void GV_SetNamedActor(void *actor, void *act, void *die, const char *name) {
  (void)actor;
  (void)act;
  (void)die;
  (void)name;
  assert(!"unexpected constructor dependency");
}

static void Initialize(void) {
  const Input *in = &fixture->input;
  memset(actors, 0, sizeof(actors));
  memset(&Z10_Command, 0, sizeof(Z10_Command));
  Z10_Mode = Z10_Unknown = Z10_PlayerAddress = Z10_PlayerMap = GM_AlertMax =
      trace_size = 0;
  Z10_PlayerPosition = (SVECTOR){0};
  Z10_Alert = in->external;
  Z10_Activated = in->activated;
  GM_PlayerAddress = in->address;
  GM_PlayerMap = 2;
  GM_PlayerPosition = (SVECTOR){100, 200, 300, 0};
  Z10_Command.name = 1234;
  Z10_Command.n_watchers = 3;
  Z10_Command.time2 = in->time2;
  Z10_Command.alert_time = in->alert_time;
  Z10_Command.alert_level = in->level;
  Z10_Command.alert_mode = in->mode;
  Z10_Command.n_zones = 2;
  Z10_Command.zones[1] = 1;
  Z10_Command.field_110 = in->flags;
  Z10_Command.voice = 123456;
  Z10_Command.map = &map;
  map.hzd = &hzd;
  hzd.def = &definition;
  definition.zones = zones;
  const int distances[] = {5000, 1000, 3000};
  for (int i = 0; i < 3; i++) {
    Z10_Command.order[i] = i;
    Z10_Command.watchers[i] = (Z10Watcher){1, i == 0 ? in->state : 2,
                                           i == 0 ? in->phase : 0, &actors[i]};
    actors[i].sn_dis = distances[i];
    actors[i].alert_level = in->watcher_alert;
    actors[i].param.next = in->next;
    zones[i].x = 100 + i * 100;
    zones[i].z = 300;
    zones[i].y = 200;
  }
}
static void Check(void) {
  int output[] = {Z10_Command.time,
                  Z10_Command.time2,
                  Z10_Command.alert_time,
                  Z10_Command.alert_level,
                  Z10_Command.alert_mode,
                  Z10_Command.order[0],
                  Z10_Command.order[1],
                  Z10_Command.order[2],
                  Z10_Command.field_64,
                  Z10_Command.field_110,
                  Z10_Command.far_zone,
                  Z10_Command.watchers[0].field_0,
                  Z10_Command.watchers[0].state,
                  Z10_Command.watchers[0].field_8,
                  actors[0].chase_dis,
                  actors[1].chase_dis,
                  actors[2].chase_dis,
                  Z10_Mode,
                  Z10_Alert,
                  Z10_Unknown,
                  Z10_Activated,
                  Z10_PlayerAddress,
                  Z10_PlayerMap,
                  Z10_PlayerPosition.vx,
                  Z10_PlayerPosition.vy,
                  Z10_PlayerPosition.vz,
                  Z10_PlayerPosition.pad,
                  GM_AlertMax};
  for (int i = 0; i < 28; i++) {
    if (output[i] != fixture->output[i])
      fprintf(stderr, "%s field %d: %d != %d\n", fixture->name, i, output[i],
              fixture->output[i]);
    assert(output[i] == fixture->output[i]);
  }
  assert(trace_size == fixture->trace_size);
  assert(memcmp(trace, fixture->trace, trace_size * sizeof(int)) == 0);
}
int main(void) {
  for (unsigned i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); i++) {
    fixture = &fixtures[i];
    Initialize();
    for (int tick = 0; tick < fixture->input.ticks; tick++)
      Act(NULL);
    Check();
  }
  puts("S10 Zako commander: 20 original-MIPS fixtures passed");
  return 0;
}
