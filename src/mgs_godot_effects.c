#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "libdg/libdg.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#undef fprintf

enum { EFFECT_LIMIT = 1024 };
typedef struct { DG_PRIM *prim; unsigned texture; int first_face, face_count; } Effect;
typedef struct { float position[4], uv_color[4], color_blend[4]; } EffectVertex;
static Effect effects[EFFECT_LIMIT];

static void EffectFailure(const char *message) {
    fprintf(stderr, "Godot effects: %s\n", message);
    exit(EXIT_FAILURE);
}

void MgsGodotRegisterEffect(DG_PRIM *prim, unsigned texture, int first_face, int face_count) {
    if (first_face < 0 || face_count < 1 || first_face > prim->prim_count - face_count)
        EffectFailure("invalid registered face range");
    for (unsigned i = 0; i < EFFECT_LIMIT; ++i) {
        if (!effects[i].prim || (effects[i].prim == prim && effects[i].first_face == first_face)) {
            effects[i] = (Effect){prim, texture, first_face, face_count};
            return;
        }
    }
    EffectFailure("registry capacity exceeded");
}

void MgsGodotRemoveEffect(DG_PRIM *prim) {
    for (unsigned i = 0; i < EFFECT_LIMIT; ++i)
        if (effects[i].prim == prim) effects[i].prim = NULL;
}

static unsigned EffectTexture(const DG_PRIM *prim, int face) {
    for (unsigned i = 0; i < EFFECT_LIMIT; ++i)
        if (effects[i].prim == prim && face >= effects[i].first_face &&
            face - effects[i].first_face < effects[i].face_count) return effects[i].texture;
    return 0;
}

static unsigned PacketPage(const DG_PRIM *prim, const void *packet) {
    return (prim->type & 31) == DG_PRIM_POLY_GT4 ?
        ((const POLY_GT4 *)packet)->tpage : ((const POLY_FT4 *)packet)->tpage;
}

int MgsGodotOwnsEffect(DG_PRIM *prim, int face, const void *packet) {
    const int kind = prim->type & 31;
    if (kind != DG_PRIM_POLY_FT4 && kind != DG_PRIM_POLY_GT4) return 0;
    if (prim->type & (DG_PRIM_ON_CAMERA | DG_PRIM_SORTONLY | DG_PRIM_FREEPACKS)) return 0;
    if (!EffectTexture(prim, face)) return 0;
    const unsigned page = PacketPage(prim, packet);
    const unsigned code = ((const POLY_FT4 *)packet)->code;
    /* Subtractive and framebuffer effects retain their native compositor. */
    return (page & 0x180) != 0x100 && (!(code & 2) || ((page >> 5) & 3) != 2);
}

static void TransformPoint(float out[3], const MATRIX *matrix, const float in[3]) {
    for (int row = 0; row < 3; ++row) {
        out[row] = (float)matrix->t[row];
        for (int column = 0; column < 3; ++column)
            out[row] += matrix->m[row][column] * in[column] / 4096.0f;
    }
}

static void EffectPosition(float out[4], const DG_CHANL *channel, const DG_PRIM *prim,
                           int face, int corner, const unsigned char *packet) {
    const SVECTOR *source = &prim->pos[(prim->type & DG_PRIM_RECTANGLE) ? face : face * 4 + corner];
    const float local[] = {source->vx, source->vy, source->vz};
    float world[3], view[3];
    TransformPoint(world, &prim->world, local);
    TransformPoint(view, &channel->eye_inv, world);
    if (prim->type & DG_PRIM_RECTANGLE) {
        const short *screen = (const short *)(packet + prim->voffset + corner * prim->vstep);
        view[0] = screen[0] * view[2] / channel->screen;
        view[1] = screen[1] * view[2] / channel->screen * (64.0f / 58.0f);
    }
    out[0] = view[0] / 1000.0f;
    out[1] = -view[1] / 1000.0f;
    out[2] = -view[2] / 1000.0f;
    out[3] = 0;
}

static void EffectQuad(EffectVertex out[4], const DG_CHANL *channel, const DG_PRIM *prim,
                       int face, const unsigned char *packet, const DG_TEX *texture) {
    const unsigned code = ((const POLY_FT4 *)packet)->code;
    const unsigned blend = (code & 2) ? 1 + ((PacketPage(prim, packet) >> 5) & 3) : 0;
    const int gouraud = (prim->type & 31) == DG_PRIM_POLY_GT4;
    const float surface_bias = texture->id == GV_StrCode("ripple") ? 0.001f : 0.0f;
    for (int corner = 0; corner < 4; ++corner) {
        const unsigned char *uv = packet + prim->voffset + corner * prim->vstep + 4;
        const unsigned char *color = packet + prim->voffset - 4 + (gouraud ? corner * prim->vstep : 0);
        EffectPosition(out[corner].position, channel, prim, face, corner, packet);
        out[corner].position[3] = surface_bias;
        out[corner].uv_color[0] = ((unsigned char)(uv[0] - texture->off_x) + 0.5f) / (texture->w + 1);
        out[corner].uv_color[1] = ((unsigned char)(uv[1] - texture->off_y) + 0.5f) / (texture->h + 1);
        out[corner].uv_color[2] = color[0] / 128.0f;
        out[corner].uv_color[3] = color[1] / 128.0f;
        out[corner].color_blend[0] = color[2] / 128.0f;
        out[corner].color_blend[1] = (float)blend;
        out[corner].color_blend[2] = out[corner].color_blend[3] = 0;
    }
}

uint32_t MgsGodotAppendEffects(DG_CHANL *channel, int buffer_index,
                              unsigned char *destination, uint32_t capacity) {
    uint32_t bytes = 4, count = 0;
    if (capacity < bytes) EffectFailure("scene capacity exceeded");
    for (int index = channel->prim_index; index < channel->queue_size; ++index) {
        DG_PRIM *prim = (DG_PRIM *)channel->queue[index];
        if (!EffectTexture(prim, 0) || (prim->type & DG_PRIM_INVISIBLE) ||
            (prim->group_id && !(prim->group_id & DG_CurrentGroupID))) continue;
        for (int face = 0; face < prim->prim_count; ++face) {
            const unsigned identity = EffectTexture(prim, face);
            const DG_TEX *texture = DG_GetTexture(identity);
            const unsigned char *packet = (unsigned char *)prim->packs[buffer_index] + face * prim->psize;
            if (!MgsGodotOwnsEffect(prim, face, packet) || !(*(const u_short *)packet)) continue;
            struct { uint32_t texture; EffectVertex vertices[4]; } quad = {0};
            _Static_assert(sizeof(quad) == 196, "Godot effect quad layout");
            if (sizeof(quad) > capacity - bytes) EffectFailure("scene capacity exceeded");
            quad.texture = identity;
            EffectQuad(quad.vertices, channel, prim, face, packet, texture);
            memcpy(destination + bytes, &quad, sizeof(quad));
            bytes += sizeof(quad);
            ++count;
        }
    }
    memcpy(destination, &count, 4);
    return bytes;
}
