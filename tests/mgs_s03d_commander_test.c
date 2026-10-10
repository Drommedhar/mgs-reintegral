#include "mgs_native.h"
#undef fprintf
#include "overlays/s03d/animal/zako/zako.h"
#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>

ZakoComMgr s03d_commander;
#include "s03d_commander_helpers.inc"

static void CheckRetirement(unsigned removed)
{
    static const int expected_order[8][3] = {
        {1, 2, 0}, {1, 2, 0}, {2, 0, 1}, {2, 0, 1},
        {1, 0, 2}, {1, 0, 2}, {0, 1, 2}, {0, 1, 2}
    };
    static const int ranges[] = {3000, 4000, 7000};
    ZakoActor actors[3] = {0};
    memset(&s03d_commander, 0, sizeof(s03d_commander));
    s03d_commander.count = 3;
    for (int i = 0; i < 3; ++i) {
        s03d_commander.field_40[i] = i;
        s03d_commander.entries[i].field_C = &actors[i];
        s03d_commander.entries[i].field_4 = i == 1 ? 1 : 2;
        actors[i].field_B90 = i == 0 ? 5000 : 1000;
        actors[i].field_B64 = -1;
        if (removed & (1u << i))
            ZakoCom_800D4050(i);
    }
    s03d_800D47BC(&s03d_commander);
    assert(s03d_commander.count == 3);
    for (int i = 0; i < 3; ++i) {
        assert(s03d_commander.field_40[i] == expected_order[removed][i]);
        if (removed & (1u << i)) {
            assert(s03d_commander.entries[i].field_C == NULL);
            assert(s03d_commander.entries[i].field_4 == 1);
            assert(actors[i].field_B64 == -1);
        } else {
            assert(s03d_commander.entries[i].field_C == &actors[i]);
            assert(actors[i].field_B64 == ranges[i]);
        }
    }
    s03d_800D47BC(&s03d_commander);
    assert(memcmp(s03d_commander.field_40, expected_order[removed],
                  sizeof(expected_order[removed])) == 0);
}

int main(void)
{
    for (unsigned removed = 0; removed < 8; ++removed)
        CheckRetirement(removed);
    memset(&s03d_commander, 0, sizeof(s03d_commander));
    s03d_800D47BC(&s03d_commander);
    puts("S03d guard retirement: live, partial, empty and stable ordering passed");
    return 0;
}
