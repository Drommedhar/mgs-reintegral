#include "mgs_native.h"
#include "mgs_godot_scene.h"
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
typedef struct { O_TAG; u_long code, near_depth, far_depth; } WorldMarker;
static WorldMarker world_markers[2][512];

static void LinkWorldMarker(WorldMarker *marker, void *previous, unsigned near_depth, unsigned far_depth) {
    setlen(marker, 3);
    marker->code = 0xf4000000u;
    marker->near_depth = near_depth;
    marker->far_depth = far_depth;
    addPrim(previous, marker);
}

void MgsGodotSortWorld(DG_CHANL *channel, int buffer_index) {
    if (!MgsGodotSceneEnabled()) return;
    WorldMarker *marker = world_markers[buffer_index];
    unsigned far_depth = 65536;
    for (int index = 255; index >= 0; --index) {
        OT_TYPE *bucket = channel->ot[buffer_index] + 1 + index;
        void *end = bucket - 1;
        void *tail = bucket;
        while ((void *)getaddr(tail) != end) tail = (void *)getaddr(tail);
        if (tail == bucket) continue;
        unsigned upper = (index + 1u) * 256u;
        if (upper < far_depth) LinkWorldMarker(marker++, bucket, upper, far_depth);
        LinkWorldMarker(marker++, tail, index * 256u, upper);
        far_depth = index * 256u;
    }
    if (far_depth) LinkWorldMarker(marker, channel->ot[buffer_index] + 1, 0, far_depth);
}

int MgsGodotSceneEnabled(void) {
    const char *enabled = getenv("MGS_GODOT_SCENE_VIEW");
    return enabled && strcmp(enabled, "1") == 0 && !MgsVideoReferenceRequired();
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
    int linked = model->owner[part];
    const POLY_GT4 *packets = objects->objs[linked].packs[buffer_index];
    for (int count = 0; linked >= 0; ++count) {
        if (count >= PART_LIMIT || linked >= objects->def->n_x_models)
            SceneFailure("invalid live model chain");
        const DG_MDL *definition = &objects->def->models[linked];
        if (definition->flag & DG_MODEL_TRANS) return 0;
        for (int face = 0; face < definition->n_faces; ++face) {
            if (!definition->texids[face]) return 0;
            if (packets && (packets[face].code != 0x3c || (packets[face].tpage & 0x180) == 0x100))
                return 0;
        }
        if (packets) packets += definition->n_faces;
        linked = definition->extend;
    }
    return 1;
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
                }
            }
            AppendScene(bytes, packet, sizeof(packet));
            if (pack) ++pack;
        }
    }
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
    } header = {0};
    _Static_assert(sizeof(header) == 64, "Godot scene header layout");
    StageName(header.stage);
    MatrixFloats(header.view, &channel->eye_inv);
    header.projection = channel->screen;
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
            struct { float matrix[12]; uint32_t visible; } state;
            const unsigned owner = model->owner[part];
            MatrixFloats(state.matrix, &objects->objs[owner].screen);
            /* Cinematics change the meaning of .world; .screen is the final local-to-view transform. */
            for (unsigned column = 0; column < 4; ++column)
                state.matrix[4 + column] *= 64.0f / 58.0f;
            state.visible = owner < (unsigned)objects->n_models && objects->bound_mode &&
                objects->objs[owner].bound_mode && MgsGodotOwnsPart(objects, part, buffer_index);
            AppendScene(&bytes, &state, sizeof(state));
        }
        if (object.color_count) {
            AppendColors(&bytes, objects, model, buffer_index);
            AppendPackets(&bytes, objects, model, buffer_index);
        }
        ++header.count;
    }
    memcpy(scene_data, &header, sizeof(header));
    MgsGodotQueue(MGS_GODOT_SCENE_FRAME, scene_data, bytes, NULL, 0);
}
