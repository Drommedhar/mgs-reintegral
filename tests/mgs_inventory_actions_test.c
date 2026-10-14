#include "mgs_inventory_actions.h"
#include <assert.h>
#include <stdio.h>

static MgsInventoryActionView view = {.active=1,.open_mask=3,.selection=-1};

static MgsInventoryAction Command(unsigned kind, unsigned side, int target)
{
    unsigned revision = MgsInventoryActionsView(&view,3,7);
    return (MgsInventoryAction){1,MgsInventoryActionsResult().id+1,3,7,revision,kind,side,target};
}

static void Request(unsigned kind, unsigned side, int target, unsigned expected)
{
    MgsInventoryAction command=Command(kind,side,target), taken;
    assert(MgsInventoryActionsSubmit(&command));
    assert(MgsInventoryActionsResult().status==expected);
    if (expected==MGS_INV_PENDING) {
        assert(MgsInventoryActionsTake(&taken) && taken.kind==kind && taken.side==side && taken.target==target);
        MgsInventoryActionsComplete(MGS_INV_APPLIED);
    }
}

int main(void)
{
    Request(MGS_INV_OPEN,0,0,MGS_INV_PENDING);
    Request(MGS_INV_OPEN,1,0,MGS_INV_PENDING);
    Request(MGS_INV_OPEN,2,0,MGS_INV_INVALID);
    Request(MGS_INV_OPEN,0,1,MGS_INV_INVALID);
    view.open_mask=0;
    Request(MGS_INV_OPEN,0,0,MGS_INV_INVALID);
    view.mode=1; view.owned=1; view.allowed=60; view.count=4; view.selection=13;
    view.entries[0]=(MgsInventoryEntry){0,-1,1,MGS_INV_EQUIPPABLE};
    view.entries[1]=(MgsInventoryEntry){0,13,2,MGS_INV_EQUIPPABLE|MGS_INV_USABLE};
    view.entries[2]=(MgsInventoryEntry){0,2,1,0};
    view.entries[3]=(MgsInventoryEntry){1,0,12,MGS_INV_EQUIPPABLE};
    Request(MGS_INV_SELECT,0,2,MGS_INV_PENDING);
    Request(MGS_INV_EQUIP,0,2,MGS_INV_INVALID);
    Request(MGS_INV_EQUIP,0,-1,MGS_INV_PENDING);
    Request(MGS_INV_EQUIP,0,23,MGS_INV_INVALID);
    Request(MGS_INV_USE,0,13,MGS_INV_PENDING);
    Request(MGS_INV_USE,0,2,MGS_INV_INVALID);
    Request(MGS_INV_USE,1,0,MGS_INV_INVALID);
    view.entries[1].flags &= ~MGS_INV_USABLE;
    Request(MGS_INV_USE,0,13,MGS_INV_INVALID);
    Request(MGS_INV_CLOSE,0,0,MGS_INV_PENDING);
    Request(MGS_INV_CLOSE,0,13,MGS_INV_INVALID);
    MgsInventoryAction command=Command(MGS_INV_EQUIP,0,13), taken;
    assert(MgsInventoryActionsSubmit(&command));
    assert(!MgsInventoryActionsSubmit(&command));
    --view.entries[1].quantity;
    MgsInventoryActionsView(&view,3,7);
    assert(!MgsInventoryActionsTake(&taken) && MgsInventoryActionsResult().status==MGS_INV_STALE);
    command=Command(MGS_INV_CLOSE,0,0);
    assert(MgsInventoryActionsSubmit(&command));
    MgsInventoryActionsView(&view,3,8);
    assert(!MgsInventoryActionsTake(&taken) && MgsInventoryActionsResult().status==MGS_INV_STALE);
    command=Command(MGS_INV_CLOSE,0,0);
    --command.epoch;
    assert(MgsInventoryActionsSubmit(&command) && MgsInventoryActionsResult().status==MGS_INV_STALE);
    view.active=0;
    Request(MGS_INV_OPEN,0,0,MGS_INV_BUSY);
    puts("Inventory actions: side/identity, ownership, disabled equipment, consumable guards and stale single-flight requests pass.");
    return 0;
}
