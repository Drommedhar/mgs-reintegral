#include "mgs_native.h"
#include "../vendor/mgs/source/overlays/rank/chara/pocket/pocket_native.h"
#include "fixtures/mgs_pocket_back_fixtures.h"
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>

#define COUNT_OF(array) (sizeof(array) / sizeof((array)[0]))

int PocketBackCount, GV_Clock;
int PocketBackZoom = 200;
PocketNode *PocketBackNodes;
static POLY_FT4 animation_packets[6];
static uint32_t trace_hash;
static int trace_calls, trace_mode, texture_hash;
static DG_TEX texture;
static int allocation_limit = -1, allocations, destroyed, executed;

static void Record(int tag, int count, ...)
{
    va_list args;
    int i, byte;
    uint32_t value = tag;
    ++trace_calls;
    va_start(args, count);
    for (i = 0; i <= count; ++i)
    {
        for (byte = 0; byte < 4; ++byte)
        {
            trace_hash = (trace_hash ^ (value & 255)) * 16777619u;
            value >>= 8;
        }
        if (i != count)
            value = va_arg(args, int);
    }
    va_end(args);
}

static void ResetTrace(void)
{
    trace_hash = 2166136261u;
    trace_calls = 0;
}

int mgs_fprintf(int channel, const char *format, ...)
{
    va_list args;
    int result;
    (void)channel;
    va_start(args, format);
    result = vfprintf(stderr, format, args);
    va_end(args);
    return result;
}

void *GV_Malloc(int size)
{
    void *result;
    if (allocation_limit == 0)
        return NULL;
    if (allocation_limit > 0)
        --allocation_limit;
    result = malloc(size);
    if (result)
        ++allocations;
    return result;
}

void GV_DelayedFree(void *allocation)
{
    if (allocation)
        --allocations;
    free(allocation);
}

void GV_ZeroMemory(void *memory, int size)
{
    memset(memory, 0, size);
}

void GV_DestroyActor(void *actor)
{
    assert(actor);
    ++destroyed;
}

int GCL_ExecProc(int procedure, GCL_ARGS *args)
{
    assert(args == NULL);
    executed = procedure;
    return 0;
}

int GV_RandU(int maximum)
{
    assert(maximum > 0);
    return maximum - 1;
}

DG_TEX *DG_GetTexture(int hash)
{
    texture_hash = hash;
    if (trace_mode)
        Record(2, 1, hash);
    return &texture;
}

void GM_SetSound(int sound, int mode)
{
    Record(4, 2, sound, mode);
}

int rank_800CEF5C(void *packet, int gouraud, unsigned short hash, short x, short y, int semi);
void rank_800CFBD8(POLY_FT4 *poly, DG_TEX *tex, int divisor, int width, int height);
#include "pocket_back_helpers.inc"

int rank_800CEF5C(void *packet, int gouraud, unsigned short hash, short x, short y, int semi)
{
    if (!trace_mode)
        return rank_800CEF5C_actual(packet, gouraud, hash, x, y, semi);
    Record(1, 6, (int)((POLY_FT4 *)packet - animation_packets), gouraud, hash, x, y, semi);
    return 0;
}

void rank_800CFBD8(POLY_FT4 *poly, DG_TEX *tex, int divisor, int width, int height)
{
    if (!trace_mode)
        rank_800CFBD8_actual(poly, tex, divisor, width, height);
    else
        Record(3, 5, (int)(poly - animation_packets), texture_hash, divisor, width, height);
}

static void SetPacket(void *packet, const BackPacket *fixture, int gouraud)
{
    setaddr(packet, fixture->address);
    setlen(packet, fixture->length);
    memcpy((unsigned char *)packet + sizeof(OT_TYPE), fixture->body, gouraud ? 48 : 36);
}

static void CheckPacket(const void *packet, const BackPacket *fixture, int gouraud,
                        const char *group, size_t index, int ordinal)
{
    if ((uintptr_t)getaddr(packet) != fixture->address || getlen(packet) != fixture->length ||
        memcmp((const unsigned char *)packet + sizeof(OT_TYPE), fixture->body, gouraud ? 48 : 36))
    {
        printf("%s fixture %u packet %d differs: addr %x/%x len %u/%u\n", group,
               (unsigned)index, ordinal, (unsigned)(uintptr_t)getaddr(packet), fixture->address,
               (unsigned)getlen(packet), fixture->length);
        abort();
    }
}

