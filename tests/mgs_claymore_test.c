#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include <assert.h>

enum { NO_HIT, WALL_HIT, FLOOR_HIT };
static int hit_kind, point_reads, normal_reads;
static MAP map;
static HZD_HDL hazard;
static HZD_FLR floor_data;
static SVECTOR origin = {123, -456, 789, 0};
static SVECTOR direction = {0};

void DG_SetPos2(SVECTOR *position, SVECTOR *rotation)
{
    assert(position == &origin && rotation == &direction);
}

static void CheckedPutVector(SVECTOR *from, SVECTOR *to, int count, size_t capacity)
{
    assert(count == 2);
    if (capacity < count * sizeof(*to)) {
        fprintf(stderr, "Claymore trajectory requires two vectors; caller provides %zu bytes\n", capacity);
        exit(1);
    }
    for (int i = 0; i < count; ++i) {
        to[i] = from[i];
        to[i].vx += origin.vx;
        to[i].vy += origin.vy;
        to[i].vz += origin.vz;
    }
}

#include "claymore_helpers.inc"

int HZD_OnlineHazardCheck(HZD_HDL *hzd, SVECTOR *from, SVECTOR *to, int flags, int attributes)
{
    assert(hzd == &hazard && flags == HZD_CHK_ALL && attributes == HZD_SEG_NO_PLAYER);
    assert(from->vx == 123 && from->vy == -456 && from->vz == 989);
    assert(to->vx == 123 && to->vy == -456 && to->vz == 10789);
    return hit_kind != NO_HIT;
}

void HZD_GetOnlinePoint(SVECTOR *point)
{
    ++point_reads;
    *point = (SVECTOR){123, -456, 3989, 0};
}

void *HZD_GetOnlineHazard(void)
{
    return hit_kind == FLOOR_HIT ? HZD_FLOOR_HAZARD(&floor_data) : &floor_data;
}

void HZD_NormalVector(void *hzd, SVECTOR *normal)
{
    assert(hit_kind == WALL_HIT && hzd == &floor_data);
    ++normal_reads;
    *normal = (SVECTOR){-9, 8, 7, 0};
}

int GV_VecLen3(SVECTOR *delta)
{
    assert(delta->vx == 0 && delta->vy == 0 && delta->vz > 0);
    return delta->vz;
}

static void CheckTrajectory(int kind)
{
    Work work = {0};
    work.field_118 = (SVECTOR){-1, -2, -3, 0};
    hit_kind = kind;
    point_reads = normal_reads = 0;
    int length = claymore_loader_helper_800735A0(&work, &origin, &direction);
    assert(length == (kind == NO_HIT ? 9800 : 3000));
    assert(work.field_128 == (kind != NO_HIT));
    assert(work.field_110.vx == 123 && work.field_110.vy == -456);
    assert(work.field_110.vz == (kind == NO_HIT ? 10789 : 3989));
    assert(point_reads == (kind != NO_HIT));
    assert(normal_reads == (kind == WALL_HIT));
    static const SVECTOR normals[] = {{-1, -2, -3, 0}, {-9, 8, 7, 0}, {-40, 60, 50, 0}};
    assert(memcmp(&work.field_118, &normals[kind], sizeof(SVECTOR)) == 0);
}

int main(void)
{
    _Static_assert(sizeof(Work) == 0x12c, "Original claymore actor size");
    map.hzd = &hazard;
    claymore_MAP_800bdf08 = &map;
    floor_data.p1.h = -40;
    floor_data.p2.h = 50;
    floor_data.p3.h = 60;
    for (int kind = NO_HIT; kind <= FLOOR_HIT; ++kind)
        CheckTrajectory(kind);
    puts("Claymore trajectory: two-vector capacity, clear ray, wall and floor passed");
    return 0;
}
