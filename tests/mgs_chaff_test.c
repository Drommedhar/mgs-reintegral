#include "mgs_native.h"
#include "game/game.h"
#include "mts/mts.h"
#include <stdint.h>
#undef fprintf

_Alignas(16) unsigned long psyz_scratchpad[256];
int GM_CurrentMap, GM_GameStatus;

#include "chaff_helpers.inc"

static unsigned checks, random_calls, transform_calls, queue_calls, dequeue_calls;
static int allocation_failure, allocation_size;
static unsigned char *allocation;
static DG_PRIM *queued;
static const int random_values[] = {0, 1, 1, 0, 1, 1, 0, 0};

static void Check(int condition, const char *expression, int line)
{
    ++checks;
    if (!condition) {
        fprintf(stderr, "Chaff regression line %d: %s\n", line, expression);
        exit(EXIT_FAILURE);
    }
}

#define CHECK(condition) Check((condition), #condition, __LINE__)

void *GV_Malloc(int size)
{
    CHECK(!allocation);
    CHECK(size == (int)(sizeof(DG_PRIM) + 128 * sizeof(TILE)));
    if (allocation_failure)
        return NULL;
    allocation_size = size;
    allocation = malloc((size_t)size + 32);
    CHECK(allocation != NULL);
    memset(allocation, 0xa5, (size_t)size + 32);
    return allocation + 16;
}

void GV_ZeroMemory(void *pointer, int size)
{
    CHECK(pointer == allocation + 16 && size == sizeof(DG_PRIM));
    memset(pointer, 0, (size_t)size);
}

void GV_DelayedFree(void *pointer)
{
    CHECK(pointer == allocation + 16 && dequeue_calls == 1);
    for (int i = 0; i < 16; ++i) {
        CHECK(allocation[i] == 0xa5);
        CHECK(allocation[allocation_size + 16 + i] == 0xa5);
    }
    free(allocation);
    allocation = NULL;
}

int DG_QueuePrim(DG_PRIM *prim)
{
    CHECK(queue_calls++ == 0);
    queued = prim;
    return 0;
}

void DG_DequeuePrim(DG_PRIM *prim)
{
    CHECK(prim == queued && dequeue_calls++ == 0);
}

int mts_get_tick_count(void)
{
    return 1234;
}

int GV_RandU(int limit)
{
    CHECK(limit == 2 || limit == 1024 || limit == 512 || limit == 4096);
    return random_values[random_calls++ % 8];
}

void DG_SetPos2(SVECTOR *position, SVECTOR *rotation)
{
    CHECK(position == &DG_ZeroVector);
    CHECK(rotation->vx >= -257 && rotation->vx <= -256);
    CHECK(rotation->vy == 0 || rotation->vy == 1);
    CHECK(rotation->vz == 0);
}

void DG_PutVector(SVECTOR *from, SVECTOR *to, int count)
{
    CHECK(count == 1 && from->vx == 0 && from->vy == 0);
    CHECK(from->vz == 100 || from->vz == 101);
    to->vx = from->vx;
    to->vy = from->vy;
    to->vz = from->vz;
    to->pad = 0;
    ++transform_calls;
}

static void CheckParticleSizes(DG_PRIM *prim)
{
    for (unsigned buffer = 0; buffer < 2; ++buffer) {
        TILE *tiles = prim->packs[buffer];
        for (unsigned i = 0; i < 64; ++i) {
            CHECK(getlen(&tiles[i]) == 3 && tiles[i].code == 0x60);
            CHECK(tiles[i].w == random_values[(i * 2) % 8] + 1);
            CHECK(tiles[i].h == random_values[(i * 2 + 1) % 8] + 1);
            CHECK(tiles[i].r0 == 0xa5 && tiles[i].g0 == 0xa5 && tiles[i].b0 == 0xa5);
        }
        TILE expected[64];
        memcpy(expected, tiles, sizeof(expected));
        for (unsigned i = 0; i < 64; ++i) {
            expected[i].r0 = expected[i].g0 = 255;
            expected[i].b0 = 0;
        }
        InitParticleColor(tiles);
        CHECK(memcmp(expected, tiles, sizeof(expected)) == 0);
    }
}