static void SetNode(PocketNode *node, const int *fields)
{
    memset(node, 0, sizeof(*node));
    node->time = fields[0];
    node->time2 = fields[1];
    node->phase = fields[2];
    node->field_18 = fields[3];
    node->flags = fields[4];
    node->visible = fields[5];
    node->depth = fields[6];
    node->selection = fields[7];
    node->id = 1;
    node->count = 3;
    node->packets.flat = animation_packets;
}

static void CheckNode(const PocketNode *node, const int *expected)
{
    int fields[] = {node->time, node->time2, node->phase, node->field_18,
                    node->flags, node->visible, node->depth, node->selection};
    assert(memcmp(fields, expected, sizeof(fields)) == 0);
}

static void CheckAnimations(void)
{
    size_t i;
    int j;
    trace_mode = 1;
    for (i = 0; i < COUNT_OF(back_anim_fixtures); ++i)
    {
        const BackAnimFixture *fixture = &back_anim_fixtures[i];
        PocketBackWork work = {0};
        PocketNode node, source = {0};
        SetNode(&node, fixture->before);
        source.packets.flat = animation_packets + 3;
        node.next = &source;
        PocketBackNodes = &node;
        work.flags = fixture->work_flags;
        for (j = 0; j < 6; ++j)
            SetPacket(&animation_packets[j], &fixture->input[j], 0);
        ResetTrace();
        if (fixture->kind == 0)
            rank_800CF938(&work, &node);
        else if (fixture->kind == 1)
            rank_800CFD00(&work, &node);
        else
            rank_800D0258(&work, &node);
        CheckNode(&node, fixture->after);
        assert(trace_hash == fixture->trace_hash && trace_calls == fixture->trace_calls);
        for (j = 0; j < 3; ++j)
            CheckPacket(&animation_packets[j], &fixture->output[j], 0, "animation", i, j);
    }
    trace_mode = 0;
}

static void CheckGeometry(void)
{
    size_t i;
    int j;
    for (i = 0; i < COUNT_OF(back_geometry_fixtures); ++i)
    {
        const BackGeometryFixture *fixture = &back_geometry_fixtures[i];
        PocketNode destination = {0}, source = {0};
        destination.packets.flat = animation_packets;
        destination.field_18 = fixture->before_field;
        source.packets.flat = animation_packets + 3;
        for (j = 0; j < 3; ++j)
        {
            SetPacket(&animation_packets[j], &fixture->input[j], 0);
            SetPacket(&animation_packets[j + 3], &fixture->input[j], 0);
        }
        if (fixture->kind == 0)
            rank_800CFF1C(&destination, &source);
        else
            rank_800D007C(animation_packets, fixture->zoom, fixture->boundary);
        assert(destination.field_18 == fixture->after_field);
        for (j = 0; j < 3; ++j)
            CheckPacket(&animation_packets[j], &fixture->output[j], 0, "geometry", i, j);
    }
}

static void CheckQueues(void)
{
    size_t i;
    for (i = 0; i < COUNT_OF(back_queue_fixtures); ++i)
    {
        const BackQueueFixture *fixture = &back_queue_fixtures[i];
        const int *in = fixture->before, *out = fixture->after;
        PocketBackWork work = {0};
        PocketNode node = {0};
        work.time = in[0];
        work.state = in[1];
        work.field_28 = in[2];
        work.update_count = in[3];
        memcpy(work.updates, fixture->updates_before, sizeof(work.updates));
        node.flags = fixture->flags_before;
        PocketBackNodes = &node;
        ResetTrace();
        rank_800D04A8(&work);
        assert(work.time == out[0] && work.state == out[1] && work.field_28 == out[2]);
        assert(work.update_count == out[3] && node.flags == fixture->flags_after);
        assert(memcmp(work.updates, fixture->updates_after, sizeof(work.updates)) == 0);
        assert(trace_hash == fixture->trace_hash && trace_calls == fixture->trace_calls);
    }
}

typedef union PacketSet
{
    POLY_FT4 flat[3];
    POLY_GT4 smooth[3];
} PacketSet;

static void *PacketAt(PacketSet *packets, int gouraud, int index)
{
    return gouraud ? (void *)&packets->smooth[index] : &packets->flat[index];
}

