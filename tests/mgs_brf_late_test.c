#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_native.h"
#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct BriefingLateFixture {
  int input[6];
  uint32_t hash, trace, calls;
} BriefingLateFixture;
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_bio_timeline.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_late_animation.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_bio.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_late.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_scenes_smoke.c"
#include "fixtures/mgs_brf_late_fixtures.h"

int brf_dword_800C38E8[9], brf_dword_800C390C[18], brf_dword_800C3954[9];
int brf_dword_800C3978[15], brf_dword_800C39B4[6];
static BriefingGraphWork work;
static DG_TEX texture;
static uint32_t trace_hash, trace_calls;
static int seed;

static uint32_t HashBytes(uint32_t hash, const void *memory, size_t size) {
  const unsigned char *bytes = memory;
  for (size_t i = 0; i < size; ++i)
    hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}

static void Record(int tag, int count, ...) {
  va_list args;
  va_start(args, count);
  trace_hash = HashBytes(trace_hash, &tag, sizeof(tag));
  for (int i = 0; i < count; ++i) {
    int value = va_arg(args, int);
    trace_hash = HashBytes(trace_hash, &value, sizeof(value));
  }
  va_end(args);
  ++trace_calls;
}

static int Polygon(const void *pointer) {
  const POLY_FT4 *poly = pointer;
  assert(poly >= work.field_28C && poly < work.field_28C + 840);
  return (int)(poly - work.field_28C);
}

static unsigned int Table(int *pointer) {
  if (pointer == brf_dword_800C38E8)
    return 0x800c38e8;
  if (pointer == brf_dword_800C390C)
    return 0x800c390c;
  if (pointer == brf_dword_800C3954)
    return 0x800c3954;
  if (pointer == brf_dword_800C3978)
    return 0x800c3978;
  assert(pointer == brf_dword_800C39B4);
  return 0x800c39b4;
}

int GV_StrCode(const char *text) {
  unsigned short hash = 0;
  while (*text) {
    hash = (unsigned short)((hash << 5) | (hash >> 11));
    hash += (unsigned char)*text++;
  }
  return hash;
}

void GM_SeSet2(int pan, int volume, int sound) {
  Record(0x32968, 3, pan, volume, sound);
}
void GM_StreamPlayStart(void) { Record(0x37d1c, 0); }
DG_TEX *brf_800CABF4(BriefingGraphWork *actor, int id) {
  assert(actor == &work);
  Record(0xcabf4, 1, id);
  return &texture;
}
void brf_800CAC7C(BriefingGraphWork *actor, int id) {
  assert(actor == &work);
  Record(0xcac7c, 1, id);
}
void brf_800CADD4(BriefingGraphWork *actor, void *poly, int id) {
  assert(actor == &work);
  Record(0xcadd4, 2, Polygon(poly), id);
}
void brf_800CBB68(BriefingGraphWork *actor, void *poly, int id) {
  assert(actor == &work);
  Record(0xcbb68, 2, Polygon(poly), id);
}
void brf_800CBD5C(BriefingGraphWork *actor, void *poly) {
  assert(actor == &work);
  Record(0xcbd5c, 1, Polygon(poly));
}
void brf_800CBDC8(BriefingGraphWork *actor, void *poly) {
  assert(actor == &work);
  Record(0xcbdc8, 1, Polygon(poly));
}
void brf_800CBF48(BriefingGraphWork *actor, POLY_FT4 *poly) {
  assert(actor == &work);
  Record(0xcbf48, 1, Polygon(poly));
}
int brf_800CBE34(BriefingGraphWork *actor, POLY_FT4 *poly) {
  assert(actor == &work);
  Record(0xcbe34, 1, Polygon(poly));
  return 0x1234;
}
void brf_800CC150(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xcc150, 0);
}
void brf_800CC190(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xcc190, 0);
}
void brf_800CC28C(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xcc28c, 0);
}
void brf_800CC388(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xcc388, 0);
}
void brf_800CC480(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xcc480, 0);
}
void brf_800CC560(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xcc560, 0);
}
int brf_800CC5E4(BriefingGraphWork *actor, POLY_FT4 *a, POLY_FT4 *b) {
  assert(actor == &work);
  Record(0xcc5e4, 2, Polygon(a), Polygon(b));
  return 0x1234;
}
int brf_800CCBD4(BriefingGraphWork *actor, POLY_FT4 *poly) {
  assert(actor == &work);
  Record(0xccbd4, 1, Polygon(poly));
  return 0x1234;
}
void brf_800CD8B8(BriefingGraphWork *actor, int a, int b, int c) {
  assert(actor == &work);
  Record(0xcd8b8, 3, a, b, c);
}
void brf_800CDDD4(BriefingGraphWork *actor, int a, int b) {
  assert(actor == &work);
  Record(0xcddd4, 2, a, b);
}
void brf_800CF4A0(BriefingGraphWork *actor, int a, int b, int c, int d, int e,
                  int *table) {
  assert(actor == &work);
  Record(0xcf4a0, 6, a, b, c, d, e, Table(table));
}
int brf_800CF4E0(BriefingGraphWork *actor, int a, int b, int c, int d, int e,
                 int f, int *table) {
  assert(actor == &work);
  Record(0xcf4e0, 7, a, b, c, d, e, f, Table(table));
  return 0x1234;
}
BOOL brf_800CF5A8(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xcf5a8, 0);
  return seed & 1;
}
void brf_800D5CC4(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xd5cc4, 0);
}
void brf_800D5D30(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xd5d30, 0);
}
void brf_800D5D9C(BriefingGraphWork *actor, POLY_FT4 *a, POLY_FT4 *b) {
  assert(actor == &work);
  Record(0xd5d9c, 2, Polygon(a), Polygon(b));
}
void brf_800D5DDC(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xd5ddc, 0);
}
void brf_800D68D0(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xd68d0, 0);
}
void brf_800CECE4(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xcece4, 0);
}
void brf_800CF430(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xcf430, 0);
}

