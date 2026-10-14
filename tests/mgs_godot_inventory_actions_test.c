#include "mgs_godot_inventory_actions.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static uint32_t epoch=3, sent, generation, revision;
static MgsInventoryAction next;
static MgsInventoryActionView view={.active=1,.open_mask=3,.selection=-1,.count=1,.entries={{0,13,2,3}}};
bool MgsGodotHasCapability(unsigned bit) { return bit==MGS_INVENTORY_ACTIONS_CAPABILITY; }
uint32_t MgsGodotSceneEpoch(void) { return epoch; }
void MgsGodotCopySessionId(unsigned char data[16]) { memset(data,7,16); }
void MgsGodotExchange(uint32_t operation, const void *data, uint32_t size, void *reply, uint32_t reply_size)
{
    assert(operation==MGS_GODOT_INVENTORY_ACTION && size==652 && reply_size==32);
    const uint32_t *words=data;
    assert(words[0]==1 && words[1]==epoch && words[2]==0x07070707);
    assert(words[6]==MgsInventoryActionsResult().id && words[7]==MgsInventoryActionsResult().status);
    generation=words[8]; revision=words[9];
    assert(memcmp(words+10,&view,sizeof(view))==0);
    memcpy(reply,&next,sizeof(next));
    ++sent;
}

void MgsGodotRequest(uint32_t operation, const void *data, uint32_t size,
                     uint32_t reply_size, void (*complete)(const void *))
{
    uint32_t reply[16];
    assert(reply_size <= sizeof(reply));
    MgsGodotExchange(operation, data, size, reply, reply_size);
    complete(reply);
}

int main(void)
{
    next=(MgsInventoryAction){.schema=1};
    MgsGodotInventoryActionsBegin();
    MgsGodotInventoryActionsView(&view);
    MgsGodotPublishInventoryActions();
    assert(generation && revision);
    next=(MgsInventoryAction){1,1,epoch,generation,revision,MGS_INV_OPEN,0,0};
    MgsGodotPublishInventoryActions();
    MgsGodotInventoryActionsReset();
    MgsGodotInventoryActionsView(&view);
    MgsInventoryAction taken;
    assert(MgsInventoryActionsTake(&taken));
    MgsInventoryActionsComplete(MGS_INV_APPLIED);
    next=(MgsInventoryAction){.schema=1};
    MgsGodotPublishInventoryActions();
    assert(MgsInventoryActionsResult().status==MGS_INV_APPLIED && sent==3);
    next=(MgsInventoryAction){1,2,epoch,generation,revision,MGS_INV_OPEN,0,0};
    MgsGodotPublishInventoryActions();
    MgsGodotInventoryActionsEnd();
    assert(!MgsInventoryActionsTake(&taken) && MgsInventoryActionsResult().status==MGS_INV_STALE);
    ++epoch;
    view=(MgsInventoryActionView){0};
    next=(MgsInventoryAction){.schema=1};
    MgsGodotPublishInventoryActions();
    puts("Inventory wire: high-bit capability, public identity, entries, acknowledgements, draw reset and actor end pass.");
    return 0;
}
