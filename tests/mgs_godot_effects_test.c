#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "libdg/libdg.h"
#include <assert.h>
#include <math.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

int DG_CurrentGroupID = 1;
static DG_TEX texture = {.id = 42, .w = 63, .h = 63};
DG_TEX *DG_GetTexture(int id) { assert(id == 42 || id == 43); return &texture; }
int GV_StrCode(const char *name) { (void)name; return 900; }

static float ReadFloat(const unsigned char *data, unsigned offset)
{
    float value;
    memcpy(&value, data + offset, sizeof(value));
    return value;
}

static void CheckRipple(void)
{
    unsigned char data[4 + 8 * 196];
    POLY_FT4 packets[8] = {{0}};
    SVECTOR points[32] = {{0}};
    DG_PRIM prim = {0};
    prim.type = DG_PRIM_POLY_FT4;
    prim.prim_count = 8;
    prim.pos = points;
    prim.psize = sizeof(POLY_FT4);
    prim.voffset = offsetof(POLY_FT4, x0);
    prim.vstep = 8;
    prim.packs[0] = packets;
    prim.world.m[0][0] = prim.world.m[1][1] = prim.world.m[2][2] = 4096;
    DG_OBJS *queue[] = {(DG_OBJS *)&prim};
    DG_CHANL channel = {0};
    channel.queue = queue;
    channel.queue_size = 1;
    channel.eye_inv = prim.world;
    for (int face = 0; face < 8; ++face) packets[face].code = 0x2e;
    MgsGodotRegisterRipple(&prim, 42);
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == sizeof(data));
    assert(data[0] == 8);
    for (int face = 0; face < 8; ++face)
        assert(((unsigned)ReadFloat(data, 44 + face * 196) & 64) != 0);
    prim.type |= DG_PRIM_INVISIBLE;
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 4);
    MgsGodotRemoveEffect(&prim);
}

static void CheckSnow(void)
{
    unsigned char data[512];
    TILE packets[2] = {{0}};
    SVECTOR position = {1000, 2000, 3000, 0};
    DG_PRIM prim = {0};
    prim.type = DG_PRIM_TILE | DG_PRIM_RECTANGLE;
    prim.prim_count = 1;
    prim.pos = &position;
    prim.psize = sizeof(TILE);
    prim.packs[0] = &packets[0];
    prim.packs[1] = &packets[1];
    prim.world.m[0][0] = prim.world.m[1][1] = prim.world.m[2][2] = 4096;
    prim.world.t[0] = 2000;
    DG_OBJS *queue[] = {(DG_OBJS *)&prim};
    DG_CHANL channel = {0};
    channel.queue = queue;
    channel.queue_size = 1;
    channel.eye_inv.m[0][0] = channel.eye_inv.m[1][1] = channel.eye_inv.m[2][2] = 4096;
    assert(!MgsGodotOwnsEffect(&prim, 0, packets));
    MgsGodotRegisterEffect(&prim, MGS_GODOT_EFFECT_SNOW, 0, 1);
    for (int buffer = 0; buffer < 2; ++buffer) {
        packets[buffer].r0 = 51;
        packets[buffer].g0 = 102;
        packets[buffer].b0 = 204;
        packets[buffer].w = buffer + 1;
        packets[buffer].h = 2;
        packets[buffer].x0 = 32767;
        assert(MgsGodotAppendEffects(&channel, buffer, data, sizeof(data)) == 200);
        uint32_t identity;
        memcpy(&identity, data + 4, 4);
        assert(identity == MGS_GODOT_EFFECT_SNOW);
        for (int corner = 0; corner < 4; ++corner) {
            const unsigned start = 8 + corner * 48;
            assert(ReadFloat(data, start) == 3 && ReadFloat(data, start + 4) == -2);
            assert(ReadFloat(data, start + 8) == -3 && ReadFloat(data, start + 12) == 0);
            assert(fabsf(ReadFloat(data, start + 24) - 0.2f) < 0.00001f);
            assert(fabsf(ReadFloat(data, start + 28) - 0.4f) < 0.00001f);
            assert(fabsf(ReadFloat(data, start + 32) - 0.8f) < 0.00001f);
            assert(ReadFloat(data, start + 40) == (corner & 1 ? buffer + 1 : 0));
            assert(ReadFloat(data, start + 44) == (corner & 2 ? -2 : 0));
        }
    }
    for (unsigned flag = DG_PRIM_ON_CAMERA; flag <= DG_PRIM_FREEPACKS; flag <<= 1) {
        if (!(flag & (DG_PRIM_ON_CAMERA | DG_PRIM_SORTONLY | DG_PRIM_FREEPACKS))) continue;
        prim.type |= flag;
        assert(!MgsGodotOwnsEffect(&prim, 0, packets));
        prim.type &= ~flag;
    }
    MgsGodotRemoveEffect(&prim);
    assert(!MgsGodotOwnsEffect(&prim, 0, packets));
}

