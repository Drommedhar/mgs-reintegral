#include "mgs_native.h"
#undef fprintf
#include "mgs_visibility.h"
#include "libdg/libdg.h"
#include <assert.h>
#include <stddef.h>

typedef struct { DG_OBJS group; DG_OBJ models[3]; } TestGroup;
static TestGroup fixture;
static DG_MDL models[3];
static DG_DEF definition;
static DG_OBJS *queue[1];
static DG_CHANL channel;
static unsigned scratch[256];
static int projected_bounds[6], allocations, fail_allocation, projections;
static int half_width = 214;
int DG_CurrentGroupID = 1;
int s12c_800DA428 = 8, s12c_800DA430 = 20;
short DG_ClipMin[2], DG_ClipMax[2];
#undef SCRPAD_ADDR
#define SCRPAD_ADDR ((unsigned char *)scratch)

int MgsVideoHalfWidth(void) { return half_width; }
void DG_Clip(RECT *rect, int distance)
{
    (void)distance;
    DG_ClipMin[0] = -half_width;
    DG_ClipMax[0] = half_width - 1;
    DG_ClipMin[1] = rect->y;
    DG_ClipMax[1] = rect->y + rect->h - 1;
}
static void CopyBounds(int *bounds)
{ memcpy(projected_bounds, bounds, sizeof(projected_bounds)); ++projections; }
static void GetClipBounds(int flag, SVECTOR *clip)
{ (void)flag; memset(clip, 0, sizeof(*clip)); }
static void StoreXY(void *output)
{
    DVECTOR *points = output;
    int offset = (int)((unsigned char *)output - (SCRPAD_ADDR + 0x30)) / 4;
    for (int i = 0; i < 3; ++i) {
        points[i].vx = (short)projected_bounds[(offset + i) & 1 ? 0 : 3];
        points[i].vy = (short)projected_bounds[(offset + i) & 2 ? 1 : 4];
    }
}
static void StoreZ(void *output)
{ for (int i = 0; i < 3; ++i) ((long *)output)[i] = projected_bounds[2]; }
int DG_MakeObjPacket(DG_OBJ *object, int index, int flags)
{
    (void)flags;
    if (++allocations == fail_allocation) return -1;
    object->packs[index] = (POLY_GT4 *)&definition;
    return 0;
}
void DG_FreeObjPacket(DG_OBJ *object, int index) { object->packs[index] = NULL; }
void s12c_800D5B00(DG_CHANL *chanl, int index) { (void)chanl; (void)index; }
#undef gte_SetRotMatrix
#undef gte_SetTransMatrix
#undef gte_stsxy3c
#undef gte_stsz3c
#undef gte_ldv3c
#undef gte_rtpt_b
#define gte_SetRotMatrix(matrix) ((void)(matrix))
#define gte_SetTransMatrix(matrix) ((void)(matrix))
#define gte_stsxy3c StoreXY
#define gte_stsz3c StoreZ
#define gte_ldv3c(vertices) ((void)(vertices))
#define gte_rtpt_b() ((void)0)
#include "fog_visibility_helpers.inc"

static void Bounds(int *bounds, int left, int right, int depth)
{
    bounds[0] = left; bounds[1] = -10; bounds[2] = depth;
    bounds[3] = right; bounds[4] = 10; bounds[5] = depth;
}
static void Reset(int left, int right, int depth)
{
    memset(&fixture, 0, sizeof(fixture));
    memset(models, 0, sizeof(models));
    fixture.group.def = &definition;
    fixture.group.flag = DG_FLAG_BOUND | DG_FLAG_GBOUND | DG_FLAG_PAINT;
    fixture.group.n_models = 3;
    Bounds(&definition.lx, left, right, depth);
    for (int index = 0; index < 3; ++index) {
        fixture.models[index].model = &models[index];
        fixture.models[index].bound_mode = 0x18;
        Bounds(&models[index].lx, left, right, depth);
    }
    queue[0] = &fixture.group;
    channel.queue = queue;
    channel.objs_index = 1;
    channel.clip_rect = (RECT){-160,-112,320,224};
    allocations = fail_allocation = projections = 0;
    MgsVisibilityBegin(1);
}
static void CheckBounds(void)
{
    const int cases[][5] = {
        {180,190,256,2,0}, {-190,-180,256,2,0}, {150,180,256,2,1},
        {-20,20,256,2,2}, {-20,20,2560,6,2}, {150,180,2560,6,1},
        {-20,20,5120,0,0}, {-20,20,0,0,0}, {220,230,256,0,0}};
    for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        Reset(cases[i][0], cases[i][1], cases[i][2]);
        FogBoundChanl_800D5500(&channel, 0);
        assert(fixture.group.bound_mode == cases[i][3]);
        assert(projections == (cases[i][3] ? 4 : 1));
        short model_mode = fixture.models[0].bound_mode;
        if (cases[i][3]) assert(model_mode == (0x18 | cases[i][3]));
        MgsVisibilityEnd();
        assert(fixture.group.bound_mode == cases[i][4]);
        assert(fixture.models[0].bound_mode == model_mode);
    }
    const RECT asymmetric = {-40,-30,100,80};
    assert(FogClassicMode(6, &asymmetric, -40,-30,59,49) == 2);
    assert(FogClassicMode(6, &asymmetric, 59,0,61,10) == 1);
    assert(FogClassicMode(6, &asymmetric, 60,0,61,10) == 0);
    assert(FogClassicMode(0, &asymmetric, -10,0,10,10) == 0);
}
static void CheckFailures(void)
{
    Reset(-20,190,256);
    Bounds(&models[0].lx, 180,190,256);
    Bounds(&models[1].lx, -20,20,256);
    Bounds(&models[2].lx, -20,20,256);
    fail_allocation = 1;
    FogBoundChanl_800D5500(&channel, 0);
    assert(fixture.group.bound_mode == 0 && allocations == 3 && projections == 4);
    MgsVisibilityEnd();
    assert(fixture.group.bound_mode == 1);
    Reset(-20,20,256);
    fail_allocation = 1;
    FogBoundChanl_800D5500(&channel, 1);
    assert(allocations == 1 && projections == 2);
    MgsVisibilityEnd();
    assert(fixture.group.bound_mode == 0);
}
static void CheckClipping(void)
{
    const int cases[][3] = {{-215,0,1},{-214,0,0},{-161,0,0},{160,0,0},
        {214,0,0},{215,0,2},{0,-113,4},{0,113,8},{215,113,10}};
    for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        DVECTOR vertices[256] = {0};
        vertices[0] = (DVECTOR){(short)cases[i][0],(short)cases[i][1]};
        CALCULATE_CLIPPING(vertices);
        assert(((unsigned char *)&vertices[128])[3] == cases[i][2]);
        assert(vertices[0].vx == cases[i][0] && vertices[0].vy == cases[i][1]);
    }
    half_width = 160;
    DVECTOR vertices[256] = {0};
    vertices[0].vx = 161;
    CALCULATE_CLIPPING(vertices);
    assert(((unsigned char *)&vertices[128])[3] == 2);
}
int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    assert(offsetof(TestGroup, models) == sizeof(DG_OBJS));
    CheckBounds();
    CheckFailures();
    CheckClipping();
    puts("Fog preserves classic group visibility, render cache bits and wider vertex clipping");
    return 0;
}
