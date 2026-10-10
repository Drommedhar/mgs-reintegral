#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/rank/chara/pocket/pocket_native.h"
#include <assert.h>
#include <stdint.h>

typedef struct InputFixture
{
    int input[7], output[3];
} InputFixture;
typedef struct CursorFixture
{
    int input[6];
    uint32_t hash;
} CursorFixture;
typedef struct GlyphFixture
{
    int input[7];
    const char *text;
    int count;
    uint32_t hash;
} GlyphFixture;
#include "mgs_pocket_entry_render_fixtures.h"

int PocketEntryCount;
PocketNode *PocketEntryNodes;
MenuPrim PocketEntryPrims;
int PocketTextPosition[3];
unsigned int PocketTextColor;
unsigned char PocketTextBuffers[2][8192];
SPRT PocketGlyphSprite;
POLY_FT4 PocketGlyphQuad;
static int allocation_limit = -1;
static int allocations;

void *GV_Malloc(int size)
{
    void *allocation;
    if (!allocation_limit)
        return NULL;
    if (allocation_limit > 0)
        --allocation_limit;
    allocation = malloc(size);
    if (allocation)
        ++allocations;
    return allocation;
}

void GV_DelayedFree(void *allocation)
{
    if (allocation)
        --allocations;
    free(allocation);
}

void GV_ZeroMemory(void *buffer, int size)
{
    memset(buffer, 0, size);
}

#include "pocket_entry_render_helpers.inc"

static uint32_t HashBytes(uint32_t hash, const void *data, size_t size)
{
    const unsigned char *bytes = data;
    size_t i;
    for (i = 0; i < size; ++i)
        hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static void CheckInput(void)
{
    size_t i;
    for (i = 0; i < sizeof(input_fixtures) / sizeof(input_fixtures[0]); ++i)
    {
        const InputFixture *fixture = &input_fixtures[i];
        const int *in = fixture->input;
        PocketEntryWork work = {0};
        PocketNode node = {0};
        GV_PAD pad = {0};
        work.state = in[0];
        work.flags = in[1];
        work.direction = in[2];
        work.repeat = in[3];
        pad.status = in[4];
        pad.press = in[5];
        work.pad = &pad;
        node.flags = in[6];
        PocketEntryNodes = &node;
        rank_800D2574(&work);
        assert(work.direction == fixture->output[0]);
        assert(work.repeat == fixture->output[1]);
        assert(node.flags == fixture->output[2]);
    }
}

static void CheckCursor(void)
{
    size_t i;
    for (i = 0; i < sizeof(cursor_fixtures) / sizeof(cursor_fixtures[0]); ++i)
    {
        const CursorFixture *fixture = &cursor_fixtures[i];
        const int *in = fixture->input;
        PocketNode node = {0};
        POLY_FT4 polys[9] = {0};
        uint32_t hash = 2166136261u;
        int p;
        PocketEntryNodes = &node;
        node.id = 1;
        node.packets.flat = polys;
        rank_800D2644(in[0], in[1], in[2], in[3], in[4], in[5]);
        for (p = 0; p < 9; ++p)
            hash = HashBytes(hash, &polys[p].r0, 36);
        assert(hash == fixture->hash);
    }
}

static void CheckGlyphs(void)
{
    size_t i;
    for (i = 0; i < sizeof(glyph_fixtures) / sizeof(glyph_fixtures[0]); ++i)
    {
        const GlyphFixture *fixture = &glyph_fixtures[i];
        const int *in = fixture->input;
        OT_TYPE ot = {0};
        unsigned char *packet;
        uint32_t hash = 2166136261u;
        int count = 0;
        memset(PocketTextBuffers, 0, sizeof(PocketTextBuffers));
        memset(&PocketGlyphSprite, 0, sizeof(PocketGlyphSprite));
        memset(&PocketGlyphQuad, 0, sizeof(PocketGlyphQuad));
        rank_800D12D0();
        PocketEntryPrims.next = PocketTextBuffers[0];
        PocketEntryPrims.end = PocketTextBuffers[0] + sizeof(PocketTextBuffers[0]);
        PocketEntryPrims.ot = (u_long *)&ot;
        rank_800D1218(in[1], in[2], in[3]);
        rank_800D128C(in[4], in[5], in[6], in[0]);
        rank_800D1230(fixture->text, in[0]);
        for (packet = PocketTextBuffers[0]; packet < PocketEntryPrims.next; ++count)
        {
            unsigned int length = getlen(packet);
            assert(length == 1 || length == 4 || length == 9);
            hash = HashBytes(hash, packet + sizeof(OT_TYPE), length * 4);
            packet += sizeof(OT_TYPE) + length * 4;
        }
        if (count != fixture->count || hash != fixture->hash)
        {
            printf("glyph %u: packets %d/%d hash%u/%u text=%s\n", (unsigned)i, count,
                   fixture->count, hash, fixture->hash, fixture->text);
            abort();
        }
    }
}

static void CheckNodeFailures(void)
{
    PocketNode *nodes[8];
    int i;
    PocketEntryNodes = NULL;
    PocketEntryCount = 0;
    allocation_limit = 0;
    assert(rank_800D20B0(0, 4, 0, 2) == NULL);
    allocation_limit = 1;
    assert(rank_800D20B0(0, 4, 0, 2) == NULL);
    assert(PocketEntryCount == 0 && PocketEntryNodes == NULL && allocations == 0);
    allocation_limit = -1;
    for (i = 0; i < 8; ++i)
    {
        nodes[i] = rank_800D20B0(i, 4, i % 2, 2);
        assert(nodes[i]);
        assert(nodes[i]->previous == NULL);
        if (i)
            assert(nodes[i]->next == nodes[i - 1] && nodes[i - 1]->previous == nodes[i]);
    }
    assert(rank_800D20B0(8, 4, 0, 2) == NULL);
    rank_800D1B78(nodes[3]);
    assert(nodes[4]->next == nodes[2] && nodes[2]->previous == nodes[4]);
    rank_800D1B78(nodes[0]);
    assert(nodes[1]->next == NULL);
    while (PocketEntryNodes)
        rank_800D1B78(PocketEntryNodes);
    assert(PocketEntryCount == 0 && allocations == 0);
}

int main(void)
{
    CheckInput();
    CheckCursor();
    CheckGlyphs();
    CheckNodeFailures();
    puts("3072 original PocketStation input/render fixtures and native allocation failures passed");
    return 0;
}
