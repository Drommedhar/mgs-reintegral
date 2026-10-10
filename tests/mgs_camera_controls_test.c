#include "mgs_native.h"
#include "../vendor/mgs/source/overlays/camera/unknown/camera_native.h"
#include "fixtures/mgs_camera_controls_fixtures.h"
#include "fixtures/mgs_camera_color_fixtures.h"
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>

static uint32_t trace_hash;

static uint32_t HashBytes(uint32_t value, const void *data, size_t size)
{
    const unsigned char *bytes = data;
    size_t i;
    for (i = 0; i < size; ++i)
        value = (value ^ bytes[i]) * 16777619u;
    return value;
}

void GM_SeSet2(int x, int volume, int sound)
{
    int values[4] = {1, x, volume, sound};
    trace_hash = HashBytes(trace_hash, values, sizeof(values));
}

void camera_800C884C(CameraWork *work, int x, int y, int w, int h, int color, int unused)
{
    int values[7] = {2, x, y, w, h, color, unused};
    (void)work;
    trace_hash = HashBytes(trace_hash, values, sizeof(values));
}

void camera_800C869C(CameraWork *work)
{
    int tag = 3;
    (void)work;
    trace_hash = HashBytes(trace_hash, &tag, sizeof(tag));
}

#include "../vendor/mgs/source/overlays/camera/unknown/camera_controls.c"

static void CheckKeyboard(const CameraKeyboardFixture *fixture, size_t index)
{
    CameraWork work = {0};
    GV_PAD pad = {0};
    uint32_t after;
    pad.status = fixture->status;
    pad.press = fixture->press;
    work.pad = &pad;
    work.field_4940 = fixture->key;
    work.field_49C0 = fixture->count;
    work.field_49C4 = fixture->direction;
    work.name_cursor = fixture->cursor;
    work.name_length = fixture->length;
    work.field_4934 = fixture->ghost;
    work.field_4938 = fixture->frame;
    work.field_493C = fixture->phase;
    memcpy(work.photo_name, "ORIGINAL PHOTO 01", 16);
    memcpy(work.original_name, "EDITED ALBUM 0123", 16);
    trace_hash = 2166136261u;
    camera_800C8AD4(&work);
    after = HashBytes(2166136261u, &work.field_4934, 180);
    if (after != fixture->after || trace_hash != fixture->calls)
        printf("Camera keyboard fixture %u: state %08x/%08x, calls %08x/%08x\n",
               (unsigned int)index, after, fixture->after, trace_hash, fixture->calls);
    assert(after == fixture->after);
    assert(trace_hash == fixture->calls);
}

static void CheckColor(const CameraColorFixture *fixture, size_t index)
{
    CameraWork work = {0};
    GV_PAD pad = {0};
    const int *input = fixture->input;
    uint32_t after;
    work.pad = &pad;
    work.field_4948 = input[0];
    pad.status = input[1];
    pad.press = input[2];
    work.field_4934 = input[3];
    work.field_4938 = input[4];
    work.field_4944 = input[5];
    memcpy(work.adjustment, input + 6, sizeof(work.adjustment));
    work.field_4974 = input[9];
    work.field_4978 = input[10];
    work.field_497C = input[11];
    memcpy(work.color, input + 12, sizeof(work.color));
    trace_hash = 2166136261u;
    camera_800CB024(&work);
    after = HashBytes(2166136261u, &work.field_4934, 180);
    if (after != fixture->after || trace_hash != fixture->calls)
        printf("Camera color fixture %u: state %08x/%08x, calls %08x/%08x\n",
               (unsigned int)index, after, fixture->after, trace_hash, fixture->calls);
    assert(after == fixture->after);
    assert(trace_hash == fixture->calls);
}

int main(void)
{
    size_t i;
    setvbuf(stdout, NULL, _IONBF, 0);
    for (i = 0; i < sizeof(CameraKeyboardFixtures) / sizeof(CameraKeyboardFixtures[0]); ++i)
        CheckKeyboard(&CameraKeyboardFixtures[i], i);
    printf("Camera keyboard: %u original MIPS fixtures passed\n", (unsigned int)i);
    for (i = 0; i < sizeof(CameraColorFixtures) / sizeof(CameraColorFixtures[0]); ++i)
        CheckColor(&CameraColorFixtures[i], i);
    printf("Camera color: %u original MIPS fixtures passed\n", (unsigned int)i);
    return 0;
}
