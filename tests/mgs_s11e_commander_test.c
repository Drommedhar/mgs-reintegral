#include "mgs_native.h"
#undef fprintf
#include "enemy/enemy.h"
#include <assert.h>
#include <limits.h>

ZAKO_COMMAND ZakoCommand_800DF280;
int s11e_dword_800C3908[8] = {3000, 4000, 7000, 8000, 8000, 8000, 8000, 8000};
#include "s11e_commander_helpers.inc"

static void CheckRetirement(unsigned removed)
{
    static const int distances[8] = {3000, 1000, 2000, 1000, 5000, 4000, 7000, 6000};
    static const int sorted[8] = {1, 3, 2, 0, 5, 4, 7, 6};
    ZakoWork actors[8] = {0};
    ZAKO_COMMAND *command = &ZakoCommand_800DF280;
    int expected[8], count = 0;
    memset(command, 0, sizeof(*command));
    command->field_0x08 = 8;
    for (int i = 0; i < 8; ++i) {
        assert(s11e_zk11ecom_800D9A20(&actors[i]) == i);
        command->field_0x40[i] = i;
        actors[i].sn_dis = distances[i];
        actors[i].field_BFC = -1;
        if (!(removed & (1u << sorted[i]))) expected[count++] = sorted[i];
    }
    for (int i = 0; i < 8; ++i)
        if (removed & (1u << i)) {
            s11e_zk11ecom_800D9A64(i);
            expected[count++] = i;
        }
    assert(count == 8);
    for (int pass = 0; pass < 2; ++pass) {
        s11e_zk11ecom_800DA16C(command);
        assert(command->field_0x08 == 8);
        for (int i = 0; i < 8; ++i) {
            assert(command->field_0x40[i] == expected[i]);
            if (removed & (1u << i)) {
                assert(command->field_0x8C[i].watcher == NULL);
                assert(command->field_0x8C[i].field_04 == 1);
                assert(actors[i].field_BFC == -1);
            } else {
                assert(command->field_0x8C[i].watcher == (WatcherWork *)&actors[i]);
                assert(actors[i].field_BFC == s11e_dword_800C3908[i]);
            }
        }
    }
    for (int i = 0; i < 8; ++i)
        if (removed & (1u << i))
            assert(s11e_zk11ecom_800D9A20(&actors[i]) == i);
    s11e_zk11ecom_800DA16C(command);
    for (int i = 0; i < 8; ++i) {
        assert(actors[i].field_BFC == s11e_dword_800C3908[i]);
        if (i)
            assert(actors[command->field_0x40[i - 1]].sn_dis <= actors[command->field_0x40[i]].sn_dis);
    }
}

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    for (unsigned removed = 0; removed < 256; ++removed) CheckRetirement(removed);
    memset(&ZakoCommand_800DF280, 0, sizeof(ZakoCommand_800DF280));
    s11e_zk11ecom_800DA16C(&ZakoCommand_800DF280);
    puts("Elevator commander: 256 retirement masks, stable sorting and slot reuse passed.");
    return 0;
}
