#include "mgs_godot_inventory.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static unsigned epoch = 1, queued, size;
static bool capable = true;
static unsigned char session = 7, wire[400000];

int MgsGodotSceneEnabled(void) { return 1; }
uint32_t MgsGodotSceneEpoch(void) { return epoch; }
bool MgsGodotHasCapability(unsigned bit) { assert(bit == MGS_GODOT_INVENTORY_CAPABILITY); return capable; }
void MgsGodotCopySessionId(unsigned char data[16]) { memset(data, session, 16); }
void MgsGodotQueue(uint32_t op, const void *header, uint32_t hsize, const void *data, uint32_t bytes)
{
    assert(op == MGS_GODOT_INVENTORY && hsize == 176 && hsize + bytes <= sizeof(wire));
    size = hsize + bytes;
    memcpy(wire, header, hsize);
    memcpy(wire + hsize, data, bytes);
    ++queued;
}
static uint32_t Word(unsigned offset)
{
    uint32_t value;
    memcpy(&value, wire + offset, 4);
    return value;
}

int main(void)
{
    unsigned char buffer[8], palette[32] = {0};
    MgsGodotResetInventory();
    MgsGodotSubmitInventoryPanel((MgsInventoryPanel){.id=13,.x=16,.y=184,.icon=22,
        .flags=MGS_INVENTORY_COUNT,.quantity=2,.maximum=5}, "RATION");
    MgsTextLayout *layout = MgsGodotPrepareInventoryDescription();
    MgsTextLayoutBegin(layout, buffer);
    MgsTextLayoutEmit(buffer, (MgsTextGlyph){.kind=MGS_TEXT_DASH,.width=18,.height=1}, NULL);
    MgsTextLayoutEnd(palette, 200, 80);
    MgsGodotInventoryDescription((MgsSubtitleFrame){.active=1,.visible=1,.x=86,.y=72,.width=200,.height=80});
    MgsGodotInventoryShape(2);
    MgsGodotPublishInventory();
    assert(queued == 1 && size == 336 && Word(8) == 1 && Word(16) == 2);
    assert(Word(60) == 1 && Word(132) == 1 && Word(180) == 13);
    assert(memcmp(wire + 224, "RATION", 7) == 0 && Word(256) == MGS_TEXT_DASH);
    MgsGodotPublishInventory();
    assert(size == 256 && Word(60) == 0 && Word(132) == 0);
    ++session;
    MgsGodotPublishInventory();
    assert(size == 336 && Word(60) == 1 && wire[32] == session && wire[64] == session);
    ++epoch;
    MgsGodotPublishInventory();
    assert(size == 176 && Word(4) == epoch && Word(8) == 0 && Word(80) == 0 && Word(16) == UINT32_MAX);
    MgsGodotResetInventory();
    for (unsigned i=0; i<MGS_INVENTORY_PANEL_LIMIT; ++i)
        MgsGodotSubmitInventoryPanel((MgsInventoryPanel){.id=-1}, "NO ITEM");
    MgsGodotPublishInventory();
    assert(Word(8) == 32 && size == 176 + 32 * 80);
    capable = false;
    MgsGodotPublishInventory();
    assert(queued == 5 && !MgsGodotOwnsInventory());
    MgsTextLayoutFree(layout);
    puts("Inventory wire: panels, retained text, session/epoch reset and ownership pass.");
    return 0;
}
