#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/s19a/guard/commander.c"
#include "../vendor/mgs/source/overlays/s19a/guard/data.c"
#undef fprintf
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct AlertFixture {
  int mode, level, timer;
  int output[6];
  int trace_size, trace[5];
} AlertFixture;
typedef struct SortFixture {
  int count, distances[8], output[16];
} SortFixture;
#include "mgs_s19_commander_fixtures.h"

int GM_AlertMax, GM_PlayerAddress, GM_PlayerMap;
SVECTOR GM_PlayerPosition, GM_NoisePosition;
CONTROL *GM_WhereList[96];
short linkvarbuf[MAX_LINKVARBUF];
static S19Work guards[8];
static int trace[5], trace_size;

void GM_AlertModeSet(int mode) {
  trace[trace_size++] = 1;
  trace[trace_size++] = mode;
}
void GM_SeSet2(int pan, int volume, int sound) {
  assert(pan == 0);
  trace[trace_size++] = 2;
  trace[trace_size++] = volume;
  trace[trace_size++] = sound;
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
int GCL_ExecProc(int id, GCL_ARGS *args) {
  (void)id;
  (void)args;
  abort();
}
char *GCL_GetOption(char option) {
  (void)option;
  abort();
}
char *GCL_NextStr(void) { abort(); }
int GCL_StrToInt(char *value) {
  (void)value;
  abort();
}
int GV_DiffVec3(SVECTOR *a, SVECTOR *b) {
  (void)a;
  (void)b;
  abort();
}
int HZD_GetAddress(HZD_HDL *hzd, SVECTOR *pos, int last) {
  (void)hzd;
  (void)pos;
  (void)last;
  abort();
}
MAP *GM_GetMap(int name) {
  (void)name;
  abort();
}
int GV_ReceiveMessage(int name, GV_MSG **messages) {
  (void)name;
  (void)messages;
  abort();
}
void *NewAsiato(int name, int where, int argc, char **argv) {
  (void)name;
  (void)where;
  (void)argc;
  (void)argv;
  abort();
}
void *GV_NewActor(int level, int size) {
  (void)level;
  (void)size;
  abort();
}
void GV_SetNamedActor(void *work, void *act, void *die, const char *name) {
  (void)work;
  (void)act;
  (void)die;
  (void)name;
  abort();
}
int mgs_fprintf(int stream, const char *format, ...) {
  (void)stream;
  (void)format;
  return 0;
}

static void VerifyAlert(const AlertFixture *fixture) {
  int actual[6];
  memset(&S19_Command, 0, sizeof(S19_Command));
  S19_Command.alert_mode = fixture->mode;
  S19_Command.alert_level = fixture->level;
  S19_Command.alert_time = fixture->timer;
  S19_Command.field_60 = 199;
  GM_AlertMax = 17;
  trace_size = 0;
  s19a_800D7060((unsigned int *)&S19_Command);
  actual[0] = S19_Command.alert_time;
  actual[1] = S19_Command.alert_level;
  actual[2] = S19_Command.alert_mode;
  actual[3] = S19_Command.field_60;
  actual[4] = S19_Command.start_proc2;
  actual[5] = GM_AlertMax;
  assert(memcmp(actual, fixture->output, sizeof(actual)) == 0);
  assert(trace_size == fixture->trace_size &&
         memcmp(trace, fixture->trace, trace_size * sizeof(int)) == 0);
}

static void VerifySort(const SortFixture *fixture) {
  int actual[16];
  memset(&S19_Command, 0, sizeof(S19_Command));
  memset(guards, 0, sizeof(guards));
  S19_Command.n_watchers = fixture->count;
  for (int i = 0; i < 8; ++i) {
    S19_Command.field_40[i] = i;
    S19_Command.watchers[i].work = &guards[i];
    guards[i].sn_dis = fixture->distances[i];
  }
  s19a_800D6CA4((int)&S19_Command);
  for (int i = 0; i < 8; ++i) {
    actual[i] = S19_Command.field_40[i];
    actual[i + 8] = guards[i].chase_dis;
  }
  assert(memcmp(actual, fixture->output, sizeof(actual)) == 0);
}

int main(void) {
  _set_error_mode(_OUT_TO_STDERR);
  for (unsigned i = 0; i < sizeof(alerts) / sizeof(alerts[0]); ++i)
    VerifyAlert(&alerts[i]);
  for (unsigned i = 0; i < sizeof(sorts) / sizeof(sorts[0]); ++i)
    VerifySort(&sorts[i]);
  S19_Command.time = 5;
  assert(s19a_800D68B4(2) == 1 && s19a_800D68B4(3) == 2);
  puts("Garage commander matches 264 original MIPS alert and stable "
       "guard-order cases.");
  return 0;
}
