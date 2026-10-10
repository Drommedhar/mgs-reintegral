#include "mgs_native.h"

#include "overlays/rank/menu/pocket_menu.h"
#undef fprintf
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct Fixture {
  int input[4];
  unsigned char name[8];
  uint32_t expected, original;
} Fixture;
#include "mgs_rank_pocket_fixtures.h"
unsigned char pocket_image[32768], PocketCardData[256];
int PocketImageSize = sizeof(pocket_image), PocketNameId, PocketPortMask,
    PocketPortState[4];
char PocketFilename[24];
char *PocketPortNames[2] = {"LEFT MEMORY CARD", "RIGHT MEMORY CARD"};
PocketScores PocketScoreboard;
static Work work;
static struct {
  SELECT_INFO info;
  MENU_CURPOS entries[2];
} selector;
void rank_800CC19C(char *filename) {
  memcpy(filename, "TESTP0-NAMEQ0123!", 17);
}
#include "rank_pocket_helpers.inc"
_Static_assert(sizeof(PocketScores) == 212, "Original scoreboard layout");
_Static_assert(offsetof(SELECT_INFO, menu) == 36,
               "Original selector menu offset");

static uint32_t Hash(uint32_t hash, const void *data, size_t count) {
  const unsigned char *bytes = data;
  for (size_t i = 0; i < count; i++)
    hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}
static uint32_t ScoreHash(void) {
  uint32_t hash = Hash(2166136261u, &PocketScoreboard.count, 4);
  for (int i = 0; i < 10; i++) {
    PocketScore *score =
        i ? &PocketScoreboard.others[i - 1] : &PocketScoreboard.first;
    hash = Hash(hash, score->name, 9);
    hash = Hash(hash, &score->mode, 8);
  }
  return hash;
}
static uint32_t Packing(const Fixture *fixture) {
  char name[8];
  uint32_t hash;
  memset(pocket_image, 0x55, sizeof(pocket_image));
  memset(PocketFilename, 0, sizeof(PocketFilename));
  memcpy(name, fixture->name, 8);
  PocketNameId = 12345678;
  rank_800CBD14(fixture->input[1], fixture->input[2], name);
  for (size_t i = 0; i < sizeof(pocket_image) - 512; i++)
    assert(pocket_image[i] == 0x55);
  hash = Hash(2166136261u, pocket_image + sizeof(pocket_image) - 512, 512);
  hash = Hash(hash, name, 8);
  return Hash(hash, &PocketNameId, 4);
}
static uint32_t Decoding(const Fixture *fixture) {
  int count = fixture->input[1], seed = fixture->input[2];
  memset(PocketCardData, 0, sizeof(PocketCardData));
  memset(&PocketScoreboard, 0xa5, sizeof(PocketScoreboard));
  PocketWriteWord(PocketCardData + 8,
                  0xffc00000u | ((seed * 12345) & 0x3fffff));
  for (int i = 0; i < count; i++) {
    uint32_t first = 0x80000000u, second = ((seed * 17 + i * 23) & 255) << 24;
    second |= ((seed * 11 + i * 3) & 63) << 18;
    for (int j = 0; j < 8; j++) {
      uint32_t code = (seed + j * 13 + i * 7) % 64;
      if (j < 5)
        first |= code << (6 * j);
      else
        second |= code << (6 * (j - 5));
    }
    PocketWriteWord(PocketCardData + 132 + 12 * i, first);
    PocketWriteWord(PocketCardData + 136 + 12 * i, second);
  }
  assert(rank_800CC3D4() == (count != 0));
  if (count)
    for (int i = 0; i < count; i++) {
      PocketScore *score =
          i ? &PocketScoreboard.others[i - 1] : &PocketScoreboard.first;
      assert(score->name[8] == 0 && score->name[9] == 0 &&
             score->name[10] == 0 && score->name[11] == 0);
    }
  return ScoreHash();
}
static uint32_t Selector(const Fixture *fixture) {
  static const char message[] = "SYNTHETIC CARD SELECTION";
  unsigned char bytes[108];
  uint32_t one = 1;
  memset(&selector, 0xa5, sizeof(selector));
  PocketPortMask = fixture->input[1];
  PocketPortState[1] = fixture->input[2];
  assert(rank_800CDCF4(&work, message, &selector.info) == 1);
  assert(selector.info.kcb == &work.kcb && selector.info.message == message);
  memcpy(bytes, &selector, sizeof(bytes));
  memcpy(bytes + 28, &one, 4);
  memcpy(bytes + 32, &one, 4);
  return Hash(2166136261u, bytes, sizeof(bytes));
}
int main(void) {
  unsigned repaired = 0;
  for (size_t i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); i++) {
    const Fixture *fixture = &fixtures[i];
    uint32_t hash;
    if (fixture->input[0] == 0)
      hash = Packing(fixture);
    else if (fixture->input[0] == 1)
      hash = Decoding(fixture);
    else
      hash = Selector(fixture);
    if (hash != fixture->expected) {
      fprintf(stderr, "Pocket case%zu kind%d native%u expected%u original%u\n",
              i, fixture->input[0], hash, fixture->expected, fixture->original);
      return 1;
    }
    if (fixture->expected != fixture->original) {
      assert(fixture->input[0] == 1 && fixture->input[1] >= 9);
      ++repaired;
    }
  }
  assert(repaired == 128);
  printf("Pocket packing/selector: %zu cases passed, including128 explicit "
         "stack-overlap repairs\n",
         sizeof(fixtures) / sizeof(fixtures[0]));
  return 0;
}
