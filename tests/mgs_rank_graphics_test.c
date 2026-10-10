#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/rank/onoda/rank/rank_graphics.c"
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct Fixture {
  int input[10];
  int count;
  uint32_t hash;
} Fixture;
#include "mgs_rank_graphics_fixtures.h"
int GV_Clock;
static RankWork work;
static POLY_FT4 packet;
static DG_TEX texture;
static OT_TYPE ot;
static int values[200], value_count, trace[40], trace_count;
static unsigned char buffer[900];
static void Append(int *out, int *length, int count, va_list args) {
  while (count-- > 0)
    out[(*length)++] = va_arg(args, int);
}
static void Value(int count, ...) {
  va_list args;
  assert(value_count + count <= 200);
  va_start(args, count);
  Append(values, &value_count, count, args);
  va_end(args);
}
static void Trace(int count, ...) {
  va_list args;
  assert(trace_count + count <= 40);
  va_start(args, count);
  Append(trace, &trace_count, count, args);
  va_end(args);
}
DG_TEX *DG_GetTexture(int name) {
  Trace(2, 1, name);
  return &texture;
}
int font_init_kcb(KCB *font, RECT *rect, int x, int y) {
  assert(font == &work.kcb[0]);
  Trace(7, 2, rect->x, rect->y, rect->w, rect->h, x, y);
  return 0;
}
int font_set_kcb(KCB *font, int width, int height, int cskip, int lskip,
                 int tskip, int flag) {
  assert(font == &work.kcb[0]);
  Trace(7, 3, width, height, cskip, lskip, tskip, flag);
  return 0;
}
int font_get_buffer_size(KCB *font) {
  assert(font == &work.kcb[0]);
  Trace(1, 4);
  return sizeof(buffer);
}
void *GV_AllocMemory(int pool, int size) {
  Trace(3, 5, pool, size);
  return buffer;
}
void font_set_buffer(KCB *font, void *data) {
  assert(font == &work.kcb[0] && data == buffer);
  Trace(1, 6);
}
void font_set_color(KCB *font, int code, int fore, int back) {
  assert(font == &work.kcb[0]);
  Trace(4, 7, code, fore, back);
}
void font_clut_update(KCB *font) {
  assert(font == &work.kcb[0]);
  Trace(1, 8);
}
void font_print_string(KCB *font, const char *text) {
  assert(font == &work.kcb[0] && text == (char *)buffer);
  Trace(1, 9);
}
void font_update(KCB *font) {
  assert(font == &work.kcb[0]);
  Trace(1, 10);
}

static void Geometry(const Fixture *fixture) {
  const int *a = fixture->input + 1;
  switch (fixture->input[0]) {
  case 0:
    rank_800D98D4(&work, a[0], a[1], a[2], a[3], a[4], a[5]);
    for (int i = 0; i < 9; i++) {
      POLY_FT4 *p = &work.pol_cur[i];
      Value(12, work.z_cur[i], p->r0, p->g0, p->b0, p->x0, p->y0, p->x1, p->y1,
            p->x2, p->y2, p->x3, p->y3);
    }
    break;
  case 1:
    texture = (DG_TEX){0, 0, 0, a[4], a[5], a[0], a[1], a[2], a[3]};
    rank_800D8E64(&work, 765, &packet);
    Value(10, packet.u0, packet.v0, packet.u1, packet.v1, packet.u2, packet.v2,
          packet.u3, packet.v3, packet.tpage, packet.clut);
    break;
  case 2:
    rank_800DAD08(&work, &packet, a[0], a[1], a[2], a[3], a[4]);
    Value(13, getlen(&packet), packet.r0, packet.g0, packet.b0, packet.code,
          packet.x0, packet.y0, packet.x1, packet.y1, packet.x2, packet.y2,
          packet.x3, packet.y3);
    break;
  default:
    abort();
  }
}

static void Sprites(const int *a) {
  RankText *text = &work.text[0];
  P_TAG *node;
  int count = 0;
  GV_Clock = a[0];
  text->num = a[1];
  text->unk[1] = a[2];
  text->unk[2] = a[3];
  text->unk[3] = a[4];
  text->unk[4] = a[5];
  text->unk[6] = a[8];
  text->unk[7] = a[6];
  text->unk[8] = a[7];
  termPrim(&ot);
  rank_800D4F70(&work, &ot);
  Value(1, 0);
  for (node = nextPrim(&ot); node != (void *)0xffffff; node = nextPrim(node)) {
    assert(++count <= 6);
    if (node == (P_TAG *)&work.draw_mode)
      Value(3, 10, getlen(node), (int)work.draw_mode.code[0]);
    else {
      SPRT *p = (SPRT *)node;
      int index = (int)(p - text->sprt);
      assert(index >= 0 && index < 10);
      Value(13, index, getlen(p), p->r0, p->g0, p->b0, p->code, p->x0, p->y0,
            p->u0, p->v0, p->clut, p->w, p->h);
    }
  }
  values[0] = count;
}

static void Font(const Fixture *fixture) {
  const int *a = fixture->input + 1;
  RankText *text = &work.text[0];
  if (fixture->input[0] == 4) {
    work.font_x = a[0];
    work.clut_x = a[1];
    work.font_y = a[2];
    work.clut_y = a[3];
    rank_800D4CB8(&work, 0);
    Value(8, work.font_x, work.clut_x, work.font_y, work.clut_y, text->unk[5],
          text->unk[6], text->unk[7], text->unk[8]);
  } else if (fixture->input[0] == 5) {
    text->string = a[0] ? (char *)buffer : NULL;
    work.kcb[0].max_width = a[1];
    work.kcb[0].max_height = a[2];
    rank_800D4E2C(&work, 0);
    Value(6, text->string != NULL, text->num, text->unk[1], text->unk[2],
          text->unk[3], text->unk[4]);
  } else
    rank_800D51EC(&work, 0, a[0]);
}

int main(void) {
  int failures = 0;
  for (size_t i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); i++) {
    const Fixture *fixture = &fixtures[i];
    uint32_t hash = 2166136261u;
    memset(&work, 0, sizeof(work));
    memset(&packet, 0, sizeof(packet));
    value_count = trace_count = 0;
    if (fixture->input[0] <= 2)
      Geometry(fixture);
    else if (fixture->input[0] == 3)
      Sprites(fixture->input + 1);
    else
      Font(fixture);
    for (int j = 0; j < trace_count; j++)
      Value(1, trace[j]);
    for (int j = 0; j < value_count; j++)
      for (int k = 0; k < 4; k++)
        hash = (hash ^ (((uint32_t)values[j] >> (8 * k)) & 255)) * 16777619u;
    if (value_count != fixture->count || hash != fixture->hash) {
      fprintf(stderr, "graphics case%zu kind%d count%d/%d hash%u/%u\n", i,
              fixture->input[0], value_count, fixture->count, hash,
              fixture->hash);
      ++failures;
    }
  }
  if (failures) return 1;
  printf("Rank graphics: %zu original-MIPS packet/font cases passed\n",
         sizeof(fixtures) / sizeof(fixtures[0]));
  return 0;
}