void brf_800CAE84(BriefingGraphWork *actor, int a, int b) {
  assert(actor == &work);
  Record(0xcae84, 2, a, b);
}
void brf_800CB23C(BriefingGraphWork *actor, int a, int b) {
  assert(actor == &work);
  Record(0xcb23c, 2, a, b);
}
void brf_800CB5F4(BriefingGraphWork *actor, int a, int b) {
  assert(actor == &work);
  Record(0xcb5f4, 2, a, b);
}
void brf_800CD958(BriefingGraphWork *actor, int a, int b, int c) {
  assert(actor == &work);
  Record(0xcd958, 3, a, b, c);
}
void brf_800CDA10(BriefingGraphWork *actor, int a, int b) {
  assert(actor == &work);
  Record(0xcda10, 2, a, b);
}
void brf_800CDAA8(BriefingGraphWork *actor, int a) {
  assert(actor == &work);
  Record(0xcdaa8, 1, a);
}
void brf_800CE1C4(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xce1c4, 0);
}
void brf_800CE2F8(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xce2f8, 0);
}
void brf_800CE648(BriefingGraphWork *actor, int a, int b, int c) {
  assert(actor == &work);
  Record(0xce648, 3, a, b, c);
}
void brf_800CE6F0(BriefingGraphWork *actor, int a, int b, int c) {
  assert(actor == &work);
  Record(0xce6f0, 3, a, b, c);
}
void brf_800CF22C(BriefingGraphWork *actor, int a) {
  assert(actor == &work);
  Record(0xcf22c, 1, a);
}
void brf_800CF354(BriefingGraphWork *actor, int a) {
  assert(actor == &work);
  Record(0xcf354, 1, a);
}
void brf_800D1764(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xd1764, 0);
}
void brf_800D17E8(BriefingGraphWork *actor, int a, int b) {
  assert(actor == &work);
  Record(0xd17e8, 2, a, b);
}
void brf_800D1838(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xd1838, 0);
}
void brf_800D18D8(BriefingGraphWork *actor, int a, int b, int c) {
  assert(actor == &work);
  Record(0xd18d8, 3, a, b, c);
}
void brf_800D1A04(BriefingGraphWork *actor, int a, int b) {
  assert(actor == &work);
  Record(0xd1a04, 2, a, b);
}
void brf_800D1AD8(BriefingGraphWork *actor) {
  assert(actor == &work);
  Record(0xd1ad8, 0);
}

