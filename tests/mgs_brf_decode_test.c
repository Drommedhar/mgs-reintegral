#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/brf/onoda/brf/select_decode.c"
#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct Fixture {
  int input[7];
  unsigned int output[4];
} Fixture;
#include "mgs_brf_decode_fixtures.h"
unsigned char
    mgs_main_ram[MGS_RESIDENT_HEADROOM + MGS_MAIN_RAM_SIZE + MGS_TOP_RAM_SIZE];
static unsigned char allocation[0x10000], packed[4096];
static Work test_work;
static unsigned int trace_hash;
static int trace_count;
static unsigned int HashBytes(unsigned int hash, const void *data,
                              size_t count) {
  const unsigned char *bytes = data;
  for (size_t i = 0; i < count; ++i)
    hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}
static void Trace(int count, ...) {
  va_list args;
  va_start(args, count);
  trace_count += count;
  while (count--) {
    unsigned int value = va_arg(args, int);
    trace_hash = HashBytes(trace_hash, &value, sizeof(value));
  }
  va_end(args);
}
int mgs_fprintf(int channel, const char *format, ...) {
  va_list args;
  va_start(args, format);
  int result = vfprintf(stderr, format, args);
  va_end(args);
  return result;
}
void *GV_Malloc(int size) {
  Trace(2, 3, size);
  assert(size <= sizeof(allocation));
  return allocation;
}
int LoadImage(RECT *rect, u_long *pixels) {
  Trace(6, 1, rect->x, rect->y, rect->w, rect->h,
        HashBytes(2166136261u, pixels, rect->w * rect->h * 2));
  return 0;
}
void brf_800C5478(Work *work, int id, int tp, int abr, RECT *image,
                  RECT *palette, int col) {
  assert(work == &test_work);
  Trace(13, 2, id, tp, abr, image->x, image->y, image->w, image->h, palette->x,
        palette->y, palette->w, palette->h, col);
}
void brf_800C5584(Work *work, int id, int tp, int abr, RECT *image,
                  RECT *palette, int col, void *buffer) {
  assert(buffer == allocation);
  brf_800C5478(work, id, tp, abr, image, palette, col);
}
static unsigned char *PackCodes(unsigned char *dst, int runs, int bits,
                                int factor, int offset) {
  int per_word = 32 / bits;
  unsigned int word = 0;
  for (int i = 0; i < runs; ++i) {
    unsigned int value = (i * factor + offset) & ((1u << bits) - 1);
    word |= value << ((i % per_word) * bits);
    if (i % per_word == per_word - 1 || i == runs - 1) {
      memcpy(dst, &word, sizeof(word));
      dst += sizeof(word);
      word = 0;
    }
  }
  return dst;
}
static int Initialize(const int *in) {
  BrfPackedImage *header = (BrfPackedImage *)packed;
  memset(packed, 0, sizeof(packed));
  header->bytes_per_pixel = in[1];
  header->code_bits = in[2] | (in[3] << 4);
  header->palette_count = in[5];
  header->height = 1;
  header->flags = in[1] | ((in[6] & 3) << 4);
  header->x = 64 + in[6] * 17;
  header->y = 32;
  header->palette_x = 256;
  header->palette_y = 480;
  header->runs = in[4];
  for (int i = 0; i < in[4]; ++i)
    header->width += ((i * 3 + in[6] * 5) & ((1 << in[2]) - 1)) + 1;
  unsigned char *dst = packed + sizeof(*header);
  for (int i = 0; i < in[5]; ++i) {
    unsigned short color = i * 137 + in[6] * 53;
    memcpy(dst, &color, sizeof(color));
    dst += sizeof(color);
  }
  if (in[5] & 1)
    dst += 2;
  dst = PackCodes(dst, in[4], in[2], 3, in[6] * 5);
  PackCodes(dst, in[4], in[3], 17, in[6] * 19);
  trace_hash = 2166136261u;
  trace_count = 0;
  memset((unsigned char *)MEM_BOTTOM - 0x13000, 0xa5, 0x13000);
  memset(allocation, 0xa5, sizeof(allocation));
  BrfTextureCursor = (unsigned char *)MEM_BOTTOM - (in[6] < 2 ? 0x13000 : 16);
  return BrfImageBytes(header);
}
static int Check(int index) {
  const Fixture *test = &fixtures[index];
  const int *in = test->input;
  int size = Initialize(in);
  const int ids[] = {0x12345678, 0, 0xbeef};
  unsigned char *buffer = allocation;
  if (!in[0]) {
    buffer = BrfTextureCursor;
    if (buffer + (size / 4 + 1) * 4 > (unsigned char *)MEM_BOTTOM - 1)
      buffer = (unsigned char *)MEM_BOTTOM - 0x13000;
    brf_800C56C0(&test_work, packed, ids[in[6]]);
  } else
    brf_800C5A68(&test_work, packed, ids[in[6]]);
  unsigned int output[] = {
      (unsigned int)(BrfTextureCursor -
                     ((unsigned char *)MEM_BOTTOM - 0x13000)),
      HashBytes(2166136261u, buffer, size), trace_count, trace_hash};
  if (memcmp(output, test->output, sizeof(output))) {
    fprintf(stderr,
            "Briefing decoder case %d failed: %u/%u %u/%u %u/%u %u/%u\n", index,
            output[0], test->output[0], output[1], test->output[1], output[2],
            test->output[2], output[3], test->output[3]);
    return 1;
  }
  return 0;
}
int main(void) {
  int count = sizeof(fixtures) / sizeof(fixtures[0]);
  for (int i = 0; i < count; ++i)
    if (Check(i))
      return 1;
  printf("Briefing image decoder: %d original-MIPS cases passed\n", count);
  return 0;
}