static void CheckLamp(DG_CHANL *channel, DG_PRIM *prim)
{
    unsigned char data[512];
    POLY_FT4 *packets = prim->packs[0];
    prim->type |= DG_PRIM_ONESIDE;
    for (int face = 0; face < 2; ++face) {
        packets[face].code = 0x2f;
        packets[face].tpage = 1 << 5;
        packets[face].r0 = 0;
    }
    MgsGodotRegisterLamp(prim, 42);
    assert(MgsGodotAppendEffects(channel, 0, data, sizeof(data)) == 396);
    assert(ReadFloat(data, 32) == 1 && ReadFloat(data, 36) == 1 && ReadFloat(data, 40) == 1);
    assert(ReadFloat(data, 44) == (2 | 8 | 16));
    assert(ReadFloat(data, 240) == (2 | 8 | 16));
    prim->type &= ~DG_PRIM_ONESIDE;
    packets[0].code = 0x2e;
    packets[0].r0 = 64;
    packets[0].u0 = 16;
    MgsGodotRegisterLamp(prim, 43);
    assert(MgsGodotAppendEffects(channel, 0, data, sizeof(data)) == 396);
    assert(data[0] == 2 && data[4] == 43 && data[200] == 43);
    assert(ReadFloat(data, 32) == 0.5f && ReadFloat(data, 44) == (2 | 8));
    assert(ReadFloat(data, 24) == 16.5f / 64);
    prim->type |= DG_PRIM_INVISIBLE;
    assert(MgsGodotAppendEffects(channel, 0, data, sizeof(data)) == 4);
    prim->type &= ~DG_PRIM_INVISIBLE;
    packets[0].tpage = 2 << 5;
    assert(!MgsGodotOwnsEffect(prim, 0, packets));
    MgsGodotRemoveEffect(prim);
    assert(MgsGodotAppendEffects(channel, 0, data, sizeof(data)) == 4);
}

static void CheckBeam(void)
{
    unsigned char data[512];
    SVECTOR points[4] = {{-1000, 0, 2000}, {1000, 0, 2000}, {0, 0, 3000}, {0, 0, 3000}};
    POLY_GT4 packets[2] = {{0}};
    DG_PRIM prim = {.type = DG_PRIM_LINE_GT2, .prim_count = 2, .pos = points,
                    .psize = sizeof(POLY_GT4), .voffset = offsetof(POLY_GT4, x0), .vstep = 12};
    prim.world.m[0][0] = prim.world.m[1][1] = prim.world.m[2][2] = 4096;
    prim.world.t[0] = 1000;
    prim.packs[0] = packets;
    DG_OBJS *queue[] = {(DG_OBJS *)&prim};
    DG_CHANL channel = {.queue = queue, .queue_size = 1};
    channel.eye_inv.m[0][0] = channel.eye_inv.m[1][1] = channel.eye_inv.m[2][2] = 4096;
    packets[0].code = packets[1].code = 0x3e;
    packets[0].tpage = packets[1].tpage = 1 << 5;
    packets[0].r0 = packets[0].r2 = 128;
    packets[0].r1 = packets[0].r3 = 32;
    packets[0].u0 = packets[0].u2 = 4;
    packets[0].u1 = packets[0].u3 = 11;
    packets[0].v0 = packets[0].v1 = packets[0].v2 = packets[0].v3 = 17;
    assert(!MgsGodotOwnsEffect(&prim, 0, packets));
    MgsGodotRegisterBeam(&prim, 42);
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 396);
    for (int corner = 0; corner < 4; ++corner) {
        const unsigned start = 8 + corner * 48;
        assert(ReadFloat(data, start) == (corner & 1 ? 2 : 0));
        assert(ReadFloat(data, start + 8) == -2);
        assert(ReadFloat(data, start + 24) == (corner & 1 ? 0.25f : 1));
        assert(ReadFloat(data, start + 28) == 0 && ReadFloat(data, start + 32) == 0);
        assert(ReadFloat(data, start + 16) == (corner & 1 ? 11.5f : 4.5f) / 64);
        assert(ReadFloat(data, start + 20) == 17.5f / 64);
        assert(ReadFloat(data, start + 36) == (2 | 8 | 32));
        assert(ReadFloat(data, start + 196) == 1);
    }
    packets[0].x0 = -32768;
    packets[0].y0 = 32767;
    packets[0].r0 = packets[0].r1 = packets[0].r2 = packets[0].r3 = 0;
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 396);
    assert(ReadFloat(data, 8) == 0 && ReadFloat(data, 32) == 0);
    packets[0].tpage = 2 << 5;
    assert(!MgsGodotOwnsEffect(&prim, 0, packets));
    MgsGodotRemoveEffect(&prim);
    assert(!MgsGodotOwnsEffect(&prim, 1, &packets[1]));
}

