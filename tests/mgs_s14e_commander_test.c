#include "mgs_native.h"
#undef fprintf
#include "animal/zako14/zako.h"
#include <assert.h>
#include <limits.h>

COMMANDER ZAKO14Command;
static const int ChaseDis[8] = {3000, 4000, 7000, 8000, 8000, 8000, 8000, 8000};
#include "s14e_commander_helpers.inc"

static void CheckAmbush(unsigned retired)
{
    static const int order[8][3] = {
        {1, 2, 0}, {1, 2, 0}, {2, 0, 1}, {2, 0, 1},
        {1, 0, 2}, {1, 0, 2}, {0, 1, 2}, {0, 1, 2}
    };
    Work guards[3] = {0};
    memset(&ZAKO14Command, 0, sizeof(ZAKO14Command));
    ZAKO14Command.n_watchers = 3;
    for (int id = 0; id < 3; ++id) {
        assert(ZAKO14SetWorkID(&guards[id]) == id);
        guards[id].sn_dis = id ? 100 : 200;
        guards[id].chase_dis = -1;
        ZAKO14Command.prio[id] = id;
    }
    for (int id = 2; id >= 0; --id)
        if (retired & (1u << id)) ZAKO14ResetWorkID(id);
    for (int pass = 0; pass < 2; ++pass) {
        ChangePrio(&ZAKO14Command);
        assert(ZAKO14Command.n_watchers == 3);
        for (int id = 0; id < 3; ++id) {
            assert(ZAKO14Command.prio[id] == order[retired][id]);
            if (retired & (1u << id)) {
                assert(guards[id].chase_dis == -1);
                assert(ZAKO14Command.watchers[id].work == NULL);
                assert(ZAKO14Command.watchers[id].field_4 == 1);
            } else {
                assert(guards[id].chase_dis == ChaseDis[id]);
                assert(ZAKO14Command.watchers[id].work == &guards[id]);
            }
        }
    }
}

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    for (unsigned retired = 0; retired < 8; ++retired) CheckAmbush(retired);
    memset(&ZAKO14Command, 0, sizeof(ZAKO14Command));
    ChangePrio(&ZAKO14Command);
    ZAKO14Command.n_watchers = 8;
    for (int id = 0; id < 8; ++id) ZAKO14Command.prio[id] = id;
    ChangePrio(&ZAKO14Command);
    for (int id = 0; id < 8; ++id) assert(ZAKO14Command.prio[id] == id);
    puts("Cargo commander: all ambush retirement combinations and empty registries passed.");
    return 0;
}
