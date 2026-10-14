#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "mgs_godot_palettes.h"
#include "mgs_godot_deformation.h"
#include "libdg/libdg.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int DG_CurrentGroupID = 1;
static unsigned char snapshot[256], colors[16], packets[64];
static float live_textures[16];
static float deformation_data[12];
static unsigned deformation_updates;
static DG_TEX texture = {.id = 42, .w = 63, .h = 63};
static unsigned capabilities;
static uint32_t minor = 31, snapshot_size;
uint32_t MgsGodotSelectedMinor(void) { return minor; }
int MgsVideoReferenceRequired(void) { return 0; }
float MgsVideoHorizontalScale(void) { return 1.0f; }
const char *MgsNativeResourceStage(void) { return "s00a"; }
int MgsSafetyDiscNumber(void) { return 1; }
int GV_StrCode(const char *name) { (void)name; return 900; }
DG_TEX *DG_GetTexture(int id) { (void)id; return &texture; }
bool MgsGodotHasCapability(unsigned capability) { return (capabilities & capability) != 0; }
void MgsGodotPublishContext(void) {}
void MgsGodotPublishUi(void) {}
void MgsGodotPublishBars(void) {}
void MgsGodotPublishRadar(void) {}
void MgsGodotPublishInventory(void) {}
void MgsGodotPublishInventoryActions(void) {}
void MgsGodotPublishCodec(void) {}
void MgsGodotPublishCodecActions(void) {}
void MgsGodotPublishOptions(void) {}
void MgsGodotPublishTitle(void) {}
void MgsGodotPublishSaveUi(void) {}
void MgsGodotPublishSubtitles(void) {}
void MgsGodotPublishActors(void) {}
void MgsGodotPaletteStatistics(void) {}
void MgsGodotRemoveAlarmLight(DG_OBJS *objects) { (void)objects; }
void MgsGodotRetirePalette(MgsGodotPalette *palette, uint32_t id, uint32_t kind)
{ (void)palette; (void)id; (void)kind; }
uint32_t MgsGodotPublishPalette(MgsGodotPalette *palette, uint32_t id, uint32_t kind,
                               const void *data, uint32_t size)
{
    assert(id == 1 || id == 2);
    if (kind == 4) {
        assert(size == sizeof(live_textures));
        memcpy(live_textures, data, size);
    } else if (kind == 3) {
        assert(size == sizeof(deformation_data));
        memcpy(deformation_data, data, size);
        ++deformation_updates;
    } else {
        assert(size == (kind == 1 ? sizeof(colors) : sizeof(packets)));
        memcpy(kind == 1 ? colors : packets, data, size);
    }
    return ++palette->revision;
}
uint32_t MgsGodotAppendEffects(DG_CHANL *channel, int index, unsigned char *data, uint32_t capacity)
{ (void)channel; (void)index; assert(capacity >= 4); memset(data, 0, 4); return 4; }
uint32_t MgsGodotAppendLights(unsigned char *data, uint32_t capacity)
{ assert(capacity >= 4); memset(data, 0, 4); return 4; }
void MgsGodotQueue(uint32_t operation, const void *header, uint32_t size,
                   const void *data, uint32_t data_bytes)
{
    (void)data;
    assert(operation == MGS_GODOT_RETAINED_SCENE && !data_bytes && size <= sizeof(snapshot));
    snapshot_size = size;
    memcpy(snapshot, header, size);
}

static uint32_t PartFlags(void)
{
    uint32_t flags;
    memcpy(&flags, snapshot + 148, sizeof(flags));
    return flags;
}

static void CheckMixedNullFace(DG_OBJS *objects)
{
    DG_MDL *model = objects->objs[0].model;
    unsigned short textures[] = {0, 42};
    POLY_GT4 faces[2] = {{0}};
    faces[0].code = 0xff;
    faces[0].tpage = 0x100;
    faces[1].code = 0x3c;
    model->n_faces = 2;
    model->texids = textures;
    objects->objs[0].packs[0] = faces;
    assert(MgsGodotOwnsPart(objects, 0, 0));
    faces[1].code = 0x3e;
    faces[1].tpage = 2 << 5;
    assert(!MgsGodotOwnsPart(objects, 0, 0));
    faces[1].code = 0x3c;
    faces[1].tpage = 0x100;
    assert(!MgsGodotOwnsPart(objects, 0, 0));
}

static void CheckCamouflage(DG_OBJS *objects, DG_CHANL *channel)
{
    POLY_GT4 *packet = objects->objs[0].packs[0];
    packet->tpage = 0x100;
    MgsGodotSetCamouflage(objects, 0.25f, 0x3c60a080);
    assert(!MgsGodotOwnsPart(objects, 0, 0));
    capabilities = 256 | 8192;
    assert(MgsGodotOwnsPart(objects, 0, 0));
    MgsGodotCaptureScene(channel, 0);
    uint32_t kind, tint, flags;
    float amount;
    memcpy(&kind, snapshot + 104, 4);
    memcpy(&amount, snapshot + 108, 4);
    memcpy(&tint, snapshot + 112, 4);
    memcpy(&flags, snapshot + 164, 4);
    assert(kind == 1 && amount == 0.25f && tint == 0x60a080 && flags == 3);
    MgsGodotClearCamouflage(objects);
    assert(!MgsGodotOwnsPart(objects, 0, 0));
    MgsGodotSetCamouflage(objects, 1.0f, 0x808080);
    MgsGodotRemoveInstance(objects);
    MgsGodotRegisterInstance(objects);
    assert(!MgsGodotOwnsPart(objects, 0, 0));
    capabilities = 0;
    packet->tpage = 0;
}

