#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "mgs_godot_geometry.h"
#include "mgs_stages.h"
#include "mgs_video.h"
#include "libdg/libdg.h"
#include "transport.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#undef fprintf

enum { MODEL_LIMIT = 2048, INSTANCE_LIMIT = 512, PART_LIMIT = 256 };
typedef struct {
    DG_DEF *definition;
    uint32_t identity;
    char stage[8];
    unsigned char owner[PART_LIMIT];
} Model;
typedef struct {
    DG_OBJS *objects;
    uint32_t identity;
} Instance;

static Model models[MODEL_LIMIT];
static Instance instances[INSTANCE_LIMIT];
static uint32_t next_instance;
static unsigned char scene_data[64 * 1024 * 1024];

int MgsGodotSceneEnabled(void) {
    static int enabled = -1;
    if (enabled < 0) {
        const char *setting = getenv("MGS_GODOT_SCENE_VIEW");
        enabled = setting && strcmp(setting, "1") == 0;
    }
    return enabled && !MgsVideoReferenceRequired();
}

static void SceneFailure(const char *reason) {
    fprintf(stderr, "Godot scene protocol: %s\n", reason);
    exit(EXIT_FAILURE);
}

static void StageName(char destination[8]) {
    const char *name = MgsNativeResourceStage();
    if (!name || strlen(name) > 8) SceneFailure("invalid resource stage namespace");
    memset(destination, 0, 8);
    memcpy(destination, name, strlen(name));
}

void MgsGodotRegisterModel(DG_DEF *definition, unsigned identity) {
    Model *entry = NULL;
    for (unsigned i = 0; i < MODEL_LIMIT; ++i) {
        if (models[i].definition == definition) {
            entry = &models[i];
            break;
        }
        if (!entry && !models[i].definition) entry = &models[i];
    }
    if (!entry) SceneFailure("model catalog capacity exceeded");
    entry->definition = definition;
    entry->identity = identity & 0xffffu;
    StageName(entry->stage);
    if (definition->n_x_models > PART_LIMIT || definition->n_models < 1)
        SceneFailure("invalid registered model part count");
    for (int part = 0; part < definition->n_x_models; ++part) {
        entry->owner[part] = (unsigned char)part;
    }
    for (int part = 0; part < definition->n_models; ++part) {
        int linked = part;
        for (int count = 0; linked >= 0; ++count) {
            if (count >= PART_LIMIT || linked >= definition->n_x_models)
                SceneFailure("invalid extended model chain");
            const DG_MDL *model = &definition->models[linked];
            entry->owner[linked] = (unsigned char)part;
            linked = model->extend;
        }
    }
}

void MgsGodotRegisterInstance(DG_OBJS *objects) {
    if (next_instance == UINT32_MAX) SceneFailure("instance identity exhausted");
    for (unsigned i = 0; i < INSTANCE_LIMIT; ++i) {
        if (!instances[i].objects) {
            instances[i] = (Instance){objects, ++next_instance};
            return;
        }
    }
    SceneFailure("instance capacity exceeded");
}

void MgsGodotRemoveInstance(DG_OBJS *objects) {
    MgsGodotRemoveAlarmLight(objects);
    for (unsigned i = 0; i < INSTANCE_LIMIT; ++i) {
        if (instances[i].objects == objects) {
            instances[i].objects = NULL;
            return;
        }
    }
}

static Model *FindModel(const DG_DEF *definition) {
    for (unsigned i = 0; i < MODEL_LIMIT; ++i)
        if (models[i].definition == definition) return &models[i];
    return NULL;
}

void MgsGodotRegisterGeneratedModel(DG_DEF *definition, unsigned kind) {
    if (kind != MGS_GODOT_GENERATED_LIGHT) SceneFailure("unknown generated model kind");
    MgsGodotRegisterModel(definition, 0);
    Model *model = FindModel(definition);
    model->identity = 0x80000000u | kind;
}

int MgsGodotOwnsPart(DG_OBJS *objects, int part, int buffer_index) {
    const Model *model = FindModel(objects->def);
    if (!model || part < 0 || part >= objects->def->n_x_models)
        SceneFailure("part ownership references an unregistered model");
    if (model->identity & 0x80000000u) return 0;
    if (MgsGodotLegacyPart(objects, part)) return 0;
    int linked = model->owner[part];
    const POLY_GT4 *packets = objects->objs[linked].packs[buffer_index];
    for (int count = 0; linked >= 0; ++count) {
        if (count >= PART_LIMIT || linked >= objects->def->n_x_models)
            SceneFailure("invalid live model chain");
        const DG_MDL *definition = &objects->def->models[linked];
        for (int face = 0; face < definition->n_faces; ++face) {
            if (!definition->texids[face]) {
                if (MgsGodotDegenerateFace(definition, face)) continue;
                return 0;
            }
            if (packets) {
                const unsigned code = packets[face].code, page = packets[face].tpage;
                if ((code & ~3u) != 0x3c || (page & 0x180) == 0x100 ||
                    ((code & 2) && ((page >> 5) & 3) == 2)) return 0;
            }
        }
        if (packets) packets += definition->n_faces;
        linked = definition->extend;
    }
    return 1;
}