static void CheckFades(void)
{
    size_t i;
    int j;
    for (i = 0; i < COUNT_OF(back_fade_fixtures); ++i)
    {
        const BackFadeFixture *fixture = &back_fade_fixtures[i];
        PocketNode node = {0};
        PacketSet packets;
        node.gouraud = fixture->gouraud;
        node.count = fixture->count;
        node.visible = fixture->visible;
        node.id = fixture->id;
        node.packets.allocation = &packets;
        PocketBackNodes = &node;
        for (j = 0; j < 3; ++j)
            SetPacket(PacketAt(&packets, node.gouraud, j), &fixture->input[j], node.gouraud);
        rank_800CF3FC(fixture->numerator, fixture->denominator);
        for (j = 0; j < 3; ++j)
            CheckPacket(PacketAt(&packets, node.gouraud, j), &fixture->output[j],
                        node.gouraud, "fade", i, j);
    }
}

static void CheckCopies(void)
{
    size_t i;
    int j;
    for (i = 0; i < COUNT_OF(back_copy_fixtures); ++i)
    {
        const BackCopyFixture *fixture = &back_copy_fixtures[i];
        PocketBackWork work = {0};
        PocketNode node = {0};
        DG_PRIM flat = {0}, smooth = {0};
        PacketSet input, output = {0};
        node.gouraud = fixture->gouraud;
        node.count = fixture->count;
        node.visible = fixture->visible;
        node.id = fixture->id;
        node.depth = fixture->depth;
        node.packets.allocation = &input;
        PocketBackNodes = &node;
        work.flags = fixture->flags;
        work.flat = &flat;
        work.smooth = &smooth;
        flat.packs[0] = smooth.packs[0] = (unsigned char *)&output;
        for (j = 0; j < 3; ++j)
            SetPacket(PacketAt(&input, node.gouraud, j), &fixture->input[j], node.gouraud);
        rank_800D0648(&work);
        for (j = 0; j < 3; ++j)
        {
            CheckPacket(PacketAt(&input, node.gouraud, j), &fixture->after[j],
                        node.gouraud, "copy source", i, j);
            CheckPacket(PacketAt(&output, node.gouraud, j), &fixture->output[j],
                        node.gouraud, "copy destination", i, j);
        }
    }
}

static void CheckAllocations(void)
{
    PocketNode *nodes[8];
    int i;
    PocketBackNodes = NULL;
    PocketBackCount = 0;
    allocation_limit = 0;
    assert(rank_800CF1F4(0, 3, 0, 7) == NULL);
    allocation_limit = 1;
    assert(rank_800CF1F4(0, 3, 0, 7) == NULL);
    assert(PocketBackCount == 0 && PocketBackNodes == NULL && allocations == 0);
    allocation_limit = -1;
    for (i = 0; i < 8; ++i)
    {
        nodes[i] = rank_800CF1F4(i, 3, i % 2, 7);
        assert(nodes[i] && nodes[i]->previous == NULL);
        if (i)
            assert(nodes[i]->next == nodes[i - 1] && nodes[i - 1]->previous == nodes[i]);
    }
    assert(rank_800CF1F4(8, 3, 0, 7) == NULL);
    rank_800CEE90(nodes[3]);
    assert(nodes[4]->next == nodes[2] && nodes[2]->previous == nodes[4]);
    rank_800CEE90(nodes[0]);
    assert(nodes[1]->next == NULL);
    while (PocketBackNodes)
        rank_800CEE90(PocketBackNodes);
    assert(allocations == 0 && PocketBackCount == 0);
}

static void CheckTextures(void)
{
    size_t i;
    trace_mode = 1;
    for (i = 0; i < COUNT_OF(back_texture_fixtures); ++i)
    {
        const BackTextureFixture *fixture = &back_texture_fixtures[i];
        PacketSet packets;
        void *packet = PacketAt(&packets, fixture->gouraud, 0);
        texture.tpage = fixture->texture[0];
        texture.clut = fixture->texture[1];
        texture.off_x = fixture->texture[2];
        texture.off_y = fixture->texture[3];
        texture.w = fixture->texture[4];
        texture.h = fixture->texture[5];
        SetPacket(packet, &fixture->input, fixture->gouraud);
        ResetTrace();
        assert(rank_800CEF5C_actual(packet, fixture->gouraud, fixture->hash,
                                   fixture->x, fixture->y, fixture->semi) == 0);
        CheckPacket(packet, &fixture->output, fixture->gouraud, "texture", i, 0);
        assert(trace_hash == fixture->trace_hash && trace_calls == fixture->trace_calls);
    }
    trace_mode = 0;
}

int main(void)
{
    CheckAnimations();
    CheckGeometry();
    CheckQueues();
    CheckFades();
    CheckCopies();
    CheckAllocations();
    CheckTextures();
    puts("2822 original-MIPS Pocket background fixtures and allocation failures passed");
    return 0;
}
