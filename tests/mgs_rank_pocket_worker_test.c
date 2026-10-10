#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/rank/menu/pocket_menu.h"
#include "rank_pocket_worker_helpers.inc"
#undef fprintf
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct Event {
  int kind, argument, result, port, response;
} Event;
typedef struct Fixture {
  int input[6], first_event, event_count, output[16];
  uint32_t hash;
} Fixture;
#include "mgs_rank_pocket_worker_fixtures.h"

int PocketPortState[4], PocketPortMask, PocketResult, PocketRequest,
    PocketResponse, PocketCardStatus[2], PocketTransferProgress;
int GM_PadResetDisable;
MEMCARD *PocketCards[2];
char PocketFilename[24];
static MEMCARD cards[2];
static const Fixture *fixture;
static int event_index;
static uint32_t trace_hash;

static uint32_t StringHash(const char *text) {
  uint32_t hash = 2166136261u;
  while (*text)
    hash = (hash ^ (unsigned char)*text++) * 16777619u;
  return hash;
}
static int CardId(MEMCARD *card) {
  if (!card)
    return 0;
  assert(card == &cards[0] || card == &cards[1]);
  return (int)(card - cards) + 1;
}
static void HashWord(uint32_t value) {
  for (int i = 0; i < 4; i++)
    trace_hash = (trace_hash ^ ((value >> (8 * i)) & 255)) * 16777619u;
}
static int Invoke(int kind, int argument, const char *name) {
  assert(event_index < fixture->event_count);
  const Event *event = &events[fixture->first_event + event_index++];
  assert(event->kind == kind && event->argument == argument);
  HashWord(kind);
  HashWord(argument);
  HashWord(name ? StringHash(name) : 0);
  HashWord(GM_PadResetDisable);
  if (event->port != -99)
    PocketPortState[0] = event->port;
  if (event->response != -99) {
    assert(PocketRequest == 0x20000001);
    PocketResponse = event->response;
  }
  return event->result;
}
int rank_800CC70C(int request) { return Invoke(1, request, NULL); }
int memcard_check(int port) { return Invoke(2, port, NULL); }
int rank_800CC104(int port) { return Invoke(3, port, NULL); }
MEMCARD *memcard_files(int port) {
  int id = Invoke(4, port, NULL);
  return id ? &cards[id - 1] : NULL;
}
void rank_800CC19C(char *filename) {
  Invoke(5, 0, NULL);
  strcpy(filename, "TESTP0-NAMEQ0123!");
}
int rank_800CC1E0(MEMCARD *card, const char *filename) {
  return Invoke(6, CardId(card), filename);
}
int memcard_format(int port) { return Invoke(7, port, NULL); }
int memcard_delete(int port, const char *filename) {
  return Invoke(8, port, filename);
}
int rank_800CC260(MEMCARD *card) { return Invoke(9, CardId(card), NULL); }
int rank_800CC658(MEMCARD *card, const char *filename) {
  return Invoke(10, CardId(card), filename);
}

static void Initialize(const Fixture *test) {
  fixture = test;
  event_index = 0;
  trace_hash = 2166136261u;
  PocketPortMask = 0x83;
  PocketPortState[0] = 17;
  PocketPortState[1] = test->input[2];
  PocketPortState[2] = test->input[3];
  PocketPortState[3] = 9;
  PocketResult = 7;
  PocketRequest = 0x123;
  PocketResponse = 0x456;
  PocketCardStatus[0] = 11;
  PocketCardStatus[1] = 12;
  PocketCards[0] = PocketCards[1] = NULL;
  GM_PadResetDisable = test->input[5];
  PocketTransferProgress = 55;
  memset(PocketFilename, 0, sizeof(PocketFilename));
  strcpy(PocketFilename, "initial");
  memset(cards, 0, sizeof(cards));
  for (int port = 0; port < 2; port++) {
    cards[port].port = port;
    cards[port].last_op = 1;
    cards[port].file_count = 15;
    cards[port].free_blocks = test->input[4];
    for (int i = 0; i < 15; i++)
      snprintf(cards[port].files[i].name, sizeof(cards[port].files[i].name),
               "SAVE%d-%02d", port, i);
  }
}
static int Check(int index) {
  const Fixture *test = &fixtures[index];
  Initialize(test);
  int result = rank_800CC798(test->input[0]);
  int output[] = {result,
                  PocketPortMask,
                  PocketPortState[0],
                  PocketPortState[1],
                  PocketPortState[2],
                  PocketPortState[3],
                  PocketResult,
                  PocketRequest,
                  PocketResponse,
                  PocketCardStatus[0],
                  PocketCardStatus[1],
                  CardId(PocketCards[0]),
                  CardId(PocketCards[1]),
                  GM_PadResetDisable,
                  PocketTransferProgress,
                  (int)StringHash(PocketFilename)};
  for (int i = 0; i < 16; i++) {
    if (output[i] != test->output[i]) {
      fprintf(stderr, "Worker case %d field %d: %d != %d\n", index, i,
              output[i], test->output[i]);
      return 1;
    }
  }
  if (event_index != test->event_count || trace_hash != test->hash) {
    fprintf(stderr, "Worker case %d trace: %d/%d, %u != %u\n", index,
            event_index, test->event_count, trace_hash, test->hash);
    return 1;
  }
  return 0;
}
int main(void) {
  int count = (int)(sizeof(fixtures) / sizeof(fixtures[0]));
  for (int i = 0; i < count; i++)
    if (Check(i))
      return 1;
  printf("PocketStation transfer worker: %d original-MIPS cases passed\n",
         count);
  return 0;
}
