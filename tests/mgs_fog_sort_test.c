#include "mgs_native.h"
#undef fprintf
#include "mgs_godot_scene.h"
#include "libdg/libdg.h"
#include <assert.h>

static OT_TYPE tables[2][257];
OT_TYPE DG_DivideBuffer[256];
unsigned long psyz_scratchpad[256];
int DG_CurrentGroupID = 1, GV_PauseLevel;
int s12c_800DA428 = 8, s12c_800DA430 = 20, s12c_800DA434 = 12;
static short fog_values[256];
short *s12c_800DAA44 = fog_values;
static DG_PRIM primitives[6];
static POLY_FT4 packets[6][2][2];
static POLY_GT4 legacy_mesh[2];
static DG_OBJS *queue[6];
static DG_CHANL channel;
static int enabled, callbacks, reports;
static void FogCallback(void *scratch, void *packet, int value)
{ (void)scratch; (void)packet; (void)value; ++callbacks; }
static void NoFog(void *scratch, void *packet, int value)
{ (void)scratch; (void)packet; (void)value; }
static void *fog_prim_funcs_800C347C[32];
int MgsGodotSceneEnabled(void) { return enabled; }
int MgsGodotOwnsEffect(DG_PRIM *prim, int face, const void *packet)
{ (void)packet; return prim == &primitives[0] && face == 0; }
int MgsGodotLegacyShadowPacket(const void *packet, int type)
{
    (void)type;
    return packet == &packets[2][0][0] || packet == &packets[2][1][0];
}
void MgsGodotReportWorldCoverage(DG_CHANL *current, int buffer)
{ assert(current == &channel && buffer >= 0 && buffer <= 1); ++reports; }
#undef gte_ldfcdir
#define gte_ldfcdir(r,g,b) ((void)0)
#define gte_strgb_s0(packet) ((void)(packet))
#include "fog_sort_helpers.inc"

static void Reset(int buffer)
{
    memset(DG_DivideBuffer, 0, sizeof(DG_DivideBuffer));
    memset(primitives, 0, sizeof(primitives));
    memset(packets, 0, sizeof(packets));
    memset(&legacy_mesh[buffer], 0, sizeof(legacy_mesh[buffer]));
    legacy_mesh[buffer].code = 0x3c;
    setlen(&legacy_mesh[buffer], 12);
    addPrim(&DG_DivideBuffer[0], &legacy_mesh[buffer]);
    for (int i = 0; i < 257; ++i) {
        setlen(&tables[buffer][i], 0);
        setaddr(&tables[buffer][i], i ? &tables[buffer][i - 1] : NULL);
    }
    for (int i = 0; i < 6; ++i) {
        queue[i] = (DG_OBJS *)&primitives[i];
        primitives[i].type = DG_PRIM_POLY_FT4;
        primitives[i].prim_count = 1;
        primitives[i].psize = sizeof(POLY_FT4);
        primitives[i].packs[buffer] = packets[i][buffer];
        for (int face = 0; face < 2; ++face) {
            packets[i][buffer][face].tag = 12 * 256;
            packets[i][buffer][face].code = 0x2c;
            setlen(&packets[i][buffer][face], 9);
        }
    }
    primitives[0].prim_count = 2;
    primitives[1].type |= MGS_GODOT_LEGACY_GLOW;
    primitives[3].type |= DG_PRIM_INVISIBLE;
    primitives[4].group_id = 2;
    packets[5][buffer][0].tag = 21 * 256;
    setlen(&packets[5][buffer][0], 9);
    channel.ot[buffer] = tables[buffer];
    channel.queue = queue;
    channel.prim_index = 0;
    channel.queue_size = 6;
    for (int i = 0; i < 32; ++i) fog_prim_funcs_800C347C[i] = FogCallback;
    fog_prim_funcs_800C347C[0] = NoFog;
    callbacks = reports = 0;
}
static void CheckSorted(int buffer, int godot)
{
    unsigned native = 0, world = 0, walked = 0;
    void *node = (void *)getaddr(tables[buffer] + 256);
    while (node != tables[buffer]) {
        assert(++walked < 800);
        if (getlen(node)) {
            unsigned code = *((unsigned *)node + sizeof(OT_TYPE) / sizeof(unsigned));
            if (code == 0xf4000000u) ++world;
            else {
                if (godot) assert(node == &packets[0][buffer][1] || node == &legacy_mesh[buffer]);
                ++native;
            }
        }
        node = (void *)getaddr(node);
    }
    assert(native == (godot ? 2u : 5u));
    assert((world > 0) == godot);
    assert(callbacks == (GV_PauseLevel ? 0 : godot ? 1 : 4));
    assert(reports == godot);
}
int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    for (int mode = 0; mode < 2; ++mode) {
        enabled = mode;
        for (int buffer = 0; buffer < 2; ++buffer) {
            for (int pause = 0; pause < 2; ++pause) {
                Reset(buffer);
                GV_PauseLevel = pause;
                FogSortChanl_800D4E98(&channel, buffer);
#ifdef MGS_GODOT_SCENE
                CheckSorted(buffer, mode);
#else
                CheckSorted(buffer, 0);
#endif
            }
        }
    }
    puts("Fog world markers and per-face ownership preserve legacy range, groups and pause behavior");
    return 0;
}
