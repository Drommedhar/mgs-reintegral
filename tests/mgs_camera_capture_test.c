#include "mgs_native.h"

#include "game/game.h"

#include "camera_capture_helpers.inc"
#undef fprintf
#include <assert.h>
#include <stdint.h>

typedef struct CaptureFixture {
  unsigned encoded, used, decoded, reads;
  uint32_t hash;
} CaptureFixture;

#include "fixtures/mgs_camera_capture_fixtures.h"

static unsigned pattern, image_reads;

static unsigned short Pixel(unsigned x, unsigned y) {
  uint32_t value;
  if (pattern == 0)
    return 0;
  if (pattern == 1)
    return 0x7fff;
  if (pattern == 2)
    return (unsigned short)(((x * 3 + y) & 31) | (((x + y * 2) & 31) << 5) |
                            (((x * 5 + y * 7) & 31) << 10));
  value = x + y * 320 + 123;
  value = (value ^ (value >> 16)) * 0x45d9f3bu;
  value = (value ^ (value >> 16)) * 0x45d9f3bu;
  return (unsigned short)((value ^ (value >> 16)) & 0x7fff);
}

int StoreImage(RECT *rect, u_long *destination) {
  unsigned short *pixels = (unsigned short *)destination;
  assert(rect->w == 16 && rect->h == 16);
  assert(rect->x >= 16 && rect->x <= 288 && rect->y >= 16 && rect->y <= 176);
  for (int y = 0; y < 16; ++y)
    for (int x = 0; x < 16; ++x)
      *pixels++ = Pixel((unsigned)(rect->x + x), (unsigned)(rect->y + y));
  ++image_reads;
  return 0;
}

static void CheckCapture(const CaptureFixture *expected) {
  Work work = {0};
  uint32_t hash = 2166136261u;
  unsigned char *output = (unsigned char *)PACK_ADDR1 - 0x10000;
  unsigned char *scratch_end = (unsigned char *)PACK_ADDR1 + 0x1180;
  memset(mgs_main_ram, 0, sizeof(mgs_main_ram));
  image_reads = 0;
  JpegInitMatrix(&work);
  JpegTryCompressFrame(&work);
  assert((unsigned char *)work.field_88 == output);
  assert((unsigned)work.field_7C == expected->encoded);
  assert((unsigned)work.field_80 == expected->used);
  assert((unsigned)work.field_8C_size == expected->decoded);
  assert(work.field_8C_size <= 16124);
  assert(image_reads == expected->reads);
  for (unsigned i = 0; i <= expected->used; ++i)
    hash = (hash ^ output[i]) * 16777619u;
  assert(hash == expected->hash);
  for (unsigned char *p = mgs_main_ram; p < output; ++p)
    assert(*p == 0);
  for (unsigned char *p = scratch_end; p < mgs_main_ram + sizeof(mgs_main_ram);
       ++p)
    assert(*p == 0);
}

int main(void) {
  for (pattern = 0; pattern < sizeof(fixtures) / sizeof(fixtures[0]); ++pattern)
    CheckCapture(&fixtures[pattern]);
  puts("Camera capture: four original-MIPS full-frame encodings match, with "
       "native scratch bounds.");
  return 0;
}
