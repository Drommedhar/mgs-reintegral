#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_camera.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_control.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_fog.c"
#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_motion.c"

#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct Fixture {
  int input[12];
  unsigned state_crc;
  int trace_count;
  unsigned trace_crc, result;
} Fixture;
#include "mgs_brf_camera_fixtures.h"

static BriefingGraphWork work;
static GV_PAD pad;
static DG_TEX texture;
static unsigned crc_table[256], trace_words[4096];
static int trace_count, variant;
static const short x0_values[6] = {-128, -127, -126, 0, 127, 128};
static const short x1_values[6] = {127, 128, 129, -128, -127, 0};
static const short y0_values[6] = {-105, -104, -103, 0, 90, 200};
static const short y2_values[6] = {88, 89, 90, -105, -104, 0};
static const int zoom_values[6] = {200, 201, 202, 390, 391, 392};
static const int pan_x_values[6] = {-43, 0, 33, -100, 512, -511};
static const int pan_y_values[6] = {-29, 0, 41, -123, 78, -99};
short BrfScenePacketCounts[20] = {0,   1,   5,  12, 15, 40, 74, 200, 291, 684,
                                  835, 840, 11, 6,  23, 19, 50, 9,   1,   0};
int brf_dword_800C357C[6];
int brf_dword_800C3594[6];
int brf_dword_800C35AC[6];
int brf_dword_800C35C4[6];
int brf_dword_800C35DC[6];
int brf_dword_800C35F4[6];
int brf_dword_800C360C[33];
int brf_dword_800C3690[6];
int brf_dword_800C36A8[6];
int brf_dword_800C36C0[27];
int brf_dword_800C372C[6];

static unsigned Crc(unsigned crc, const void *data, size_t size) {
  const unsigned char *p = data;
  crc = ~crc;
  for (size_t i = 0; i < size; ++i)
    crc = crc_table[(crc ^ p[i]) & 255] ^ (crc >> 8);
  return ~crc;
}
static void Trace(int count, ...) {
  va_list args;
  va_start(args, count);
  assert(trace_count + count <= 4096);
  for (int i = 0; i < count; ++i)
    trace_words[trace_count++] = va_arg(args, unsigned);
  va_end(args);
}
static unsigned Normalize(uintptr_t value) {
  if (value == (uintptr_t)&work)
    return 0;
  if (value >= (uintptr_t)work.field_34 &&
      value < (uintptr_t)(work.field_34 + 15))
    return 100 + (value - (uintptr_t)work.field_34) / sizeof(POLY_FT4);
  if (value >= (uintptr_t)work.field_28C &&
      value < (uintptr_t)(work.field_28C + 840))
    return 1000 + (value - (uintptr_t)work.field_28C) / sizeof(POLY_FT4);
  if (value == (uintptr_t)brf_dword_800C357C)
    return 0x800C357Cu;
  if (value == (uintptr_t)brf_dword_800C3594)
    return 0x800C3594u;
  if (value == (uintptr_t)brf_dword_800C35AC)
    return 0x800C35ACu;
  if (value == (uintptr_t)brf_dword_800C35C4)
    return 0x800C35C4u;
  if (value == (uintptr_t)brf_dword_800C35DC)
    return 0x800C35DCu;
  if (value == (uintptr_t)brf_dword_800C35F4)
    return 0x800C35F4u;
  if (value == (uintptr_t)brf_dword_800C360C)
    return 0x800C360Cu;
  if (value == (uintptr_t)brf_dword_800C3690)
    return 0x800C3690u;
  if (value == (uintptr_t)brf_dword_800C36A8)
    return 0x800C36A8u;
  if (value == (uintptr_t)brf_dword_800C36C0)
    return 0x800C36C0u;
  if (value == (uintptr_t)brf_dword_800C372C)
    return 0x800C372Cu;
  return value;
}
static DG_TEX *Texture(void) {
  texture.id = 77;
  texture.used = 1;
  texture.col = variant;
  texture.tpage = 0x120 + variant;
  texture.clut = 0x230 + variant;
  texture.off_x = 250 - variant * 23;
  texture.off_y = 241 - variant * 11;
  texture.w = 19 + variant * 31;
  texture.h = 27 + variant * 13;
  return &texture;
}
int GV_StrCode(const char *name) {
  unsigned h = Crc(0, name, strlen(name));
  Trace(2, 1u, h);
  return h & 65535;
}
void GM_SeSet2(int a, int b, int c) { Trace(4, 2u, a, b, c); }
int GV_RandU(int limit) {
  Trace(2, 4u, limit);
  return variant;
}
unsigned int jimctrl_helper_80037F68(unsigned int code) {
  Trace(2, 5u, code);
  return 0x1200 + variant % 4;
}
DG_TEX *DG_GetTexture(int code) {
  Trace(2, 6u, code);
  return Texture();
}
#include "mgs_brf_camera_stubs.h"

