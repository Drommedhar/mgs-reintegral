#include "mgs_native.h"

#include "../vendor/mgs/source/libgv/strcode.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_fog.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_metrics.c"
#undef fprintf
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct BrfCoreFixture {
  int input[7];
  uint32_t hash, trace, calls;
} BrfCoreFixture;
#include "fixtures/mgs_brf_core_fixtures.h"

static BriefingGraphWork work;
static DG_TEX texture;
static int geometry[18];
static uint32_t trace_hash, trace_calls;

static uint32_t HashBytes(uint32_t hash, const void *data, size_t count) {
  const unsigned char *bytes = data;
  for (size_t i = 0; i < count; ++i)
    hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}

static void Record(int tag, int argument) {
  trace_hash = HashBytes(trace_hash, &tag, sizeof(tag));
  trace_hash = HashBytes(trace_hash, &argument, sizeof(argument));
  ++trace_calls;
}

DG_TEX *DG_GetTexture(int id) {
  Record(0x1d830, id);
  return &texture;
}

DG_TEX *brf_800CABF4(BriefingGraphWork *actor, int id) {
  assert(actor == &work);
  Record(0xcabf4, id);
  return &texture;
}

int brf_800CC5CC(int digit) { return (unsigned int)digit < 10 ? digit : 0; }

static void FillPackets(POLY_FT4 *packets, int count, int seed) {
  for (int i = 0; i < count; ++i)
    for (int j = 0; j < 36; ++j)
      ((unsigned char *)&packets[i].r0)[j] =
          (unsigned char)(seed + i * 11 + (j + 4) * 7);
}

static void Initialize(const BrfCoreFixture *fixture) {
  int seed = fixture->input[1];
  memset(&work, 0, sizeof(work));
  FillPackets(work.field_34, 15, seed);
  FillPackets(work.field_28C, 20, seed);
  memset(&texture, 0, sizeof(texture));
  texture.tpage = (unsigned short)(0x123 + seed);
  texture.clut = (unsigned short)(0x234 + seed);
  texture.off_x = (unsigned char)(seed * 71);
  texture.off_y = (unsigned char)(seed * 37);
  texture.w = (unsigned char)(seed * 29);
  texture.h = (unsigned char)(seed * 43);
  for (int i = 0; i < 6; ++i) {
    unsigned int coordinates[4];
    for (int j = 0; j < 4; ++j)
      coordinates[j] = (unsigned short)(seed * 521 + i * 717 + j * 18077);
    geometry[3 * i] = (i * 3 + seed) % 20;
    geometry[3 * i + 1] = (int)(coordinates[0] | coordinates[1] << 16);
    geometry[3 * i + 2] = (int)(coordinates[2] | coordinates[3] << 16);
  }
  trace_hash = 2166136261u;
  trace_calls = 0;
}

static uint32_t OutputHash(void) {
  uint32_t hash = 2166136261u;
  for (int i = 0; i < 15; ++i)
    hash = HashBytes(hash, &work.field_34[i].r0, 36);
  for (int i = 0; i < 20; ++i)
    hash = HashBytes(hash, &work.field_28C[i].r0, 36);
  hash = HashBytes(hash, &work.field_AD30, 4);
  hash = HashBytes(hash, &work.field_AD38, 4);
  hash = HashBytes(hash, &work.field_AD74, 4);
  hash = HashBytes(hash, &work.field_ADB8, 4);
  return HashBytes(hash, &work.field_ADBC, 4);
}

static void Run(const int *input) {
  int a = input[2], b = input[3], c = input[4], d = input[5], e = input[6];
  switch (input[0]) {
  case 0xcae84:
  case 0xcb23c:
  case 0xcb5f4:
    work.field_AD38 = a;
    work.field_AD74 = b;
    if (input[0] == 0xcae84)
      brf_800CAE84(&work, c, d);
    else if (input[0] == 0xcb23c)
      brf_800CB23C(&work, c, d);
    else
      brf_800CB5F4(&work, c, d);
    break;
  case 0xcbe34:
    work.field_AD30 = a;
    brf_800CBE34(&work, &work.field_28C[c]);
    break;
  case 0xcc5e4:
    brf_800CC5E4(&work, &work.field_28C[a], &work.field_28C[b]);
    break;
  case 0xccbd4:
    brf_800CCBD4(&work, &work.field_28C[a]);
    break;
  case 0xcdaec:
    brf_800CDAEC(work.field_28C, a, geometry, b, c, d, e);
    break;
  case 0xcf4e0:
    work.field_AD38 = a;
    work.field_ADB8 = 11;
    work.field_ADBC = 22;
    brf_800CF4E0(&work, b, c, d, e, 37, 6, geometry);
    break;
  default:
    assert(0);
  }
}

int main(void) {
  for (unsigned i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
    const BrfCoreFixture *fixture = &fixtures[i];
    Initialize(fixture);
    Run(fixture->input);
    uint32_t hash = OutputHash();
    if (hash != fixture->hash || trace_hash != fixture->trace ||
        trace_calls != fixture->calls) {
      fprintf(stderr,
              "Briefing core fixture %u fn=%x seed=%d frame=%d phase=%d: hash "
              "%08x/%08x trace %08x/%08x calls %u/%u\n",
              i, fixture->input[0], fixture->input[1], fixture->input[2],
              fixture->input[3], hash, fixture->hash, trace_hash,
              fixture->trace, trace_calls, fixture->calls);
      return 1;
    }
  }
  printf("%zu original-MIPS briefing fog, metrics and geometry cases passed.\n",
         sizeof(fixtures) / sizeof(fixtures[0]));
  return 0;
}
