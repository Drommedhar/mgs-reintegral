#ifndef MGS_BRF_GRAPH_TEST_SUPPORT_H
#define MGS_BRF_GRAPH_TEST_SUPPORT_H

#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct Fixture {
  int input[6];
  unsigned state_crc;
  int trace_count;
  unsigned trace_crc;
} Fixture;
static BriefingGraphWork test_work;
static DG_TEX test_texture;
static unsigned crc_table[256];
static unsigned trace_words[2048];
static int trace_count;
static int helper_result;
static int variant;

static unsigned Crc(unsigned crc, const void *data, size_t size) {
  const unsigned char *bytes = data;
  crc = ~crc;
  for (size_t i = 0; i < size; ++i)
    crc = crc_table[(crc ^ bytes[i]) & 255] ^ (crc >> 8);
  return ~crc;
}

static void Trace(int count, ...) {
  va_list args;
  va_start(args, count);
  assert(trace_count + count <= 2048);
  for (int i = 0; i < count; ++i)
    trace_words[trace_count++] = va_arg(args, unsigned);
  va_end(args);
}

static DG_TEX *Texture(int code) {
  test_texture.id = code;
  test_texture.used = 1;
  test_texture.col = variant;
  test_texture.tpage = 0x120 + variant;
  test_texture.clut = 0x230 + variant;
  test_texture.off_x = 250 - variant * 23;
  test_texture.off_y = 241 - variant * 11;
  test_texture.w = 19 + variant * 31;
  test_texture.h = 27 + variant * 13;
  return &test_texture;
}

int GV_StrCode(const char *name) {
  unsigned crc = Crc(0, name, strlen(name));
  Trace(2, 1u, crc);
  return crc & 65535;
}

void GM_SeSet2(int a, int b, int c) { Trace(4, 2u, a, b, c); }

void GM_StreamPlayStart(void) { Trace(1, 3u); }

static void InitWork(const Fixture *fixture) {
  static const int results[] = {0, 1, 17};
  unsigned char *tail = (unsigned char *)&test_work.field_A588;
  int time = fixture->input[2];
  variant = fixture->input[1];
  helper_result = results[variant];
  memset(&test_work, 0, sizeof(test_work));
  for (int i = 0; i < 840; ++i) {
    unsigned char *payload = &test_work.field_28C[i].r0;
    for (int j = 0; j < 36; ++j)
      payload[j] = j * 13 + i * 7 + variant * 17;
  }
  for (int i = 0; i < 0x840; ++i)
    tail[i] = (0xa588 + i) * 11 + variant * 31;
  memset(&test_work.pad, 0, sizeof(test_work) - offsetof(Work, pad));
  test_work.field_AD28 = time;
  test_work.field_AD2C = time;
  test_work.field_AD30 = time;
  test_work.field_AD34 = time;
  test_work.field_AD38 = time;
  test_work.field_AD3C = time;
  test_work.field_AD20 = fixture->input[3];
  test_work.field_AD24 = fixture->input[4];
  test_work.field_AD5C = fixture->input[5];
  test_work.field_ADBC = variant;
  trace_count = 0;
}

static int RunFixtures(const Fixture *fixtures, size_t count, void (*run)(int),
                       int packet_count, const char *name) {
  for (unsigned i = 0; i < 256; ++i) {
    unsigned crc = i;
    for (int j = 0; j < 8; ++j)
      crc = (crc >> 1) ^ ((crc & 1) ? 0xedb88320u : 0);
    crc_table[i] = crc;
  }
  for (size_t i = 0; i < count; ++i) {
    const Fixture *fixture = &fixtures[i];
    unsigned state_crc = 0;
    InitWork(fixture);
    run(fixture->input[0]);
    for (int j = 0; j < packet_count; ++j)
      state_crc = Crc(state_crc, &test_work.field_28C[j].r0, 36);
    state_crc = Crc(state_crc, &test_work.field_A588, 0x840);
    unsigned trace_crc = Crc(0, trace_words, trace_count * sizeof(unsigned));
    if (state_crc != fixture->state_crc ||
        trace_count != fixture->trace_count ||
        trace_crc != fixture->trace_crc) {
      fprintf(stderr,
              "Fixture %zu function %d variant %d time %d state %d: state "
              "%08x/%08x, trace %d/%d %08x/%08x\n",
              i, fixture->input[0], variant, fixture->input[2],
              fixture->input[3], state_crc, fixture->state_crc, trace_count,
              fixture->trace_count, trace_crc, fixture->trace_crc);
      for (int j = 0; j < trace_count; ++j)
        fprintf(stderr, "%08x ", trace_words[j]);
      fprintf(stderr, "\n");
      return 1;
    }
  }
  printf("%s: %zu original-MIPS state/packet/call-trace fixtures passed\n",
         name, count);
  return 0;
}

#endif
