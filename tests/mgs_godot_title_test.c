#include "mgs_godot_title.h"
#include "mgs_title_actions.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static uint32_t epoch = 3, queued, bytes;
static unsigned char session = 7, wire[400000];
static bool capable = true, actions;
static MgsTitleAction command;
uint32_t MgsGodotSceneEpoch(void) { return epoch; }
bool MgsGodotHasCapability(unsigned bit) { return bit == MGS_TITLE_ACTIONS_CAPABILITY ? actions : capable; }
void MgsGodotCopySessionId(unsigned char data[16]) { memset(data, session, 16); }
void MgsGodotQueue(uint32_t op, const void *header, uint32_t size, const void *data, uint32_t count)
{
    assert(op == MGS_GODOT_TITLE && size == 72 && size + count <= sizeof(wire));
    memcpy(wire, header, size);
    memcpy(wire + size, data, count);
    bytes = size + count;
    ++queued;
}
void MgsGodotExchange(uint32_t op, const void *header, uint32_t size, void *data, uint32_t count)
{
    assert(op == MGS_GODOT_TITLE_ACTION && size == 32 && count == sizeof(command));
    const unsigned char *ack = header;
    assert(ack[8] == session);
    if (!command.schema) command.schema = 1;
    memcpy(data, &command, count);
    command = (MgsTitleAction){.schema=1};
}
static uint32_t Word(unsigned offset)
{
    uint32_t value;
    memcpy(&value, wire + offset, 4);
    return value;
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
    MgsTitleElement elements[MGS_TITLE_ELEMENTS] = {{0}};
    unsigned char buffer[16];
    uint16_t palette[16] = {0,0,0,32767};
    MgsGodotTitleBegin();
    MgsGodotTitleBeginText(23, buffer);
    MgsTextLayoutEmit(buffer, (MgsTextGlyph){.kind=MGS_TEXT_DASH,.width=18,.height=1}, NULL);
    MgsTextLayoutEnd(palette, 128, 21);
    MgsGodotTitleView((MgsTitleFrame){.active=1,.selection=2}, elements, 0);
    MgsSubtitleFrame text = {.active=1,.visible=1,.x=12,.y=190,.width=128,.height=21};
    MgsGodotTitleText(23,text,palette);
    MgsGodotPublishTitle();
    const unsigned at = 72 + sizeof(elements);
    assert(Word(32)==1 && Word(64)==55 && Word(68)==1 && Word(at)==23);
    assert(Word(at+16)==1 && Word(at+88)==1 && bytes==at+132+80);
    MgsGodotPublishTitle();
    assert(Word(at+16)==0 && bytes==at+132);
    palette[3]=31;
    MgsGodotTitleText(23,text,palette);
    MgsGodotPublishTitle();
    assert(Word(at+16)==1 && wire[at+106]==31);
    MgsGodotResetTitle();
    MgsGodotTitleView((MgsTitleFrame){.active=1},elements,0);
    ++session;
    MgsGodotPublishTitle();
    assert(Word(68)==0);
    MgsGodotTitleText(23,text,palette);
    MgsGodotPublishTitle();
    assert(Word(at+16)==1 && wire[16]==session);
    ++epoch;
    MgsGodotPublishTitle();
    assert(bytes==72 && Word(4)==epoch && Word(32)==0 && Word(64)==0);
    MgsGodotTitleEnd();
    capable=false;
    MgsGodotPublishTitle();
    assert(queued==6);
    capable=actions=true;
    MgsTitleFrame view={.active=1,.mode=7,.selection=0};
    MgsGodotTitleBegin();
    MgsGodotTitleView(view,elements,1);
    MgsGodotPublishTitle();
    unsigned revision=Word(12), generation=Word(8);
    assert(revision);
    command=(MgsTitleAction){1,1,epoch,generation,revision,MGS_TITLE_ACTIVATE,0};
    MgsGodotPublishTitle();
    assert(MgsTitleActionsResult().status==MGS_TITLE_PENDING);
    MgsGodotResetTitle();
    MgsTitleAction taken;
    assert(MgsTitleActionsTake(view,1,&taken) && taken.id==1);
    MgsTitleActionsComplete(MGS_TITLE_APPLIED);
    MgsGodotTitleView(view,elements,0);
    MgsGodotPublishTitle();
    assert(!Word(12));
    MgsGodotTitleView(view,elements,1);
    MgsGodotPublishTitle();
    command=(MgsTitleAction){1,2,epoch,generation,Word(12),MGS_TITLE_BACK,0};
    MgsGodotPublishTitle();
    MgsGodotTitleEnd();
    assert(MgsTitleActionsResult().status==MGS_TITLE_STALE);
    puts("Title: resource/text deltas, palette change, delayed session resync and epoch clearing pass.");
    return 0;
}
