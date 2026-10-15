#include "mgs_native.h"
#undef fprintf
#include "mgs_godot_coverage.h"
#include "mgs_godot_scene.h"
#include "mgs_godot_context.h"
#include "mgs_safety.h"
#include "libdg/libdg.h"

static void CountMeshes(MgsGodotWorldCoverage *coverage, DG_CHANL *channel, int buffer)
{
    for (int index = 0; index < channel->objs_index; ++index) {
        DG_OBJS *objects = channel->queue[index];
        if (!MgsGodotRetainObjects(objects)) continue;
        for (int part = 0; part < objects->n_models; ++part) {
            if (MgsGodotLegacyPart(objects, part))
                ++coverage->suppressed_meshes;
            else if (MgsGodotOwnsPart(objects, part, buffer))
                ++coverage->godot_meshes;
            else
                ++coverage->compatibility_meshes;
        }
    }
}

MgsGodotWorldCoverage MgsGodotCountWorldCoverage(DG_CHANL *channel, int buffer)
{
    MgsGodotWorldCoverage coverage = {0};
    CountMeshes(&coverage, channel, buffer);
    for (int index = channel->prim_index; index < channel->queue_size; ++index) {
        DG_PRIM *prim = (DG_PRIM *)channel->queue[index];
        if ((prim->type & DG_PRIM_INVISIBLE) ||
            (prim->group_id && !(prim->group_id & DG_CurrentGroupID))) continue;
        for (int face = 0; face < prim->prim_count; ++face) {
            const char *packet = (const char *)prim->packs[buffer] + face * prim->psize;
            if ((prim->type & MGS_GODOT_LEGACY_GLOW) || MgsGodotLegacyShadowPacket(packet, prim->type))
                ++coverage.suppressed_effects;
            else if (MgsGodotOwnsEffect(prim, face, packet))
                ++coverage.godot_effects;
            else {
                ++coverage.compatibility_effects;
                coverage.compatibility_primitive_types |= 1u << (prim->type & 31);
            }
        }
    }
    return coverage;
}

static int AuditMode(void)
{
    static int mode = -1;
    if (mode >= 0) return mode;
    const char *value = getenv("MGS_GODOT_WORLD_AUDIT");
    if (!value || !*value) return mode = 0;
    if (strcmp(value, "log") == 0) return mode = 1;
    if (strcmp(value, "strict") == 0) return mode = 2;
    if (strcmp(value, "detail") == 0) return mode = 3;
    fprintf(stderr, "Godot world audit: use MGS_GODOT_WORLD_AUDIT=log or strict or detail\n");
    exit(EXIT_FAILURE);
}

static void ReportUnsupportedMeshes(DG_CHANL *channel, int buffer)
{
    for (int index = 0; index < channel->objs_index; ++index) {
        DG_OBJS *objects = channel->queue[index];
        if (!MgsGodotRetainObjects(objects)) continue;
        for (int part = 0; part < objects->n_models; ++part) {
            if (MgsGodotLegacyPart(objects, part) || MgsGodotOwnsPart(objects, part, buffer)) continue;
            const DG_MDL *definition = &objects->def->models[part];
            const POLY_GT4 *packet = objects->objs[part].packs[buffer];
            printf("MGS_WORLD_UNSUPPORTED model=%08x part=%d faces=%d texture=%04x code=%02x page=%04x\n",
                   MgsGodotModelIdentity(objects), part, definition->n_faces,
                   definition->n_faces && definition->texids ? definition->texids[0] : 0,
                   packet ? packet->code : 0, packet ? packet->tpage : 0);
        }
    }
}

static void ReportUnsupportedEffects(DG_CHANL *channel, int buffer)
{
    for (int index = channel->prim_index; index < channel->queue_size; ++index) {
        DG_PRIM *prim = (DG_PRIM *)channel->queue[index];
        if ((prim->type & (DG_PRIM_INVISIBLE | MGS_GODOT_LEGACY_GLOW)) ||
            (prim->group_id && !(prim->group_id & DG_CurrentGroupID))) continue;
        for (int face = 0; face < prim->prim_count; ++face) {
            const void *packet = (const char *)prim->packs[buffer] + face * prim->psize;
            if (MgsGodotLegacyShadowPacket(packet, prim->type) || MgsGodotOwnsEffect(prim, face, packet)) continue;
            printf("MGS_WORLD_UNSUPPORTED effect_type=%04x face=%d texture=%08x",
                   prim->type, face, MgsGodotEffectTexture(prim, face));
            if ((prim->type & 31) == DG_PRIM_POLY_FT4) {
                const POLY_FT4 *quad = packet;
                printf(" code=%02x page=%04x clut=%04x uv=%d,%d:%d,%d",
                       quad->code, quad->tpage, quad->clut, quad->u0, quad->v0, quad->u3, quad->v3);
            }
            putchar('\n');
        }
    }
}

void MgsGodotReportWorldCoverage(DG_CHANL *channel, int buffer)
{
    static MgsGodotWorldCoverage previous;
    static uint32_t previous_epoch;
    static int reported;
    int mode = AuditMode();
    if (!mode || !MgsGodotSceneEnabled()) return;
    MgsGodotWorldCoverage current = MgsGodotCountWorldCoverage(channel, buffer);
    uint32_t epoch = MgsGodotSceneEpoch();
    if (!reported || epoch != previous_epoch || memcmp(&previous, &current, sizeof(current)) != 0) {
        printf("MGS_WORLD_COVERAGE disc=%d stage=%s epoch=%u "
               "meshes_godot=%u meshes_compat=%u meshes_suppressed=%u "
               "effects_godot=%u effects_compat=%u effects_suppressed=%u prim_types=0x%08x\n",
               MgsSafetyDiscNumber(), MgsNativeResourceStage(), epoch,
               current.godot_meshes, current.compatibility_meshes, current.suppressed_meshes,
               current.godot_effects, current.compatibility_effects, current.suppressed_effects,
               current.compatibility_primitive_types);
        if (mode == 3) {
            ReportUnsupportedMeshes(channel, buffer);
            ReportUnsupportedEffects(channel, buffer);
        }
        previous = current;
        previous_epoch = epoch;
        reported = 1;
    }
    if (mode == 2 && (current.compatibility_meshes || current.compatibility_effects)) {
        fprintf(stderr, "Godot strict world audit: unsupported native world content in %s; "
                "see MGS_WORLD_COVERAGE (UI/video are outside this audit).\n", MgsNativeResourceStage());
        exit(EXIT_FAILURE);
    }
}
