#include "mgs_native.h"
#undef fprintf
#include "overlays/s19b/takabe/jeep_mrl/jeep_mrl_native.h"
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <rand.h>

typedef struct DriverFixture
{
    int output[29];
    int trace_count;
    int trace[32];
} DriverFixture;
#include "mgs_jeep_driver_fixtures.h"

EscapeSystem Takabe_JeepSystem;
int s19b_dword_800DE648, s19b_dword_800C39CC;
SVECTOR DG_ZeroVector;
unsigned char EscapeRumble39A0[16], EscapeRumble39B0[12];
static struct { DG_OBJS header; DG_OBJ joints[3]; } turret;
static DG_OBJS chassis;
static int input_index, trace_count, trace[32];

static void Record(int count, ...)
{
    va_list args;
    assert(trace_count + count <= 32);
    va_start(args, count);
    while (count--)
        trace[trace_count++] = va_arg(args, int);
    va_end(args);
}

void s19b_jeep_mrl_800D2D3C(EscapeJeepWork *work)
{
    assert(work);
    Record(1, 20);
}
int s19b_jeep_gls_800CEDFC(int distance, int offset)
{
    static const int events[] = {0, 9, 10, 11, 12, 13};
    assert(distance == 0);
    Record(2, 21, offset);
    return events[input_index % 6];
}
int s19b_jeep_mrl_800D3A54(SVECTOR *position, short *heading, int turn, short speed)
{
    Record(3, 22, turn, speed);
    *position = (SVECTOR){17, 0, 31, 0};
    *heading += 7;
    return *heading;
}
int s19b_jeep_mrl_800D39F0(void)
{
    Record(1, 23);
    return input_index % 3;
}
void s19b_jeep_mrl_800D3CA8(EscapeJeepWork *work, int index)
{
    assert(work);
    Record(2, 24, index);
}
void DG_SetPos2(SVECTOR *position, SVECTOR *rotation)
{
    assert(position == &DG_ZeroVector && rotation);
}
void DG_RotVector(SVECTOR *source, SVECTOR *target, int count)
{
    SVECTOR input = *source;
    assert(count == 1);
    input.vx = input.vz / 3;
    input.vz = -input.vz / 2;
    *target = input;
}
void s19b_jblood_800C850C(MATRIX *joint, MATRIX *world)
{
    int index;
    assert(world == &chassis.world);
    for (index = 1; index < 3; ++index)
        if (joint == &turret.header.objs[index].world)
        {
            Record(2, 25, 72 + index * 92);
            return;
        }
    assert(0);
}
void GM_SeSet(SVECTOR *position, int sound)
{
    (void)position;
    Record(2, 26, sound);
}
void GM_SetSound(int sound, int mode)
{
    Record(3, 27, (int)sound, mode);
}
void *NewPadVibration(unsigned char *script, int channel)
{
    assert(script == EscapeRumble39A0 || script == EscapeRumble39B0);
    Record(3, 28, script == EscapeRumble39A0 ? 0x798 : 0x7a8, channel);
    return NULL;
}
void Voicesys_800CE2D0(void) { Record(1, 29); }
void Voicesys_800CE5F8(int index, int mode) { Record(3, 30, index, mode); }
void Voicesys_800CE6AC(int value) { Record(2, 31, value); }
void s19b_jlamp_800D0FE4(int view) { Record(2, 32, view); }

#include "jeep_driver_helpers.inc"
#include "../vendor/mgs/source/libgv/near.c"

static void Prepare(EscapeJeepWork *work, int index)
{
    memset(work, 0, sizeof(*work));
    memset(&Takabe_JeepSystem, 0, sizeof(Takabe_JeepSystem));
    work->field_A8.objs = &chassis;
    work->field_18C.objs = &turret.header;
    work->step = (SVECTOR){index % 7 - 3, 0, index % 9 - 4, 0};
    work->field_3A8 = (SVECTOR){index % 17 - 8, 0, index % 19 - 9, 0};
    work->field_3B8.vy = index * 73 % 4096;
    work->field_3C8 = index * 31 % 3201 - 1600;
    work->field_3CC = index % 95;
    work->field_3D0 = index * 19 % 701 - 300;
    work->field_3D4 = 400;
    work->field_3DC = index % 7 - 1;
    work->field_3E0 = index % 2;
    work->field_3E8 = 777;
    work->field_3EC = index * 23 % 1001 - 500;
    Takabe_JeepSystem.field_50 = 0x71234567;
    s19b_dword_800DE648 = index % 11;
    s19b_dword_800C39CC = index % 12;
    trace_count = 0;
    input_index = index;
}

static void Check(const EscapeJeepWork *work, const DriverFixture *fixture)
{
    short vectors[14];
    int scalars[11], output[29], index;
    memcpy(vectors, &work->step, 8);
    memcpy(vectors + 4, &work->field_3A8, 8);
    memcpy(vectors + 8, &work->field_3B8, 8);
    vectors[12] = work->field_3C8;
    vectors[13] = work->field_3CA;
    memcpy(scalars, &work->field_3CC, sizeof(scalars));
    for (index = 0; index < 14; ++index) output[index] = vectors[index];
    for (index = 0; index < 11; ++index) output[index + 14] = scalars[index];
    if (!work->state) output[25] = 0;
    else if (work->state == s19b_jeep_mrl_800D2E78) output[25] = 1;
    else if (work->state == EscapeState_800D32C4) output[25] = 2;
    else { assert(work->state == s19b_jeep_mrl_800D3928); output[25] = 3; }
    output[26] = Takabe_JeepSystem.field_50;
    output[27] = s19b_dword_800DE648;
    output[28] = s19b_dword_800C39CC;
    for (index = 0; index < 29; ++index)
    {
        if (output[index] != fixture->output[index])
            fprintf(stderr, "driver %d field %d: %d != %d\n", input_index, index, output[index], fixture->output[index]);
        assert(output[index] == fixture->output[index]);
    }
    assert(trace_count == fixture->trace_count);
    assert(memcmp(trace, fixture->trace, trace_count * sizeof(int)) == 0);
}

int main(void)
{
    static void (*const states[])(EscapeJeepWork *) = {
        EscapeState_800D2F54, EscapeState_800D32C4,
        s19b_jeep_mrl_800D36A4, s19b_jeep_mrl_800D37D0
    };
    EscapeJeepWork work;
    int state, index;
    for (state = 0; state < 4; ++state)
        for (index = 0; index < 384; ++index)
        {
            Prepare(&work, index);
            states[state](&work);
            Check(&work, &fixtures[state * 384 + index]);
        }
    puts("1536 original MIPS driver state comparisons passed");
    return 0;
}
