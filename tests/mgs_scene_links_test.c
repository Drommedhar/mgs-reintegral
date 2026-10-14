#include "mgs_native.h"
#undef fprintf
#include "mgstype.h"
#include "libdg/libdg.h"
#include <assert.h>
#include <stddef.h>

typedef struct { DG_OBJS group; DG_OBJ parts[2]; } TestGroup;
static TestGroup fixture;
static DG_MDL models[2];
static SVECTOR vertex;
static POLY_GT4 packets[2][2];
static DG_OBJS *queue[] = {&fixture.group};
static DG_CHANL channel;
unsigned long psyz_scratchpad[256];
int GV_Clock, DG_CurrentGroupID = 1;
static int transforms, enabled = 1;
static int shadings;
SVECTOR DG_Ambient;
#ifdef MGS_GODOT_SCENE
int MgsGodotRetainObjects(const DG_OBJS *objects)
{
    return enabled && !(objects->flag & DG_FLAG_INVISIBLE) &&
        (!objects->group_id || (objects->group_id & DG_CurrentGroupID));
}
#define RETAINED 1
#else
#define RETAINED 0
#endif

void DG_Clip(RECT *rect, int distance) { (void)rect; (void)distance; }
void MgsTextureCorrectionCopy(const void *destination, const void *source)
{ (void)destination; (void)source; }
static void DG_TransObj(DG_OBJ *object, int index);
static void s12c_800D6020(DG_OBJ *object, int index);
static void DG_ShadeObj(DG_OBJ *object, int index);
#undef gte_SetRotMatrix
#define gte_SetRotMatrix(matrix) ((void)(matrix))
#undef gte_SetTransMatrix
#define gte_SetTransMatrix(matrix) ((void)(matrix))
#undef gte_SetColorMatrix
#define gte_SetColorMatrix(matrix) ((void)(matrix))
#undef gte_SetBackColor
#define gte_SetBackColor(r, g, b) ((void)0)
#undef gte_SetLightMatrix
#define gte_SetLightMatrix(matrix) ((void)(matrix))
#undef DG_MulRotMatrix0
#define DG_MulRotMatrix0(source, destination) ((void)0)
#include "scene_links_helpers.inc"

static void DG_ShadeObj(DG_OBJ *object, int index)
{
    ++shadings;
    if (object == &fixture.parts[1]) {
        unsigned indices = 0x80808080;
        DG_ShadePacksIndirect(&indices, object->packs[index], 1, &indices);
    }
}

static void Transform(DG_OBJ *object, int index,
                      unsigned int (*write_vertices)(unsigned int, POLY_GT4 *))
{
    ++transforms;
    if (object == &fixture.parts[1])
        object->packs[index]->tag = write_vertices(0x80808080, object->packs[index]);
}
static void DG_TransObj(DG_OBJ *object, int index)
{ Transform(object, index, DG_WriteObjVerticesIndirect); }
static void s12c_800D6020(DG_OBJ *object, int index)
{ Transform(object, index, s12c_800D5CDC); }

static void Reset(int visible)
{
    memset(&fixture, 0, sizeof(fixture));
    memset(packets, 0, sizeof(packets));
    fixture.group.flag = DG_FLAG_SHADE | DG_FLAG_GBOUND;
    fixture.group.n_models = 2;
    fixture.group.bound_mode = visible;
    vertex.pad = offsetof(POLY_GT4, x0);
    for (int part = 0; part < 2; ++part) {
        models[part].verts = &vertex;
        models[part].parent = 0;
        models[part].flag = part ? DG_MODEL_INDIRECT : 0;
        fixture.parts[part].model = &models[part];
        fixture.parts[part].bound_mode = visible;
        for (int buffer = 0; buffer < 2; ++buffer)
            fixture.parts[part].packs[buffer] = &packets[part][buffer];
    }
    channel.queue = queue;
    channel.objs_index = 1;
    enabled = 1;
    transforms = 0;
    shadings = 0;
}

static void CheckMissingParent(void)
{
    Reset(0);
    GV_Clock = 0;
    fixture.parts[0].packs[0] = NULL;
    unsigned color = 0x3c808080;
    POLY_GT4 *child = &packets[1][0];
    memcpy(&child->r0, &color, sizeof(color));
    memcpy(&child->r1, &color, sizeof(color));
    memcpy(&child->r2, &color, sizeof(color));
    memcpy(&child->r3, &color, sizeof(color));
    DG_TransChanl(&channel, 0);
    DG_ShadeChanl(&channel, 0);
    assert(shadings == 0);
    fixture.parts[0].packs[0] = &packets[0][0];
    memcpy(&packets[0][0].r0, &color, sizeof(color));
    DG_TransChanl(&channel, 0);
    DG_ShadeChanl(&channel, 0);
    assert(shadings == (RETAINED ? 2 : 0));
    assert(memcmp(&child->r1, &color, sizeof(color)) == 0);
}
static void CheckLinks(void (*transform)(DG_CHANL *, int),
    POLY_GT4 *(*shade)(unsigned int *, POLY_GT4 *, int, unsigned int *))
{
    for (int visible = 0; visible <= 2; visible += 2) {
        Reset(visible);
        for (int frame = 0; frame < 20; ++frame) {
            GV_Clock = frame & 1;
            unsigned int indices = 0x80808080;
            unsigned int color = 0x3c402010 + frame;
            POLY_GT4 *parent = &packets[0][GV_Clock];
            POLY_GT4 *child = &packets[1][GV_Clock];
            memcpy(&parent->r0, &color, sizeof(color));
            transform(&channel, GV_Clock);
            assert(transforms == (visible || RETAINED ? (frame + 1) * 2 : 0));
            if (visible || RETAINED) {
                assert(child->tag == 0);
                shade(&indices, child, 1, &indices);
                assert(memcmp(&child->r0, &color, 4) == 0);
                assert(memcmp(&child->r1, &color, 4) == 0);
                assert(memcmp(&child->r2, &color, 4) == 0);
                assert(memcmp(&child->r3, &color, 4) == 0);
            }
            assert(fixture.group.bound_mode == visible);
            assert(fixture.parts[1].bound_mode == visible);
        }
    }
    for (int excluded = 0; excluded < 3; ++excluded) {
        Reset(0);
        if (excluded == 0) fixture.group.flag |= DG_FLAG_INVISIBLE;
        if (excluded == 1) fixture.group.group_id = 2;
        if (excluded == 2) enabled = 0;
        transform(&channel, 0);
        assert(transforms == 0);
    }
    Reset(0);
    fixture.parts[1].packs[0] = NULL;
    transform(&channel, 0);
    assert(transforms == RETAINED);
}
int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    assert(offsetof(TestGroup, parts) == sizeof(DG_OBJS));
    CheckLinks(DG_TransChanl, DG_ShadePacksIndirect);
    CheckLinks(FogTransChanl_800D63B0, s12c_800D67F0);
    CheckMissingParent();
    puts("Retained connected meshes refresh temporary color links before each shading pass");
    return 0;
}
