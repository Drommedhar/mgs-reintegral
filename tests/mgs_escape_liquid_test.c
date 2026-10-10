#include "mgs_native.h"
#include "overlays/s19b/jeep_liquid.h"
#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

typedef EscapeLiquidWork Work;
typedef struct LiquidFixture
{
    int output[25];
    int trace_count;
    int trace[8];
} LiquidFixture;
#include "mgs_escape_liquid_fixtures.h"
typedef struct CollisionFixture
{
    int input[4];
    int output[16];
} CollisionFixture;
#include "mgs_escape_collision_fixtures.h"

EscapeSystem Takabe_JeepSystem;
SVECTOR DG_ZeroVector;
short linkvarbuf[MAX_LINKVARBUF];
static int input_index, trace_count, trace[8];
int GV_PassageTime, s19b_dword_800C3AD4;
MATRIX DG_ZeroMatrix = {{{4096, 0, 0}, {0, 4096, 0}, {0, 0, 4096}}, {0, 0, 0}};
static const CollisionFixture *collision;
static int collision_effects[5];
static HZD_HDL collision_hazard;

int HZD_NearHazardCheck(HZD_HDL *hazard, SVECTOR *from, int radius, int flags, int mask)
{
    assert(hazard == &collision_hazard);
    assert(from->vx == 1234 && from->vy == 1450 && from->vz == -5678);
    assert(radius == 475 && flags == 12 && mask == 0);
    return collision->input[0];
}

void HZD_GetNearVector(SVECTOR *vectors)
{
    vectors[0].vx = collision->input[1];
    vectors[0].vy = vectors[0].vz = 0;
    vectors[1].vx = 0x1357;
    vectors[1].vy = -0x2468;
    vectors[1].vz = 0x369;
}

int GV_VecLen3(SVECTOR *vector)
{
    assert(vector->vx == collision->input[1] && !vector->vy && !vector->vz);
    return abs(vector->vx);
}

void *NewSpark2M(MATRIX *world)
{
    assert(memcmp(world->m, DG_ZeroMatrix.m, sizeof(world->m)) == 0);
    ++collision_effects[0];
    for (int i = 0; i < 3; ++i)
        collision_effects[i + 2] = world->t[i];
    return world;
}

void GM_SeSetMode(SVECTOR *position, int sound, int mode)
{
    assert(sound == 195 && mode == 1);
    assert(position->vx == collision_effects[2] && position->vy == collision_effects[3] &&
           position->vz == collision_effects[4]);
    ++collision_effects[1];
}

static void Record(int count, ...)
{
    va_list args;
    assert(trace_count + count <= 8);
    va_start(args, count);
    while (count-- > 0)
        trace[trace_count++] = va_arg(args, int);
    va_end(args);
}
void GM_SeSet(SVECTOR *position, int sound)
{
    assert(position);
    Record(2, 1, sound);
}
void GM_ConfigObjectAction(OBJECT *object, int action, int frame, int interpolation)
{
    assert(object);
    Record(4, 2, action, frame, interpolation);
}
int s19b_spark2_m_800D88D8(Work *work)
{
    assert(work);
    Record(1, 3);
    return input_index % 3 == 0;
}
int s19b_jeep_mrl_800D399C(void) { return input_index * 29 % 801 - 200; }
void s19b_spark2_m_800D9390(Work *work, int mode) { (void)work; (void)mode; assert(0); }
void s19b_spark2_m_800D9434(Work *work, int mode) { (void)work; (void)mode; assert(0); }
void s19b_spark2_m_800D94C8(Work *work, int mode) { (void)work; (void)mode; assert(0); }
void s19b_spark2_m_800D91DC(Work *work, int mode) { (void)work; (void)mode; assert(0); }

#include "escape_liquid_helpers.inc"
#include "../vendor/mgs/source/libgv/near.c"

static void Prepare(Work *work, TARGET *target, int index)
{
    static const int flags[] = {0, 2, 0x1000, 0x8000, 0x20000, 0x21002, 0x8002, 0x18000};
    memset(work, 0, sizeof(*work));
    memset(target, 0, sizeof(*target));
    memset(&Takabe_JeepSystem, 0, sizeof(Takabe_JeepSystem));
    Takabe_JeepSystem.field_54 = flags[index % 8];
    Takabe_JeepSystem.field_44 = 7;
    GM_GameLevel = index % 5 - 1;
    work->f8E4 = target;
    work->f8F4 = 13;
    work->f8FC = index % 4 == 0 ? 20 : 7;
    work->f900 = (index % 2 ? 0x2000000 : 0) | (index % 3 ? 0x10 : 0);
    work->f914 = 2;
    work->f918 = 31;
    work->own_control.turn = (SVECTOR){121, -42, 77, 0};
    target->damaged = index % 4 < 2 ? TARGET_POWER : 0;
    target->vital = index * 71 % 701 - 350;
    target->damage = 43;
    target->force = (SVECTOR){17, 29, -33, 9};
    input_index = index;
    trace_count = 0;
}

