#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "game/game.h"
#include "strcode.h"
#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#undef fprintf

CONTROL *GM_WhereList[96];
int GM_CurrentMap = 1, DG_CurrentGroupID = 1;
static DG_TEX texture = {.id = PCX_ASIATO, .w = 31, .h = 31};
static DG_PRIM primitive;
static POLY_FT4 packets[2];
static MATRIX transform;
static int destroyed;

DG_TEX *DG_GetTexture(int id) { assert(id == PCX_ASIATO); return &texture; }
int GV_StrCode(const char *name) { assert(strcmp(name, "ripple") == 0); return 900; }
void GV_DestroyActor(void *actor) { assert(actor); ++destroyed; }
DG_PRIM *DG_MakePrim(int type, int count, int channel, SVECTOR *positions, RECT *rect)
{
    assert(type == DG_PRIM_POLY_FT4 && count == 1 && channel == 0 && !rect);
    memset(&primitive, 0, sizeof(primitive));
    primitive.type = type;
    primitive.prim_count = count;
    primitive.pos = positions;
    primitive.psize = sizeof(POLY_FT4);
    primitive.voffset = offsetof(POLY_FT4, x0);
    primitive.vstep = 8;
    primitive.packs[0] = &packets[0];
    primitive.packs[1] = &packets[1];
    return &primitive;
}
int DG_QueuePrim(DG_PRIM *prim) { assert(prim == &primitive); return 0; }
void DG_SetPos(MATRIX *matrix) { transform = *matrix; }
void DG_SetPos2(SVECTOR *position, SVECTOR *rotation)
{
    assert(rotation->vy == 0);
    memset(&transform, 0, sizeof(transform));
    transform.m[0][0] = transform.m[1][1] = transform.m[2][2] = 4096;
    transform.t[0] = position->vx;
    transform.t[1] = position->vy;
    transform.t[2] = position->vz;
}
void DG_PutPrim(DG_PRIM *prim) { prim->world = transform; }

#if FOOTPRINT_KIND == 0
#include "asiato_effect.inc"
#elif FOOTPRINT_KIND == 1
#include "asiato2_effect.inc"
#else
#include "demoasi_effect.inc"
#endif

static float ReadFloat(const unsigned char *bytes, int offset)
{
    float value;
    memcpy(&value, bytes + offset, sizeof(value));
    return value;
}

static void CheckPublished(int foot)
{
    unsigned char data[200];
    DG_OBJS *queue[] = {(DG_OBJS *)&primitive};
    DG_CHANL channel = {.queue = queue, .queue_size = 1};
    channel.eye_inv.m[0][0] = channel.eye_inv.m[1][1] = channel.eye_inv.m[2][2] = 4096;
    for (int buffer = 0; buffer < 2; ++buffer) {
        assert((packets[buffer].tpage & 0x60) == 0x40 && (packets[buffer].code & 2));
        assert(MgsGodotEffectTexture(&primitive, 0) == PCX_ASIATO);
        assert(MgsGodotAppendEffects(&channel, buffer, data, sizeof(data)) == sizeof(data));
        assert(data[0] == 1);
        assert(ReadFloat(data, 12) == 0.4f);
        assert(ReadFloat(data, 8) == (foot == 1 ? 1.07f : 0.93f));
        assert(ReadFloat(data, 32) == packets[buffer].r0 / 128.0f);
        assert(ReadFloat(data, 44) == (3 | 128));
        assert(ReadFloat(data, 20) > 0);
    }
    primitive.type |= DG_PRIM_INVISIBLE;
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 4);
    primitive.type &= ~DG_PRIM_INVISIBLE;
    primitive.group_id = 2;
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 4);
    primitive.group_id = 1;
}

int main(void)
{
    CONTROL player = {0};
    GM_WhereList[0] = &player;
    for (int foot = 1; foot <= 2; ++foot) {
        Work work = {0};
        MATRIX world = {.t = {1000, 200, 3000}};
        world.m[0][0] = world.m[1][1] = world.m[2][2] = 4096;
        destroyed = 0;
#if FOOTPRINT_KIND == 0
        assert(AsiatoChar_GetResources(&work, &world, foot, -400) == 0);
#elif FOOTPRINT_KIND == 1
        assert(Asiato2Char_GetResources(&work, &world, foot, -400, 0) == 0);
        work.f54 = 690;
#else
        work.world = &world;
        assert(GetResources(&work, foot, -400, 690) == 0);
#endif
        CheckPublished(foot);
        for (int tick = 0; tick < 391; ++tick) {
#if FOOTPRINT_KIND == 0
            AsiatoChar_Act(&work);
#elif FOOTPRINT_KIND == 1
            Asiato2Char_Act(&work);
#else
            Act(&work);
#endif
            if (tick == 199) {
                assert(packets[0].r0 < 48 && packets[0].r0 == packets[1].r0);
                CheckPublished(foot);
            }
        }
        assert(destroyed == 1);
        MgsGodotRemoveEffect(&primitive);
        assert(!MgsGodotOwnsEffect(&primitive, 0, packets));
    }
    puts("Native footprint construction, handedness, floor, fade and expiry passed");
    return 0;
}
