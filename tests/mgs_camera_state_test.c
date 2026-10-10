#include "mgs_native.h"
#include "../vendor/mgs/source/overlays/camera/unknown/camera_native.h"
#include "fixtures/mgs_camera_state_fixtures.h"
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>

GV_PAD GV_PadData[4];
DG_CHANL DG_Chanls[3];
int GV_Clock;
unsigned char *camera_dword_800D0704;
int camera_dword_800D0708;
char camera_dword_800D0710[24];
const char *camera_dword_800C3914[5] = {
    "SAVE", "ERROR", "DONE", "NO CARD", "FAILED"
};
static MEMCARD card;
static uint32_t trace_hash;
static int card_result, busy_count, card_return;

int mgs_fprintf(int channel, const char *format, ...)
{
    va_list args;
    int result;
    assert(channel == 2);
    va_start(args, format);
    result = vprintf(format, args);
    va_end(args);
    return result;
}

static uint32_t HashBytes(uint32_t value, const void *data, size_t size)
{
    const unsigned char *bytes = data;
    size_t i;
    for (i = 0; i < size; ++i)
        value = (value ^ bytes[i]) * 16777619u;
    return value;
}

static void Record(int tag, int count, ...)
{
    va_list args;
    int i, value = tag;
    va_start(args, count);
    for (i = 0; i <= count; ++i)
    {
        trace_hash = HashBytes(trace_hash, &value, sizeof(value));
        if (i != count)
            value = va_arg(args, int);
    }
    va_end(args);
}

static void RecordText(int tag, const char *text)
{
    size_t i, length = strlen(text);
    Record(tag, 1, (int)length);
    for (i = 0; i < length; ++i)
    {
        int value = (unsigned char)text[i];
        trace_hash = HashBytes(trace_hash, &value, sizeof(value));
    }
}

void GM_SeSet2(int pan, int volume, int sound) { Record(1, 3, pan, volume, sound); }
void camera_800C869C(CameraWork *work) { (void)work; Record(3, 0); }
void camera_800C86BC(CameraWork *work, int x, int y, int w, int h, int color, int unused)
{
    (void)work;
    Record(4, 6, x, y, w, h, color, unused);
}
void camera_800C864C(CameraWork *work) { (void)work; Record(5, 0); }
void GV_FreeMemory(int region, void *memory)
{
    assert(memory == camera_dword_800D0704);
    Record(6, 1, region);
}
void camera_800C82EC(void) { Record(7, 0); }
void MENU_Locate(int x, int y, int flags) { Record(8, 3, x, y, flags); }
void MENU_Color(int r, int g, int b) { Record(9, 3, r, g, b); }
int MENU_Printf(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    RecordText(10, !strcmp(format, "%s") ? va_arg(args, const char *) : format);
    va_end(args);
    return 0;
}
void camera_800CD0A0(MenuPrim *prim, int x, int y, int w, int h)
{
    (void)prim;
    Record(11, 4, x, y, w, h);
}
void camera_800C6054(MenuWork *work, u_long *ot, SELECT_INFO *info)
{
    (void)work; (void)ot; (void)info;
    Record(12, 0);
}
void drawCaption_800C5EB4(MenuWork *work, const char *caption)
{
    (void)work;
    RecordText(13, caption);
}
void camera_800CDAB4(CameraWork *work) { (void)work; Record(14, 0); }
void camera_800CD790(CameraWork *work) { (void)work; Record(15, 0); }
int memcard_delete(int port, const char *filename)
{
    assert(filename == camera_dword_800D0710);
    Record(16, 1, port);
    return card_result;
}
MEMCARD *memcard_files(int port) { Record(17, 1, port); return &card; }
void memcard_write(int port, const char *filename, int offset, char *buffer, int size)
{
    assert(filename == camera_dword_800D0710 && buffer == (char *)camera_dword_800D0704);
    assert(size == 0x4000);
    Record(18, 2, port, offset);
}
int memcard_status(void)
{
    int result = busy_count > 0 ? 1 : card_result;
    --busy_count;
    Record(19, 1, result);
    return result;
}
int mts_wait_vbl(long count) { Record(20, 1, count); return 0; }
int camera_800C73E4(MenuWork *work, GV_PAD *pad)
{
    (void)work;
    assert(pad == &GV_PadData[2]);
    Record(21, 0);
    return card_return;
}
void camera_800C4394(CameraWork *work) { (void)work; Record(22, 0); }
int GCL_ExecProc(int id, GCL_ARGS *args)
{
    assert(args == NULL);
    Record(23, 1, id);
    return 0;
}
void GV_DestroyActor(void *actor) { (void)actor; Record(24, 0); }
void camera_800CA918(CameraWork *work) { (void)work; Record(25, 0); }
void camera_800CC3C8(CameraWork *work) { (void)work; Record(26, 0); }
void camera_800CBDE4(CameraWork *work) { (void)work; Record(27, 0); }
void camera_800C8554(int *caption, int x, int y, int flags)
{
    (void)caption;
    Record(28, 3, x, y, flags);
}
void camera_800C85B8(int *caption, int r, int g, int b)
{
    (void)caption;
    Record(29, 3, r, g, b);
}
void camera_800C8564(MenuPrim *prim, SELECT_INFO *caption, char *text)
{
    (void)prim; (void)caption;
    RecordText(30, text);
}

