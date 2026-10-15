#include "mgs_godot_codec.h"
#include "mgs_codec_actions.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static unsigned epoch = 1, size, queued;
static bool capable = true;
static unsigned char session = 7, wire[400000];
int MgsGodotSceneEnabled(void) { return 1; }
uint32_t MgsGodotSceneEpoch(void) { return epoch; }
bool MgsGodotHasCapability(unsigned bit) { assert(bit == MGS_GODOT_CODEC_CAPABILITY || bit == MGS_CODEC_ACTIONS_CAPABILITY); return bit == MGS_GODOT_CODEC_CAPABILITY && capable; }
void MgsGodotCopySessionId(unsigned char data[16]) { memset(data, session, 16); }
void MgsGodotQueue(uint32_t op, const void *header, uint32_t hsize, const void *data, uint32_t bytes)
{
    assert(op == MGS_GODOT_CODEC && hsize == 320 && hsize + bytes <= sizeof(wire));
    size = hsize + bytes;
    memcpy(wire, header, hsize);
    memcpy(wire + hsize, data, bytes);
    ++queued;
}
void MgsGodotRequest(uint32_t op, const void *data, uint32_t size,
                     uint32_t reply_size, void (*complete)(const void *))
{
    (void)op; (void)data; (void)size; (void)reply_size; (void)complete;
    assert(!"Codec actions were not negotiated in this portrait test");
}
static uint32_t Word(unsigned offset)
{
    uint32_t value;
    memcpy(&value, wire + offset, 4);
    return value;
}
int main(void)
{
    unsigned char pixels[4] = {1,2,3,4}, buffer[8], palette[512] = {0};
    palette[2] = 31;
    MgsGodotResetCodec();
    *MgsGodotCodecFrame() = (MgsCodecFrame){.active=1,.frequency=14085,.signal=8};
    MgsGodotCodecImage(1, 2, 3, 2, 2, pixels);
    MgsGodotCodecPalette(1, palette);
    MgsGodotCodecBackup(1);
    *MgsGodotCodecFace(1) = (MgsCodecFace){.x=237,.y=30,.width=52,.height=89,.visible=1};
    MgsGodotCodecBeginText(buffer);
    MgsTextLayoutEmit(buffer, (MgsTextGlyph){.kind=MGS_TEXT_DASH,.width=18,.height=1}, NULL);
    MgsTextLayoutEnd(palette,252,76);
    MgsGodotCodecText((MgsSubtitleFrame){.active=1,.visible=1,.x=34,.y=132,.width=252,.height=76});
    MgsGodotCodecBeginText(buffer);
    MgsTextLayoutEnd(palette,252,76);
    MgsGodotPublishCodec();
    assert(size == 400 + 4*MGS_CODEC_IMAGE_BYTES && Word(8)==15 && Word(204)==1);
    assert(wire[400 + 2*MGS_CODEC_IMAGE_BYTES + 3*64+2]==1);
    assert(wire[400 + 3*MGS_CODEC_IMAGE_BYTES + 4*64+3]==4);
    assert(wire[400 + 2*MGS_CODEC_IMAGE_BYTES + 6146]==31);
    MgsGodotPublishCodec();
    assert(size==320 && Word(8)==0 && Word(204)==0);
    pixels[0]=9;
    MgsGodotCodecImage(1,2,3,2,2,pixels);
    MgsGodotPublishCodec();
    assert(size==320+MGS_CODEC_IMAGE_BYTES && Word(8)==4 && wire[320+3*64+2]==9);
    ++session;
    MgsGodotPublishCodec();
    assert(Word(8)==15 && Word(204)==1 && wire[16]==session);
    ++epoch;
    MgsGodotPublishCodec();
    assert(Word(4)==epoch && Word(32)==0 && Word(224)==0 && Word(8)==15);
    MgsGodotCodecContact(7,14152);
    MgsGodotPublishCodec();
    assert(Word(188)==14152 && size==320);
    capable=false;
    MgsGodotPublishCodec();
    assert(queued==6 && !MgsGodotOwnsCodec());
    puts("Codec wire: indexed patches, palettes, crossfade backup, deltas, text and resync pass.");
    return 0;
}
