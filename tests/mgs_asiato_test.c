#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include "strcode.h"
#include <assert.h>
#include <limits.h>
#include <stddef.h>

CONTROL *GM_WhereList[96];
OBJECT *GM_PlayerBody;
SVECTOR GM_PlayerPosition;
SVECTOR AsiatoPositions[49];
int GM_PlayerStatus, GM_CurrentMap, dword_800AB9D4;

static CONTROL player;
static MAP map;
static HZD_HDL hazard;
static OBJECT body;
static struct {
    DG_OBJS header;
    DG_OBJ joints[16];
} model;
static int pool, footprint_floor, hazard_calls, emission_calls, cases;
static int emitted_foot, emitted_index, emitted_shade;

static int asiato_800D1500(HZD_HDL *hdl, SVECTOR *pos, int name) {
    assert(hdl == &hazard && pos == &GM_PlayerPosition);
    ++hazard_calls;
    if (name == HASH_POOL) {
        assert(hazard_calls == 1);
        return pool;
    }
    assert(name == HASH_ASIATO && hazard_calls == 2);
    return footprint_floor;
}

void *NewAsiatoChar(MATRIX *world, int foot, int level, int index, int shade) {
    assert(foot == 1 || foot == 2);
    assert(world == &model.joints[foot == 1 ? 12 : 15].world);
    assert(level == -400 && GM_CurrentMap == 8);
    emitted_foot = foot;
    emitted_index = index;
    emitted_shade = shade;
    ++emission_calls;
    return NULL;
}

#include "asiato_helpers.inc"

static void Reset(void) {
    memset(&player, 0, sizeof(player));
    memset(AsiatoPositions, 0, sizeof(AsiatoPositions));
    GM_WhereList[0] = &player;
    GM_PlayerBody = &body;
    player.map = &map;
    player.levels[0] = -400;
    map.index = 8;
    map.hzd = &hazard;
    body.objs = &model.header;
    GM_PlayerStatus = PLAYER_MOVE;
    GM_PlayerPosition = (SVECTOR){-1234, 567, 890, 0};
    GM_CurrentMap = -1;
    hazard_calls = emission_calls = 0;
    pool = footprint_floor = 0;
}

static void CheckUnavailablePlayer(void) {
    static const int other_flags[] = {0, 1, PLAYER_MOVE_WATCH, INT_MIN};
    for (int flags = 0; flags < 8; ++flags) {
        int status = (flags & 1 ? PLAYER_MOVE : 0) |
                     (flags & 2 ? PLAYER_GROUND : 0) |
                     (flags & 4 ? PLAYER_CAUTION : 0);
        if (status == PLAYER_MOVE)
            continue;
        for (unsigned int i = 0; i < sizeof(other_flags) / sizeof(other_flags[0]); ++i) {
            Work2 work = {0};
            Reset();
            player.map = NULL;
            GM_PlayerBody = NULL;
            GM_PlayerStatus = status | other_flags[i];
            work.field_20 = 314;
            work.field_24 = 59;
            Act(&work);
            assert(hazard_calls == 0 && emission_calls == 0);
            assert(work.field_20 == 314 && work.field_24 == 59);
            assert(AsiatoPositions[48].vx == 0 && AsiatoPositions[48].vy == 0);
            assert(GM_CurrentMap == -1);
            ++cases;
        }
    }
}

static void CheckActivePlayer(int foot, int wet_ticks, int in_pool, int on_floor) {
    Work2 work = {0};
    int floor_allows = !in_pool && (wet_ticks > 0 || on_floor);
    int expected_foot = floor_allows ? (foot == 2 ? 1 : foot == 10 ? 2 : 0) : 0;
    Reset();
    pool = in_pool;
    footprint_floor = on_floor;
    dword_800AB9D4 = foot;
    work.field_24 = wet_ticks;
    Act(&work);
    assert(hazard_calls == (in_pool || wet_ticks ? 1 : 2));
    assert(work.field_24 == (in_pool ? 60 : wet_ticks > 0 ? wet_ticks - 1 : 0));
    assert(work.field_20 == (!in_pool && wet_ticks > 0 ? 360 - wet_ticks * 2 : 0));
    assert(emission_calls == (expected_foot != 0));
    assert(AsiatoPositions[48].vx == emission_calls);
    assert(AsiatoPositions[48].vy == emission_calls);
    if (expected_foot) {
        assert(emitted_foot == expected_foot && emitted_index == 0);
        assert(emitted_shade == work.field_20);
        assert(AsiatoPositions[0].vx == -1234 && AsiatoPositions[0].vy == 567);
        assert(AsiatoPositions[0].vz == 890 && AsiatoPositions[0].pad == 1);
    } else {
        assert(GM_CurrentMap == -1);
    }
    ++cases;
}

static void CheckRingLimits(void) {
    Work2 work = {0};
    Reset();
    footprint_floor = 1;
    dword_800AB9D4 = 2;
    AsiatoPositions[48].vx = 47;
    AsiatoPositions[48].vy = 47;
    Act(&work);
    assert(emission_calls == 1 && emitted_index == -1);
    assert(AsiatoPositions[48].vx == 0 && AsiatoPositions[48].vy == 48);
    assert(AsiatoPositions[47].vx == -1234 && AsiatoPositions[47].pad == 1);
    hazard_calls = 0;
    Act(&work);
    assert(hazard_calls == 2 && emission_calls == 1);
    assert(AsiatoPositions[48].vx == 0 && AsiatoPositions[48].vy == 48);
    cases += 2;
}

int main(void) {
    _Static_assert(offsetof(typeof(model), joints) == sizeof(DG_OBJS), "joint layout");
    CheckUnavailablePlayer();
    for (int foot = -1; foot <= 12; ++foot)
        for (int wet = 0; wet <= 60; ++wet)
            for (int in_pool = 0; in_pool <= 1; ++in_pool)
                for (int on_floor = 0; on_floor <= 1; ++on_floor)
                    CheckActivePlayer(foot, wet, in_pool, on_floor);
    CheckRingLimits();
    printf("Footprints: %d cinematic, eligibility, wetness and emission cases passed\n", cases);
    return 0;
}