static void FillPackets(POLY_FT4 *packets, int count) {
  for (int i = 0; i < count; ++i) {
    POLY_FT4 *p = &packets[i];
    for (int j = 0; j < 36; ++j)
      (&p->r0)[j] = j * 13 + i * 7 + variant * 17;
    p->x0 = p->x2 = x0_values[variant];
    p->x1 = p->x3 = x1_values[variant];
    p->y0 = p->y1 = y0_values[variant];
    p->y2 = p->y3 = y2_values[variant];
  }
}
static void Initialize(const Fixture *fixture) {
  const int *c = fixture->input;
  int time = c[2];
  unsigned char *tail = (unsigned char *)&work.field_A588;
  variant = c[1];
  memset(&work, 0, sizeof(work));
  FillPackets(work.field_34, 15);
  FillPackets(work.field_28C, 840);
  for (int i = 0; i < 0x840; ++i)
    tail[i] = (0xa588 + i) * 11 + variant * 31;
  memset(&work.pad, 0, sizeof(work) - offsetof(Work, pad));
  memset(&pad, 0, sizeof(pad));
  pad.status = c[9];
  pad.press = c[10];
  work.pad = &pad;
  work.field_A588 = c[3];
  work.field_AD2C = work.field_AD30 = work.field_AD38 = time;
  work.field_AD78 = work.field_AD84 = work.field_AD90 = pan_x_values[variant];
  work.field_AD7C = work.field_AD88 = work.field_AD94 = pan_y_values[variant];
  work.field_AD80 = work.field_AD8C = work.field_AD98 = zoom_values[variant];
  work.field_AD48 = variant & 1;
  work.field_AD70 = variant % 4;
  work.field_AD9C = c[5];
  work.field_ADA0 = c[6];
  work.field_ADA4 = c[4];
  work.field_ADA8 = c[7];
  work.field_ADAC = c[8];
  work.field_ADB0 = variant;
  work.field_ADB8 = 11;
  work.field_ADBC = 13;
  work.field_ADC0 = 15;
  trace_count = 0;
}
static unsigned Run(const Fixture *fixture) {
  int mode = fixture->input[4], arg = fixture->input[11];
  switch (fixture->input[0]) {
  case 0:
    brf_800CC070(&work, (arg % 3 + 3) % 3);
    break;
  case 1:
    brf_800CC150(&work);
    break;
  case 2:
    brf_800CC190(&work);
    break;
  case 3:
    brf_800CC28C(&work);
    break;
  case 4:
    brf_800CC388(&work);
    break;
  case 5:
    brf_800CC480(&work);
    break;
  case 6:
    brf_800CC560(&work);
    break;
  case 7:
    return brf_800CC5CC(arg);
  case 8:
    return brf_800CD734((unsigned char)arg);
  case 9:
    return brf_800CD7DC(&work, (unsigned char)arg) == &texture;
  case 10:
    brf_800CD870(&work, 2);
    break;
  case 11:
    brf_800CD8B8(&work, abs(arg) + 1, 2, 3);
    break;
  case 12:
    brf_800CD958(&work, 2, 3, 4);
    break;
  case 13:
    brf_800CDA10(&work, 2, 3);
    break;
  case 14:
    brf_800CDAA8(&work, 2);
    break;
  case 15:
    brf_800CDC8C(&work, &work.field_28C[2]);
    break;
  case 16:
    brf_800CDDD4(&work, arg, 2);
    break;
  case 17:
    brf_800CDF34(&work);
    break;
  case 18:
    brf_800CDFE4(&work);
    break;
  case 19:
    brf_800CE1C4(&work);
    break;
  case 20:
    brf_800CE2F8(&work);
    break;
  case 21:
    brf_800CE430(&work);
    break;
  case 22:
    brf_800CE648(&work, 2, mode, arg);
    break;
  case 23:
    brf_800CE6F0(&work, 2, mode, arg);
    break;
  case 24:
    brf_800CE798(&work, 2, mode, arg);
    break;
  case 25:
    brf_800CE840(&work, 2, mode, arg);
    break;
  case 26:
    brf_800CE8E8(&work, mode, arg);
    break;
  case 27:
    brf_800CE9A0(&work, mode, arg);
    break;
  case 28:
    brf_800CEA58(&work, 2, mode, arg);
    break;
  case 29:
    brf_800CEAF4(&work, mode, arg);
    break;
  case 30:
    brf_800CEB4C(&work, 2, mode);
    break;
  case 31:
    brf_800CEC68(&work);
    break;
  case 32:
    brf_800CECE4(&work);
    break;
  case 33:
    brf_800CF22C(&work, mode);
    break;
  case 34:
    brf_800CF354(&work, mode);
    break;
  case 35:
    brf_800CF394(&work, mode);
    break;
  case 36:
    brf_800CF430(&work);
    break;
  case 37:
    brf_800CF4A0(&work, -31, 25, 200, 390, 2, brf_dword_800C357C);
    break;
  }
  return 0;
}
static unsigned StateCrc(void) {
  unsigned crc = 0;
  for (int i = 0; i < 15; ++i)
    crc = Crc(crc, &work.field_34[i].r0, 36);
  for (int i = 0; i < 20; ++i)
    crc = Crc(crc, &work.field_28C[i].r0, 36);
  work.pad = NULL;
  return Crc(crc, &work.field_A588, 0x840);
}
int main(void) {
  for (unsigned i = 0; i < 256; ++i) {
    unsigned crc = i;
    for (int j = 0; j < 8; ++j)
      crc = (crc >> 1) ^ ((crc & 1) ? 0xedb88320u : 0);
    crc_table[i] = crc;
  }
  for (size_t i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
    const Fixture *f = &fixtures[i];
    Initialize(f);
    unsigned result = Run(f), state = StateCrc(),
             trace = Crc(0, trace_words, trace_count * sizeof(unsigned));
    if (result != f->result || state != f->state_crc ||
        trace_count != f->trace_count || trace != f->trace_crc) {
      fprintf(stderr,
              "Fixture %zu function %d variant %d mode %d: state %08x/%08x "
              "trace %d/%d %08x/%08x result %08x/%08x\n",
              i, f->input[0], variant, f->input[4], state, f->state_crc,
              trace_count, f->trace_count, trace, f->trace_crc, result,
              f->result);
      for (int j = 0; j < trace_count; ++j)
        fprintf(stderr, "%08x ", trace_words[j]);
      fprintf(stderr, "\n");
      return 1;
    }
  }
  printf("Briefing camera/control/motion: %zu original-MIPS cases passed\n",
         sizeof(fixtures) / sizeof(fixtures[0]));
  return 0;
}
