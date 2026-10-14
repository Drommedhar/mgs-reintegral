#include "mgs_native.h"
#undef fprintf
#include "mgs_godot_coverage.h"
#include "mgs_godot_scene.h"
#include "libdg/libdg.h"
#include <assert.h>

static struct { DG_OBJS group; DG_OBJ parts[3]; } objects[3];
static struct { DG_DEF definition; DG_MDL parts[3]; } model;
static DG_PRIM primitives[4];
static POLY_FT4 packets[4][2];
static DG_OBJS *queue[7];
static int enabled = 1;
static uint32_t epoch = 1;
int DG_CurrentGroupID = 1;
int MgsGodotSceneEnabled(void) { return enabled; }
int MgsSafetyDiscNumber(void) { return 2; }
const char *MgsNativeResourceStage(void) { return "s12c"; }
uint32_t MgsGodotSceneEpoch(void) { return epoch; }
int MgsGodotRetainObjects(const DG_OBJS *object)
{
    return enabled && !(object->flag & DG_FLAG_INVISIBLE) &&
        (!object->group_id || object->group_id & DG_CurrentGroupID);
}
int MgsGodotLegacyPart(DG_OBJS *object, int part) { (void)object; return part == 2; }
unsigned MgsGodotModelIdentity(const DG_OBJS *object) { (void)object; return 0x1234; }
unsigned MgsGodotEffectTexture(const DG_PRIM *prim, int face) { (void)prim; (void)face; return 0x5678; }
int MgsGodotOwnsPart(DG_OBJS *object, int part, int buffer)
{ (void)object; (void)buffer; return part == 0; }
int MgsGodotOwnsEffect(DG_PRIM *prim, int face, const void *packet)
{ (void)packet; return prim == primitives && face == 0; }
int MgsGodotLegacyShadowPacket(const void *packet, int type)
{ (void)type; return packet == &packets[1][0]; }

int main(int argc, char **argv)
{
    _set_error_mode(_OUT_TO_STDERR);
    DG_CHANL channel = {0};
    for (int i = 0; i < 3; ++i) {
        objects[i].group.n_models = 3;
        objects[i].group.def = &model.definition;
        queue[i] = &objects[i].group;
    }
    objects[1].group.flag = DG_FLAG_INVISIBLE;
    objects[2].group.group_id = 2;
    model.parts[1].n_faces = 1;
    for (int i = 0; i < 4; ++i) {
        primitives[i].type = DG_PRIM_POLY_FT4;
        primitives[i].prim_count = 2;
        primitives[i].psize = sizeof(POLY_FT4);
        primitives[i].packs[0] = packets[i];
        queue[3 + i] = (DG_OBJS *)&primitives[i];
    }
    primitives[1].prim_count = 1;
    primitives[2].type |= MGS_GODOT_LEGACY_GLOW;
    primitives[3].group_id = 2;
    channel.queue = queue;
    channel.objs_index = 3;
    channel.prim_index = 3;
    channel.queue_size = 7;
    MgsGodotWorldCoverage counts = MgsGodotCountWorldCoverage(&channel, 0);
    assert(counts.godot_meshes == 1 && counts.compatibility_meshes == 1 && counts.suppressed_meshes == 1);
    assert(counts.godot_effects == 1 && counts.compatibility_effects == 1 && counts.suppressed_effects == 3);
    assert(counts.compatibility_primitive_types == (1u << DG_PRIM_POLY_FT4));
    if (argc > 1) {
        if (argc > 2) {
            objects[0].group.n_models = 1;
            primitives[0].prim_count = 1;
        }
        _putenv_s("MGS_GODOT_WORLD_AUDIT", argv[1]);
        enabled = 0;
        MgsGodotReportWorldCoverage(&channel, 0);
        enabled = 1;
        MgsGodotReportWorldCoverage(&channel, 0);
        MgsGodotReportWorldCoverage(&channel, 0);
        ++epoch;
        MgsGodotReportWorldCoverage(&channel, 0);
    }
    puts("World coverage distinguishes semantic, compatibility and deliberately suppressed content");
    return 0;
}
