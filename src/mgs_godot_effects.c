#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "libdg/libdg.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#undef fprintf

enum { EFFECT_LIMIT = 1024, EFFECT_EMISSIVE = 8, EFFECT_ONE_SIDED = 16,
       EFFECT_BEAM = 32, EFFECT_RIPPLE = 64, EFFECT_FOOTPRINT = 128 };
typedef struct { DG_PRIM *prim; unsigned texture, flags; int first_face, face_count; } Effect;
typedef struct { float position[4], uv_color[4], color_blend[4]; } EffectVertex;
static Effect effects[EFFECT_LIMIT];

static void EffectFailure(const char *message) {
    fprintf(stderr, "Godot effects: %s\n", message);
    exit(EXIT_FAILURE);
}

static void RegisterEffect(DG_PRIM *prim, unsigned texture, int first_face, int face_count, unsigned flags) {
    if (first_face < 0 || face_count < 1 || first_face > prim->prim_count - face_count)
        EffectFailure("invalid registered face range");
    for (unsigned i = 0; i < EFFECT_LIMIT; ++i) {
        if (!effects[i].prim || (effects[i].prim == prim && effects[i].first_face == first_face)) {
            effects[i] = (Effect){prim, texture, flags, first_face, face_count};
            return;
        }
    }
    EffectFailure("registry capacity exceeded");
}

void MgsGodotRegisterEffect(DG_PRIM *prim, unsigned texture, int first_face, int face_count) {
    RegisterEffect(prim, texture, first_face, face_count, 0);
}

void MgsGodotRegisterRipple(DG_PRIM *prim, unsigned texture) {
    if (prim->prim_count != 8 || (prim->type & 31) != DG_PRIM_POLY_FT4)
        EffectFailure("surface ripple requires eight native ring quads");
    RegisterEffect(prim, texture, 0, prim->prim_count, EFFECT_RIPPLE);
}

void MgsGodotRegisterFootprint(DG_PRIM *prim, unsigned texture) {
    if (prim->prim_count != 1 || (prim->type & 31) != DG_PRIM_POLY_FT4)
        EffectFailure("footprint requires one native floor quad");
    RegisterEffect(prim, texture, 0, 1, EFFECT_FOOTPRINT);
}

void MgsGodotRegisterLamp(DG_PRIM *prim, unsigned texture) {
    RegisterEffect(prim, texture, 0, prim->prim_count,
                   EFFECT_EMISSIVE | ((prim->type & DG_PRIM_ONESIDE) ? EFFECT_ONE_SIDED : 0));
}

void MgsGodotRegisterBeam(DG_PRIM *prim, unsigned texture) {
    RegisterEffect(prim, texture, 0, prim->prim_count, EFFECT_EMISSIVE | EFFECT_BEAM);
}

void MgsGodotRemoveEffect(DG_PRIM *prim) {
    for (unsigned i = 0; i < EFFECT_LIMIT; ++i)
        if (effects[i].prim == prim) effects[i].prim = NULL;
}

static const Effect *FindEffect(const DG_PRIM *prim, int face) {
    for (unsigned i = 0; i < EFFECT_LIMIT; ++i)
        if (effects[i].prim == prim && face >= effects[i].first_face &&
            face - effects[i].first_face < effects[i].face_count) return &effects[i];
    return NULL;
}

unsigned MgsGodotEffectTexture(const DG_PRIM *prim, int face) {
    const Effect *effect = FindEffect(prim, face);
    return effect ? effect->texture : 0;
}

static unsigned PacketPage(const DG_PRIM *prim, const void *packet) {
    const int kind = prim->type & 31;
    return kind == DG_PRIM_POLY_GT4 || kind == DG_PRIM_LINE_GT2 ?
        ((const POLY_GT4 *)packet)->tpage : ((const POLY_FT4 *)packet)->tpage;
}

int MgsGodotOwnsEffect(DG_PRIM *prim, int face, const void *packet) {
    const int kind = prim->type & 31;
    if (prim->type & (DG_PRIM_ON_CAMERA | DG_PRIM_SORTONLY | DG_PRIM_FREEPACKS)) return 0;
    const Effect *effect = FindEffect(prim, face);
    if (!effect || !prim->pos) return 0;
    const unsigned identity = effect->texture;
    if (identity == MGS_GODOT_EFFECT_SNOW)
        return kind == DG_PRIM_TILE && (prim->type & DG_PRIM_RECTANGLE) && prim->pos;
    const int beam = (effect->flags & EFFECT_BEAM) &&
        (kind == DG_PRIM_LINE_FT2 || kind == DG_PRIM_LINE_GT2) && !(prim->type & DG_PRIM_RECTANGLE);
    if (!beam && kind != DG_PRIM_POLY_FT4 && kind != DG_PRIM_POLY_GT4) return 0;
    if (!identity) return 0;
    const unsigned page = PacketPage(prim, packet);
    const unsigned code = ((const POLY_FT4 *)packet)->code;
    /* Only explicitly registered footprints transfer subtractive blending. */
    return (page & 0x180) != 0x100 &&
        (!(code & 2) || ((page >> 5) & 3) != 2 || (effect->flags & EFFECT_FOOTPRINT));
}

static void TransformPoint(float out[3], const MATRIX *matrix, const float in[3]) {
    for (int row = 0; row < 3; ++row) {
        out[row] = (float)matrix->t[row];
        for (int column = 0; column < 3; ++column)
            out[row] += matrix->m[row][column] * in[column] / 4096.0f;
    }
}