int MgsGodotLegacyPart(DG_OBJS *objects, int part) {
    if (objects->flag & MGS_GODOT_LEGACY_GLOW) return 1;
    const DG_MDL *model = &objects->def->models[part];
    const unsigned shadow = GV_StrCode("shadow");
    if (!model->n_faces || !model->texids) return 0;
    for (int face = 0; face < model->n_faces; ++face)
        if (model->texids[face] != shadow) return 0;
    return 1;
}

int MgsGodotLegacyShadowPacket(const void *packet, int type) {
    if ((type & 31) != DG_PRIM_POLY_FT4) return 0;
    const DG_TEX *texture = DG_GetTexture(GV_StrCode("shadow"));
    if (!texture->id) return 0;
    const POLY_FT4 *quad = packet;
    return (quad->code & 0xfe) == 0x2e &&
           (quad->tpage & ~0x60) == (texture->tpage & ~0x60) &&
           quad->clut == texture->clut &&
           quad->u0 == texture->off_x && quad->v0 == texture->off_y &&
           quad->u3 == texture->off_x + texture->w &&
           quad->v3 == texture->off_y + texture->h;
}

static void MatrixFloats(float out[12], const MATRIX *matrix) {
    for (unsigned row = 0; row < 3; ++row) {
        for (unsigned column = 0; column < 3; ++column)
            out[row * 4 + column] = matrix->m[row][column] / 4096.0f;
        out[row * 4 + 3] = (float)matrix->t[row];
    }
}

static uint32_t InstanceIdentity(const DG_OBJS *objects) {
    for (unsigned i = 0; i < INSTANCE_LIMIT; ++i)
        if (instances[i].objects == objects) return instances[i].identity;
    SceneFailure("queued object lacks an instance identity");
    return 0;
}

static void AppendScene(uint32_t *bytes, const void *data, uint32_t size) {
    if (size > sizeof(scene_data) - *bytes) SceneFailure("scene snapshot capacity exceeded");
    memcpy(scene_data + *bytes, data, size);
    *bytes += size;
}

static POLY_GT4 *PartPackets(DG_OBJS *objects, const Model *model, int part, int buffer_index) {
    DG_OBJ *owner = &objects->objs[model->owner[part]];
    POLY_GT4 *pack = owner->packs[buffer_index];
    if (pack) {
        while (owner != &objects->objs[part]) {
            pack += owner->n_packs;
            owner = owner->extend;
            if (!owner) SceneFailure("invalid part packet chain");
        }
    }
    return pack;
}

static void AppendColors(uint32_t *bytes, DG_OBJS *objects, const Model *model, int buffer_index) {
    for (int part = 0; part < objects->def->n_x_models; ++part) {
        POLY_GT4 *pack = PartPackets(objects, model, part, buffer_index);
        for (int face = 0; face < objects->def->models[part].n_faces; ++face) {
            unsigned char colors[16] = {0};
            if (pack) {
                memcpy(colors, &pack->r0, 3);
                memcpy(colors + 4, &pack->r1, 3);
                memcpy(colors + 8, &pack->r3, 3);
                memcpy(colors + 12, &pack->r2, 3);
                for (int corner = 0; corner < 4; ++corner)
                    colors[corner * 4 + 3] = (pack->tag & 0xffffu) ? 255 : 0;
                if (pack->code & 1)
                    for (int corner = 0; corner < 4; ++corner)
                        memset(colors + corner * 4, 128, 3);
                ++pack;
            }
            AppendScene(bytes, colors, sizeof(colors));
        }
    }
}