static void CheckLiveTextures(DG_OBJS *objects, DG_CHANL *channel)
{
    POLY_GT4 *packet = objects->objs[0].packs[0];
    MgsGodotUseLiveTextures(objects);
    minor = 32;
    assert(!MgsGodotOwnsPart(objects, 0, 0));
    minor = 33;
    packet->u0 = 17;
    packet->v0 = 31;
    packet->tpage = 0x9a;
    packet->clut = 0x600;
    assert(MgsGodotOwnsPart(objects, 0, 0));
    MgsGodotCaptureScene(channel, 0);
    assert(live_textures[0] == 17.5f && live_textures[1] == 31.5f);
    assert(live_textures[2] == 0x9b && live_textures[3] == 0x600);
    packet->tpage = 0x3c;
    packet->clut = 0x800;
    MgsGodotCaptureScene(channel, 0);
    assert(live_textures[2] == 0x3d && live_textures[3] == 0x800);
}

int main(void)
{
    _putenv_s("MGS_GODOT_SCENE_VIEW", "1");
    struct { DG_DEF definition; DG_MDL model; } asset = {0};
    struct { DG_OBJS group; DG_OBJ part; } actor = {0};
    unsigned short texid = 42;
    asset.definition.n_models = asset.definition.n_x_models = 1;
    asset.model.n_faces = 1;
    asset.model.texids = &texid;
    asset.model.extend = -1;
    actor.group.def = &asset.definition;
    actor.group.n_models = 1;
    actor.part.model = &asset.model;
    actor.part.screen.m[0][0] = actor.part.screen.m[1][1] = actor.part.screen.m[2][2] = 4096;
    POLY_GT4 packet = {0};
    packet.code = 0x3c;
    packet.u0 = 32;
    actor.part.packs[0] = &packet;
    DG_OBJS *queue[] = {&actor.group};
    DG_CHANL channel = {0};
    channel.queue = queue;
    channel.objs_index = 1;
    channel.eye_inv = actor.part.screen;
    MgsGodotRegisterModel(&asset.definition, 1);
    MgsGodotRegisterInstance(&actor.group);
    actor.group.flag = DG_FLAG_IRTEXTURE;
    MgsGodotCaptureScene(&channel, 0);
    uint32_t object_flags;
    memcpy(&object_flags, snapshot + 84, sizeof(object_flags));
    assert(object_flags == DG_FLAG_IRTEXTURE && actor.group.flag == DG_FLAG_IRTEXTURE);
    assert(PartFlags() == 3 && colors[3] == 127);
    assert(actor.group.bound_mode == 0 && actor.part.bound_mode == 0);
    minor = 35;
    actor.part.raise = -500;
    MgsGodotCaptureScene(&channel, 0);
    assert((PartFlags() & 0xffffu) == 3 && (int16_t)(PartFlags() >> 16) == -500);
    actor.part.raise = 1000;
    MgsGodotCaptureScene(&channel, 0);
    assert((int16_t)(PartFlags() >> 16) == 1000);
    minor = 31;
    actor.part.raise = 0;
    float uv;
    memcpy(&uv, packets, sizeof(uv));
    assert(uv == 32.5f / 64);
    actor.group.bound_mode = actor.part.bound_mode = 2;
    packet.tag = 123;
    MgsGodotCaptureScene(&channel, 0);
    assert(PartFlags() == 3 && colors[3] == 255);
    actor.group.flag = DG_FLAG_INVISIBLE | DG_FLAG_IRTEXTURE;
    MgsGodotCaptureScene(&channel, 0);
    assert(PartFlags() == 0 && !MgsGodotRetainObjects(&actor.group));
    actor.group.flag = 0;
    actor.group.group_id = 2;
    MgsGodotCaptureScene(&channel, 0);
    assert(PartFlags() == 0 && !MgsGodotRetainObjects(&actor.group));
    actor.group.group_id = 0;
    SVECTOR vertices[4] = {{0, 0, 0, -1}, {1000, 0, 0, -1},
                          {1000, 1000, 0, -1}, {0, 1000, 0, -1}};
    unsigned char indices[] = {0, 1, 2, 3};
    asset.model.verts = vertices;
    asset.model.vindices = indices;
    asset.model.n_verts = 4;
    asset.model.parent = -1;
    MgsGodotCaptureVertexOwners(&asset.definition, 0);
    uint32_t previous_size = snapshot_size;
    minor = 32;
    MgsGodotCaptureScene(&channel, 0);
    assert(snapshot_size == previous_size + 4);
    uint32_t deformation;
    memcpy(&deformation, snapshot + 160, 4);
    assert(!deformation);
    MgsGodotTrackDeformation(&asset.definition);
    vertices[1].vx += 500;
    MgsGodotDeformationChanged(&asset.definition);
    MgsGodotCaptureScene(&channel, 0);
    memcpy(&deformation, snapshot + 160, 4);
    assert(deformation == 1 && deformation_updates == 1 && deformation_data[3] == 0.5f);
    MgsGodotCaptureScene(&channel, 0);
    assert(deformation_updates == 1);
    vertices[1].vx -= 500;
    MgsGodotDeformationChanged(&asset.definition);
    MgsGodotCaptureScene(&channel, 0);
    assert(deformation_updates == 2 && deformation_data[3] == 0);
    minor = 31;
    texid = 0;
    MgsGodotCaptureScene(&channel, 0);
    assert(PartFlags() == 3);
    for (unsigned i = 0; i < sizeof(packets); ++i) assert(packets[i] == 0);
    texid = 42;
    CheckCamouflage(&actor.group, &channel);
    CheckLiveTextures(&actor.group, &channel);
    CheckMixedNullFace(&actor.group);
    MgsGodotRemoveInstance(&actor.group);
    puts("Active scene meshes survive native culling without changing gameplay flags.");
    return 0;
}
