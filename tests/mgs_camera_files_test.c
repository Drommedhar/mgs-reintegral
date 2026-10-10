#include "mgs_native.h"
#include "../vendor/mgs/source/overlays/camera/unknown/camera_native.h"
#include "fixtures/mgs_camera_files_fixtures.h"
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>

int GV_Clock, GV_Time, camera_dword_800C3880;
DATA_INFO *camera_dword_800D072C;
MEMCARD *camera_dword_800D0748[2];
SELECT_INFO *camera_dword_800D0754;
Menu_Triangle camera_dword_800C38A4, camera_dword_800C38B4;
static uint32_t trace_hash;
static void *packets[32];
static size_t packet_count;

static uint32_t HashBytes(uint32_t value, const void *data, size_t size)
{
    const unsigned char *bytes = data;
    size_t i;
    for (i = 0; i < size; ++i)
        value = (value ^ bytes[i]) * 16777619u;
    return value;
}

static void Record(int value) { trace_hash = HashBytes(trace_hash, &value, sizeof(value)); }

void *CameraAlbumPacket(MenuPrim *prim, size_t size)
{
    void *result = prim->next;
    assert(size <= (size_t)(prim->end - prim->next));
    assert(packet_count < sizeof(packets) / sizeof(packets[0]));
    prim->next += size;
    packets[packet_count++] = result;
    return result;
}

void CameraFormat(char *output, size_t capacity, const char *format, ...)
{
    va_list args;
    int length;
    va_start(args, format);
    length = vsnprintf(output, capacity, format, args);
    va_end(args);
    assert(length >= 0 && (size_t)length < capacity);
}

static void RecordText(int tag, TextConfig *text, const char *string)
{
    size_t i, length = strlen(string);
    Record(tag);
    Record(text->xpos);
    Record(text->ypos);
    Record(text->flags);
    Record(text->color);
    Record((int)length);
    for (i = 0; i < length; ++i)
        Record((unsigned char)string[i]);
}

void _menu_number_draw_string(MenuPrim *prim, TextConfig *text, const char *string)
{
    (void)prim;
    RecordText(1, text, string);
}

void _menu_number_draw_string2(MenuPrim *prim, TextConfig *text, const char *string)
{
    (void)prim;
    RecordText(2, text, string);
}

void camera_800C5B00(int x, int y, int w, int h, int divisor)
{
    Record(3); Record(x); Record(y); Record(w); Record(h); Record(divisor);
}

void menu_draw_triangle(MenuPrim *prim, Menu_Triangle *triangle)
{
    (void)prim;
    assert(triangle == &camera_dword_800C38A4 || triangle == &camera_dword_800C38B4);
    Record(4);
    Record(triangle == &camera_dword_800C38A4 ? 0 : 1);
}

void camera_800C5D2C(SPRT *sprite)
{
    LSTORE(0x80808080, &sprite->r0);
    setSprt(sprite);
    setClut(sprite, 960, 510);
}

#include "../vendor/mgs/source/overlays/camera/unknown/camera_files.c"

static void CheckFiles(const CameraFilesFixture *fixture, size_t index)
{
    struct { SELECT_INFO info; MENU_CURPOS entries[17]; } selection = {0};
    MenuWork work = {0};
    MenuPrim prim = {0};
    SELECT_INFO ports = {0};
    MEMCARD card = {0};
    DATA_INFO data = {0};
    u_long buffer[2048] = {0}, ot[2] = {0};
    const int *input = fixture->input;
    uint32_t after = 2166136261u;
    size_t i;
    selection.info.max_num = input[0];
    selection.info.top = input[1];
    selection.info.current = input[2];
    selection.info.open_count = input[3];
    selection.info.field_18 = input[4];
    selection.info.enable = input[5];
    selection.info.height = input[6];
    GV_Clock = input[7];
    GV_Time = input[8];
    camera_dword_800C3880 = input[9];
    ports.max_num = input[10];
    card.free_blocks = input[11];
    data.blocks_count = input[12];
    for (i = 0; i < 17; ++i)
    {
        memcpy(selection.entries[i].mes, "C1234H", 6);
        if ((i + input[13]) % 3 == 0)
            selection.entries[i].mes[0] = 'G';
        selection.entries[i].num = (i + input[13]) % 4 == 0 ? 16 : (int)i;
    }
    camera_dword_800D072C = &data;
    camera_dword_800D0754 = &ports;
    camera_dword_800D0748[input[9]] = &card;
    prim.next = (unsigned char *)buffer;
    prim.end = (unsigned char *)(buffer + 2048);
    prim.ot = ot;
    work.prim = &prim;
    packet_count = 0;
    trace_hash = 2166136261u;
    camera_800C6110(&work, ot, &selection.info);
    assert(packet_count == (size_t)fixture->packets);
    for (i = 0; i < packet_count; ++i)
    {
        u_long *packet = packets[i];
        assert(packet[1] > 0 && packet[1] <= 9);
        after = HashBytes(after, packet + 1, 4);
        after = HashBytes(after, packet + 2, packet[1] * 4);
    }
    after = HashBytes(after, &selection.info.open_count, 4);
    if (after != fixture->after || trace_hash != fixture->calls)
        printf("Camera files %u: state %08x/%08x, calls %08x/%08x\n",
               (unsigned int)index, after, fixture->after, trace_hash, fixture->calls);
    assert(after == fixture->after);
    assert(trace_hash == fixture->calls);
}

int main(void)
{
    size_t i;
    setvbuf(stdout, NULL, _IONBF, 0);
    for (i = 0; i < sizeof(CameraFilesFixtures) / sizeof(CameraFilesFixtures[0]); ++i)
        CheckFiles(&CameraFilesFixtures[i], i);
    printf("Camera card list: %u original MIPS packet/state fixtures passed\n", (unsigned int)i);
    return 0;
}