static void Initialize(const BriefingLateFixture *fixture) {
  seed = fixture->input[5];
  memset(&work, 0, sizeof(work));
  for (int i = 0; i < 75; ++i)
    for (int j = 0; j < 36; ++j)
      ((unsigned char *)&work.field_28C[i].r0)[j] =
          (unsigned char)(i * 11 + (j + 4) * 7 + seed);
  for (int i = 0; i < 840; ++i)
    work.z_A597[i] = (unsigned char)((i * 13 + seed) % 16);
  for (int i = 0; i < 842; ++i)
    work.field_A9B6[i] = (unsigned char)((i + seed) % 2);
  for (int i = 0; i < 39; ++i) {
    int value = (0xad28 / 4 + i + seed) % 4;
    memcpy((char *)&work.field_AD28 + i * 4, &value, sizeof(value));
  }
  work.field_AD20 = fixture->input[1];
  work.field_AD30 = fixture->input[2];
  work.field_AD34 = fixture->input[3];
  work.field_AD5C = fixture->input[4];
  if (fixture->input[0] == 0xd1bdc || fixture->input[0] == 0xd26e4)
    work.field_AD3C = fixture->input[2];
  memset(&texture, 0, sizeof(texture));
  texture.tpage = (unsigned short)(0x123 + seed);
  texture.clut = (unsigned short)(0x234 + seed);
  texture.off_x = (unsigned char)(13 + seed);
  texture.off_y = (unsigned char)(229 - seed);
  texture.w = 41;
  texture.h = 29;
  trace_hash = 2166136261u;
  trace_calls = 0;
}

static uint32_t OutputHash(void) {
  uint32_t hash = 2166136261u;
  for (int i = 0; i < 75; ++i)
    hash = HashBytes(hash, &work.field_28C[i].r0, 36);
  hash = HashBytes(hash, work.z_A597, 840);
  hash = HashBytes(hash, work.field_A9B6, 842);
  hash = HashBytes(hash, &work.field_AD20, 4);
  return HashBytes(hash, &work.field_AD28, 156);
}

static void Run(int address) {
  switch (address) {
  case 0xd0234:
    brf_800D0234(&work);
    break;
  case 0xd02f4:
    brf_800D02F4(&work);
    break;
  case 0xd1bdc:
    brf_800D1BDC(&work);
    break;
  case 0xd26e4:
    brf_800D26E4(&work);
    break;
  case 0xd5e54:
    brf_800D5E54(&work);
    break;
  case 0xd5ed0:
    brf_800D5ED0(&work);
    break;
  case 0xd674c:
    brf_800D674C(&work);
    break;
  case 0xd693c:
    brf_800D693C(&work);
    break;
  case 0xd69a8:
    brf_800D69A8(&work);
    break;
  case 0xd6f98:
    brf_800D6F98(&work);
    break;
  case 0xd70a4:
    brf_800D70A4(&work);
    break;
  case 0xd75f0:
    brf_800D75F0(&work);
    break;
  case 0xd8060:
    brf_800D8060(&work);
    break;
  default:
    assert(0);
  }
}

int main(void) {
  for (unsigned i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
    const BriefingLateFixture *fixture = &fixtures[i];
    Initialize(fixture);
    Run(fixture->input[0]);
    uint32_t hash = OutputHash();
    if (hash != fixture->hash || trace_hash != fixture->trace ||
        trace_calls != fixture->calls) {
      fprintf(stderr,
              "Briefing late fixture %u fn=%x state=%d time=%d seed=%d: hash "
              "%08x/%08x trace %08x/%08x calls %u/%u\n",
              i, fixture->input[0], fixture->input[1], fixture->input[2], seed,
              hash, fixture->hash, trace_hash, fixture->trace, trace_calls,
              fixture->calls);
      return 1;
    }
  }
  printf("%zu original-MIPS briefing scene and animation cases passed.\n",
         sizeof(fixtures) / sizeof(fixtures[0]));
  return 0;
}
