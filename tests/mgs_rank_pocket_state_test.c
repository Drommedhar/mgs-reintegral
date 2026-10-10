#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/rank/menu/pocket_state.c"
#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef struct Fixture {
  int input[12], output[16], trace_count;
  uint32_t hash;
} Fixture;
#include "mgs_rank_pocket_state_fixtures.h"
int PocketMenuState, PocketMessageTime, PocketRequest, PocketResponse,
    PocketPortMask, PocketPortState[4], PocketTransferProgress;
SELECT_INFO *PocketCurrentSelect, *PocketConfirmSelect, *PocketPortSelect,
    *PocketFileSelect;
RadioFileModeStruElem *PocketUi;
const char *PocketDownloadMessages[14], *PocketUploadMessages[14],
    *PocketMenuLabels[5];
char *PocketConfirmMessages[2], *PocketYesNo[2];
static Work work;
static GV_PAD pad;
static SELECT_INFO selections[4];
static SELECT_INFO *pointers[] = {NULL, &selections[0], &selections[1],
                                  &selections[2], &selections[3]};
static RadioFileModeStru_800ABB7C ui;
static OT_TYPE ot;
static unsigned char packets[64];
static char messages[30][32];
static const Fixture *fixture;
static int trace_count;
static uint32_t trace_hash;
static int PointerId(SELECT_INFO *value) {
  for (int i = 0; i < 5; i++)
    if (pointers[i] == value)
      return i;
  abort();
}
static void Trace(int count, ...) {
  va_list args;
  va_start(args, count);
  trace_count += count;
  while (count-- > 0) {
    uint32_t v = va_arg(args, int);
    for (int i = 0; i < 4; i++)
      trace_hash = (trace_hash ^ ((v >> (8 * i)) & 255)) * 16777619u;
  }
  va_end(args);
}
static int MessageId(const char *text) {
  return (int)((text - (char *)messages) / 32);
}
void sub_80048124(void) { Trace(1, 1); }
void font_set_color(KCB *font, int code, int color, int background) {
  assert(font == &work.kcb);
  Trace(4, 2, code, color, background);
}
void font_clut_update(KCB *font) {
  assert(font == &work.kcb);
  Trace(1, 3);
}
void GM_SeSet2(int channel, int volume, int sound) {
  Trace(4, 4, channel, volume, sound);
}
void mts_wup_tsk(int task) { Trace(2, 5, task); }
void rank_800CD568(int a, int b, int c, int d, int e) {
  Trace(6, 6, a, b, c, d, e);
}
void rank_800CD8F0(int a, int b, int c, int d, int e) {
  Trace(6, 7, a, b, c, d, e);
}
void rank_800CDC70(SELECT_INFO *info) { Trace(2, 8, PointerId(info)); }
void rank_800CDC98(SELECT_INFO **info, int count) {
  int which = info == &PocketPortSelect ? 2 : 3;
  Trace(3, 9, which, count);
  *info = pointers[which];
}
int rank_800CDCF4(Work *actor, const char *message, SELECT_INFO *info) {
  assert(actor == &work && strcmp(message, "SELECT MEMORY CARD") == 0);
  Trace(2, 10, PointerId(info));
  return 1;
}
void rank_800CD688(int a, int b, int c, int d, SELECT_INFO *info) {
  Trace(6, 11, a, b, c, d, PointerId(info));
}
void rank_800CD760(int a, int b, int c, int d, int e, int f) {
  Trace(7, 12, a, b, c, d, e, f);
}
void rank_800CD8D8(int index) { Trace(2, 13, index); }
void rank_800CDB44(Work *actor, char *message) {
  assert(actor == &work);
  Trace(2, 14, MessageId(message));
}
void rank_800CDEB8(Work *actor, char **text, int count, int initial,
                   char *message, SELECT_INFO *info) {
  assert(actor == &work && text == PocketYesNo);
  Trace(5, 15, count, initial, MessageId(message), PointerId(info));
}
int rank_800CE148(GV_PAD *input, int *result, SELECT_INFO *info) {
  assert(input == &pad);
  Trace(2, 16, PointerId(info));
  *result = fixture->input[4];
  return fixture->input[5];
}
void rank_800CDFC8(MenuPrim *prim, SELECT_INFO *info) {
  assert(prim == work.prim_ptr);
  Trace(2, 17, PointerId(info));
}
void rank_800CE260(MenuPrim *prim, OT_TYPE *table) {
  assert(prim == work.prim_ptr && table == &ot);
  Trace(1, 18);
}
void rank_800CDBB0(Work *actor, OT_TYPE *table) {
  assert(actor == &work && table == &ot);
  Trace(1, 19);
}
void rank_800CDA44(void *prim) {
  DR_TPAGE *page = (DR_TPAGE *)packets;
  assert(prim == work.prim_ptr && getaddr(&ot) == (u_long)page &&
         isendprim(page));
  Trace(3, 20, getlen(page), (int)page->code[0]);
  if (fixture->input[0] == 6 && !fixture->input[2]) {
    const unsigned char *text = (unsigned char *)ui.field_c0_array[2].field_4;
    Trace(1, 21);
    do {
      Trace(1, *text);
    } while (*text++);
  }
}
void rank_800CD540(void) { Trace(1, 22); }
void _menu_number_draw_string2(MenuPrim *prim, TextConfig *config,
                               const char *text) {
  assert(prim == work.prim_ptr && strcmp(text, "PRESS * TO EXIT") == 0);
  Trace(5, 23, config->xpos, config->ypos, config->flags, (int)config->color);
}
static void Prepare(void) {
  const int *a = fixture->input;
  memset(&work, 0, sizeof(work));
  memset(&pad, 0, sizeof(pad));
  memset(packets, 0, sizeof(packets));
  work.prim_ptr = &work.prim;
  work.prim.next = packets;
  work.prim.end = packets + sizeof(packets);
  work.prim.ot = (u_long *)&ot;
  termPrim(&ot);
  pad.press = a[3];
  PocketMenuState = a[0];
  PocketRequest = a[1];
  PocketResponse = 99;
  PocketPortMask = a[6];
  PocketMessageTime = a[10];
  PocketTransferProgress = a[11];
  PocketFileSelect = a[7] ? pointers[1] : NULL;
  PocketPortSelect = a[8] ? pointers[2] : NULL;
  PocketConfirmSelect = a[9] ? pointers[3] : NULL;
  PocketCurrentSelect = pointers[4];
  PocketUi = (RadioFileModeStruElem *)&ui;
  for (int i = 0; i < 4; i++) {
    PocketPortState[i] = 5 + i;
    selections[i].enable = 1;
  }
  for (int i = 0; i < 14; i++) {
    PocketDownloadMessages[i] = messages[i];
    PocketUploadMessages[i] = messages[i + 14];
  }
  PocketConfirmMessages[0] = messages[28];
  PocketConfirmMessages[1] = messages[29];
  trace_count = 0;
  trace_hash = 2166136261u;
}
int main(void) {
  for (size_t i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); i++) {
    fixture = &fixtures[i];
    Prepare();
    int result = rank_800CE330(&work, &pad, fixture->input[2]);
    int out[] = {result,
                 PocketMenuState,
                 PocketMessageTime,
                 PocketRequest,
                 PocketResponse,
                 PocketPortMask,
                 PocketPortState[0],
                 PocketPortState[1],
                 PocketPortState[2],
                 PocketPortState[3],
                 PointerId(PocketFileSelect),
                 PointerId(PocketPortSelect),
                 PointerId(PocketConfirmSelect),
                 PointerId(PocketCurrentSelect),
                 selections[1].enable,
                 selections[2].enable};
    for (int j = 0; j < 16; j++)
      if (out[j] != fixture->output[j]) {
        fprintf(stderr, "menu case%zu state%d output%d native%d original%d\n",
                i, fixture->input[0], j, out[j], fixture->output[j]);
        return 1;
      }
    if (trace_count != fixture->trace_count || trace_hash != fixture->hash) {
      fprintf(stderr, "menu case%zu state%d request%x count%d/%d hash%u/%u\n",
              i, fixture->input[0], fixture->input[1], trace_count,
              fixture->trace_count, trace_hash, fixture->hash);
      return 1;
    }
    assert(strcmp(PocketMenuLabels[0],
                  fixture->input[2] ? "FOXDIE" : "DOWNLOAD") == 0);
    assert(strcmp(PocketMenuLabels[1], fixture->input[2] ? "CHECKING" : "") ==
           0);
    assert(strcmp(PocketMenuLabels[3],
                  fixture->input[2] ? "NO FILE" : "NO SPACE") == 0);
  }
  printf("Pocket menu: %zu original-MIPS state/effect cases passed\n",
         sizeof(fixtures) / sizeof(fixtures[0]));
  return 0;
}
