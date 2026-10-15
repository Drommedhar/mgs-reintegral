#include "mgs_codec_actions.h"
#include <assert.h>
#include <stdio.h>

static MgsCodecActionView view = {1,1,1,14085,1022,0,4};
static uintptr_t item = 10;

static MgsCodecAction Command(unsigned kind, unsigned target)
{
    unsigned revision = MgsCodecActionsView(view,3,7,item);
    return (MgsCodecAction){1,MgsCodecActionsResult().id+1,3,7,revision,kind,target};
}

static void Request(unsigned kind, unsigned target, unsigned expected)
{
    MgsCodecAction command=Command(kind,target), taken;
    assert(MgsCodecActionsSubmit(&command));
    assert(MgsCodecActionsResult().status==expected);
    if (expected==MGS_CODEC_PENDING) {
        assert(MgsCodecActionsTake(&taken) && taken.kind==kind && taken.target==target);
        MgsCodecActionsComplete();
    }
}

int main(void)
{
    Request(MGS_CODEC_TUNE,14000,MGS_CODEC_PENDING);
    Request(MGS_CODEC_TUNE,14199,MGS_CODEC_PENDING);
    Request(MGS_CODEC_TUNE,13999,MGS_CODEC_INVALID);
    Request(MGS_CODEC_TUNE,14200,MGS_CODEC_INVALID);
    Request(MGS_CODEC_CONFIRM,3,MGS_CODEC_PENDING);
    Request(MGS_CODEC_CONFIRM,4,MGS_CODEC_INVALID);
    Request(MGS_CODEC_SELECT,0,MGS_CODEC_PENDING);
    Request(MGS_CODEC_CALL,1,MGS_CODEC_INVALID);
    Request(0,0,MGS_CODEC_INVALID);
    Request(32,0,MGS_CODEC_INVALID);
    view.allowed=1u<<MGS_CODEC_ADVANCE;
    Request(MGS_CODEC_SKIP,0,MGS_CODEC_INVALID);
    Request(MGS_CODEC_ADVANCE,0,MGS_CODEC_PENDING);
    MgsCodecAction command=Command(MGS_CODEC_ADVANCE,0), taken;
    assert(MgsCodecActionsSubmit(&command));
    assert(!MgsCodecActionsSubmit(&command));
    ++command.id;
    assert(!MgsCodecActionsSubmit(&command));
    MgsCodecActionsView(view,3,7,++item);
    assert(!MgsCodecActionsTake(&taken) && MgsCodecActionsResult().status==MGS_CODEC_STALE);
    command=Command(MGS_CODEC_ADVANCE,0);
    assert(MgsCodecActionsSubmit(&command));
    view.allowed=0;
    MgsCodecActionsView(view,3,7,item);
    assert(!MgsCodecActionsTake(&taken) && MgsCodecActionsResult().status==MGS_CODEC_STALE);
    command=Command(MGS_CODEC_ADVANCE,0);
    --command.epoch;
    assert(MgsCodecActionsSubmit(&command) && MgsCodecActionsResult().status==MGS_CODEC_STALE);
    command=Command(MGS_CODEC_ADVANCE,0);
    --command.generation;
    assert(MgsCodecActionsSubmit(&command) && MgsCodecActionsResult().status==MGS_CODEC_STALE);
    view.active=0;
    Request(MGS_CODEC_OPEN,0,MGS_CODEC_BUSY);
    puts("Codec actions: tuning bounds, choices, locked skips, dialogue identity, lifecycle and single flight pass.");
    return 0;
}
