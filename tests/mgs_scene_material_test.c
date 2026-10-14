#include "mgs_native.h"
#undef fprintf
#include "libdg/libdg.h"
#include "game/game.h"
#include <assert.h>
#include <limits.h>
#include <stddef.h>

typedef struct { DG_OBJS group; DG_OBJ parts[2]; } TestGroup;
static TestGroup fixture;
static DG_OBJ extension;
static DG_MDL models[3];
static POLY_GT4 packets[2][2][3];
static unsigned short texture_ids[3] = {5, 6, 7};
static DG_TEX textures[3];
static MATRIX lights[2];
static unsigned scratch[256];
static DG_OBJS *queue[] = {&fixture.group};
static DG_CHANL channel;
static int shades, paints, fog_paints, light_scale;
static int scene_enabled;
int GM_GameStatus, DG_CurrentGroupID = 1;
SVECTOR DG_Ambient;
DG_TEX DG_UnknownTexture_800C34FC;
int s12c_800DA428, s12c_800DA42C, s12c_800DA430, s12c_800DA434;
short s12c_800DA440[768];
short *s12c_800DAA40, *s12c_800DAA44, *s12c_800DAA48, *s12c_800DAA4C;
#ifdef MGS_GODOT_SCENE
int MgsGodotRetainObjects(const DG_OBJS *objects)
{
    return scene_enabled && !(objects->flag & DG_FLAG_INVISIBLE) &&
        (!objects->group_id || (objects->group_id & DG_CurrentGroupID));
}
#define RETAINED 1
#else
#define RETAINED 0
#endif

DG_TEX *DG_GetTexture(int id)
{
    assert(id >= 5 && id <= 7);
    return &textures[id - 5];
}
static void Shade(DG_OBJ *object, int index)
{
    assert(object->packs[index]);
    ++shades;
}
static void FogPaint(DG_OBJ *object, int index)
{
    assert(object->packs[index]);
    ++fog_paints;
}
void DG_WriteObjPacketRGB(DG_OBJ *object, int index)
{
    assert(object->packs[index]);
    ++paints;
}
static MATRIX *Scale(MATRIX *matrix, VECTOR *scale)
{
    assert(scale->vx == scale->vy && scale->vy == scale->vz);
    light_scale = scale->vx;
    return matrix;
}
#undef SCRPAD_ADDR
#define SCRPAD_ADDR ((unsigned char *)scratch)
#undef gte_ldfcdir
#define gte_ldfcdir(r,g,b) ((void)0)
#undef gte_SetRotMatrix
#define gte_SetRotMatrix(matrix) ((void)(matrix))
#undef gte_SetColorMatrix
#define gte_SetColorMatrix(matrix) ((void)(matrix))
#undef gte_SetBackColor
#define gte_SetBackColor(r,g,b) ((void)(r), (void)(g), (void)(b))
#undef DG_MulRotMatrix0
#define DG_MulRotMatrix0(source,destination) ((void)(source), (void)(destination))
#define SetLightMatrix(matrix) ((void)(matrix))
#define ScaleMatrix Scale
#define s12c_800D6958 Shade
#define s12c_800D6588 FogPaint
#include "scene_material_helpers.inc"

