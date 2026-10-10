#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>

short s11d_rope_levels[2];
u_char s11d_vibration_800C32B0[4];
MATRIX DG_ZeroMatrix = {{{4096, 0, 0}, {0, 4096, 0}, {0, 0, 4096}}, {0, 0, 0}};
static uint32_t boundary_trace;

static void Trace(unsigned int value)
{
    boundary_trace = (boundary_trace * 33 + value) & 0x7fffffffu;
}

void GM_SeSet(SVECTOR *position, int sound)
{
    assert(position);
    Trace(1);
    Trace(sound);
    Trace(0);
}

void *NewPadVibration(u_char *script, int channel)
{
    assert(script == s11d_vibration_800C32B0);
    Trace(2);
    Trace(0xA8);
    Trace(channel);
    return NULL;
}

#include "rope_helpers.inc"
#include "../vendor/mgs/source/libgv/near.c"
#include "mgs_rope_fixtures.h"
_Static_assert(sizeof(Work) == 0x1098, "Rappel actor layout");

static void PrepareRope(Work *work, DG_PRIM *prim, HZD_SEG *wall, int index)
{
    static const int flags[] = {0, 0x1000, 0x4000, 0x5000, 0x100, 0x200, 0x300, 0x1010};
    memset(work, 0, sizeof(*work));
    memset(prim, 0, sizeof(*prim));
    memset(wall, 0, sizeof(*wall));
    boundary_trace = 0;
    work->control.mov = (SVECTOR){index * 19 - 2000, -index * 71 - 1000, index * 23 - 4000, 0};
    work->control.step = (SVECTOR){index % 37 - 18, index % 23 - 11, index % 41 - 20, 0};
    work->control.grounded = index % 4;
    work->control.n_touches = index % 2;
    work->control.segs[0] = wall;
    wall->p1.x = -2000;
    wall->p1.z = index * 37 - 3000;
    wall->p1.y = 1000;
    work->previous_position = (SVECTOR){-index * 3 + 3000, 0, 0, 0};
    work->field_A14 = prim;
    for (int i = 0; i < 128; ++i)
        work->lower_vertices[i] = (SVECTOR){i * 11 - 1000, i * 13, i * 17, 49};
    for (int i = 0; i < 32; ++i) work->rope_angles[i] = index * 7 + i * 31 - 1400;
    work->field_E9C = index * 19 - 1800;
    work->field_EB4 = index % 3 - 1;
    for (int axis = 0; axis < 2; ++axis)
    {
        int *swing = axis ? work->swing_z : work->swing_x;
        int direction = axis ? 1 : -1;
        const int initial[] = {16 + index % 11 * 16, index * 7 - 700,
            index % 4 ? direction : -direction, axis ? 64 : 24,
            index % 151 - 75, index * 13 - 1800, 13000, index * 11 - 1400,
            index * 17 - 2100, 43, -71, index % 4, -1000};
        memcpy(swing, initial, sizeof(initial));
        swing[13] = (int)(axis ? &work->control.mov.vz : &work->control.mov.vx);
        swing[14] = (int)(axis ? &work->control.turn.vx : &work->control.turn.vz);
    }
    work->rope_length = 5000 + index * 37;
    work->field_F60 = -(index % 9);
    work->field_F64 = -(index % 7);
    work->field_F68 = -(index % 5);
    work->field_F74 = flags[index % 8];
    work->field_F84 = -7000;
    work->field_F86 = -20000;
    work->field_F88 = -4000;
    work->field_F8C = 6000;
    work->field_F8E = 24000;
    work->field_F94 = -3000;
    work->field_F96 = 30000;
    work->field_F98 = 600;
    s11d_rope_levels[0] = index % 3 == 0 ? -index * 71 - 1000 : 26000;
    s11d_rope_levels[1] = -20000;
    for (int i = 0; i < 9; ++i) prim->world.m[i / 3][i % 3] = (i + 1) * 101;
    { const short padding = 1234; memcpy((char *)&prim->world + 18, &padding, sizeof(padding)); }
    prim->world.t[0] = 1001;
    prim->world.t[1] = -2002;
    prim->world.t[2] = 3003;
    prim->root = (MATRIX *)0x80012340u;
}

static uint32_t HashBytes(const void *source, size_t size)
{
    const unsigned char *bytes = source;
    uint32_t hash = 2166136261u;
    for (size_t i = 0; i < size; ++i) hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static uint32_t HashWork(const Work *work)
{
    static const size_t offsets[] = {offsetof(Work, control.segs), offsetof(Work, field_A14),
        offsetof(Work, swing_x[13]), offsetof(Work, swing_x[14]),
        offsetof(Work, swing_z[13]), offsetof(Work, swing_z[14])};
    static const uint32_t addresses[] = {0x801c1000u, 0x801c0000u, 0x801d0020u,
        0x801d0070u, 0x801d0024u, 0x801d006cu};
    unsigned char bytes[sizeof(*work)];
    memcpy(bytes, work, sizeof(bytes));
    for (size_t i = 0; i < sizeof(offsets) / sizeof(offsets[0]); ++i)
        memcpy(bytes + offsets[i], &addresses[i], sizeof(addresses[i]));
    return HashBytes(bytes, sizeof(bytes));
}

int main(void)
{
    for (int operation = 0; operation < 5; ++operation)
    {
        for (int index = 0; index < 256; ++index)
        {
            Work work;
            DG_PRIM prim;
            HZD_SEG wall;
            const uint32_t *expected = rappel_rope_fixtures[operation * 256 + index];
            PrepareRope(&work, &prim, &wall, index);
            switch (operation)
            {
            case 0: s11d_rope_800C4B78(&work); break;
            case 1: s11d_rope_800C5584(&work, work.swing_x, 0); break;
            case 2: s11d_rope_800C5584(&work, work.swing_z, 1); break;
            case 3: s11d_rope_800C5E74(&work); break;
            case 4: s11d_rope_800C634C(&work); break;
            }
            if (HashWork(&work) != expected[0] || HashBytes(&prim, 36) != expected[1]
                || boundary_trace != expected[2])
            {
                fprintf(stderr, "Rope op %d case %d: %u/%u/%u expected %u/%u/%u\n",
                    operation, index, HashWork(&work), HashBytes(&prim, 36), boundary_trace,
                    expected[0], expected[1], expected[2]);
                return 1;
            }
        }
    }
    puts("1280 original-MIPS rope physics/geometry fixtures PASS");
    return 0;
}
