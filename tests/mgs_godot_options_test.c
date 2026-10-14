#include "mgs_godot_options.h"
#include "mgs_options_actions.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static uint32_t epoch = 3, queued, bytes;
static unsigned char session = 7, wire[400000];
static bool capable = true;
uint32_t MgsGodotSceneEpoch(void) { return epoch; }
bool MgsGodotHasCapability(unsigned bit) { assert(bit == MGS_GODOT_OPTIONS_CAPABILITY || bit == MGS_OPTIONS_ACTIONS_CAPABILITY); return capable; }
void MgsGodotCopySessionId(unsigned char data[16]) { memset(data, session, 16); }
void MgsGodotQueue(uint32_t op, const void *header, uint32_t size, const void *data, uint32_t count)
{
    assert(op == MGS_GODOT_OPTIONS && size == 104 && size + count <= sizeof(wire));
    memcpy(wire, header, size);
    memcpy(wire + size, data, count);
    bytes = size + count;
    ++queued;
}
static uint32_t Word(unsigned offset)
{
    uint32_t value;
    memcpy(&value, wire + offset, 4);
    return value;
}
void MgsGodotExchange(uint32_t op, const void *data, uint32_t size, void *reply, uint32_t reply_size)
{
    assert(op == MGS_GODOT_OPTIONS_ACTION && size == 32 && reply_size == sizeof(MgsOptionsAction));
    assert(((const uint32_t *)data)[1] == epoch && Word(12) != 0);
    *(MgsOptionsAction *)reply = (MgsOptionsAction){.schema = 1};
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
    MgsOptionsElement elements[MGS_OPTIONS_ELEMENTS] = {{0}};
    unsigned char buffer[16];
    uint16_t palette[16] = {0,0,0,32767};
    MgsGodotOptionsBegin();
    MgsGodotOptionsBeginText(30, buffer);
    MgsTextLayoutEmit(buffer, (MgsTextGlyph){.kind=MGS_TEXT_DASH,.width=18,.height=1}, NULL);
    MgsTextLayoutEnd(palette, 128, 21);
    MgsGodotOptionsView((MgsOptionsFrame){.active=1,.selection=2}, elements);
    MgsSubtitleFrame text = {.active=1,.visible=1,.x=12,.y=190,.width=128,.height=21};
    MgsGodotOptionsText(30,text,palette);
    MgsGodotPublishOptions();
    const unsigned at = 104 + sizeof(elements);
    assert(Word(32)==1 && Word(96)==57 && Word(100)==1 && Word(at)==30);
    assert(Word(at+16)==1 && Word(at+88)==1 && bytes==at+132+80);
    MgsGodotPublishOptions();
    assert(Word(at+16)==0 && bytes==at+132);
    palette[3]=31;
    MgsGodotOptionsText(30,text,palette);
    MgsGodotPublishOptions();
    assert(Word(at+16)==1 && wire[at+106]==31);
    MgsOptionsAction action = {1,1,epoch,Word(8),Word(12),MGS_OPTIONS_SET,3,1};
    assert(MgsOptionsActionsSubmit(&action));
    MgsGodotResetOptions();
    MgsOptionsAction consumed;
    assert(MgsOptionsActionsTake((MgsOptionsFrame){.active=1,.selection=2}, &consumed));
    assert(consumed.id == 1 && consumed.target == 3 && consumed.value == 1);
    MgsOptionsActionsComplete(MGS_OPTIONS_APPLIED);
    MgsGodotOptionsView((MgsOptionsFrame){.active=1},elements);
    ++session;
    MgsGodotPublishOptions();
    assert(Word(100)==0);
    MgsGodotOptionsText(30,text,palette);
    MgsGodotPublishOptions();
    assert(Word(at+16)==1 && wire[16]==session);
    ++epoch;
    MgsGodotPublishOptions();
    assert(bytes==104 && Word(4)==epoch && Word(32)==0 && Word(96)==0);
    MgsGodotOptionsEnd();
    capable=false;
    MgsGodotPublishOptions();
    assert(queued==6);
    puts("Options: resource/text deltas, palette change, delayed session resync and epoch clearing pass.");
    return 0;
}
