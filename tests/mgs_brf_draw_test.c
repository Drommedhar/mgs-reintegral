#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/brf/onoda/brf/select_border.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/select_draw.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/select_layout.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/select_reveal.c"
#undef fprintf
#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

typedef struct Fixture {
  int input[12];
  unsigned int hash;
} Fixture;
#include "mgs_brf_draw_fixtures.h"
static Work work;
void GM_SeSet2(int channel, int volume, int sound) { abort(); }
static unsigned int HashBytes(unsigned int hash, const void *data,
                              size_t count) {
  const unsigned char *bytes = data;
  for (size_t i = 0; i < count; ++i)
    hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}
static void Initialize(const int *in) {
  memset(&work, 0, sizeof(work));
  const int indices[] = {0, 2, 4, 9, 12, 14};
  for (int bit = 0; bit < 6; ++bit)
    work.field_80[indices[bit]] = (in[1] >> bit) & 1;
  for (int i = 0; i < 53; ++i) {
    POLY_FT4 *poly = i < 44 ? &work.field_780[i] : &work.field_E60[i - 44];
    for (int j = 0; j < 36; ++j)
      ((unsigned char *)&poly->r0)[j] = j * 13 + i * 7 + in[10] * 17;
    short xy[8];
    for (int j = 0; j < 8; ++j)
      xy[j] = ((i * 11 + j * 5 + in[10] * 13) % 241) - 120;
    setXY4(poly, xy[0], xy[1], xy[2], xy[3], xy[4], xy[5], xy[6], xy[7]);
  }
  work.field_70 = 7;
  work.field_74 = in[5];
  work.field_D0 = in[2];
  work.field_FD4 = in[6];
  work.field_FD8 = in[7];
  work.field_FDC = in[8];
  work.field_FE0 = in[9];
}
static unsigned int Run(const int *in) {
  Initialize(in);
  switch (in[0]) {
  case 0:
    brf_800C62B0(&work, in[10] * 13 - 200, in[10] * 11 - 170, in[10] * 3 + 8,
                 in[10] * 5 + 12, in[10] * 37, in[11]);
    break;
  case 1:
    brf_800C6E88(&work, in[3]);
    break;
  case 2:
    brf_800C731C(&work, in[3], in[4]);
    break;
  case 3:
    brf_800C7488(&work, in[3], in[4]);
    break;
  case 4:
    brf_800C75F0(&work, in[3], in[4]);
    break;
  case 5:
    brf_800C7B94(&work);
    break;
  default:
    abort();
  }
  unsigned int hash =
      HashBytes(2166136261u, (char *)&work + 0x2c, 0x780 - 0x2c);
  for (int i = 0; i < 53; ++i) {
    POLY_FT4 *poly = i < 44 ? &work.field_780[i] : &work.field_E60[i - 44];
    hash = HashBytes(hash, &poly->r0, 36);
  }
  return HashBytes(hash, &work.field_FC8, 32);
}
int main(void) {
  _Static_assert(offsetof(Work, field_780) == 0x780, "Selector prefix layout");
  int count = sizeof(fixtures) / sizeof(fixtures[0]);
  for (int i = 0; i < count; ++i) {
    unsigned int result = Run(fixtures[i].input);
    if (result != fixtures[i].hash) {
      fprintf(stderr, "Briefing draw case %d (function %d): %u != %u\n", i,
              fixtures[i].input[0], result, fixtures[i].hash);
      return 1;
    }
  }
  printf("Briefing draw: %d original-MIPS cases passed\n", count);
  return 0;
}
