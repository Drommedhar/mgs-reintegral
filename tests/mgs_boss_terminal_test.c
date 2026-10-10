#include "mgs_native.h"
#undef fprintf
#include "animal/liquid/liquid_native.h"
#include "overlays/s17a/rex_native.h"
#include "takabe/thing.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  int kind;
  int seed;
  unsigned int state_hash;
  unsigned int trace_hash;
  unsigned int trace_words;
} BossTerminalFixture;

#include "mgs_boss_terminal_fixtures.h"

RexWork RexDefaults;
int GM_GameStatus;
int GM_GameOverTimer;

static unsigned int trace[64];
static unsigned int trace_words;
static int current_kind;
static int current_seed;
static int random_index;
static void *current_work;

static void Event(unsigned int value) {
  assert(trace_words < sizeof(trace) / sizeof(trace[0]));
  trace[trace_words++] = value;
}

int GV_RandS(int limit) {
  static const int values[] = {-128, -1, 0, 127};
  int result = values[(current_seed + random_index++) % 4];
  Event(0);
  Event(limit);
  Event(result);
  return result;
}

void MENU_DrawBar2(int y, int rest, int now, int max, MENU_BAR_CONF *configuration) {
  Event(1);
  Event(y);
  Event(rest);
  Event(now);
  Event(max);
  Event((unsigned char *)configuration - (unsigned char *)current_work);
}

void THING_Msg_SendMessage(unsigned short address, unsigned short message) {
  Event(2);
  Event(address);
  Event(message);
}

void GV_DestroyActor(void *actor) {
  RexWork *work = actor;
  assert(actor == current_work);
  Event(3);
  Event(GM_GameStatus);
  Event(work->field_1AA8);
  work->actor.act = (GV_ACTFUNC)(uintptr_t)0x12345678;
}

int GCL_ExecProc(int procedure, GCL_ARGS *arguments) {
  int *counter = current_kind < 2 ? &((RexWork *)current_work)->field_1AA8
                                : &((LiquidWork *)current_work)->field_968;
  assert(arguments == NULL);
  Event(4);
  Event(procedure);
  Event(0);
  Event(GM_GameStatus);
  Event(*counter);
  if (current_seed & 1) {
    *counter = 91;
    GM_GameStatus ^= 0x100;
  }
  return 0x1357;
}

#include "boss_terminal_helpers.inc"

static unsigned int HashBytes(unsigned int hash, const void *data, size_t size) {
  const unsigned char *bytes = data;
  for (size_t i = 0; i < size; ++i)
    hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}

static void FillWork(void *data, size_t size, int seed) {
  unsigned char *bytes = data;
  for (size_t i = 0; i < size; ++i)
    bytes[i] = (unsigned char)(i * 37 + seed * 11 + 3);
}

static void InitializeRex(RexWork *work, int seed) {
  static const int timers[] = {0, 30, 31, 32, 33, 38, 39, 40, 100};
  static const int actions[] = {0, 2, 11, 7};
  static const int remaining[] = {0, 1, 999, 1000};
  static const int health[] = {1000, 501, 0, -1};
  FillWork(work, sizeof(*work), seed);
  work->field_1AA8 = timers[seed % 9];
  work->field_1960 = seed / 9 % 3;
  work->field_1954 = actions[seed / 54 % 4];
  work->field_1958 = 13;
  work->field_1764 = 0x1234;
  work->field_1768 = 0xABCD;
  work->field_1ABC = 1000;
  work->field_1AC0 = remaining[seed / 54 % 4];
  work->field_1AC4 = health[seed / 54 % 4];
}

static void InitializeLiquid(LiquidWork *work, int seed) {
  static const int timers[] = {0, 1, 2, -1, 39};
  static const int procedures[] = {-1, 0, 1, 0x7FFF, 0xFFFF};
  FillWork(work, sizeof(*work), seed);
  work->field_968 = timers[seed % 5];
  work->field_9E0 = procedures[seed / 5 % 5];
}

static unsigned int RunFixture(const BossTerminalFixture *fixture) {
  static const unsigned int statuses[] = {0, 0x8000, 0x800000, 0xA5838123};
  RexWork rex;
  LiquidWork liquid;
  unsigned int hash = 2166136261u;
  current_kind = fixture->kind;
  current_seed = fixture->seed;
  random_index = 0;
  trace_words = 0;
  GM_GameStatus = statuses[current_seed / 27 % 4];
  GM_GameOverTimer = current_seed / 27 % 2;
  memset(&RexDefaults, 0xA5, sizeof(RexDefaults));
  if (current_kind < 2) {
    InitializeRex(&rex, current_seed);
    current_work = &rex;
    if (current_kind == 0)
      RexFunc_800DB268(&rex);
    else
      RexFunc_800DB478(&rex);
    hash = HashBytes(hash, &rex, sizeof(rex));
    hash = HashBytes(hash, &RexDefaults, sizeof(RexDefaults));
  } else {
    InitializeLiquid(&liquid, current_seed);
    current_work = &liquid;
    liquid_800CE6B4(&liquid);
    hash = HashBytes(hash, &liquid, sizeof(liquid));
  }
  return HashBytes(hash, &GM_GameStatus, sizeof(GM_GameStatus));
}

int main(void) {
  _Static_assert(sizeof(RexWork) == 6904, "Original REX actor size");
  _Static_assert(sizeof(LiquidWork) == 2636, "Original Liquid actor size");
  for (size_t i = 0; i < sizeof(boss_terminal_fixtures) /
                             sizeof(boss_terminal_fixtures[0]); ++i) {
    const BossTerminalFixture *fixture = &boss_terminal_fixtures[i];
    unsigned int state = RunFixture(fixture);
    unsigned int calls = HashBytes(2166136261u, trace, trace_words * sizeof(*trace));
    if (state != fixture->state_hash || calls != fixture->trace_hash ||
        trace_words != fixture->trace_words) {
      fprintf(stderr, "Boss terminal kind %d seed %d: state %08x/%08x, "
                      "trace %08x/%08x, words %u/%u\n",
              fixture->kind, fixture->seed, state, fixture->state_hash, calls,
              fixture->trace_hash, trace_words, fixture->trace_words);
      return 1;
    }
  }
  puts("964 boss terminal states and ordered callback traces match original MIPS.");
  return 0;
}
