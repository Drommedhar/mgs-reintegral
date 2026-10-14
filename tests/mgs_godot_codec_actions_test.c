#include "mgs_godot_codec_actions.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static uint32_t epoch=3, sent, generation, revision;
static MgsCodecAction next;
static MgsCodecActionView view={1,1,1,14085,1u<<MGS_CODEC_CALL,0,0};
bool MgsGodotHasCapability(unsigned bit) { return bit==MGS_CODEC_ACTIONS_CAPABILITY; }
uint32_t MgsGodotSceneEpoch(void) { return epoch; }
void MgsGodotCopySessionId(unsigned char data[16]) { memset(data,7,16); }
void MgsGodotExchange(uint32_t operation, const void *data, uint32_t size, void *reply, uint32_t reply_size)
{
    assert(operation==MGS_GODOT_CODEC_ACTION && size==68 && reply_size==28);
    const uint32_t *words=data;
    assert(words[0]==1 && words[1]==epoch && words[2]==0x07070707);
    assert(words[6]==MgsCodecActionsResult().id && words[7]==MgsCodecActionsResult().status);
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
    next=(MgsCodecAction){.schema=1};
    MgsGodotCodecActionsBegin();
    MgsGodotCodecActionsView(view,0);
    MgsGodotPublishCodecActions();
    assert(generation && revision);
    next=(MgsCodecAction){1,1,epoch,generation,revision,MGS_CODEC_CALL,0};
    MgsGodotPublishCodecActions();
    MgsGodotCodecActionsReset();
    MgsGodotCodecActionsView(view,0);
    MgsCodecAction taken;
    assert(MgsCodecActionsTake(&taken));
    MgsCodecActionsComplete();
    next=(MgsCodecAction){.schema=1};
    MgsGodotPublishCodecActions();
    assert(MgsCodecActionsResult().status==MGS_CODEC_APPLIED && sent==3);
    next=(MgsCodecAction){1,2,epoch,generation,revision,MGS_CODEC_CALL,0};
    MgsGodotPublishCodecActions();
    MgsGodotCodecActionsEnd();
    assert(!MgsCodecActionsTake(&taken) && MgsCodecActionsResult().status==MGS_CODEC_STALE);
    ++epoch;
    view=(MgsCodecActionView){0};
    next=(MgsCodecAction){.schema=1};
    MgsGodotPublishCodecActions();
    puts("Codec actions wire: public identity, snapshot, acknowledgement, draw reset and actor end pass.");
    return 0;
}