static void AppendPackets(uint32_t *bytes, DG_OBJS *objects, const Model *model, int buffer_index) {
    for (int part = 0; part < objects->def->n_x_models; ++part) {
        const DG_MDL *definition = &objects->def->models[part];
        const POLY_GT4 *pack = PartPackets(objects, model, part, buffer_index);
        const int raise = objects->objs[model->owner[part]].raise;
        for (int face = 0; face < definition->n_faces; ++face) {
            float packet[4][4] = {{0}};
            if (pack && definition->texids[face]) {
                const DG_TEX *texture = DG_GetTexture(definition->texids[face]);
                const unsigned char u[] = {pack->u0, pack->u1, pack->u3, pack->u2};
                const unsigned char v[] = {pack->v0, pack->v1, pack->v3, pack->v2};
                for (int corner = 0; corner < 4; ++corner) {
                    packet[corner][0] = ((unsigned char)(u[corner] - texture->off_x) + 0.5f) / (texture->w + 1);
                    packet[corner][1] = ((unsigned char)(v[corner] - texture->off_y) + 0.5f) / (texture->h + 1);
                    packet[corner][2] = (unsigned short)((pack->tag & 0xffffu) - raise);
                    packet[corner][3] = (pack->code & 2) ? 1 + ((pack->tpage >> 5) & 3) : 0;
                }
            }
            AppendScene(bytes, packet, sizeof(packet));
            if (pack) ++pack;
        }
    }
}

static int PartTransparent(DG_OBJS *objects, const Model *model, int part, int buffer_index) {
    const POLY_GT4 *pack = PartPackets(objects, model, part, buffer_index);
    const DG_MDL *definition = &objects->def->models[part];
    if (!pack) return (definition->flag & DG_MODEL_TRANS) != 0;
    for (int face = 0; face < definition->n_faces; ++face)
        if (pack[face].code & 2) return 1;
    return 0;
}

void MgsGodotCaptureScene(DG_CHANL *channel, int buffer_index) {
    if (MgsVideoReferenceRequired()) return;
    if (!MgsNativeResourceStage()) {
        if (channel->objs_index) SceneFailure("scene objects exist before stage initialization");
        return;
    }
    struct {
        char stage[8];
        float view[12];
        float projection;
        uint32_t count;
        float horizontal_scale;
    } header = {0};
    _Static_assert(sizeof(header) == 68, "Godot scene header layout");
    StageName(header.stage);
    MatrixFloats(header.view, &channel->eye_inv);
    header.projection = channel->screen;
    header.horizontal_scale = MgsVideoHorizontalScale();
    uint32_t bytes = sizeof(header);
    for (int index = 0; index < channel->objs_index; ++index) {
        DG_OBJS *objects = channel->queue[index];
        const Model *model = FindModel(objects->def);
        if (!model) SceneFailure("unregistered model definition");
        const unsigned parts = objects->def->n_x_models;
        if (!parts || parts > PART_LIMIT) SceneFailure("invalid model part count");
        struct {
            uint32_t instance, asset;
            char stage[8];
            uint32_t flags, parts, visible_parts, color_count;
        } object = {InstanceIdentity(objects), model->identity, {0}, objects->flag,
                    parts, objects->n_models, 0};
        if (!(model->identity & 0x80000000u))
            for (unsigned part = 0; part < parts; ++part)
                object.color_count += objects->def->models[part].n_faces * 4u;
        memcpy(object.stage, model->stage, sizeof(object.stage));
        AppendScene(&bytes, &object, sizeof(object));
        for (unsigned part = 0; part < parts; ++part) {
            struct { float matrix[12]; uint32_t flags; } state;
            const unsigned owner = model->owner[part];
            MatrixFloats(state.matrix, &objects->objs[owner].screen);
            /* Cinematics change the meaning of .world; .screen is the final local-to-view transform. */
            for (unsigned column = 0; column < 4; ++column)
                state.matrix[4 + column] *= 64.0f / 58.0f;
            const int active = owner < (unsigned)objects->n_models &&
                !(objects->flag & DG_FLAG_INVISIBLE) &&
                (!objects->group_id || (objects->group_id & DG_CurrentGroupID)) &&
                MgsGodotOwnsPart(objects, part, buffer_index);
            state.flags = active ? MGS_GODOT_PART_SHADOW : 0;
            if (active && objects->bound_mode && objects->objs[owner].bound_mode)
                state.flags |= MGS_GODOT_PART_VISIBLE;
            if (active && PartTransparent(objects, model, part, buffer_index))
                state.flags |= MGS_GODOT_PART_TRANSPARENT;
            AppendScene(&bytes, &state, sizeof(state));
        }
        if (object.color_count) {
            AppendColors(&bytes, objects, model, buffer_index);
            AppendPackets(&bytes, objects, model, buffer_index);
        }
        ++header.count;
    }
    memcpy(scene_data, &header, sizeof(header));
    bytes += MgsGodotAppendEffects(channel, buffer_index, scene_data + bytes, sizeof(scene_data) - bytes);
    bytes += MgsGodotAppendLights(scene_data + bytes, sizeof(scene_data) - bytes);
    MgsGodotQueue(MGS_GODOT_SCENE_FRAME, scene_data, bytes, NULL, 0);
}
