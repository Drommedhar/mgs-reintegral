#include "mgs_native.h"
#include "../vendor/mgs/source/overlays/camera/unknown/camera_native.h"
#include "fixtures/mgs_camera_photo_fixtures.h"
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>

unsigned char *camera_dword_800D0700, *camera_dword_800D0704;
const char camera_dword_800D03D0[] = "\x82\x6c\x82\x66\x82\x72";
const char camera_dword_800D011C[] = "\x81\x40";
const char camera_dword_800D03D8[] = "\x8e\xca\x90\x5e\x82\x6d\x82\x8f\x81\x44";
static int decoded_blocks, uploaded_blocks, built_photo, built_ghost;

static uint32_t HashBytes(uint32_t value, const void *data, size_t size)
{
    const unsigned char *bytes = data;
    size_t i;
    for (i = 0; i < size; ++i)
        value = (value ^ bytes[i]) * 16777619u;
    return value;
}

int mgs_fprintf(int channel, const char *format, ...)
{
    va_list args;
    int length;
    (void)channel;
    va_start(args, format);
    length = vfprintf(stderr, format, args);
    va_end(args);
    return length;
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

void DecDCTReset(int mode)
{
    assert(mode == 0);
    decoded_blocks = uploaded_blocks = built_photo = built_ghost = 0;
}

void DecDCTin(u_long *runlevel, int mode)
{
    assert(mode == 0 && runlevel[0] == 0x38000002u);
}

void DecDCTout(u_long *cell, int size)
{
    assert(size == 128);
    memset(cell, 0x5a, 512);
    ++decoded_blocks;
}

int DecDCToutSync(int mode) { assert(mode == 0); return 0; }

int LoadImage(RECT *rectangle, u_long *cell)
{
    assert(rectangle->w == 16 && rectangle->h == 16);
    assert(rectangle->x == 16 * (uploaded_blocks / 11));
    assert(rectangle->y == 256 + 16 * (uploaded_blocks % 11));
    assert(cell[0] == 0x5a5a5a5au && cell[127] == 0x5a5a5a5au);
    assert(decoded_blocks == uploaded_blocks + 1);
    ++uploaded_blocks;
    return 0;
}

void camera_800C3D3C(CameraWork *work) { (void)work; ++built_photo; }
void camera_800C4350(CameraWork *work) { assert(work->field_4934); ++built_ghost; }

#include "../vendor/mgs/source/overlays/camera/unknown/camera_photo.c"

static void CheckUnpack(void)
{
    unsigned short output[132];
    size_t i;
    for (i = 0; i < sizeof(CameraUnpackFixtures) / sizeof(CameraUnpackFixtures[0]); ++i)
    {
        const CameraUnpackFixture *fixture = &CameraUnpackFixtures[i];
        memset(output, 0, sizeof(output));
        assert(CameraUnpackPhoto(fixture->data, fixture->bytes, output, 132) == fixture->words);
        assert(HashBytes(2166136261u, output, fixture->words * 2) == fixture->hash);
        assert(!CameraUnpackPhoto(fixture->data, fixture->bytes - 1, output, 132));
        assert(!CameraUnpackPhoto(fixture->data, fixture->bytes, output, fixture->words - 1));
    }
    assert(!CameraUnpackPhoto(NULL, 0, output, 132));
    assert(!CameraUnpackPhoto((const unsigned char *)"\0\0\0\0", 4, output, 132));
}

static void CheckPhoto(void)
{
    size_t i;
    unsigned char photo[0x4000] = {0};
    for (i = 0; i < sizeof(CameraPhotoFixtures) / sizeof(CameraPhotoFixtures[0]); ++i)
    {
        CameraWork work = {0};
        uint32_t hash;
        memcpy(photo, CameraPhotoFixtures[i].data, 260);
        memcpy(photo + 260, "\0\2\4\0\17\17", 6);
        memcpy(work.photo_name, "________________", 16);
        camera_dword_800D0700 = photo;
        camera_800C4394(&work);
        hash = HashBytes(2166136261u, &work.field_4934, 180);
        if (hash != CameraPhotoFixtures[i].hash)
            printf("Photo %u: %08x/%08x\n", (unsigned int)i, hash, CameraPhotoFixtures[i].hash);
        assert(hash == CameraPhotoFixtures[i].hash);
        assert(camera_dword_800D0700 == photo + 260);
        assert(uploaded_blocks == 198 && built_photo == 1);
        assert(built_ghost == !!work.field_4934);
    }
}

static void CheckWrite(void)
{
    size_t i, byte;
    unsigned char photo[260];
    for (i = 0; i < sizeof(CameraWriteFixtures) / sizeof(CameraWriteFixtures[0]); ++i)
    {
        const CameraWriteFixture *fixture = &CameraWriteFixtures[i];
        CameraWork work = {0};
        uint32_t hash;
        for (byte = 0; byte < sizeof(photo); ++byte)
            photo[byte] = byte * 19 + fixture->seed;
        work.photo_number = fixture->input[0];
        work.name_length = fixture->input[1];
        work.field_4934 = fixture->input[2];
        memcpy(work.adjustment, fixture->input + 3, sizeof(work.adjustment));
        memcpy(work.photo_name, fixture->name, 16);
        camera_dword_800D0704 = photo;
        camera_800CD790(&work);
        hash = HashBytes(2166136261u, photo, fixture->title_end + 1);
        hash = HashBytes(hash, photo + 68, sizeof(photo) - 68);
        if (hash != fixture->hash)
            printf("Photo write %u: %08x/%08x\n", (unsigned int)i, hash, fixture->hash);
        assert(hash == fixture->hash);
        for (byte = fixture->title_end + 1; byte < 68; ++byte)
            assert(photo[byte] == 0);
    }
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    CheckUnpack();
    CheckPhoto();
    CheckWrite();
    puts("Camera photo: 1536 original MIPS fixtures and malformed-input checks passed");
    return 0;
}