static void CheckInitialization(Work *work, MATRIX *world)
{
    DG_PRIM *prim = work->field_a34;
    CHECK(prim && prim == queued);
    CHECK(prim->rect != NULL);
    CHECK(prim->rect == &chaff_particle_anchor);
    CHECK(prim->rect->x == 0 && prim->rect->y == 0);
    CHECK(prim->rect->w == 0 && prim->rect->h == 0);
    CHECK(prim->type == (DG_PRIM_RECTANGLE | DG_PRIM_TILE));
    CHECK(prim->prim_count == 64 && prim->pos == work->field_834);
    CHECK(prim->psize == sizeof(TILE) && prim->voffset == offsetof(TILE, x0));
    CHECK(prim->verts == 1 && prim->group_id == GM_CurrentMap);
    CHECK(prim->packs[1] == (char *)prim->packs[0] + 64 * sizeof(TILE));
    CHECK(okajima_CHAF_LIFE == 300 && dword_800BDF9C == 1234);
    CHECK(work->field_a38 == 64 && work->field_28 == 240 && work->field_24 == 0);
    CHECK(work->map == GM_CurrentMap && random_calls == 640 && transform_calls == 128);
    CHECK(memcmp(&work->field_a80, &DG_ZeroMatrix, sizeof(MATRIX)) == 0);
    for (int i = 0; i < 64; ++i) {
        CHECK(work->field_a40[i] == 0);
        for (int buffer = 0; buffer < 2; ++buffer) {
            SVECTOR *position = &work->field_434[buffer][i];
            CHECK(position->vx == world->t[0] && position->vy == world->t[1]);
            CHECK(position->vz == world->t[2]);
        }
    }
    CheckParticleSizes(prim);
}

static void CheckProjection(DG_PRIM *prim, int buffer, int x, int y)
{
    static const short coordinates[] = {-32768, -4097, -1, 0, 1, 257, 8192, 32767};
    SVECTOR *projected = (SVECTOR *)psyz_scratchpad;
    TILE *tiles = prim->packs[buffer], expected[64], other[64];
    RECT anchor = {(short)x, (short)y, 123, -456};
    RECT *saved = prim->rect;
    if (x || y)
        prim->rect = &anchor;
    for (int i = 0; i < 64; ++i) {
        projected[i].vx = coordinates[i % 8];
        projected[i].vy = coordinates[(i + 3) % 8];
        projected[i].vz = coordinates[(i + 5) % 8];
        projected[i].pad = 0x1234;
        tiles[i].tag = 0xabcd7890u;
    }
    memcpy(expected, tiles, sizeof(expected));
    memcpy(other, prim->packs[1 - buffer], sizeof(other));
    for (int i = 0; i < 64; ++i) {
        expected[i].tag = 0xabcd0000u | (unsigned short)projected[i].vz;
        expected[i].x0 = (short)((int)projected[i].vx - x);
        expected[i].y0 = (short)((int)projected[i].vy - y);
    }
    CHECK(_MakeXYZRectangleSingle(prim, (char *)tiles, 64) == (char *)(tiles + 64));
    CHECK(memcmp(expected, tiles, sizeof(expected)) == 0);
    CHECK(memcmp(other, prim->packs[1 - buffer], sizeof(other)) == 0);
    prim->rect = saved;
}

static void ResetBoundaries(void)
{
    random_calls = transform_calls = queue_calls = dequeue_calls = 0;
    allocation_failure = 0;
    queued = NULL;
    GM_CurrentMap = 0x1357;
}

static void CheckSuccessfulLifetime(int x, int y, int z)
{
    Work work = {0};
    MATRIX world = DG_ZeroMatrix;
    ResetBoundaries();
    world.t[0] = x;
    world.t[1] = y;
    world.t[2] = z;
    CHECK(GetResources(&work, &world) == 0);
    CheckInitialization(&work, &world);
    for (int buffer = 0; buffer < 2; ++buffer) {
        CheckProjection(work.field_a34, buffer, 0, 0);
        CheckProjection(work.field_a34, buffer, 23, -57);
        CheckProjection(work.field_a34, buffer, -100, 31);
    }
    GM_GameStatus = STATE_CHAFF | STATE_NVG;
    Die(&work);
    CHECK(GM_GameStatus == STATE_NVG && allocation == NULL && dequeue_calls == 1);
    CHECK(chaff_particle_anchor.x == 0 && chaff_particle_anchor.y == 0);
}

static void CheckAllocationFailure(void)
{
    Work work = {0};
    ResetBoundaries();
    allocation_failure = 1;
    CHECK(GetResources(&work, &DG_ZeroMatrix) == -1);
    CHECK(work.field_a34 == NULL && allocation == NULL && queue_calls == 0);
    CHECK(random_calls == 0 && transform_calls == 0);
}

int main(void)
{
    CheckSuccessfulLifetime(0, 0, 0);
    CheckSuccessfulLifetime(-19008, 1022, 7337);
    CheckSuccessfulLifetime(32767, -32768, -1);
    CheckAllocationFailure();
    printf("Chaff constructor and rectangle packets: %u checks passed.\n", checks);
    return 0;
}