static void Reset(int visible)
{
    memset(&fixture, 0, sizeof(fixture));
    memset(&extension, 0, sizeof(extension));
    memset(models, 0, sizeof(models));
    memset(packets, 0, sizeof(packets));
    fixture.group.n_models = 2;
    fixture.group.flag = DG_FLAG_IRTEXTURE;
    fixture.group.bound_mode = visible;
    fixture.group.light = lights;
    for (int part = 0; part < 2; ++part) {
        fixture.parts[part].model = &models[part];
        fixture.parts[part].n_packs = 2;
        fixture.parts[part].bound_mode = visible;
        models[part].texids = texture_ids;
        for (int buffer = 0; buffer < 2; ++buffer) {
            fixture.parts[part].packs[buffer] = packets[part][buffer];
            for (int face = 0; face < 3; ++face)
                packets[part][buffer][face].clut = (unsigned short)(100 + face);
        }
    }
    fixture.parts[0].extend = &extension;
    extension.model = &models[2];
    extension.n_packs = 1;
    models[2].texids = &texture_ids[2];
    for (int i = 0; i < 3; ++i) textures[i].clut = (unsigned short)(100 + i);
    channel.queue = queue;
    channel.objs_index = 1;
    shades = paints = fog_paints = 0;
    light_scale = -1;
    scene_enabled = 1;
    GM_GameStatus = 0;
    s12c_800D497C(8, 12);
}
static void CheckThermal(void (*update)(DG_CHANL *, int))
{
    for (int visible = 0; visible <= 2; visible += 2) {
        Reset(visible);
        for (int buffer = 0; buffer < 2; ++buffer) {
            GM_GameStatus = STATE_THERMG;
            update(&channel, buffer);
            int expected = visible || RETAINED;
            assert(packets[0][buffer][0].clut == (expected ? 0x3fff : 100));
            assert(packets[0][buffer][2].clut == (expected ? 0x3fff : 102));
            assert(packets[1][buffer][1].clut == (expected ? 0x3fff : 101));
            GM_GameStatus = 0;
            update(&channel, buffer);
            assert(packets[0][buffer][0].clut == 100);
            assert(packets[0][buffer][2].clut == 102);
            assert(packets[1][buffer][1].clut == 101);
            assert(fixture.group.bound_mode == visible);
            assert(fixture.parts[0].bound_mode == visible);
        }
    }
    for (int excluded = 0; excluded < 4; ++excluded) {
        Reset(0);
        if (excluded == 0) fixture.group.flag |= DG_FLAG_INVISIBLE;
        if (excluded == 1) fixture.group.group_id = 2;
        if (excluded == 2) fixture.group.flag &= ~DG_FLAG_IRTEXTURE;
        if (excluded == 3) scene_enabled = 0;
        GM_GameStatus = STATE_THERMG;
        update(&channel, 0);
        assert(packets[0][0][0].clut == 100);
    }
    Reset(0);
    fixture.parts[0].packs[0] = NULL;
    GM_GameStatus = STATE_THERMG;
    update(&channel, 0);
    GM_GameStatus = 0;
    update(&channel, 0);
    assert(packets[0][0][0].clut == 100);
}
static void CheckShade(void)
{
    for (int visible = 0; visible <= 2; visible += 2) {
        Reset(visible);
        fixture.group.flag = DG_FLAG_SHADE;
        FogShadeChanl_800D6A04(&channel, 0);
        assert(shades == ((visible || RETAINED) ? 2 : 0));
        assert(fixture.group.bound_mode == visible);
    }
    const int depths[] = {INT_MIN, -256, 0, 14 * 256, INT_MAX};
    const int scales[] = {4096, 4096, 4096, 2048, 0};
    for (int i = 0; i < 5; ++i) {
        Reset(0);
        fixture.group.flag = DG_FLAG_SHADE;
        fixture.parts[0].screen.t[2] = depths[i];
        fixture.parts[1].packs[0] = NULL;
        FogShadeChanl_800D6A04(&channel, 0);
        assert(shades == RETAINED);
        assert(light_scale == (RETAINED ? scales[i] : -1));
    }
    for (int excluded = 0; excluded < 3; ++excluded) {
        Reset(0);
        fixture.group.flag = DG_FLAG_SHADE;
        if (excluded == 0) fixture.group.flag |= DG_FLAG_INVISIBLE;
        if (excluded == 1) fixture.group.group_id = 2;
        if (excluded == 2) scene_enabled = 0;
        FogShadeChanl_800D6A04(&channel, 0);
        assert(shades == 0);
    }
}
static void CheckPaint(void)
{
    Reset(0);
    fixture.group.flag = DG_FLAG_PAINT;
    for (int buffer = 0; buffer < 2; ++buffer) {
        FogShadeChanl_800D6A04(&channel, buffer);
        assert(paints == (buffer + 1) * 2 * RETAINED);
        FogShadeChanl_800D6A04(&channel, buffer);
        assert(paints == (buffer + 1) * 2 * RETAINED);
    }
    assert(fog_paints == 0 && fixture.group.bound_mode == 0);
    Reset(6);
    fixture.group.flag = DG_FLAG_PAINT;
    FogShadeChanl_800D6A04(&channel, 0);
    assert(fog_paints == 2 && paints == 0);
    assert(fixture.group.bound_mode == 2 && fixture.parts[0].bound_mode == 2);
}
int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    assert(offsetof(TestGroup, parts) == sizeof(DG_OBJS));
    CheckThermal(UpdateThermalTexture);
    CheckThermal(s12c_800D5B00);
    CheckShade();
    CheckPaint();
    puts("Fog shading and thermal palettes preserve native visibility and update retained objects");
    return 0;
}
