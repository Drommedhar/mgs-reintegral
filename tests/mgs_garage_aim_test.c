#include "mgs_native.h"
#undef fprintf
#include "overlays/s19a/props_native.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    short angles[3], matrix[9];
    uint32_t geometry[3];
} AimFixture;
#include "mgs_garage_aim_fixtures.h"

SVECTOR GarageGunOffset = {0, 1435, -925, 0};
SVECTOR GarageBulletOffset = {0, 286, 574, 0};
SVECTOR GarageBulletRotation = {3072, 0, 0, 0};
MATRIX *GarageGunWorld;
static MATRIX bullet;
static int bullet_calls, sound_calls, casing_calls;

#include "garage_aim_helpers.inc"

void *NewBullet(MATRIX *world, int side, int color, int type)
{
    assert(side == 1 && color == 1 && type == 0);
    bullet = *world;
    ++bullet_calls;
    return &bullet;
}

void GM_SeSet(SVECTOR *position, int sound)
{
    assert(sound == 46);
    assert(position->vx == bullet.t[0] && position->vy == bullet.t[1] && position->vz == bullet.t[2]);
    ++sound_calls;
}

void Garage_800DC0D4(MATRIX *matrix)
{
    assert(memcmp(matrix->m, bullet.m, sizeof(bullet.m)) == 0);
    assert(memcmp(matrix->t, bullet.t, sizeof(bullet.t)) == 0);
    ++casing_calls;
}

static uint32_t Hash(uint32_t value, const void *data, size_t size)
{
    const unsigned char *bytes = data;
    for (size_t i = 0; i < size; ++i)
        value = (value ^ bytes[i]) * 16777619u;
    return value;
}

static uint32_t Geometry(const MATRIX *gun)
{
    SVECTOR step = {0, -750, 0, 0}, start = {0, 400, 0, 0};
    DG_SetPos(&bullet);
    DG_RotVector(&step, &step, 1);
    DG_PutVector(&start, &start, 1);
    uint32_t hash = Hash(2166136261u, gun->m, sizeof(gun->m));
    hash = Hash(hash, gun->t, sizeof(gun->t));
    hash = Hash(hash, bullet.m, sizeof(bullet.m));
    hash = Hash(hash, bullet.t, sizeof(bullet.t));
    hash = Hash(hash, &step, 6);
    return Hash(hash, &start, 6);
}

static void CheckFixture(const AimFixture *fixture, unsigned index)
{
    GarageSnake work = {0};
    CONTROL control = {0};
    MATRIX observed;
    MATRIX rotation;
    work.aim = (SVECTOR){fixture->angles[0], fixture->angles[1], fixture->angles[2], 0};
    memset(&rotation, 0xa5, sizeof(rotation));
    RotMatrixZYX(&work.aim, &rotation);
    assert(memcmp(rotation.m, fixture->matrix, sizeof(rotation.m)) == 0);
    assert(rotation.t[0] == (int)0xa5a5a5a5u && rotation.t[2] == (int)0xa5a5a5a5u);
    work.root_control = &control;
    GarageGunWorld = &observed;
    for (unsigned root = 0; root < 3; ++root) {
        MATRIX parent = fixture_roots[root];
        work.root_matrix = &parent;
        control.rot.vy = (short)(root * 1499);
        BuildAim(&work);
        assert(memcmp(observed.m, work.field_8E4.m, sizeof(observed.m)) == 0);
        assert(work.field_8CC.vy == ((work.aim.vy + control.rot.vy) & 4095));
        Garage_800DA8A0(&work);
        uint32_t actual = Geometry(&work.field_8E4);
        if (actual != fixture->geometry[root]) {
            fprintf(stderr, "Garage aim fixture%u root%u angles=(%d,%d,%d): %08x != %08x\n",
                    index, root, work.aim.vx, work.aim.vy, work.aim.vz, actual, fixture->geometry[root]);
            exit(1);
        }
    }
}

int main(void)
{
    unsigned count = sizeof(aim_fixtures) / sizeof(aim_fixtures[0]);
    for (unsigned i = 0; i < count; ++i)
        CheckFixture(&aim_fixtures[i], i);
    assert(bullet_calls == (int)count * 3 && sound_calls == bullet_calls && casing_calls == bullet_calls);
    printf("PASS: %u retail MIPS rotations; %u live-controller/bullet compositions.\n", count, count * 3);
    return 0;
}
