#include "mgs_native.h"
#undef fprintf
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "game/game.h"

unsigned long psyz_scratchpad[256];

#include "jeep_packets.inc"

static void CheckTexture(const POLY_FT4 *packet, const DG_TEX *texture)
{
    assert(packet->code == 0x2e);
    assert(packet->clut == texture->clut);
    assert(packet->tpage == texture->tpage);
    assert(packet->u0 == texture->off_x && packet->u2 == texture->off_x);
    assert(packet->u1 == texture->off_x + texture->w);
    assert(packet->u3 == texture->off_x + texture->w);
    assert(packet->v0 == texture->off_y && packet->v1 == texture->off_y);
    assert(packet->v2 == texture->off_y + texture->h);
    assert(packet->v3 == texture->off_y + texture->h);
}

int main(void)
{
    POLY_FT4 packets[10];
    POLY_FT4 boundary;
    DG_TEX texture = {0};
    int count, index;

    texture.off_x = 17;
    texture.off_y = 33;
    texture.w = 27;
    texture.h = 39;
    texture.tpage = 0x16d;
    texture.clut = 0x7a23;
    for (count = 0; count <= 8; ++count)
    {
        memset(packets, 0xa5, sizeof(packets));
        memset(psyz_scratchpad, 0x5a, sizeof(psyz_scratchpad));
        boundary = packets[0];
        InitPacks(packets + 1, count, &texture);
        ShadePacks(packets + 1, count, 73);
        assert(memcmp(packets, &boundary, sizeof(boundary)) == 0);
        assert(memcmp(packets + count + 1, &boundary, sizeof(boundary)) == 0);
        for (index = 1; index <= count; ++index)
        {
            if (((P_TAG *)&packets[index])->len != 9)
            {
                fprintf(stderr, "Jeep spark packet %d has invalid length %lu\n",
                        index, ((P_TAG *)&packets[index])->len);
                return 1;
            }
            CheckTexture(&packets[index], &texture);
            assert(packets[index].r0 == 73 && packets[index].g0 == 73 && packets[index].b0 == 73);
            assert(packets[index].x0 == (short)0xa5a5);
            assert(packets[index].y3 == (short)0xa5a5);
        }
    }
    puts("Jeep spark native packet headers, textures, shading and bounds PASS");
    return 0;
}