static int CallbackId(const Work *work)
{
    if (!work->f8EC) return 0;
    if (work->f8EC == s19b_spark2_m_800D9390) return 1;
    if (work->f8EC == s19b_spark2_m_800D9434) return 2;
    if (work->f8EC == s19b_spark2_m_800D94C8) return 3;
    assert(work->f8EC == s19b_spark2_m_800D91DC);
    return 4;
}

static void ActorOutput(const Work *work, const TARGET *target, int result, int *out)
{
    out[0] = work->f8F4;
    out[1] = work->f8FC;
    out[2] = work->f900;
    out[3] = work->f914;
    out[4] = work->f918;
    out[5] = work->own_control.turn.vx;
    out[6] = work->own_control.turn.vy;
    out[7] = work->own_control.turn.vz;
    out[8] = work->own_control.turn.pad;
    out[9] = CallbackId(work);
    out[10] = target->damaged;
    out[11] = target->vital;
    out[12] = target->damage;
    out[13] = target->force.vx;
    out[14] = target->force.vy;
    out[15] = target->force.vz;
    out[16] = target->force.pad;
    out[17] = Takabe_JeepSystem.field_44;
    out[18] = result;
}

static void WheelOutput(int index, int *out)
{
    SVECTOR joints[5], rotation = {11, index * 73 % 4096 - 2048, -13, 7};
    SVECTOR previous = {-11, index * 29 % 4096 - 2048, 13, -7};
    short values[24];
    int field;
    for (field = 0; field < 20; ++field)
        values[field] = (index * 37 + field * 11) % 6001 - 3000;
    memcpy(joints, values, sizeof(joints));
    out[24] = s19b_spark2_m_800DA0B4(joints, index * 37 % 1201 - 600, &rotation, &previous);
    memcpy(values, joints, sizeof(joints));
    memcpy(values + 20, &previous, sizeof(previous));
    for (field = 0; field < 24; ++field)
        out[field] = values[field];
}

static unsigned CheckCollision(void)
{
    unsigned count = sizeof(collision_fixtures) / sizeof(collision_fixtures[0]);
    for (unsigned index = 0; index < count; ++index)
    {
        CONTROL control, expected;
        MAP map = {0};
        VECTOR position = {110000, 220000, -330000, 44};
        SVECTOR delta = {17, 18, 19, 20};
        int speed = -141, output[16];
        collision = &collision_fixtures[index];
        memset(&control, 0xA5, sizeof(control));
        memset(collision_effects, 0, sizeof(collision_effects));
        map.hzd = &collision_hazard;
        control.mov = (SVECTOR){1234, 1200, -5678, 45};
        control.map = &map;
        expected = control;
        s19b_dword_800C3AD4 = collision->input[2];
        GV_PassageTime = collision->input[3];
        output[0] = s19b_spark2_m_800D9C90(&control, &position, &speed, &delta);
        output[1] = control.mov.vx; output[2] = control.mov.vy; output[3] = control.mov.vz;
        output[4] = position.vx; output[5] = position.vy; output[6] = position.vz;
        output[7] = delta.vx; output[8] = delta.vy; output[9] = delta.vz;
        output[10] = s19b_dword_800C3AD4;
        memcpy(output + 11, collision_effects, sizeof(collision_effects));
        assert(memcmp(output, collision->output, sizeof(output)) == 0);
        expected.mov = control.mov;
        assert(memcmp(&control, &expected, sizeof(control)) == 0);
        assert(position.pad == 44 && delta.pad == 20 && speed == -141);
    }
    return count;
}

int main(void)
{
    Work work;
    TARGET target;
    int operation, index, field;
    for (operation = 0; operation < 5; ++operation)
        for (index = 0; index < 512; ++index)
        {
            int output[25] = {0}, result = 0;
            const LiquidFixture *fixture = &fixtures[operation * 512 + index];
            Prepare(&work, &target, index);
            if (operation == 0) result = s19b_spark2_m_800D87A4(&work);
            else if (operation == 1) s19b_spark2_m_800D9148(&work, index % 105);
            else if (operation == 2) result = s19b_spark2_m_800D9680(&work);
            else if (operation == 3) WheelOutput(index, output);
            else output[0] = s19b_jeep_liq_800D771C(index * 37 % 1201 - 600,
                                                  index * 31 % 2001 - 1000, index * 113 % 10001 - 5000);
            if (operation < 3) ActorOutput(&work, &target, result, output);
            for (field = 0; field < 25; ++field)
            {
                if (output[field] != fixture->output[field])
                    fprintf(stderr, "Liquid operation %d case %d field %d: %d != %d\n",
                            operation, index, field, output[field], fixture->output[field]);
                assert(output[field] == fixture->output[field]);
            }
            assert(trace_count == fixture->trace_count);
            assert(memcmp(trace, fixture->trace, trace_count * sizeof(int)) == 0);
        }
    printf("%u original MIPS escape Liquid and vehicle comparisons passed, including wall contact\n",
           2560 + CheckCollision());
    return 0;
}
