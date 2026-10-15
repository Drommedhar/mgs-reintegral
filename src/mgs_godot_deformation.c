#include "mgs_native.h"
#include "mgs_godot_deformation.h"
#include "mgs_godot_scene.h"
#include "libdg/libdg.h"
#include <stdio.h>
#include <stdlib.h>
#undef fprintf

enum { MODEL_LIMIT = 2048, PART_LIMIT = 256, VERTEX_LIMIT = 256, BYTE_LIMIT = 64 * 1024 * 1024 };
typedef struct {
    DG_DEF *definition;
    uint16_t *owners;
    SVECTOR *baseline;
    float *deltas;
    uint32_t count, captured;
    uint64_t version;
    int next_part, dirty;
} Deformation;

static Deformation models[MODEL_LIMIT];
static uint16_t vertex_owners[PART_LIMIT][VERTEX_LIMIT];
static uint32_t resident_bytes;
static uint64_t next_version;

static void Fail(const char *message)
{
    fprintf(stderr, "Godot native deformation: %s\n", message);
    exit(EXIT_FAILURE);
}

static void *Allocate(uint32_t count, uint32_t stride)
{
    if (count > (BYTE_LIMIT - resident_bytes) / stride) Fail("memory budget exceeded");
    void *data = malloc(count * stride);
    if (!data) Fail("allocation failed");
    resident_bytes += count * stride;
    return data;
}

static Deformation *Find(DG_DEF *definition)
{
    for (unsigned i = 0; i < MODEL_LIMIT; ++i)
        if (models[i].definition == definition) return &models[i];
    return NULL;
}

static Deformation *Begin(DG_DEF *definition)
{
    Deformation *entry = Find(definition);
    if (!entry) {
        for (unsigned i = 0; i < MODEL_LIMIT; ++i) {
            if (!models[i].definition) { entry = &models[i]; break; }
        }
    }
    if (!entry) Fail("model capacity exceeded");
    resident_bytes -= entry->count * (entry->owners ? sizeof(uint16_t) : 0);
    resident_bytes -= entry->count * (entry->baseline ? sizeof(SVECTOR) + 3 * sizeof(float) : 0);
    free(entry->owners);
    free(entry->baseline);
    free(entry->deltas);
    *entry = (Deformation){.definition = definition};
    if (definition->n_x_models < 1 || definition->n_x_models > PART_LIMIT)
        Fail("invalid model part count");
    for (int part = 0; part < definition->n_x_models; ++part) {
        int faces = definition->models[part].n_faces;
        if (faces < 0 || faces > 65535) Fail("invalid face count");
        entry->count += (uint32_t)faces * 4;
    }
    if (entry->count) entry->owners = Allocate(entry->count, sizeof(uint16_t));
    return entry;
}

void MgsGodotCaptureVertexOwners(DG_DEF *definition, int part)
{
    if (!MgsGodotSceneEnabled()) return;
    Deformation *entry = part == 0 ? Begin(definition) : Find(definition);
    if (!entry || part != entry->next_part || part >= definition->n_x_models)
        Fail("unordered model loading");
    const DG_MDL *model = &definition->models[part];
    if (model->n_verts < 0 || model->n_verts > VERTEX_LIMIT || model->parent < -1 || model->parent >= part)
        Fail("invalid vertex ownership extent");
    for (int vertex = 0; vertex < model->n_verts; ++vertex) {
        int parent_index = model->verts[vertex].pad;
        uint16_t owner = (uint16_t)((part << 8) | vertex);
        if (parent_index != -1) {
            if (model->parent < 0 || parent_index < 0 || parent_index >= definition->models[model->parent].n_verts)
                Fail("linked vertex outside parent");
            owner = vertex_owners[model->parent][parent_index];
        }
        vertex_owners[part][vertex] = owner;
    }
    for (int corner = 0; corner < model->n_faces * 4; ++corner) {
        unsigned vertex = model->vindices[corner];
        if (vertex >= (unsigned)model->n_verts || entry->captured >= entry->count)
            Fail("face vertex outside model");
        entry->owners[entry->captured++] = vertex_owners[part][vertex];
    }
    ++entry->next_part;
}

static SVECTOR Vertex(const Deformation *entry, uint32_t corner)
{
    unsigned owner = entry->owners[corner];
    return entry->definition->models[owner >> 8].verts[owner & 255];
}

void MgsGodotTrackDeformation(DG_DEF *definition)
{
    if (!MgsGodotSceneEnabled()) return;
    Deformation *entry = Find(definition);
    if (!entry || entry->next_part != definition->n_x_models || entry->captured != entry->count)
        Fail("deformation started without original vertex ownership");
    if (entry->baseline || !entry->count) return;
    entry->baseline = Allocate(entry->count, sizeof(SVECTOR));
    entry->deltas = Allocate(entry->count, 3 * sizeof(float));
    for (uint32_t corner = 0; corner < entry->count; ++corner)
        entry->baseline[corner] = Vertex(entry, corner);
    MgsGodotDeformationChanged(definition);
}

void MgsGodotDeformationChanged(DG_DEF *definition)
{
    if (!MgsGodotSceneEnabled()) return;
    Deformation *entry = Find(definition);
    if (!entry || !entry->baseline) return;
    if (next_version == UINT64_MAX) Fail("deformation version exhausted");
    entry->version = ++next_version;
    entry->dirty = 1;
}

const float *MgsGodotDeformation(DG_DEF *definition, uint32_t *size, uint64_t *version)
{
    Deformation *entry = Find(definition);
    *size = 0;
    *version = 0;
    if (!entry || !entry->baseline) return NULL;
    if (entry->dirty) {
        for (uint32_t corner = 0; corner < entry->count; ++corner) {
            SVECTOR current = Vertex(entry, corner), baseline = entry->baseline[corner];
            entry->deltas[corner * 3] = (current.vx - baseline.vx) / 1000.0f;
            entry->deltas[corner * 3 + 1] = (baseline.vy - current.vy) / 1000.0f;
            entry->deltas[corner * 3 + 2] = (baseline.vz - current.vz) / 1000.0f;
        }
        entry->dirty = 0;
    }
    *size = entry->count * 3 * sizeof(float);
    *version = entry->version;
    return entry->deltas;
}
