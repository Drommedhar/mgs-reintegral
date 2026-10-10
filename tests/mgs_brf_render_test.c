#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_native.h"
#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "../vendor/mgs/source/overlays/brf/onoda/brf/graph_data.c"
#include "../vendor/mgs/source/overlays/brf/overlay3.c"
#include "brf_render_helpers.inc"

typedef struct BrfRenderFixture
{
    int input[5];
    uint32_t hash, trace, calls;
} BrfRenderFixture;
#include "fixtures/mgs_brf_render_fixtures.h"

unsigned char mgs_main_ram[MGS_RESIDENT_HEADROOM + MGS_MAIN_RAM_SIZE + MGS_TOP_RAM_SIZE];
int GM_CurrentMap, GV_Clock;
static Work work;
static DG_TEX texture;
static DG_PRIM prims[5];
static unsigned char packets[2][5][840 * sizeof(POLY_FT4)];
static uint32_t trace_hash, trace_calls, random_state;
static int allocated, seed;
static int allocation_failure = -1;

static uint32_t HashBytes(uint32_t hash, const void *data, size_t length)
{
    const unsigned char *bytes = data;
    for (size_t i = 0; i < length; i++)
        hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static void Record(unsigned tag, int count, ...)
{
    va_list args;
    trace_hash = HashBytes(trace_hash, &tag, 4);
    va_start(args, count);
    for (int i = 0; i < count; i++)
    {
        unsigned value = va_arg(args, unsigned);
        trace_hash = HashBytes(trace_hash, &value, 4);
    }
    va_end(args);
    trace_calls++;
}

int GV_StrCode(const char *text)
{
    unsigned short hash = 0;
    while (*text)
    {
        hash = (unsigned short)((hash << 5) | (hash >> 11));
        hash += (unsigned char)*text++;
    }
    return hash;
}

DG_TEX *DG_GetTexture(int id)
{
    Record(0x1d830, 1, id);
    return &texture;
}

DG_TEX *brf_800CABF4(Work *actor, int id)
{
    assert(actor == &work);
    Record(0xcabf4, 1, id);
    return &texture;
}

DG_PRIM *DG_MakePrim(int type, int count, int channel, SVECTOR *position, RECT *rect)
{
    assert(position == NULL && rect == NULL && allocated < 5);
    Record(0x1babc, 3, type, count, channel);
    int slot = allocated++;
    return slot == allocation_failure ? NULL : &prims[slot];
}

int DG_QueuePrim(DG_PRIM *prim)
{
    Record(0x18274, 1, (int)(prim - prims));
    return 0;
}

int GV_RandU(int limit)
{
    random_state = random_state * 1103515245u + 12345u;
    int value = ((random_state >> 16) & 0x7fff) % limit;
    Record(0x17090, 2, limit, value);
    return value;
}

void GM_SeSet2(int pan, int volume, int sound)
{
    Record(0x32968, 3, pan, volume, sound);
}

void GM_SetSound(int sound, int time)
{
    Record(0x32c48, 2, sound, time);
}

static void InitPacket(void *memory, int index, size_t body)
{
    P_TAG *packet = memory;
    packet->addr = (index * 19 + seed) & 0xffffff;
    packet->len = (index + seed) % 13;
    unsigned char *payload = (unsigned char *)memory + offsetof(POLY_FT4, r0);
    for (size_t j = 0; j < body; j++)
        payload[j] = (unsigned char)(index * 11 + j * 7 + seed);
}

static int Count(int slot)
{
    const int sizes[] = {2, 15, 5, BrfScenePacketCounts[work.field_A588], 200};
    return sizes[slot];
}

static void Initialize(const BrfRenderFixture *fixture)
{
    int function = fixture->input[0], frame = fixture->input[2], mode = fixture->input[3];
    seed = fixture->input[4];
    trace_hash = 2166136261u;
    trace_calls = allocated = 0;
    random_state = seed + 1;
    memset(&work, 0, sizeof(work));
    work.field_A588 = fixture->input[1];
    work.field_A50C = (POLY_FT4 *)((unsigned char *)PACK_ADDR0 + 50 * 1024);
    for (int i = 0; i < 15; i++)
        InitPacket(&work.field_34[i], i, 36);
    for (int i = 0; i < 840; i++)
    {
        InitPacket(&work.field_28C[i], i, 36);
        InitPacket(&work.field_A50C[i], i + 7, 36);
    }
    for (int i = 0; i < 200; i++)
        InitPacket(&work.field_85CC[i], i, 36);
    for (int i = 0; i < 5; i++)
        InitPacket(&work.field_A510[i], i, 20);
    struct
    {
        unsigned char *bytes;
        size_t count;
    } visibility[] = {{work.z_A590, 5},   {work.z_A595, 2},  {work.z_A597, 840},
                      {work.z_A8DF, 200}, {work.z_A9A7, 15}, {work.field_A9B6, 842}};
    for (unsigned a = 0; a < sizeof(visibility) / sizeof(visibility[0]); a++)
        for (size_t i = 0; i < visibility[a].count; i++)
            visibility[a].bytes[i] = (i * 13 + seed) % 16;
    work.field_24 = &prims[0];
    work.field_2C = &prims[1];
    work.field_20 = &prims[2];
    work.field_28 = &prims[3];
    work.field_30 = &prims[4];
    memset(prims, 0, sizeof(prims));
    for (int slot = 0; slot < 5; slot++)
        for (int buffer = 0; buffer < 2; buffer++)
        {
            size_t stride = slot == 2 ? sizeof(POLY_F4) : sizeof(POLY_FT4);
            prims[slot].packs[buffer] = packets[buffer][slot];
            for (int i = 0; i < Count(slot); i++)
                InitPacket(packets[buffer][slot] + i * stride, i + slot, slot == 2 ? 20 : 36);
        }
    GM_CurrentMap = 13;
    GV_Clock = seed & 1;
    memset(&texture, 0, sizeof(texture));
    texture.tpage = 0x123 + seed;
    texture.clut = 0x234 + seed;
    texture.off_x = 13 + seed * 31;
    texture.off_y = 229 - seed * 17;
    texture.w = 41 + seed * 19;
    texture.h = 29 + seed * 23;
    work.field_AD28 = frame;
    work.field_AD2C = frame;
    work.field_AD5C = mode;
    work.field_ADB8 = function == 0xdd830 ? mode : frame;
    work.field_ADBC = mode;
    work.field_ADC0 = 8 + seed;
}

static uint32_t HashPacket(uint32_t hash, const void *memory, size_t body)
{
    const P_TAG *packet = memory;
    uint32_t address = packet->addr & 0xffffff, length = packet->len;
    hash = HashBytes(hash, &address, 4);
    hash = HashBytes(hash, &length, 4);
    return HashBytes(hash, (const unsigned char *)memory + offsetof(POLY_FT4, r0), body);
}

static uint32_t OutputHash(void)
{
    uint32_t hash = 2166136261u;
    for (int i = 0; i < 15; i++)
        hash = HashPacket(hash, &work.field_34[i], 36);
    for (int i = 0; i < 840; i++)
        hash = HashPacket(hash, &work.field_28C[i], 36);
    for (int i = 0; i < 200; i++)
        hash = HashPacket(hash, &work.field_85CC[i], 36);
    for (int i = 0; i < 5; i++)
        hash = HashPacket(hash, &work.field_A510[i], 20);
    for (int i = 0; i < 840; i++)
        hash = HashPacket(hash, &work.field_A50C[i], 36);
    for (int slot = 0; slot < 5; slot++)
        for (int buffer = 0; buffer < 2; buffer++)
        {
            size_t stride = slot == 2 ? sizeof(POLY_F4) : sizeof(POLY_FT4);
            for (int i = 0; i < Count(slot); i++)
                hash = HashPacket(hash, packets[buffer][slot] + i * stride, slot == 2 ? 20 : 36);
        }
    hash = HashBytes(hash, work.z_A590, 5);
    hash = HashBytes(hash, work.z_A595, 2);
    hash = HashBytes(hash, work.z_A597, 840);
    hash = HashBytes(hash, work.z_A8DF, 200);
    hash = HashBytes(hash, work.z_A9A7, 15);
    hash = HashBytes(hash, work.field_A9B6, 842);
    return HashBytes(hash, &work.field_AD20, 168);
}

int main(void)
{
    for (unsigned i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); i++)
    {
        const BrfRenderFixture *fixture = &fixtures[i];
        Initialize(fixture);
        switch (fixture->input[0])
        {
        case 0xde2e0:
            brf_800DE2E0(&work);
            break;
        case 0xdecf8:
            brf_800DECF8(&work, fixture->input[1]);
            break;
        case 0xcd164:
            brf_800CD164(&work);
            break;
        case 0xcf5a8:
            brf_800CF5A8(&work);
            break;
        case 0xdd830:
            brf_800DD830(&work);
            break;
        default:
            assert(0);
        }
        uint32_t hash = OutputHash();
        if (hash != fixture->hash || trace_hash != fixture->trace || trace_calls != fixture->calls)
        {
            fprintf(stderr,
                    "Briefing render %u fn=%x scene=%d frame=%d mode=%d seed=%d: hash %08x/%08x "
                    "trace %08x/%08x calls %u/%u\n",
                    i, fixture->input[0], fixture->input[1], fixture->input[2], fixture->input[3],
                    seed, hash, fixture->hash, trace_hash, fixture->trace, trace_calls,
                    fixture->calls);
            return 1;
        }
    }
    for (int slot = 0; slot < 5; slot++)
    {
        Initialize(&fixtures[0]);
        uint32_t before = OutputHash();
        allocation_failure = slot;
        brf_800DE2E0(&work);
        assert(allocated == 5 && trace_calls == 9);
        assert(OutputHash() == before);
    }
    printf("%zu original-MIPS briefing rendering and resource cases passed.\n",
           sizeof(fixtures) / sizeof(fixtures[0]));
    return 0;
}
