#include "mgs_native.h"
#include "../vendor/mgs/source/overlays/camera/unknown/camera_native.h"
#include "fixtures/mgs_camera_animation_fixtures.h"
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>

static uint32_t trace_hash;
int GV_Time;
Menu_Triangle camera_dword_800C341C;

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

void camera_800C884C(CameraWork *work, int x, int y, int w, int h, int color, int unused)
{
    (void)work;
    Record(2, 6, x, y, w, h, color, unused);
}

void camera_800C86BC(CameraWork *work, int x, int y, int w, int h, int color, int unused)
{
    (void)work;
    Record(4, 6, x, y, w, h, color, unused);
}

void camera_800C8554(int *caption, int x, int y, int flags)
{
    (void)caption;
    Record(5, 3, x, y, flags);
}

void camera_800C85B8(int *caption, int r, int g, int b)
{
    (void)caption;
    Record(6, 3, r, g, b);
}

void camera_800C8564(MenuPrim *prim, SELECT_INFO *caption, char *text)
{
    (void)prim;
    (void)caption;
    assert(memcmp(text, "EDITED ALBUM 0123", 16) == 0);
    Record(7, 0);
}

void MENU_Locate(int x, int y, int flags) { Record(8, 3, x, y, flags); }
void MENU_Color(int r, int g, int b) { Record(9, 3, r, g, b); }

int MENU_Printf(const char *format, ...)
{
    va_list args;
    if (!strcmp(format, "-"))
        Record(10, 1, 1);
    else if (!strcmp(format, "+"))
        Record(10, 1, 2);
    else
    {
        assert(!strcmp(format, "%3d"));
        va_start(args, format);
        Record(10, 2, 3, va_arg(args, int));
        va_end(args);
    }
    return 0;
}

void camera_800C8AD4(CameraWork *work) { (void)work; Record(11, 0); }
void camera_800CB024(CameraWork *work) { (void)work; Record(12, 0); }
void CameraDrawPhotoName(CameraWork *work) { (void)work; }
void camera_800CBCC8(CameraWork *work) { (void)work; Record(14, 0); }
void camera_800C89DC(CameraWork *work) { (void)work; Record(15, 0); }
void menu_draw_triangle(MenuPrim *prim, Menu_Triangle *triangle)
{
    (void)prim;
    assert(triangle == &camera_dword_800C341C);
    Record(16, 0);
}

#include "../vendor/mgs/source/overlays/camera/unknown/camera_animation.c"

static uint32_t HashActor(CameraWork *work)
{
    uint32_t value = 2166136261u;
    size_t i;
    for (i = 0; i < 4; ++i)
        value = HashBytes(value, &work->polys_lr[i].r0, 36);
    for (i = 0; i < 9; ++i)
        value = HashBytes(value, &work->polys[i].r0, 36);
    for (i = 0; i < 26; ++i)
        value = HashBytes(value, &work->polys2[i].r0, 36);
    value = HashBytes(value, work->field_654, sizeof(work->field_654));
    value = HashBytes(value, work->field_664, sizeof(work->field_664));
    value = HashBytes(value, work->field_688, sizeof(work->field_688));
    value = HashBytes(value, &work->f28, 8);
    return HashBytes(value, &work->field_4934, 180);
}

static void InitPackets(POLY_FT4 *packets, int *depth, int first, int count)
{
    int i, byte;
    for (i = 0; i < count; ++i)
    {
        unsigned char *body = &packets[i].r0;
        for (byte = 0; byte < 36; ++byte)
            body[byte] = (first + i) * 13 + byte * 7;
        depth[i] = (first + i) * 31 - 500;
    }
}

static void CheckAnimation(const CameraAnimationFixture *fixture, size_t index)
{
    CameraWork work = {0};
    GV_PAD pad = {0};
    const int *input = fixture->input;
    uint32_t after;
    InitPackets(work.polys_lr, work.field_654, 0, 4);
    InitPackets(work.polys, work.field_664, 4, 9);
    InitPackets(work.polys2, work.field_688, 13, 26);
    work.f28 = 41;
    work.f2C = 42;
    work.pad = &pad;
    work.field_4934 = input[3];
    work.field_4938 = input[2];
    if (input[0] == 0)
        work.field_493C = input[1];
    else if (input[0] == 3)
    {
        work.field_49B8 = input[1];
        pad.status = pad.press = input[3];
        GV_Time = input[4];
    }
    else
        work.field_4944 = input[1];
    work.name_cursor = input[4];
    memcpy(work.adjustment, input + 5, sizeof(work.adjustment));
    memcpy(work.original_name, "EDITED ALBUM 0123", 16);
    trace_hash = 2166136261u;
    if (input[0] == 0)
        camera_800CA918(&work);
    else if (input[0] == 1)
        camera_800CC3C8(&work);
    else if (input[0] == 2)
        camera_800CB8AC(&work);
    else
        camera_800CBDE4(&work);
    after = HashActor(&work);
    if (after != fixture->after || trace_hash != fixture->calls)
        printf("Camera animation fixture %u: state %08x/%08x, calls %08x/%08x\n",
               (unsigned int)index, after, fixture->after, trace_hash, fixture->calls);
    assert(after == fixture->after);
    assert(trace_hash == fixture->calls);
}

int main(void)
{
    size_t i;
    setvbuf(stdout, NULL, _IONBF, 0);
    for (i = 0; i < sizeof(CameraAnimationFixtures) / sizeof(CameraAnimationFixtures[0]); ++i)
        CheckAnimation(&CameraAnimationFixtures[i], i);
    printf("Camera animation: %u original MIPS fixtures passed\n", (unsigned int)i);
    return 0;
}
