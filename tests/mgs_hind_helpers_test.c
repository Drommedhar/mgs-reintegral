#include "mgs_native.h"
#undef fprintf
#include "overlays/s11g/kojo/hind.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>

short linkvarbuf[MAX_LINKVARBUF];
SVECTOR GM_PlayerPosition;
int GV_Time;
static uint32_t random_state, boundary_trace, random_calls;

static void Trace(uint32_t value)
{
    boundary_trace = (boundary_trace * 33 + value) & 0x7fffffffu;
}

static int Random(int range, int signed_value)
{
    int result;
    assert(range > 0 && (range & (range - 1)) == 0);
    random_state = random_state * 1664525u + 1013904223u;
    result = (random_state >> 16) & (range - 1);
    if (signed_value)
        result -= range / 2;
    ++random_calls;
    Trace(signed_value ? 2 : 1);
    Trace(range);
    Trace(result);
    return result;
}

int GV_RandU(int range) { return Random(range, 0); }
int GV_RandS(int range) { return Random(range, 1); }
void s11g_hind_800D619C(HindWork *work, int index)
{
    assert(work);
    Trace(3);
    Trace(index);
}
void s11g_hind_800D5E54(int distance, SVECTOR *position, int sound)
{
    assert(position);
    Trace(4);
    Trace(distance);
    Trace(sound);
}

#include "hind_helpers.inc"

typedef struct {
    int input[2];
    uint32_t output[3];
} HindFixture;
#include "mgs_hind_fixtures.h"
#include "mgs_hind_ribbon_fixtures.h"
#include "mgs_tower_geometry_fixtures.h"
_Static_assert(sizeof(Work) == 0x3B9C, "Hind ribbon actor layout");
_Static_assert(sizeof(PutHzdWork) == 0x50, "PutHzd actor layout");
_Static_assert(sizeof(InverseLightWork) == 0xf0, "InverseLight actor layout");

static void Prepare(HindWork *work, int index)
{
    static const int states[] = {0, 4, 5, 6, 7, 8, 9, 10};
    static const int timers[] = {-1, 0, 1, 9, 10, 33};
    static const int angles[] = {-512, 0, 256, 1024, 1792, 2048, 2800, 4095, 4608};
    memset(work, 0, sizeof(*work));
    random_state = index + 1001;
    boundary_trace = random_calls = 0;
    work->field_5C4 = 2;
    work->field_5C8 = states[index % 8];
    work->field_5E4 = timers[index / 8 % 6];
    work->field_5E8 = index % 5 - 1;
    work->field_5F4 = angles[index % 9];
    work->field_5F8 = index % 2;
    work->field_430 = 900;
    work->field_434 = 80 + index * 7 % 900;
    work->control.mov = (SVECTOR){index * 19 - 2000, 12000, index * 37 % 20000 - 3000, 0};
    work->field_4BC = (VECTOR){index * 97 - 12000, 15000, index * 101 - 7000, 0};
    work->field_5FC = (VECTOR){1500 - index * 31, 22000 - index * 5, index * 83 - 9000, 0};
    work->field_60C = (VECTOR){3000 - index * 67, 18000 + index * 7, index * 89 - 2000, 0};
    work->field_65C = (SVECTOR){15, -20, 25, 0};
    work->field_664 = (SVECTOR){100, -200, 300, 0};
    GM_PlayerPosition = (SVECTOR){index * 17 - 2000, 1000, index * 23 - 3000, 0};
    GM_GameLevel = index % 5 - 1;
    GV_Time = index * 8;
}

static uint32_t HashBytes(const void *data, size_t size)
{
    const unsigned char *bytes = data;
    uint32_t hash = 2166136261u;
    for (size_t index = 0; index < size; ++index)
        hash = (hash ^ bytes[index]) * 16777619u;
    return hash;
}

