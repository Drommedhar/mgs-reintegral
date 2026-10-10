#include "mgs_native.h"
#undef fprintf
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include "libhzd/libhzd.h"
#include "game/game.h"

short linkvarbuf[MAX_LINKVARBUF];
SVECTOR GM_PlayerPosition;
SVECTOR DG_ZeroVector;
CONTROL *GM_PlayerControl;
int GV_Time;
static uint32_t boundary_trace;

static void Trace(unsigned int value)
{
    boundary_trace = (boundary_trace * 33 + value) & 0x7fffffffu;
}

void GV_DestroyActor(void *actor)
{
    assert(actor);
    Trace(1);
}

void GV_SubVec3(SVECTOR *left, SVECTOR *right, SVECTOR *out)
{
    out->vx = left->vx - right->vx;
    out->vy = left->vy - right->vy;
    out->vz = left->vz - right->vz;
}

int GV_VecLen3(SVECTOR *vec)
{
    return abs(vec->vx) + abs(vec->vy) + abs(vec->vz) + 1;
}

int GV_VecDir2(SVECTOR *vec)
{
    return (vec->vx + vec->vz * 3) & 4095;
}

void GV_LenVec3(SVECTOR *vec, SVECTOR *out, int denominator, int length)
{
    out->vx = vec->vx * length / denominator;
    out->vy = vec->vy * length / denominator;
    out->vz = vec->vz * length / denominator;
}

void DG_PutVector(SVECTOR *vec, SVECTOR *out, int count)
{
    assert(count == 1);
    out->vx = vec->vx + 100;
    out->vy = vec->vy - 200;
    out->vz = vec->vz + 300;
    Trace(2);
}

#include "rappel_helpers.inc"
#include "mgs_rappel_hind_fixtures.h"
_Static_assert(sizeof(Work) == 0x97C, "Original rappel helicopter layout");

static void Prepare(Work *work, GV_MSG *messages, CONTROL *player, int index)
{
    static const int flags[] = {0, 1, 2, 0x10, 0x101, 0x201, 0x241, 4};
    static const int commands[] = {0x5A47, 0x983F, 0x6A3E, 0xFFFA};
    static const int hover[] = {3, 64, 80, 96, 128, 80, 64};
    memset(work, 0, sizeof(*work));
    memset(messages, 0, sizeof(GV_MSG) * 4);
    boundary_trace = 0;
    work->control.mov = (SVECTOR){index * 19 - 2000, index * 7 - 3000, index * 37 - 4000, 0};
    work->control.rot = (SVECTOR){0, index * 71 - 4000, 0, 0};
    work->control.step = (SVECTOR){index % 37 - 18, index % 23 - 11, index % 41 - 20, 0};
    work->control.turn = (SVECTOR){index % 51 - 25, index * 17 - 2100, index % 17 - 8, 0};
    work->control.n_msg = index % 5;
    work->control.msg = messages;
    work->field_1C8 = flags[index % 8];
    work->field_1CC = index % 2;
    work->field_1CE = index % 4;
    work->field_1D0 = (SVECTOR){index * 31 - 4000, -2900, 4100, 0};
    work->field_1D8 = (SVECTOR){0, -1440, 2980, 0};
    work->field_1E0 = -5000;
    work->field_1E2 = -2500;
    work->field_1E4 = index % 127;
    work->field_1E8 = index % 3;
    work->field_1EA = index / 3 % 2;
    work->field_1EC = index * 13 - 3500;
    work->field_1EE = 160;
    work->field_1F0 = 32 + index % 9 * 32;
    work->field_1F2 = 96;
    work->field_1F8 = (SVECTOR){-8000, 8000, 3456, 0};
    work->field_200 = 7;
    for (int route = 0; route < 7; ++route)
    {
        work->field_202[route] = 4;
        for (int point = 0; point < 4; ++point)
            work->field_210[route][point] = (SVECTOR){route * 1000 + point * 37 - 3000,
                -4000 + point * 11, point * 631 - 777, (index % 4 << 8) | (point << 5) | 3};
    }
    work->field_910 = (u_short *)work->field_210[0];
    work->field_916 = 1;
    work->field_91C = index % 7 + 1;
    work->field_920 = -1;
    memcpy(work->field_93C, hover, sizeof(hover));
    work->field_958 = index % 4;
    work->field_95C = index % 61 - 30;
    work->field_960 = index * 7 - 1100;
    work->field_964 = index % 101 - 50;
    for (int item = 0; item < 4; ++item)
    {
        messages[item].message[0] = commands[item];
        messages[item].message[1] = item == 2 ? index % 7 + 1 : index % 2;
        messages[item].message[2] = 3100;
    }
    GM_PlayerPosition = (SVECTOR){index * 17 - 3000, index * 29 - 1000, index * 43 - 4500, 0};
    GM_PlayerControl = player;
    player->levels[0] = 700;
    GV_Time = index * 7;
    GM_Weapon = index % 11 == 0 ? 4 : 0;
}

static uint32_t HashWork(Work *work)
{
    uint32_t cursor = 0x801d0000u + (uintptr_t)work->field_910 - (uintptr_t)work;
    uint32_t messages = 0x801c0000u;
    uint32_t hash = 2166136261u;
    unsigned char bytes[sizeof(*work)];
    memcpy(bytes, work, sizeof(bytes));
    memcpy(bytes + offsetof(Work, field_910), &cursor, sizeof(cursor));
    memcpy(bytes + offsetof(Work, control.msg), &messages, sizeof(messages));
    for (size_t i = 0; i < sizeof(bytes); ++i) hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

int main(void)
{
    for (int operation = 0; operation < 6; ++operation)
    {
        for (int index = 0; index < 256; ++index)
        {
            Work work;
            GV_MSG messages[4];
            CONTROL player = {0};
            const uint32_t *expected = rappel_hind_fixtures[operation * 256 + index];
            Prepare(&work, messages, &player, index);
            switch (operation)
            {
            case 0: s11d_hind_800C99F4(&work); break;
            case 1: s11d_hind_800C9B94(&work); break;
            case 2: s11d_hind_800C9C7C(&work); break;
            case 3: s11d_hind_800C9D60(&work); break;
            case 4: s11d_hind_800CA504(&work); break;
            case 5: s11d_hind_800CA6D8(&work, index % 3); break;
            }
            if (HashWork(&work) != expected[0] || boundary_trace != expected[1])
            {
                fprintf(stderr, "Rappel op %d case %d: %u/%u expected %u/%u\n",
                    operation, index, HashWork(&work), boundary_trace, expected[0], expected[1]);
                return 1;
            }
        }
    }
    puts("1536 original-MIPS rappel helicopter fixtures PASS");
    return 0;
}
