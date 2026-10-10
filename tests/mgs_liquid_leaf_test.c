#include "mgs_native.h"
#undef fprintf
#include "animal/liquid/liquid_native.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

int GM_PlayerStatus;
int GM_PlayerAction;
int GV_Time;
SVECTOR GM_PlayerPosition;
short linkvarbuf[96];
int liquid_voice_state[16];

#include "liquid_helpers.inc"
#include "mgs_liquid_leaf_fixtures.h"

static const unsigned short fields[] = {
    0x910, 0x914, 0x934, 0x938, 0x93c, 0x940, 0x944, 0x948, 0x950, 0x954, 0x958,
    0x95c, 0x960, 0x964, 0x968, 0x96c, 0x978, 0x97c, 0x980, 0x984, 0x988, 0x98c,
    0x994, 0x998, 0x99c, 0x9a0, 0x9a4, 0x9a8, 0x9ac, 0x9b0, 0x9b4, 0x9b8};
static const int values[] = {0,  1,  2,  3,  4,  7,   15,  16,  17,  29, 30,
                             31, 59, 60, 63, 64, 127, 128, 254, 255, -1};
static const int distances[] = {0,    299,  300,  499,  500,  999,
                                1000, 1799, 1800, 2499, 2500, 4096};
static const int statuses[] = {0, 4, 32, 64, 96, 0x800, 0x804, 0x860};
static const int actions[] = {0, 2, 5, 8, 9};
static const int damage_types[] = {0, 3, 4, 36};
static const short health[] = {0, 40, 41, 1024};

static unsigned int HashBytes(unsigned int hash, const void *data,
                              size_t size) {
  const unsigned char *bytes = data;
  for (size_t i = 0; i < size; i++)
    hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}

static void InitWork(LiquidWork *work, int seed) {
  memset(work, 0, sizeof(*work));
  for (size_t i = 0; i < sizeof(fields) / sizeof(fields[0]); i++) {
    int value = values[(seed + i * 3) % (sizeof(values) / sizeof(values[0]))];
    memcpy((unsigned char *)work + fields[i], &value, sizeof(value));
  }
  work->field_940 = seed % 2;
  work->field_9B8 = damage_types[seed % 4];
  work->field_9B0 = distances[seed % 12];
  GM_PlayerStatus = statuses[seed % 8];
  GM_PlayerAction = actions[seed % 5];
  GV_Time = seed;
  GM_PlayerPosition = (SVECTOR){100, seed % 2, -500, 0};
  linkvarbuf[11] = health[seed % 4];
  for (int i = 0; i < 16; i++)
    liquid_voice_state[i] = seed % 3;
}

static void CheckState(size_t index, int seed) {
  LiquidWork work;
  int result = 0;
  unsigned int hash = 2166136261u;
  const struct LiquidTestRoutine *routine = &liquid_test_routines[index];
  InitWork(&work, seed);
  if (routine->query)
    result = routine->query(&work);
  else
    routine->update(&work);
  hash = HashBytes(hash, &work, sizeof(work));
  hash = HashBytes(hash, liquid_voice_state, sizeof(liquid_voice_state));
  if (routine->query)
    hash = HashBytes(hash, &result, sizeof(result));
  if (hash != liquid_leaf_hashes[index][seed])
    fprintf(stderr, "Liquid routine %zu seed %d: %08x != %08x\n", index, seed,
            hash, liquid_leaf_hashes[index][seed]);
  assert(hash == liquid_leaf_hashes[index][seed]);
}

int main(void) {
  for (size_t index = 0;
       index < sizeof(liquid_test_routines) / sizeof(liquid_test_routines[0]);
       index++)
    for (int seed = 0; seed < 128; seed++)
      CheckState(index, seed);
  puts("7680 Liquid state updates match original MIPS execution.");
  return 0;
}
