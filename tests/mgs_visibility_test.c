#include "mgs_native.h"
#undef fprintf
#include "mgs_visibility.h"
#include "libdg/libdg.h"
#include "libgv/libgv.h"
#include <libapi.h>
#include <assert.h>

typedef struct {
    DG_OBJS group;
    DG_OBJ models[3];
} TestGroup;

static DVECTOR projected[4][3];
static long depths[4][3];
static int half_width = 214;
static int projections, allocations, releases, fail_allocation;
static int render_checks, screen_calls;
static int expected_group, expected_model;
static DG_MDL models[3];
static DG_DEF definition;
static TestGroup fixture;
static DG_OBJS *queue[1];
static int stop_chanl_system_flag;
static DG_CHANLFUNC DG_ChanlUnits[7];
int DG_CurrentGroupID = 1;
int DG_HikituriFlag;
short N_ChanlPerfMax;
u_short DG_ChanlTime[32];
OT_TYPE DG_DivideBuffer[256];
DG_CHANL DG_Chanls[3];

void MgsTextureCorrectionBegin(int frame) { (void)frame; }

int MgsVideoHalfWidth(void) { return half_width; }
void DG_Clip(RECT *rect, int distance) { (void)rect; (void)distance; }
long GetRCnt(long counter) { (void)counter; return 0; }
void GV_ZeroMemory(void *memory, int size) { memset(memory, 0, (size_t)size); }

static void MakeBoundVerts(int *bounds)
{
    ++projections;
    for (int index = 0; index < 8; ++index)
    {
        (&projected[1][0])[index].vx = (short)bounds[index & 1 ? 0 : 3];
        (&projected[1][0])[index].vy = (short)bounds[index & 2 ? 1 : 4];
        (&depths[1][0])[index] = bounds[2];
    }
}

int DG_MakeObjPacket(DG_OBJ *object, int index, int flags)
{
    (void)flags;
    ++allocations;
    if (allocations == fail_allocation)
        return -1;
    object->packs[index] = (POLY_GT4 *)&definition;
    return 0;
}

void DG_FreeObjPacket(DG_OBJ *object, int index)
{
    ++releases;
    object->packs[index] = NULL;
}

static void UpdateThermalTexture(DG_CHANL *channel, int index)
{
    (void)channel;
    (void)index;
}

#undef gte_SetRotMatrix
#undef gte_SetTransMatrix
#define gte_SetRotMatrix(matrix) ((void)(matrix))
#define gte_SetTransMatrix(matrix) ((void)(matrix))
#define VXY projected
#define VZP depths
#include "visibility_helpers.inc"

static void screen(DG_CHANL *channel, int index)
{
    (void)channel;
    (void)index;
    ++screen_calls;
}

static void rendering(DG_CHANL *channel, int index)
{
    (void)channel;
    (void)index;
    assert(fixture.group.bound_mode == expected_group);
    assert(fixture.models[0].bound_mode == expected_model);
    ++render_checks;
}

static void bounds(int *values, int left, int right)
{
    values[0] = left;
    values[1] = -10;
    values[2] = 1;
    values[3] = right;
    values[4] = 10;
    values[5] = 1;
}

static void reset(int flags, int left, int right)
{
    memset(&fixture, 0, sizeof(fixture));
    memset(models, 0, sizeof(models));
    memset(&definition, 0, sizeof(definition));
    fixture.group.flag = (unsigned)flags;
    fixture.group.def = &definition;
    fixture.group.n_models = 3;
    fixture.group.group_id = 1;
    bounds(&definition.lx, left, right);
    for (int index = 0; index < 3; ++index)
    {
        fixture.models[index].model = &models[index];
        bounds(&models[index].lx, left, right);
    }
    queue[0] = &fixture.group;
    DG_Chanls[1].queue = queue;
    DG_Chanls[1].objs_index = 1;
    DG_ChanlUnits[0] = screen;
    DG_ChanlUnits[1] = DG_BoundChanl;
    for (int index = 2; index < 7; ++index)
        DG_ChanlUnits[index] = rendering;
    projections = allocations = releases = fail_allocation = 0;
    render_checks = screen_calls = 0;
    stop_chanl_system_flag = DG_HikituriFlag = 0;
    half_width = 214;
}

