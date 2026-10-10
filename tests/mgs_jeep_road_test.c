#include "mgs_native.h"
#undef fprintf
#include "overlays/s19b/takabe/jeep_srl_native.h"
#include "game/vibrate.h"
#include "takabe/fadeio.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

EscapeSystem Takabe_JeepSystem;
struct EscapeRoadWork *s19b_dword_800DE5B0;
int GM_GameOverTimer;

typedef struct {
    int input[5];
    int timer;
    int event_count;
    int events[2][3];
} FinaleFixture;

static int finale_event_count;
static int finale_events[2][3];

static void FinaleEvent(int kind, int first, int second)
{
    assert(finale_event_count < 2);
    finale_events[finale_event_count][0] = kind;
    finale_events[finale_event_count][1] = first;
    finale_events[finale_event_count++][2] = second;
}

void *NewFadeInOut(int mode, int shade)
{
    FinaleEvent(1, mode, shade);
    return NULL;
}

void *NewPadVibration(unsigned char *data, int port)
{
    assert(data == EscapeRoadRumble || data == EscapeRoadRumble + 20);
    FinaleEvent(2, (int)(data - EscapeRoadRumble), port);
    return NULL;
}

int GCL_ExecProc(int procedure, GCL_ARGS *arguments)
{
    FinaleEvent(3, procedure, arguments != NULL);
    return 0;
}

#include "jeep_road_helpers.inc"
#include "../vendor/mgs/source/libgv/near.c"
#include "mgs_jeep_road_fixtures.h"
#include "mgs_jeep_finale_fixtures.h"

static void CheckSequence(void)
{
    static const int remaining[] = {0, 1, 2, -8, 8, -16, 16, 3};
    Work work;
    int index, field, output[4];
    for (index = 0; index < 1024; ++index)
    {
        memset(&work, 0, sizeof(work));
        work.curve_x = index * 37 % 4001 - 2000;
        work.curve_y = index * 53 % 4001 - 2000;
        work.remaining = remaining[index % 8];
        work.event_delay = index % 9 - 3;
        work.sequence = EscapeRoadSequence[index % 24];
        Takabe_JeepSystem.field_40 = 19;
        Takabe_JeepSystem.field_44 = index % 4;
        s19b_jeep_srl_800CD638(&work, output);
        for (field = 0; field < 4; ++field)
            assert(output[field] == sequence[index][field]);
        assert(work.curve_x == sequence[index][4]);
        assert(work.curve_y == sequence[index][5]);
        assert(work.remaining == sequence[index][6]);
        assert(work.event_delay == sequence[index][7]);
        assert(work.sequence == EscapeRoadSequence[sequence[index][8]]);
        assert(Takabe_JeepSystem.field_40 == sequence[index][9]);
        assert(Takabe_JeepSystem.field_44 == sequence[index][10]);
    }
}

static void CheckRouting(void)
{
    Work work;
    int index, segment, result;
    memset(&work, 0, sizeof(work));
    s19b_dword_800DE5B0 = &work;
    for (index = 0; index < 1024; ++index)
    {
        work.tail = index % 16;
        for (segment = 0; segment < 16; ++segment)
        {
            work.segments[segment].position.vz = -31500 + segment * 4000;
            work.segments[segment].event = 100 + segment;
        }
        result = s19b_jeep_gls_800CEDFC(index * 191 % 100001 - 50000,
                                      index * 71 % 20000 - 10000);
        assert(result == route[index]);
    }
}

static void CheckFloors(void)
{
    SVECTOR position, vertices[4];
    HZD_FLR floor;
    short values[24];
    int index, vertex, field;
    for (index = 0; index < 512; ++index)
    {
        memset(&floor, 0xa5, sizeof(floor));
        position = (SVECTOR){index * 197 % 60001 - 30000,
                             index * 149 % 60001 - 30000,
                             index * 103 % 60001 - 30000, 0};
        for (vertex = 0; vertex < 4; ++vertex)
            vertices[vertex] = (SVECTOR){(index * 71 + vertex * 619) % 60001 - 30000,
                                         (index * 43 + vertex * 197) % 60001 - 30000,
                                         (index * 37 + vertex * 223) % 60001 - 30000, 0};
        s19b_jeep_gls_800CE628(&position, vertices, &floor, 0);
        memcpy(values, &floor, sizeof(values));
        for (field = 0; field < 24; ++field)
            assert(values[field] == floors[index][field]);
    }
}

static void PrepareFinale(Work *work, CONTROL *control, const FinaleFixture *fixture)
{
    memset(work, 0, sizeof(*work));
    memset(control, 0, sizeof(*control));
    memset(&Takabe_JeepSystem, 0, sizeof(Takabe_JeepSystem));
    work->final_timer = fixture->input[0];
    work->final_proc = fixture->input[1];
    work->tail = fixture->input[3];
    control->mov.vz = fixture->input[4];
    Takabe_JeepSystem.control = control;
    s19b_dword_800DE5B0 = work;
    for (int segment = 0; segment < 16; ++segment)
    {
        work->segments[segment].position.vz = -31500 + segment * 4000;
        work->segments[segment].event = 12 + segment % 4;
    }
}

static void CheckFinaleStep(Work *work, const FinaleFixture *fixture)
{
    Work expected = *work;
    EscapeSystem system_before = Takabe_JeepSystem;
    CONTROL control_before = *Takabe_JeepSystem.control;
    assert(work->final_timer == fixture->input[0]);
    GM_GameOverTimer = fixture->input[2];
    finale_event_count = 0;
    memset(finale_events, 0, sizeof(finale_events));
    UpdateFinale(work);
    expected.final_timer = fixture->timer;
    assert(memcmp(work, &expected, sizeof(*work)) == 0);
    assert(memcmp(&Takabe_JeepSystem, &system_before, sizeof(system_before)) == 0);
    assert(memcmp(Takabe_JeepSystem.control, &control_before, sizeof(control_before)) == 0);
    assert(GM_GameOverTimer == fixture->input[2]);
    assert(finale_event_count == fixture->event_count);
    assert(memcmp(finale_events, fixture->events, sizeof(finale_events)) == 0);
}

static size_t CheckFinale(void)
{
    Work work;
    CONTROL control;
    const size_t cases = sizeof(finale_fixtures) / sizeof(finale_fixtures[0]);
    const size_t steps = sizeof(finale_timeline) / sizeof(finale_timeline[0]);
    for (size_t index = 0; index < cases; ++index)
    {
        PrepareFinale(&work, &control, &finale_fixtures[index]);
        CheckFinaleStep(&work, &finale_fixtures[index]);
    }
    PrepareFinale(&work, &control, finale_timeline);
    for (size_t index = 0; index < steps; ++index)
        CheckFinaleStep(&work, &finale_timeline[index]);
    return cases + steps;
}

int main(void)
{
    CheckSequence();
    CheckRouting();
    CheckFloors();
    printf("%zu original MIPS road comparisons passed, including finale callbacks\n", 2560 + CheckFinale());
    return 0;
}
