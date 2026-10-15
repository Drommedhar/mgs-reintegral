#include "mgs_godot_codec.h"
#include "mgs_godot_codec_actions.h"
#include "mgs_godot_context.h"
#include "mgs_godot_scene.h"
#include "transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static MgsCodecFrame frame;
static MgsCodecFace faces[2];
static uint32_t contacts[8], epoch, revision;
static unsigned char images[4][MGS_CODEC_IMAGE_BYTES];
static MgsTextLayout layout;
static MgsTextLayout displayed_layout;
static MgsTextGlyph displayed_glyphs[4096];
static uint32_t displayed_revision;
static MgsSubtitleFrame message;

static void InvalidCodec(void)
{
    fputs("Godot Codec: invalid portrait or contact extent.\n", stderr);
    exit(EXIT_FAILURE);
}

int MgsGodotOwnsCodec(void)
{
    return MgsGodotHasCapability(MGS_GODOT_CODEC_CAPABILITY);
}

void MgsGodotResetCodec(void)
{
    MgsGodotCodecActionsReset();
    if (epoch != MgsGodotSceneEpoch()) {
        epoch = MgsGodotSceneEpoch();
        memset(images, 0, sizeof(images));
    }
    memset(&frame, 0, sizeof(frame));
    memset(faces, 0, sizeof(faces));
    memset(contacts, 0, sizeof(contacts));
    memset(&message, 0, sizeof(message));
}

MgsCodecFrame *MgsGodotCodecFrame(void) { return &frame; }

MgsCodecFace *MgsGodotCodecFace(unsigned side)
{
    if (side >= 2) InvalidCodec();
    return &faces[side];
}

void MgsGodotCodecImage(unsigned side, unsigned x, unsigned y,
                       unsigned width, unsigned height, const void *pixels)
{
    if (side >= 2 || x > 64 || y > 96 || width > 64 - x || height > 96 - y || !pixels)
        InvalidCodec();
    const unsigned char *source = pixels;
    for (unsigned row = 0; row < height; ++row)
        memcpy(images[side * 2] + (y + row) * 64 + x, source + row * width, width);
}

void MgsGodotCodecPalette(unsigned side, const void *palette)
{
    if (side >= 2 || !palette) InvalidCodec();
    memcpy(images[side * 2] + 64 * 96, palette, 512);
}

void MgsGodotCodecBackup(unsigned side)
{
    if (side >= 2) InvalidCodec();
    memcpy(images[side * 2 + 1], images[side * 2], MGS_CODEC_IMAGE_BYTES);
}

void MgsGodotCodecBeginText(const void *buffer)
{
    if (++revision == 0) ++revision;
    MgsTextLayoutBegin(&layout, buffer);
}

void MgsGodotCodecText(MgsSubtitleFrame value)
{
    message = value;
    if (!value.active || displayed_revision == revision) return;
    displayed_layout = layout;
    if (layout.count) memcpy(displayed_glyphs, layout.glyphs, layout.count * sizeof(*displayed_glyphs));
    displayed_layout.glyphs = displayed_glyphs;
    displayed_revision = revision;
}

void MgsGodotCodecContact(unsigned index, unsigned frequency)
{
    if (index >= 8) InvalidCodec();
    contacts[index] = frequency;
}

static void PrepareText(MgsGodotSubtitleHeader *text, const unsigned char *session, int resync)
{
    static uint32_t last_revision, last_epoch;
    static unsigned char last_session[16];
    *text = (MgsGodotSubtitleHeader){.schema = 1, .epoch = epoch,
        .revision = displayed_revision, .frame = message, .stride = sizeof(MgsTextGlyph)};
    memcpy(text->session, session, sizeof(text->session));
    if (!message.active || (!resync && last_revision == displayed_revision && last_epoch == epoch &&
                            !memcmp(last_session, session, 16))) return;
    text->has_layout = 1;
    text->width = displayed_layout.width;
    text->height = displayed_layout.height;
    text->count = (uint32_t)displayed_layout.count;
    memcpy(text->palette, displayed_layout.palette, sizeof(text->palette));
    last_revision = displayed_revision;
    last_epoch = epoch;
    memcpy(last_session, session, 16);
}

void MgsGodotPublishCodec(void)
{
    static unsigned char previous[4][MGS_CODEC_IMAGE_BYTES], last_session[16];
    static unsigned char records[4096 * sizeof(MgsTextGlyph) + sizeof(images)];
    static uint32_t last_epoch;
    if (!MgsGodotOwnsCodec()) return;
    if (epoch != MgsGodotSceneEpoch()) MgsGodotResetCodec();
    struct {
        uint32_t schema, epoch, image_mask, reserved;
        unsigned char session[16];
        MgsCodecFrame frame;
        MgsCodecFace faces[2];
        uint32_t contacts[8];
        MgsGodotSubtitleHeader text;
    } header = {.schema = 1, .epoch = epoch, .frame = frame};
    _Static_assert(sizeof(header) == 320 && sizeof(MgsCodecFace) == 32, "Codec wire layout");
    MgsGodotCopySessionId(header.session);
    int resync = last_epoch != epoch || memcmp(last_session, header.session, 16);
    memcpy(header.faces, faces, sizeof(faces));
    memcpy(header.contacts, contacts, sizeof(contacts));
    PrepareText(&header.text, header.session, resync);
    uint32_t bytes = header.text.count * sizeof(MgsTextGlyph);
    if (bytes) memcpy(records, displayed_layout.glyphs, bytes);
    for (unsigned index = 0; index < 4; ++index) {
        if (!resync && !memcmp(previous[index], images[index], MGS_CODEC_IMAGE_BYTES)) continue;
        header.image_mask |= 1u << index;
        memcpy(records + bytes, images[index], MGS_CODEC_IMAGE_BYTES);
        memcpy(previous[index], images[index], MGS_CODEC_IMAGE_BYTES);
        bytes += MGS_CODEC_IMAGE_BYTES;
    }
    memcpy(last_session, header.session, 16);
    last_epoch = epoch;
    MgsGodotQueue(MGS_GODOT_CODEC, &header, sizeof(header), records, bytes);
}