static void EffectPosition(float out[4], const DG_CHANL *channel, const DG_PRIM *prim,
                           int face, int corner) {
    const int kind = prim->type & 31;
    const int line = kind == DG_PRIM_LINE_FT2 || kind == DG_PRIM_LINE_GT2;
    const int index = line ? face * 2 + (corner & 1) : face * 4 + corner;
    const SVECTOR *source = &prim->pos[(prim->type & DG_PRIM_RECTANGLE) ? face : index];
    const float local[] = {source->vx, source->vy, source->vz};
    float world[3], view[3];
    TransformPoint(world, &prim->world, local);
    TransformPoint(view, &channel->eye_inv, world);
    out[0] = view[0] / 1000.0f;
    out[1] = -view[1] / 1000.0f;
    out[2] = -view[2] / 1000.0f;
    out[3] = 0;
}

static void EffectQuad(EffectVertex out[4], const DG_CHANL *channel, const DG_PRIM *prim,
                       int face, const unsigned char *packet, const DG_TEX *texture) {
    const unsigned code = ((const POLY_FT4 *)packet)->code;
    const unsigned flags = FindEffect(prim, face)->flags;
    const unsigned blend = ((code & 2) ? 1 + ((PacketPage(prim, packet) >> 5) & 3) : 0) | flags;
    const int raw = (flags & EFFECT_EMISSIVE) && (code & 1);
    const int kind = prim->type & 31;
    const int gouraud = kind == DG_PRIM_POLY_GT4 || kind == DG_PRIM_LINE_GT2;
    const float surface_bias = (flags & EFFECT_FOOTPRINT) ? 0.002f :
        texture->id == GV_StrCode("ripple") ? 0.001f : 0.0f;
    for (int corner = 0; corner < 4; ++corner) {
        const unsigned char *uv = packet + prim->voffset + corner * prim->vstep + 4;
        const unsigned char *color = packet + prim->voffset - 4 + (gouraud ? corner * prim->vstep : 0);
        EffectPosition(out[corner].position, channel, prim, face, corner);
        out[corner].position[3] = surface_bias;
        out[corner].uv_color[0] = ((unsigned char)(uv[0] - texture->off_x) + 0.5f) / (texture->w + 1);
        out[corner].uv_color[1] = ((unsigned char)(uv[1] - texture->off_y) + 0.5f) / (texture->h + 1);
        out[corner].uv_color[2] = raw ? 1.0f : color[0] / 128.0f;
        out[corner].uv_color[3] = raw ? 1.0f : color[1] / 128.0f;
        out[corner].color_blend[0] = raw ? 1.0f : color[2] / 128.0f;
        out[corner].color_blend[1] = (float)blend;
        out[corner].color_blend[2] = out[corner].color_blend[3] = 0;
        if (prim->type & DG_PRIM_RECTANGLE) {
            const RECT *rect = prim->rect;
            if (!rect) EffectFailure("billboard has no rectangle");
            out[corner].color_blend[2] = ((corner & 1 ? rect->w : 0) - rect->x) / 1000.0f;
            out[corner].color_blend[3] = (rect->y - (corner & 2 ? rect->h : 0)) * (64.0f / 58000.0f);
        }
    }
}

static void SnowQuad(EffectVertex out[4], const DG_CHANL *channel, const DG_PRIM *prim,
                     int face, const TILE *packet) {
    for (int corner = 0; corner < 4; ++corner) {
        EffectPosition(out[corner].position, channel, prim, face, corner);
        out[corner].uv_color[0] = corner & 1 ? 1.0f : 0.0f;
        out[corner].uv_color[1] = corner & 2 ? 1.0f : 0.0f;
        out[corner].uv_color[2] = packet->r0 / 255.0f;
        out[corner].uv_color[3] = packet->g0 / 255.0f;
        out[corner].color_blend[0] = packet->b0 / 255.0f;
        out[corner].color_blend[2] = corner & 1 ? packet->w : 0;
        out[corner].color_blend[3] = corner & 2 ? -packet->h : 0;
    }
}

uint32_t MgsGodotAppendEffects(DG_CHANL *channel, int buffer_index,
                              unsigned char *destination, uint32_t capacity) {
    uint32_t bytes = 4, count = 0;
    if (capacity < bytes) EffectFailure("scene capacity exceeded");
    for (int index = channel->prim_index; index < channel->queue_size; ++index) {
        DG_PRIM *prim = (DG_PRIM *)channel->queue[index];
        if ((prim->type & DG_PRIM_INVISIBLE) ||
            (prim->group_id && !(prim->group_id & DG_CurrentGroupID))) continue;
        for (int face = 0; face < prim->prim_count; ++face) {
            const unsigned char *packet = (unsigned char *)prim->packs[buffer_index] + face * prim->psize;
            if (!MgsGodotOwnsEffect(prim, face, packet)) continue;
            const unsigned identity = MgsGodotEffectTexture(prim, face);
            struct { uint32_t texture; EffectVertex vertices[4]; } quad = {0};
            _Static_assert(sizeof(quad) == 196, "Godot effect quad layout");
            if (sizeof(quad) > capacity - bytes) EffectFailure("scene capacity exceeded");
            quad.texture = identity;
            if (identity == MGS_GODOT_EFFECT_SNOW)
                SnowQuad(quad.vertices, channel, prim, face, (const TILE *)packet);
            else
                EffectQuad(quad.vertices, channel, prim, face, packet, DG_GetTexture(identity));
            memcpy(destination + bytes, &quad, sizeof(quad));
            bytes += sizeof(quad);
            ++count;
        }
    }
    memcpy(destination, &count, 4);
    return bytes;
}
