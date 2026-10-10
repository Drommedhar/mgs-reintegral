#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/rank/onoda/rank/rank_award.c"
#include "../vendor/mgs/source/overlays/rank/onoda/rank/rank_data.c"
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct Fixture {
  int input[12], output[19], trace_size, trace[6];
} Fixture;
#include "mgs_rank_award_fixtures.h"
short linkvarbuf[MAX_LINKVARBUF];
short GM_PDA_ClearRank;
static RankWork work;
static int trace_size, trace[6];
int GV_StrCode(const char *name) {
  assert(strcmp(name, "big_back_l") == 0 || strcmp(name, "big_back_r") == 0);
  return name[9] == 'l' ? 0x1234 : 0x5678;
}
void rank_800D8E64(RankWork *actor, int texture, POLY_FT4 *packet) {
  assert(actor == &work && trace_size + 2 <= 6);
  trace[trace_size++] = texture;
  trace[trace_size++] = (int)(packet - work.pol);
}
int main(void) {
  const int variables[] = {1, 78, 79, 91, 92, 86, 88, 87, 47, 48, 49, 3};
  unsigned long long award_bits = 0;
  for (size_t i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
    const Fixture *fixture = &fixtures[i];
    memset(&work, 0, sizeof(work));
    trace_size = 0;
    for (int j = 0; j < 12; ++j)
      linkvarbuf[variables[j]] = fixture->input[j];
    GM_PDA_ClearRank = (short)0xabcd;
    work.field_494 = 17;
    work.field_498 = 2;
    work.field_49C = 5;
    work.field_4A0 = 6;
    work.field_4A4 = 7;
    work.field_4A8 = 3;
    work.field_4AC = 8;
    work.field_4B0 = 9;
    work.field_4B4 = 10;
    rank_800D8EE4(&work);
    POLY_FT4 *p = &work.pol[12];
    int out[] = {
        work.field_494, work.field_498, work.field_49C,
        work.field_4A0, work.field_4A4, work.field_4A8,
        work.field_4AC, work.field_4B0, work.field_4B4,
        p->x0,          p->y0,          p->x1,
        p->y1,          p->x2,          p->y2,
        p->x3,          p->y3,          (unsigned short)GM_PDA_ClearRank,
        GM_Result};
    for (int j = 0; j < 19; ++j)
      if (out[j] != fixture->output[j]) {
        fprintf(stderr, "rank case%zu output%d native%d original%d\n", i, j,
                out[j], fixture->output[j]);
        return 1;
      }
    assert(trace_size == fixture->trace_size);
    assert(memcmp(trace, fixture->trace, trace_size * sizeof(int)) == 0);
    award_bits |= 1ull << work.field_494;
  }
  assert(award_bits == 0xffffffffffffull);
  printf("Rank awards: %zu original-MIPS cases cover all48 awards\n",
         sizeof(fixtures) / sizeof(fixtures[0]));
  return 0;
}