static void check_render_and_gameplay(void)
{
    const int ranges[][4] = {
        {180, 190, 2, 0}, {150, 180, 2, 1}, {-190, -180, 2, 0},
        {-180, -150, 2, 1}, {-20, 20, 2, 2}, {220, 230, 0, 0},
        {210, 220, 1, 0}, {-220, -210, 1, 0}, {-170, 170, 2, 1},
    };
    for (size_t index = 0; index < sizeof(ranges) / sizeof(ranges[0]); ++index)
    {
        reset(DG_FLAG_BOUND | DG_FLAG_GBOUND, ranges[index][0], ranges[index][1]);
        expected_group = expected_model = ranges[index][2];
        DG_SortChanlSystem(0);
        assert(render_checks == 5);
        assert(fixture.group.bound_mode == ranges[index][3]);
        for (int model = 0; model < 3; ++model)
            assert(fixture.models[model].bound_mode == ranges[index][3]);
        assert(projections == (expected_group ? 4 : 1));
    }
}

static void check_packet_failures(void)
{
    reset(DG_FLAG_BOUND | DG_FLAG_GBOUND, -20, 190);
    bounds(&models[0].lx, 180, 190);
    bounds(&models[1].lx, -20, 20);
    bounds(&models[2].lx, -20, 20);
    fail_allocation = 1;
    expected_group = expected_model = 0;
    DG_SortChanlSystem(0);
    assert(allocations == 3);
    assert(fixture.group.bound_mode == 1);
    assert(fixture.models[0].bound_mode == 0);
    assert(fixture.models[1].bound_mode == 2);
    assert(fixture.models[2].bound_mode == 2);

    reset(DG_FLAG_BOUND | DG_FLAG_GBOUND, -20, 20);
    fixture.models[1].bound_mode = 1;
    fail_allocation = 1;
    DG_SortChanlSystem(0);
    assert(allocations == 1);
    assert(fixture.group.bound_mode == 0);
    assert(fixture.models[1].bound_mode == 1);

    reset(DG_FLAG_BOUND, -20, 20);
    fail_allocation = 1;
    expected_group = 2;
    DG_SortChanlSystem(0);
    assert(allocations == 3);
    assert(fixture.group.bound_mode == 2);
    assert(fixture.models[0].bound_mode == 0);
    assert(fixture.models[2].bound_mode == 2);
}

static void custom_bounds(DG_CHANL *channel, int index)
{
    (void)channel;
    (void)index;
    MgsVisibilityRemember(&fixture.group.bound_mode, 0);
    fixture.group.bound_mode = 2;
    fixture.models[0].bound_mode = 2;
}

static void check_scope_and_default(void)
{
    reset(DG_FLAG_BOUND | DG_FLAG_GBOUND, 180, 190);
    expected_group = expected_model = 2;
    DG_SortChanlSystem(0);
    fixture.group.bound_mode = fixture.models[0].bound_mode = 1;
    DG_HikituriFlag = 1;
    DG_SortChanlSystem(0);
    assert(fixture.group.bound_mode == 1);
    stop_chanl_system_flag = 1;
    DG_SortChanlSystem(0);
    assert(fixture.models[0].bound_mode == 1);
    stop_chanl_system_flag = DG_HikituriFlag = 0;
    DG_ChanlUnits[1] = custom_bounds;
    DG_SortChanlSystem(0);
    assert(fixture.group.bound_mode == 0);
    assert(fixture.models[0].bound_mode == 2);

    reset(DG_FLAG_BOUND | DG_FLAG_GBOUND, 180, 190);
    half_width = 160;
    expected_group = expected_model = 0;
    DG_SortChanlSystem(0);
    assert(fixture.group.bound_mode == 0 && allocations == 0);
}

static void check_growth(void)
{
    short values[1025];
    MgsVisibilityBegin(1);
    for (int index = 0; index < 1025; ++index)
    {
        values[index] = 2;
        MgsVisibilityRemember(&values[index], index % 3);
    }
    MgsVisibilityEnd();
    for (int index = 0; index < 1025; ++index)
        assert(values[index] == index % 3);
}

int main(void)
{
#ifdef _WIN32
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif
    assert(offsetof(TestGroup, models) == sizeof(DG_OBJS));
    check_render_and_gameplay();
    check_packet_failures();
    check_scope_and_default();
    check_growth();
    puts("Widescreen rendering preserves classic gameplay visibility");
    return 0;
}
