#include "mgs_native.h"
#undef fprintf
#include "overlays/s15c/okajima/valcan/valcan.h"
#include <stdbool.h>
#include <assert.h>
#include <stdio.h>

typedef ValcanWork Work;
int s15c_container_phase[4];
static int random_value, random_calls, random_bound;
static unsigned int damage_trace;
static int player_distance;
short linkvarbuf[MAX_LINKVARBUF];
SVECTOR GM_PlayerPosition, svector_8009F478;
GV_PAD GV_PadData[4];
int dword_8009F46C[1], dword_8009F480, dword_8009F49C;

static void Trace(unsigned int boundary)
{
    damage_trace = (damage_trace * 33 + boundary) & 0x7fffffff;
}

int mts_get_tick_count(void)
{
    Trace(1);
    return 1000;
}

int Valcan_800D9DC0(Work *work, int player)
{
    assert(work && player == 0);
    Trace(2);
    return player_distance;
}

void Valcan_800D9F8C(Work *work) { assert(work); Trace(3); }
void Valcan_800DCF8C(Work *work) { assert(work); Trace(4); }
void Valcan_800D9F3C(Work *work, int count) { assert(work && count == 16); Trace(5); }
void Valcan_800DC06C(Work *work, int bone, int count)
{
    assert(work && bone >= 0 && bone < 8 && count == 2);
    Trace(6);
}
void Valcan_800D9D90(Work *work) { assert(work); Trace(7); }
void GM_SeSet2(int pan, int volume, int sound)
{
    assert(pan == 0 && volume == 63 && sound == 138);
    Trace(8);
}
void GM_SeSetMode(SVECTOR *position, int sound, int mode)
{
    assert(position && sound == 135 && mode == 1);
    Trace(9);
}

int GV_RandU(int range)
{
    ++random_calls;
    random_bound = range;
    Trace(10);
    return random_value & (range - 1);
}

#include "valcan_navigation.inc"

typedef struct {
    int input[15];
    int output[9];
} ValcanFixture;
#include "mgs_valcan_fixtures.h"

typedef struct {
    int input[9];
    int output[21];
} ValcanDamageFixture;
#include "mgs_valcan_damage_fixtures.h"

static void Prepare(Work *work, const int *in)
{
    for (int x = 0; x < 4; ++x)
        for (int y = 0; y < 4; ++y)
        {
            work->field_6F8[x][y][0] = x * 7000 - 10500;
            work->field_6F8[x][y][1] = y * 6000 - 7500;
        }
    work->field_738 = in[1];
    work->field_73A = in[2];
    work->field_73C = in[3];
    work->field_73E = in[4];
    work->field_740 = in[5];
    work->field_770 = in[6];
    work->field_774 = 1;
    work->field_93C = in[7];
    work->field_51C.vx = in[8];
    work->field_51C.vz = in[9];
    random_value = in[10];
    random_calls = random_bound = 0;
    for (int i = 0; i < 4; ++i)
        s15c_container_phase[i] = in[11 + i];
    work->field_6A4 = 41;
    work->field_69C = 17;
    work->field_828 = 9;
    work->field_79C = -7;
}

static void Verify(unsigned int index)
{
    static int (*const functions[])(Work *) = {
        s15c_crow_800DA2A8, s15c_crow_800DAE7C,
        s15c_crow_800DAFCC, s15c_crow_800DB200
    };
    const ValcanFixture *fixture = &valcan_fixtures[index];
    Work work = {0};
    Prepare(&work, fixture->input);
    int result = functions[fixture->input[0]](&work);
    const int output[] = {
        result, work.field_79C, work.field_828, work.field_770,
        work.field_774, work.field_6A4, work.field_69C,
        random_calls, random_bound
    };
    for (unsigned int i = 0; i < sizeof(output) / sizeof(output[0]); ++i)
    {
        if (output[i] != fixture->output[i])
            fprintf(stderr, "Valcan case %u field %u: native %d, MIPS %d\n",
                    index, i, output[i], fixture->output[i]);
        assert(output[i] == fixture->output[i]);
    }
}

static void PrepareDamage(Work *work, TARGET *target, TARGET *body, const int *in)
{
    work->field_664 = target;
    work->field_668 = body;
    GM_GameLevel = in[0];
    target->a_mode = in[1];
    target->damaged = in[2];
    target->damage = in[3];
    work->field_6B8 = in[4];
    work->field_924 = in[5];
    work->field_900 = in[6];
    target->vital = in[6] - 12;
    player_distance = in[7];
    random_value = in[8];
    damage_trace = 0;
    work->field_8E0 = 2000;
    work->field_684 = 1;
    work->field_688 = 2;
    work->field_6A4 = 23;
    work->field_69C = 17;
    work->field_944 = 700;
    work->field_948 = 800;
    work->control.mov = (SVECTOR){-500, 200, 3000, 0};
    work->control.rot = (SVECTOR){123, 321, 456, 0};
    body->damaged = 0x18;
    GM_PlayerPosition = (SVECTOR){400, 10, -800, 0};
    dword_8009F46C[0] = 0;
    dword_8009F480 = 8;
    dword_8009F49C = 9;
}

static void VerifyDamage(unsigned int index)
{
    const ValcanDamageFixture *fixture = &damage_fixtures[index];
    Work work = {0};
    TARGET target = {0}, body = {0};
    PrepareDamage(&work, &target, &body, fixture->input);
    s15c_crow_800DD03C(&work);
    const int output[] = {
        work.field_900, work.field_924, work.field_93C, work.field_6B8,
        work.field_944, work.field_948, work.field_684, work.field_780,
        work.field_784, work.field_6A4, work.field_69C, work.field_81C,
        work.field_940, target.vital, target.damage, target.damaged,
        body.damaged, work.field_910.vx, work.field_910.vy, work.field_910.vz,
        damage_trace
    };
    for (unsigned int i = 0; i < sizeof(output) / sizeof(output[0]); ++i)
    {
        if (output[i] != fixture->output[i])
            fprintf(stderr, "Valcan damage case %u field %u: native %d, MIPS %d\n",
                    index, i, output[i], fixture->output[i]);
        assert(output[i] == fixture->output[i]);
    }
    assert(dword_8009F480 == 0 && dword_8009F49C == 0);
}

int main(void)
{
    unsigned int count = sizeof(valcan_fixtures) / sizeof(valcan_fixtures[0]);
    for (unsigned int i = 0; i < count; ++i)
        Verify(i);
    printf("Valcan: %u original-MIPS navigation comparisons passed.\n", count);
    count = sizeof(damage_fixtures) / sizeof(damage_fixtures[0]);
    for (unsigned int i = 0; i < count; ++i)
        VerifyDamage(i);
    printf("Valcan: %u original-MIPS damage comparisons passed.\n", count);
    return 0;
}