static void CheckRibbon(void)
{
    for (int index = 0; index < 288; ++index)
    {
        Work work = {0};
        int group = index / 16;
        int current = index % 16;
        int previous = group * 16 + (current ? current - 1 : 15);
        SVECTOR position = {index * 5 - 1400, index * 19 - 1800, index * 23 - 2700, 51};
        work.f242C[group] = current;
        work.vertices[previous * 4] =
            (SVECTOR){index * 13 - 3000, index * 7 - 900, index * 11 - 1200, 71};
        work.vertices[previous * 4 + 2] =
            (SVECTOR){index * 9 - 1000, index * 3 - 500, index * 17 - 2400, 93};
        s11g_11g_demo_800CB878(&work, &position, group);
        assert(HashBytes(&work, sizeof(work)) == hind_ribbon_hashes[index]);
    }
}

static const short geometry_values[] = {-32768, -32001, -999, -1, 0, 1, 523, 32767};

static void CheckPutHzd(void)
{
    for (unsigned int index = 0; index < 192; ++index)
    {
        PutHzdWork work = {0};
        HZD_GRP group = {0};
        uint32_t source[96], destination[96];
        unsigned char *source_bytes = (unsigned char *)source;
        for (unsigned int i = 0; i < sizeof(source); ++i)
            source_bytes[i] = (unsigned char)(i * 73 + index * 19);
        memset(destination, 0xcd, sizeof(destination));
        work.offset = (SVECTOR){geometry_values[index % 8], geometry_values[index / 8 % 8],
                                geometry_values[index / 16 % 8], 0};
        work.n_walls = index % 6;
        work.n_floors = index / 6 % 5;
        work.walls = (HZD_SEG *)destination;
        work.floors = (HZD_FLR *)(destination + 32);
        group.walls = (HZD_SEG *)source;
        group.floors = (HZD_FLR *)(source + 32);
        PutHzdTranslate(&work, &group);
        assert(puthzd_fixtures[index][0] == index);
        assert(HashBytes(destination, sizeof(destination)) == puthzd_fixtures[index][1]);
    }
}

static void CheckInverseLight(void)
{
    static const int scales[] = {8, 11, 20, 33, 37, 50, -7, -9};
    for (unsigned int index = 0; index < 256; ++index)
    {
        InverseLightWork work;
        SVECTOR screen = {geometry_values[index / 8 % 8], geometry_values[index / 32 % 8], 0, 0};
        memset(&work, 0xa5, sizeof(work));
        memcpy(work.scales, scales, sizeof(scales));
        InverseLightVertex(&work, index % 8, &screen);
        assert(inverse_light_fixtures[index][0] == index);
        assert(HashBytes(&work, sizeof(work)) == inverse_light_fixtures[index][1]);
    }
}

int main(void)
{
    static void (*const functions[])(HindWork *) = {
        s11g_hind_800D96B0, s11g_hind_800D9B80, s11g_hind_800DA534
    };
    for (size_t index = 0; index < sizeof(hind_fixtures) / sizeof(hind_fixtures[0]); ++index)
    {
        HindWork work;
        const HindFixture *fixture = &hind_fixtures[index];
        uint32_t actual[3];
        Prepare(&work, fixture->input[1]);
        functions[fixture->input[0]](&work);
        actual[0] = HashBytes(&work, sizeof(work));
        actual[1] = random_calls;
        actual[2] = boundary_trace;
        if (memcmp(actual, fixture->output, sizeof(actual)) != 0)
        {
            fprintf(stderr, "Hind fixture %zu: hash=%08x/%08x random=%u/%u trace=%u/%u\n",
                    index, actual[0], fixture->output[0], actual[1], fixture->output[1],
                    actual[2], fixture->output[2]);
            return 1;
        }
    }
    CheckRibbon();
    CheckPutHzd();
    CheckInverseLight();
    puts("Hind: 720 original-MIPS flight/state comparisons passed.");
    puts("Hind: 288 original-MIPS ribbon comparisons passed.");
    puts("Tower: 448 original-MIPS collision and light geometry comparisons passed.");
    return 0;
}
