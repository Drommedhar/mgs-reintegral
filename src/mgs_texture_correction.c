#include "mgs_texture_correction.h"
#include <psyz/gpu.h>
#include <psyz/gte.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const void *address;
    uint32_t xy;
    PsyzProjectedVertex vertex;
} VertexDepth;

typedef struct {
    VertexDepth *entries;
    size_t capacity, count;
} DepthFrame;

static DepthFrame frames[2];
static DepthFrame *current = &frames[0];
static int correction_enabled;

static VertexDepth *FindSlot(DepthFrame *frame, const void *address)
{
    uintptr_t key = (uintptr_t)address >> 2;
    size_t index = ((key * 2654435761u) ^ (key >> 16)) & (frame->capacity - 1);
    while (frame->entries[index].address && frame->entries[index].address != address)
        index = (index + 1) & (frame->capacity - 1);
    return &frame->entries[index];
}

static void GrowFrame(DepthFrame *frame)
{
    size_t capacity = frame->capacity ? frame->capacity * 2 : 1024;
    if (capacity < frame->capacity || capacity > SIZE_MAX / sizeof(VertexDepth)) {
        fputs("Texture depth table is too large.\n", stderr);
        exit(EXIT_FAILURE);
    }
    DepthFrame expanded = {calloc(capacity, sizeof(VertexDepth)), capacity, frame->count};
    if (!expanded.entries) {
        fputs("Cannot allocate texture depth table.\n", stderr);
        exit(EXIT_FAILURE);
    }
    for (size_t i = 0; i < frame->capacity; ++i)
        if (frame->entries[i].address)
            *FindSlot(&expanded, frame->entries[i].address) = frame->entries[i];
    free(frame->entries);
    *frame = expanded;
}

int MgsTextureCorrectionConfigure(int textures, int precision, int depth)
{
    int enabled = textures || precision || depth;
    if (Psyz_GpuConfigureGeometry(enabled ? MgsTextureCorrectionGet : NULL,
                                  textures, precision, depth) != 0)
        return 0;
    correction_enabled = enabled;
    for (unsigned i = 0; i < 2; ++i) {
        free(frames[i].entries);
        frames[i] = (DepthFrame){0};
    }
    return 1;
}

void MgsTextureCorrectionSelect(int frame)
{
    if (frame < 0 || frame > 1) {
        fputs("Invalid texture depth frame.\n", stderr);
        exit(EXIT_FAILURE);
    }
    current = &frames[frame];
    Psyz_GpuResetGeometryDepth();
}

void MgsTextureCorrectionBegin(int frame)
{
    if (frame < 0 || frame > 1) {
        fputs("Invalid texture depth frame.\n", stderr);
        exit(EXIT_FAILURE);
    }
    current = &frames[frame];
    if (current->entries)
        memset(current->entries, 0, current->capacity * sizeof(VertexDepth));
    current->count = 0;
}

static void SetVertex(const void *xy, PsyzProjectedVertex vertex)
{
    if (!correction_enabled || !xy)
        return;
    if (current->count >= current->capacity / 2)
        GrowFrame(current);
    VertexDepth *entry = FindSlot(current, xy);
    if (!entry->address)
        ++current->count;
    entry->address = xy;
    memcpy(&entry->xy, xy, sizeof(entry->xy));
    entry->vertex = vertex;
}

int MgsTextureCorrectionGet(const void *xy, PsyzProjectedVertex *vertex)
{
    if (!correction_enabled || !xy || !current->capacity)
        return 0;
    const VertexDepth *entry = FindSlot(current, xy);
    uint32_t packed;
    memcpy(&packed, xy, sizeof(packed));
    if (!entry->address || entry->xy != packed || entry->vertex.depth <= 0)
        return 0;
    *vertex = entry->vertex;
    return 1;
}

static PsyzProjectedVertex Project(const MATRIX *matrix, const SVECTOR *vertex)
{
    float camera[3];
    for (int row = 0; row < 3; ++row)
        camera[row] = matrix->t[row] +
            (matrix->m[row][0] * (float)vertex->vx +
             matrix->m[row][1] * (float)vertex->vy +
             matrix->m[row][2] * (float)vertex->vz) / 4096.0f;
    float screen = (float)(Psyz_GteCtrlRead(26) & 0xffff);
    if (camera[2] <= screen / 2 || camera[2] > 65535)
        return (PsyzProjectedVertex){0};
    float scale = screen / camera[2];
    float x = camera[0] * scale + (int32_t)Psyz_GteCtrlRead(24) / 65536.0f;
    float y = camera[1] * scale + (int32_t)Psyz_GteCtrlRead(25) / 65536.0f;
    if (x < -1024 || x > 1023 || y < -1024 || y > 1023)
        return (PsyzProjectedVertex){0};
    return (PsyzProjectedVertex){x, y, camera[2]};
}

void MgsTextureCorrectionCapture(const SVECTOR *vertices, int count, const DVECTOR *xy)
{
    if (!correction_enabled) return;
    MATRIX matrix;
    ReadRotMatrix(&matrix);
    for (int i = 0; i < count; ++i)
        SetVertex(xy + i, Project(&matrix, vertices + i));
}

void MgsTextureCorrectionProject(const void *xy, const SVECTOR *vertex)
{
    if (!correction_enabled) return;
    MATRIX matrix;
    ReadRotMatrix(&matrix);
    SetVertex(xy, Project(&matrix, vertex));
}

void MgsTextureCorrectionCopy(const void *destination, const void *source)
{
    if (!correction_enabled) return;
    PsyzProjectedVertex vertex = {0};
    MgsTextureCorrectionGet(source, &vertex);
    SetVertex(destination, vertex);
}