#include "../vendor/mgs/source/overlays/camera/unknown/camera_state.c"

void camera_800C3ED8(CameraWork *work) { assert(work->prims.next > work->prims.buf[GV_Clock]); }

#include "camera_state_helpers.inc"

static void InitializeWork(CameraWork *work, GV_PAD *pad, const int *input)
{
    int i, j;
    POLY_FT4 *packet = work->polys_lr;
    memset(work, 0, sizeof(*work));
    work->f20 = 0x1234; work->pad = pad;
    work->f28 = input[1]; work->f2C = input[2];
    for (i = 0; i < 39; ++i)
        for (j = 0; j < 36; ++j)
            ((unsigned char *)&packet[i].r0)[j] = (unsigned char)(i * 13 + j * 7);
    for (i = 0; i < 39; ++i)
        work->field_654[i] = i * 31 - 500;
    work->field_4934 = input[6]; work->field_4938 = input[4];
    work->field_498C = work->field_49C8 = input[3];
    work->adjustment[0] = -83; work->adjustment[1] = 17; work->adjustment[2] = 91;
    work->f49E0 = input[5]; work->f49E4 = "CAPTION";
    work->field_49CC = &card; work->field_49D0 = input[11];
    memcpy(work->photo_name, "ORIGINAL PHOTO 1", 17);
    memcpy(work->original_name, "EDITED ALBUM 0123", 17);
    memcpy(work->title, "TITLE", 6); memcpy(work->separator, "-", 2);
    work->field_700.prim = &work->prims;
    pad->press = pad->status = (unsigned short)input[7];
}

static uint32_t StateHash(CameraWork *work)
{
    unsigned char tail[180];
    uint32_t value = 2166136261u, address;
    int i;
    POLY_FT4 *packet = work->polys_lr;
    for (i = 0; i < 39; ++i)
        value = HashBytes(value, &packet[i].r0, 36);
    value = HashBytes(value, work->field_654, 156);
    value = HashBytes(value, &work->f28, 8);
    memcpy(tail, &work->field_4934, sizeof(tail));
    assert(work->field_49CC == &card && !strcmp(work->f49E4, "CAPTION"));
    address = 0x80171000u; memcpy(tail + 0x98, &address, 4);
    address = 0x80173000u; memcpy(tail + 0xb0, &address, 4);
    return HashBytes(value, tail, sizeof(tail));
}

static void CheckFixture(const CameraStateFixture *fixture, size_t index)
{
    CameraWork work;
    GV_PAD pad = {0};
    OT_TYPE ot;
    uint32_t after;
    unsigned char buffer[0x2000];
    const int *input = fixture->input;
    InitializeWork(&work, &pad, input);
    setaddr(&ot, 0xffffff); setlen(&ot, 0);
    work.prims.next = buffer; work.prims.end = buffer + sizeof(buffer);
    work.prims.ot = (u_long *)&ot;
    card.port = 1; camera_dword_800D0708 = 1;
    card_result = input[8]; busy_count = input[9]; card_return = input[10];
    trace_hash = 2166136261u;
    switch (input[0])
    {
    case 0: camera_800CCBB0(&work); break;
    case 1: camera_800CD198(&work); break;
    case 2: camera_800CDCA4(&work); break;
    case 3: camera_800CDF18(&work); break;
    }
    after = StateHash(&work);
    if (after != fixture->after || trace_hash != fixture->calls)
        printf("Camera state %u: state %08x/%08x, calls %08x/%08x\n",
               (unsigned int)index, after, fixture->after, trace_hash, fixture->calls);
    assert(after == fixture->after && trace_hash == fixture->calls);
}

static void CheckFontPage(void)
{
    unsigned char buffer[64];
    OT_TYPE ot;
    SPRT sprite;
    CameraWork work = {0};
    DR_TPAGE *page;
    work.f28 = 2;
    work.prims.buf[0] = buffer;
    DG_Chanls[2].ot[0] = &ot;
    setaddr(&ot, 0xffffff); setlen(&ot, 0);
    setSprt(&sprite); addPrim(&ot, &sprite);
    CameraAct_800CE404(&work);
    page = (DR_TPAGE *)getaddr(&ot);
    assert(page == (DR_TPAGE *)buffer && getlen(page) == 1);
    assert(page->code[0] == 0xe100021fu);
    assert(getaddr(page) == (uintptr_t)&sprite);
    assert(work.field_4938 == 1);
}

int main(void)
{
    size_t i;
    setvbuf(stdout, NULL, _IONBF, 0);
    for (i = 0; i < sizeof(CameraStateFixtures) / sizeof(CameraStateFixtures[0]); ++i)
        CheckFixture(&CameraStateFixtures[i], i);
    CheckFontPage();
    printf("Camera state: %u original MIPS fixtures and font-page ordering passed\n", (unsigned int)i);
    return 0;
}