int main(void)
{
    unsigned char data[1024];
    POLY_FT4 packets[2] = {{0}};
    SVECTOR points[8] = {{1000, 2000, -3000}};
    RECT rectangle = {100, 200, 300, 400};
    DG_PRIM prim = {0};
    prim.type = DG_PRIM_POLY_FT4 | DG_PRIM_RECTANGLE;
    prim.prim_count = 2;
    prim.group_id = 1;
    prim.pos = points;
    prim.rect = &rectangle;
    prim.psize = sizeof(POLY_FT4);
    prim.voffset = offsetof(POLY_FT4, x0);
    prim.vstep = 8;
    prim.packs[0] = packets;
    prim.world.m[0][0] = prim.world.m[1][1] = prim.world.m[2][2] = 4096;
    DG_OBJS *queue[] = {(DG_OBJS *)&prim};
    DG_CHANL channel = {0};
    channel.eye_inv = prim.world;
    channel.queue = queue;
    channel.queue_size = 1;
    channel.screen = 320;
    packets[0].code = packets[1].code = 0x2e;
    packets[0].r0 = 64;
    packets[0].u0 = 32;
    MgsGodotRegisterEffect(&prim, 42, 0, 1);
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 200);
    assert(data[0] == 1 && data[4] == 42);
    /* Zero tag, behind-camera centre and bogus projected pixels cannot remove or distort it. */
    for (int corner = 0; corner < 4; ++corner) {
        const unsigned start = 8 + corner * 48;
        assert(ReadFloat(data, start) == 1 && ReadFloat(data, start + 4) == -2);
        assert(ReadFloat(data, start + 8) == 3);
        assert(fabsf(ReadFloat(data, start + 40) - (corner & 1 ? 0.2f : -0.1f)) < 0.00001f);
        assert(fabsf(ReadFloat(data, start + 44) - (corner & 2 ? -0.2f : 0.2f) * 64 / 58) < 0.00001f);
    }
    assert(ReadFloat(data, 32) == 0.5f);
    packets[0].x0 = 32767;
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 200);
    assert(ReadFloat(data, 8) == 1);
    prim.type |= DG_PRIM_INVISIBLE;
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 4);
    CheckSnow();
    CheckRipple();
    CheckBeam();
    prim.type &= ~DG_PRIM_INVISIBLE;
    prim.group_id = 2;
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 4);
    prim.group_id = 1;
    prim.type &= ~DG_PRIM_RECTANGLE;
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 200);
    assert(ReadFloat(data, 48) == 0 && ReadFloat(data, 52) == 0);
    MgsGodotRemoveEffect(&prim);
    MgsGodotRegisterEffect(&prim, 42, 1, 1);
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 200);
    MgsGodotRemoveEffect(&prim);
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == 4);
    CheckLamp(&channel, &prim);
    puts("World effects survive native culling and preserve billboard dimensions.");
    return 0;
}
