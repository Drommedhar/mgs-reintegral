#include "mgs_native.h"
#undef fprintf
#include "animal/liquid/liquid_native.h"
#include "psxdefs.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    unsigned state, trace, words;
} LiquidClimbFixture;

#include "mgs_liquid_climb_fixtures.h"

_Alignas(16) unsigned long psyz_scratchpad[256];
short liquid_motions[40];
static const int ticks[] = {-1, 0, 1, 25, 26, 27, 57, 58, 59, 60, 61, 79, 80, 100};
static const int climb_types[] = {-1, 0, 1, 2, 3, 4, 5, 6, 7, 8};
static const SVECTOR positions[] = {
    {100, -200, 300, 7}, {32760, -32760, -32760, -8}, {-32760, 32760, 32760, 9}
};
static const short near_values[][4] = {
    {17, -31, 271, -371}, {32767, -32768, -32768, 32767}, {-32768, 32767, 1337, -1337}
};
static unsigned trace[64], trace_count;
static int seed;
static LiquidWork *current;

static unsigned Hash(unsigned hash, const void *data, size_t size)
{
    const unsigned char *bytes = data;
    for (size_t i = 0; i < size; ++i)
        hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static void Event(unsigned value)
{
    assert(trace_count < sizeof(trace) / sizeof(trace[0]));
    trace[trace_count++] = value;
}

void liquid_800C82A4(LiquidWork *work, int tick)
{
    (void)work;
    (void)tick;
    assert(!"Climb must select the next action without invoking it");
}

int liquid_800C722C(SVECTOR *position, short *angle)
{
    assert(position == &current->control.mov && angle == &current->control.turn.vy);
    Event(0);
    Event(Hash(2166136261u, position, sizeof(*position)));
    *angle = (short)(seed * 7 - 3000);
    return climb_types[seed % 10];
}

void GM_ConfigObjectAction(OBJECT *object, int action, int frame, int interpolation)
{
    Event(1);
    Event((unsigned char *)object - (unsigned char *)current);
    Event(action);
    Event(frame);
    Event(interpolation);
}

void GM_SeSet(SVECTOR *position, int sound)
{
    Event(4);
    Event((unsigned char *)position - (unsigned char *)current);
    Event(sound);
    Event(Hash(2166136261u, position, sizeof(*position)));
}

static int SilentPrintf(const char *format, ...)
{
    (void)format;
    return 0;
}

static void CheckedNearVector(SVECTOR *output, size_t capacity);
#define printf SilentPrintf
#include "liquid_climb_helpers.inc"
#undef printf

int HZD_NearHazardCheck(HZD_HDL *hazard, SVECTOR *position, int radius, int flags, int segment_flags)
{
    Event(2);
    Event((unsigned)(uintptr_t)hazard);
    Event((unsigned char *)position - (unsigned char *)current);
    Event(radius);
    Event(flags);
    Event(segment_flags);
    const short *values = near_values[seed / 280];
    FIRST->nearest = (DVECTOR){values[0], values[1]};
    SECOND->nearest = (DVECTOR){values[2], values[3]};
    return 1 + seed % 2;
}

static void CheckedNearVector(SVECTOR *output, size_t capacity)
{
    if (capacity == (size_t)-1 || capacity < 2 * sizeof(*output)) {
        fprintf(stderr, "HZD_GetNearVector requires two vectors; caller provides %zu bytes\n", capacity);
        exit(1);
    }
    OriginalNearVector(output);
    Event(3);
    for (int i = 0; i < 2; ++i) {
        Event(output[i].vx);
        Event(output[i].vy);
        Event(output[i].vz);
    }
}

static void CheckHazardReader(void)
{
    struct {
        unsigned before;
        SVECTOR output[2];
        unsigned after;
    } buffer;
    memset(&buffer, 0xA5, sizeof(buffer));
    FIRST->nearest = (DVECTOR){-32768, 32767};
    SECOND->nearest = (DVECTOR){-12345, 23456};
    OriginalNearVector(buffer.output);
    assert(buffer.before == 0xA5A5A5A5u && buffer.after == 0xA5A5A5A5u);
    assert(buffer.output[0].vx == -32768 && buffer.output[0].vy == 0 && buffer.output[0].vz == 32767);
    assert(buffer.output[1].vx == -12345 && buffer.output[1].vy == 0 && buffer.output[1].vz == 23456);
    assert((unsigned short)buffer.output[0].pad == 0xA5A5 &&
           (unsigned short)buffer.output[1].pad == 0xA5A5);
}

static void Initialize(LiquidWork *work, MAP *map)
{
    unsigned char *bytes = (unsigned char *)work;
    for (size_t i = 0; i < sizeof(*work); ++i)
        bytes[i] = (unsigned char)(i * 37 + seed * 11 + 3);
    memset(map, 0, sizeof(*map));
    map->hzd = (HZD_HDL *)(uintptr_t)0x80183000;
    work->control.map = map;
    work->action = liquid_800CBB50;
    work->field_914 = climb_types[seed % 10];
    work->body.is_end = seed / 140 % 2;
    work->control.levels[0] = (short)(-1234 + seed);
    work->saved_position = positions[seed / 280];
}

static unsigned HashState(const LiquidWork *work)
{
    LiquidWork normalized = *work;
    normalized.control.map = (MAP *)(uintptr_t)0x80182000;
    assert(work->action == liquid_800CBB50 || work->action == liquid_800C82A4);
    normalized.action = (LiquidAction)(uintptr_t)(
        work->action == liquid_800CBB50 ? 0x800CBB50 : 0x800C82A4);
    return Hash(2166136261u, &normalized, sizeof(normalized));
}

int main(void)
{
    _Static_assert(sizeof(LiquidWork) == 2636, "Original actor size");
    _Static_assert(offsetof(ScrPad, first.nearest) == 0x78, "Original first near vector");
    _Static_assert(offsetof(ScrPad, second.nearest) == 0x94, "Original second near vector");
    CheckHazardReader();
    for (int i = 0; i < 40; ++i)
        liquid_motions[i] = (short)(i * 13 - 200);
    for (seed = 0; seed < (int)(sizeof(liquid_climb_fixtures) /
                              sizeof(liquid_climb_fixtures[0])); ++seed) {
        LiquidWork work;
        MAP map;
        Initialize(&work, &map);
        current = &work;
        trace_count = 0;
        liquid_800CBB50(&work, ticks[seed / 10 % 14]);
        unsigned state = HashState(&work);
        unsigned calls = Hash(2166136261u, trace, trace_count * sizeof(*trace));
        const LiquidClimbFixture *expected = &liquid_climb_fixtures[seed];
        if (state != expected->state || calls != expected->trace || trace_count != expected->words) {
            fprintf(stderr, "Liquid climb seed %d: state %08x/%08x, trace %08x/%08x, words %u/%u\n",
                    seed, state, expected->state, calls, expected->trace, trace_count, expected->words);
            return 1;
        }
    }
    puts("840 Liquid climb states and real hazard-reader traces match original MIPS.");
    return 0;
}
