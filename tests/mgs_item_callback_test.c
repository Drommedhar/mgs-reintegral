#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include "libgcl/libgcl.h"
#include <assert.h>
#include <stdint.h>
#include "item_callback_helpers.inc"

static Work item;
static DG_PRIM shadow;
static int cleanup_step, callback_count, callback_kind;
static uintptr_t callback_value;

void GM_FreeControl(CONTROL *control) {
    assert(control == &item.control && cleanup_step == 0);
    cleanup_step = 1;
}

void GM_FreeObject(OBJECT *object) {
    assert(object == (OBJECT *)&item.body && cleanup_step == 1);
    cleanup_step = 2;
}

void DG_DequeuePrim(DG_PRIM *prim) {
    assert(prim == &shadow && cleanup_step == 2);
    cleanup_step = 3;
}

void DG_FreePrim(DG_PRIM *prim) {
    assert(prim == &shadow && cleanup_step == 3);
    cleanup_step = 4;
}

int GCL_ExecBlock(char *block, GCL_ARGS *args) {
    assert(cleanup_step == (item.shadow ? 4 : 2) && args == NULL);
    callback_count++;
    callback_kind = 1;
    callback_value = (uintptr_t)block;
    return 0;
}

int GCL_ExecProc(int proc, GCL_ARGS *args) {
    assert(cleanup_step == (item.shadow ? 4 : 2) && args == NULL);
    callback_count++;
    callback_kind = 2;
    callback_value = (unsigned int)proc;
    return 0;
}

static void CheckDispatch(int state, unsigned int value, int expected_kind,
                          int with_shadow) {
    memset(&item, 0, sizeof(item));
    item.state = state;
    item.end_proc = (int)value;
    item.shadow = with_shadow ? &shadow : NULL;
    cleanup_step = callback_count = callback_kind = 0;
    callback_value = 0;
    Die(&item);
    assert(cleanup_step == (with_shadow ? 4 : 2));
    assert(callback_count == (expected_kind != 0));
    assert(callback_kind == expected_kind);
    assert(callback_value == (expected_kind ? value : 0));
}

int main(void) {
    static const unsigned int block_addresses[] = {
        0x00010000u, 0x009c3961u, 0x12345678u, 0x7fffffffu,
        0x80000000u, 0x80012345u, 0xfffffff0u
    };
    static const unsigned int proc_ids[] = {1, 0x1234, 0x9c39, 0xffff};
    static unsigned char script_block[4];
    assert((uintptr_t)script_block > 0xffffu);
    for (int shadow_present = 0; shadow_present <= 1; ++shadow_present) {
        for (int state = 0; state <= 3; ++state) {
            CheckDispatch(state, 0, 0, shadow_present);
            for (unsigned int i = 0; i < sizeof(proc_ids) / sizeof(proc_ids[0]); ++i)
                CheckDispatch(state, proc_ids[i], state == 2 ? 2 : 0, shadow_present);
            for (unsigned int i = 0; i < sizeof(block_addresses) / sizeof(block_addresses[0]); ++i)
                CheckDispatch(state, block_addresses[i], state == 2 ? 1 : 0, shadow_present);
            CheckDispatch(state, (unsigned int)(uintptr_t)script_block,
                          state == 2 ? 1 : 0, shadow_present);
        }
    }
    puts("Item callbacks: 104 cleanup/dispatch cases passed");
    return 0;
}
