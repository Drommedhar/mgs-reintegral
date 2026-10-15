#include "mgs_native.h"
#include "mgs_video.h"

#include "libgv/libgv.h"
#include "libdg/libdg.h"
#undef fprintf
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "water_helpers.inc"

typedef struct WaterFixture
{
    int red, green, blue, clock, phase;
    uint32_t draw_hash;
    int draw_count;
    uint32_t mask_hash;
    int mask_count;
} WaterFixture;
typedef struct WaterPriorityFixture
{
    int check, write;
    uint32_t command;
} WaterPriorityFixture;
#include "fixtures/mgs_water_fixtures.h"

DG_CHANL DG_Chanls[3];
int GV_Clock, GV_PauseLevel;
_Alignas(16) unsigned long psyz_scratchpad[256];

static struct
{
    uint32_t before;
    WaterViewPrims packets;
    uint32_t after;
} storage;
static OT_TYPE ordering[256];
static int allocations, releases, fail_allocation;

void MgsVideoSetDrawMode(void *packet, int mode)
{
    assert(mode == MGS_VIDEO_WORLD || mode == MGS_VIDEO_WATER_CANVAS);
    setlen(packet, 0);
}

void *GV_Malloc(int size)
{
    assert(size == sizeof(storage.packets));
    allocations++;
    return fail_allocation ? NULL : &storage.packets;
}

void GV_DelayedFree(void *pointer)
{
    assert(pointer == &storage.packets);
    releases++;
}

static void ResetOrdering(void)
{
    for (int i = 0; i < 256; i++)
    {
        setaddr(&ordering[i], 0x00ffffff);
        setlen(&ordering[i], 0);
    }
}

static void Reset(Work *work)
{
    memset(work, 0, sizeof(*work));
    memset(&storage, 0, sizeof(storage));
    storage.before = 0xface0123;
    storage.after = 0x4567cafe;
    work->bound[0] = (SVECTOR){-15000, -5000, -8750, 0};
    work->bound[1] = (SVECTOR){9625, -1400, 8750, 0};
    DG_Chanls[1].ot[0] = DG_Chanls[1].ot[1] = ordering;
    DG_Chanls[1].eye.t[0] = DG_Chanls[1].eye.t[2] = 0;
    DG_Chanls[1].eye.t[1] = -2000;
    GV_Clock = GV_PauseLevel = allocations = releases = fail_allocation = 0;
    ResetOrdering();
}

static uint32_t HashBytes(uint32_t hash, const void *memory, size_t size)
{
    const unsigned char *bytes = memory;
    for (size_t i = 0; i < size; i++)
        hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static void CheckChain(OT_TYPE *head, uint32_t expected_hash, int expected_count)
{
    uintptr_t pointer = getaddr(head);
    uint32_t hash = 2166136261u;
    int count = 0;
    while (pointer != 0x00ffffff)
    {
        const unsigned char *packet = (const unsigned char *)pointer;
        assert(pointer >= (uintptr_t)&storage.packets);
        assert(pointer < (uintptr_t)(&storage.packets + 1));
        uint32_t length = getlen(packet);
        if (length == 0)
        {
            pointer = getaddr(packet);
            continue;
        }
        assert(length >= 1 && length <= 4);
        unsigned char payload[16];
        memcpy(payload, packet + sizeof(OT_TYPE), length * 4);
        if (payload[3] == 0x64)
            payload[10] = payload[11] = 0;
        hash = HashBytes(hash, &length, sizeof(length));
        hash = HashBytes(hash, payload, length * 4);
        pointer = getaddr(packet);
        assert(++count <= 230);
    }
    assert(count == expected_count);
    assert(hash == expected_hash);
}

static void CheckFixtures(void)
{
    Work work;
    WaterViewInitSinTable();
    for (size_t i = 0; i < sizeof(water_fixtures) / sizeof(water_fixtures[0]); i++)
    {
        const WaterFixture *fixture = &water_fixtures[i];
        Reset(&work);
        work.color = (CVECTOR){fixture->red, fixture->green, fixture->blue, 0};
        work.n_prims = fixture->phase;
        GV_Clock = fixture->clock;
        Act(&work);
        assert(allocations == 1 && releases == 0 && work.has_alloc == 1);
        assert(work.n_prims == fixture->phase + 1);
        CheckChain(&ordering[0], fixture->draw_hash, fixture->draw_count);
        CheckChain(&ordering[255], fixture->mask_hash, fixture->mask_count);
        assert(storage.before == 0xface0123 && storage.after == 0x4567cafe);
    }
}

static void CheckPriority(void)
{
    for (size_t i = 0; i < sizeof(water_priority_fixtures) / sizeof(water_priority_fixtures[0]); i++)
    {
        const WaterPriorityFixture *fixture = &water_priority_fixtures[i];
        DR_PRIO packet;
        memset(&packet, 0xa5, sizeof(packet));
        setaddr(&packet, 0x123456);
        SetPriority(&packet, fixture->check, fixture->write);
        assert(getaddr(&packet) == 0x123456 && getlen(&packet) == 2);
        assert(packet.code[0] == fixture->command && packet.code[1] == 0);
    }
}

static void CheckSpriteBounds(void)
{
    struct
    {
        SPRT sprites[122];
        unsigned char sentinel[sizeof(SPRT)];
    } banks[2];
    CVECTOR color = {64, 128, 64, 0};
    memset(banks, 0xa5, sizeof(banks));
    SetupSprites1(banks[0].sprites, banks[1].sprites, &color);
    SetupSprites2(banks[0].sprites, banks[1].sprites, &color);
    for (int bank = 0; bank < 2; bank++)
        for (size_t i = 0; i < sizeof(SPRT); i++)
            assert(banks[bank].sentinel[i] == 0xa5);
}

static void CheckLifecycle(void)
{
    Work work;
    Reset(&work);
    fail_allocation = 1;
    Act(&work);
    assert(allocations == 1 && work.has_alloc == 0 && work.prims == NULL);
    fail_allocation = 0;
    Act(&work);
    assert(allocations == 2 && work.has_alloc == 1);
    GV_PauseLevel = 1;
    ResetOrdering();
    Act(&work);
    assert(work.n_prims == 1);
    DG_Chanls[1].eye.t[1] = -1400;
    Act(&work);
    assert(releases == 1 && work.has_alloc == 0 && work.prims == NULL);
    Die(&work);
    assert(releases == 1);
    DG_Chanls[1].eye.t[1] = -2000;
    ResetOrdering();
    Act(&work);
    assert(allocations == 3 && work.has_alloc == 1);
    Die(&work);
    assert(releases == 2);
}

int main(void)
{
    CheckPriority();
    CheckSpriteBounds();
    CheckFixtures();
    CheckLifecycle();
    puts("Water: 256 original MIPS packet traces, 25 mask modes and lifecycle/bounds PASS");
    return 0;
}
