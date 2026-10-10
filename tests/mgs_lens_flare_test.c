#include "mgs_native.h"
#include "game/game.h"
#include "takabe/fadeio.h"
#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

int GM_GameStatus, GM_CurrentMap;
static uint32_t boundary_trace;
static DVECTOR projected;
static DG_PRIM prims[8];
static unsigned int queued_frees, heap_frees;

static void Trace(uint32_t value)
{
    boundary_trace = (boundary_trace * 33 + value) & 0x7fffffffu;
}

void sub_800790E8(void) { Trace(1); }
void sub_8007913C(void) { Trace(2); }
void GM_SeSet2(int pan, int volume, int sound)
{
    Trace(3); Trace(pan); Trace(volume); Trace(sound);
}
void *NewFadeInOut(int mode, int shade)
{
    Trace(4); Trace(mode); Trace(shade);
    return NULL;
}
void GV_DestroyActor(void *actor) { assert(actor); Trace(5); }
void DG_DequeuePrim(DG_PRIM *prim)
{
    ptrdiff_t index = prim - prims;
    assert(index >= 0 && index < 8 && !(queued_frees & (1u << index)));
    queued_frees |= 1u << index;
}
void DG_FreePrim(DG_PRIM *prim)
{
    ptrdiff_t index = prim - prims;
    assert(index >= 0 && index < 8 && (queued_frees & (1u << index)));
    assert(!(heap_frees & (1u << index)));
    heap_frees |= 1u << index;
}

#include "lens_flare_helpers.inc"
#include "mgs_lens_flare_fixtures.h"

_Static_assert(sizeof(LensFlareWork) == 0xfc, "Lens flare actor layout");
_Static_assert(sizeof(POLY_FT4) - offsetof(POLY_FT4, r0) == 36, "GPU packet payload layout");

static DVECTOR LensFlareProject(LensFlareWork *work)
{
    assert(work);
    return projected;
}

static uint32_t HashBytes(const void *data, size_t size)
{
    const unsigned char *bytes = data;
    uint32_t hash = 2166136261u;
    for (size_t i = 0; i < size; ++i)
        hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static void CheckStates(void)
{
    static const int timers[] = {0, 1, 2, 7, 8, 14, 15, 16, 30};
    static const int lifetimes[] = {1, 2, 5, 15, 16, 30, 31, 40};
    static const short coordinates[] = {-32768, -511, -1, 0, 1, 1023, 32767};
    static const int scales[] = {8, 11, 20, 33, 37, 50, -7, -9};
    for (int index = 0; index < 256; ++index)
    {
        LensFlareWork work = {0};
        memcpy(work.scales, scales, sizeof(scales));
        work.timer = timers[index % 9];
        work.lifetime = lifetimes[index % 8];
        work.map = 73;
        work.ready = 1;
        GM_GameStatus = 0x40 | (index % 2) * 2;
        boundary_trace = 0;
        projected = (DVECTOR){coordinates[index % 7], coordinates[index / 7 % 7]};
        LensFlareAct(&work);
        assert(HashBytes(&work, sizeof(work)) == lens_state_fixtures[index][0]);
        assert(boundary_trace == lens_state_fixtures[index][1]);
        assert((uint32_t)GM_GameStatus == lens_state_fixtures[index][2]);
        assert(GM_CurrentMap == 73);
    }
}

static void CheckPackets(void)
{
    for (int index = 0; index < 128; ++index)
    {
        POLY_FT4 packet;
        DG_TEX texture = {0};
        memset(&packet, 0xa5, sizeof(packet));
        texture.tpage = index * 13;
        texture.clut = index * 31;
        texture.off_x = index * 71;
        texture.off_y = index * 37;
        texture.w = index * 29;
        texture.h = index * 43;
        LensFlarePacket(&packet, &texture, index * 11 % 256, index * 19 % 256, index * 17 % 256);
        assert(getlen(&packet) == lens_packet_fixtures[index][0]);
        assert(HashBytes(&packet.r0, 36) == lens_packet_fixtures[index][1]);
    }
}

static void CheckPartialCleanup(void)
{
    for (unsigned int count = 0; count <= 8; ++count)
    {
        LensFlareWork work = {0};
        queued_frees = heap_frees = 0;
        for (unsigned int index = 0; index < count; ++index)
            work.prims[index] = &prims[index];
        LensFlareDie(&work);
        LensFlareDie(&work);
        assert(heap_frees == (1u << count) - 1 && heap_frees == queued_frees);
        for (int index = 0; index < 8; ++index)
            assert(work.prims[index] == NULL);
    }
}

int main(void)
{
    CheckStates();
    CheckPackets();
    CheckPartialCleanup();
    puts("Lens flare: 384 original-MIPS state/packet cases and all partial cleanup counts passed.");
    return 0;
}
