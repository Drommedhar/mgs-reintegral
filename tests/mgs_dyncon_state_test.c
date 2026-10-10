#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/s15c/okajima/valcan/dyncon.c"
#include "../vendor/mgs/source/overlays/s15c/okajima/valcan/dyncon_setup.c"
#include "../vendor/mgs/source/overlays/s15c/okajima/valcan/dyncon_act.c"
#include "../vendor/mgs/source/libgv/strcode.c"
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    const char *name;
    int mode, phase, countdown, group, ticks, damage, hit, copies, saved, fragment, random, kind;
    uint32_t state, trace;
    int calls;
} Fixture;

#include "mgs_dyncon_state_fixtures.h"

int GM_CurrentMap;
int GM_NoisePower, GM_NoiseLength;
SVECTOR GM_PlayerPosition, GM_NoisePosition, DG_ZeroVector;
int s15c_container_available[4], s15c_container_phase[4], s15c_container_destroy;
SVECTOR s15c_valcan_position;
const char s15c_aNikitamissile_800E2D80[] = "NIKITA MISSILE * 4";
const char s15c_aC_800E2D94[] = "C4 * 2";
const char s15c_aRation_800E2D9C[] = "RATION";
const char s15c_dword_800E2E30[] = "dyncon.c";

static DynCon actor;
static TARGET targets[36];
static struct { DG_OBJS header; DG_OBJ unit; } objects[256];
static MAP map;
static HZD_HDL hazard;
static int next_object, next_target, random_choice, trace_calls;
static uint32_t trace_hash;
static SVECTOR transform;

static void HashBytes(uint32_t *hash, const void *data, size_t size)
{
    const unsigned char *bytes = data;
    size_t i;
    for (i = 0; i < size; i++)
        *hash = (*hash ^ bytes[i]) * UINT32_C(16777619);
}

static void Record(int count, ...)
{
    va_list args;
    int i;
    trace_calls++;
    va_start(args, count);
    for (i = 0; i < count; i++)
    {
        int value = va_arg(args, int);
        HashBytes(&trace_hash, &value, sizeof(value));
    }
    va_end(args);
}

static int Offset(const void *pointer) { return (const char *)pointer - (const char *)&actor; }
static DG_OBJS *AllocateObject(void)
{
    assert(next_object < (int)countof(objects));
    return &objects[next_object++].header;
}

void GV_ZeroMemory(void *data, int size) { memset(data, 0, size); }
void GV_AddVec3(SVECTOR *a, SVECTOR *b, SVECTOR *out)
{ out->vx = a->vx + b->vx; out->vy = a->vy + b->vy; out->vz = a->vz + b->vz; }
void GV_SubVec3(SVECTOR *a, SVECTOR *b, SVECTOR *out)
{ out->vx = a->vx - b->vx; out->vy = a->vy - b->vy; out->vz = a->vz - b->vz; }
MAP *GM_GetMap(int id) { assert(id == 7); return &map; }
DG_OBJS *Takabe_MakePreshade(int model, DG_LITS *light)
{ (void)light; Record(2, 1, model); return AllocateObject(); }
void GM_InitObjectNoRots(OBJECT_NO_ROTS *object, int model, int flag, int motion)
{
    Record(5, 2, Offset(object), model, flag, motion);
    memset(object, 0, sizeof(*object));
    object->objs = AllocateObject();
    object->flag = flag;
    object->map_name = GM_CurrentMap;
}
void GM_ActObject2(OBJECT *object) { Record(2, 3, Offset(object)); }
void GM_FreeObject(OBJECT *object) { Record(2, 4, Offset(object)); }
void GM_ConfigObjectLight(OBJECT *object, MATRIX *light)
{ Record(3, 5, Offset(object), Offset(light)); }
void DG_SetPos2(SVECTOR *position, SVECTOR *rotation)
{
    MATRIX matrix = {{{4096, 0, 0}, {0, 4096, 0}, {0, 0, 4096}}, {0, 0, 0}};
    Record(7, 6, position->vx, position->vy, position->vz, rotation->vx, rotation->vy, rotation->vz);
    transform = *position;
    matrix.t[0] = position->vx;
    matrix.t[1] = position->vy;
    matrix.t[2] = position->vz;
    SetRotMatrix(&matrix);
    SetTransMatrix(&matrix);
}
void DG_PutVector(SVECTOR *input, SVECTOR *output, int count)
{
    int i;
    for (i = 0; i < count; i++)
    {
        output[i].vx = input[i].vx + transform.vx;
        output[i].vy = input[i].vy + transform.vy;
        output[i].vz = input[i].vz + transform.vz;
    }
}
int DG_GetLightMatrix2(SVECTOR *position, MATRIX *light)
{ (void)light; Record(4, 7, position->vx, position->vy, position->vz); return 0; }
void s15c_dyncon_800D3F24(HZD_SEG *segments, HZD_FLR *floors, MATRIX *matrix, SVECTOR *a, SVECTOR *b)
{ (void)floors; (void)matrix; (void)a; (void)b; Record(2, 8, Offset(segments)); }
int HZD_QueueDynamicSegment2(HZD_HDL *hzd, HZD_SEG *segment, int flag)
{ assert(hzd == &hazard); Record(3, 9, Offset(segment), flag); return 0; }
void HZD_DequeueDynamicSegment(HZD_HDL *hzd, HZD_SEG *segment)
{ assert(hzd == &hazard); Record(2, 10, Offset(segment)); }
int HZD_QueueDynamicFloor(HZD_HDL *hzd, HZD_FLR *floor)
{ assert(hzd == &hazard); Record(2, 11, Offset(floor)); return 0; }
void HZD_DequeueDynamicFloor(HZD_HDL *hzd, HZD_FLR *floor)
{ assert(hzd == &hazard); Record(2, 12, Offset(floor)); }
TARGET *GM_AllocTarget(void) { assert(next_target < 36); return &targets[next_target++]; }
void GM_SetTarget(TARGET *target, int flags, int side, SVECTOR *size)
{ Record(7, 13, target - targets, flags, side, size->vx, size->vy, size->vz); }
void GM_MoveTarget(TARGET *target, SVECTOR *position)
{ Record(5, 14, target - targets, position->vx, position->vy, position->vz); }
void GM_FreeTarget(TARGET *target) { Record(2, 15, target - targets); }
void GM_SeSet(SVECTOR *position, int sound)
{ Record(5, 16, sound, position->vx, position->vy, position->vz); }
int GV_RandU(int limit) { Record(2, 17, limit); return random_choice; }
void GV_DestroyActor(void *work) { assert(work == &actor); Record(1, 18); }
void *NewPadVibration(unsigned char *data, int flags)
{ Record(4, 19, flags, data[0], data[1]); return NULL; }
void *NewItemPut(SVECTOR *position, SVECTOR *step, ITEM_INFO *info)
{ (void)step; Record(7, 20, position->vx, position->vy, position->vz, info->type, info->id, info->num); return NULL; }
void GCL_ForceExecProc(int proc, GCL_ARGS *args)
{
    int i;
    Record(3, 21, proc, args->argc);
    for (i = 0; i < args->argc; i++)
        Record(1, (int)args->argv[i]);
}
char *GCL_GetOption(char option) { (void)option; return NULL; }
char *GCL_NextStr(void) { return NULL; }
int GCL_StrToInt(char *text) { (void)text; assert(0); return 0; }
void *GV_NewActor(int level, int size) { (void)level; (void)size; assert(0); return NULL; }
void GV_SetNamedActor(void *work, void *act, void *die, const char *name)
{ (void)work; (void)act; (void)die; (void)name; assert(0); }

static void Initialize(const Fixture *fixture)
{
    static const int selected[4] = {3, 21, 24, 34};
    int i, j;
    memset(&actor, 0, sizeof(actor));
    memset(targets, 0, sizeof(targets));
    memset(objects, 0, sizeof(objects));
    memset(s15c_container_available, 0, sizeof(s15c_container_available));
    memset(s15c_container_phase, 0, sizeof(s15c_container_phase));
    s15c_container_destroy = 0;
    GM_NoisePower = GM_NoiseLength = 0;
    GM_NoisePosition = DG_ZeroVector;
    GM_PlayerPosition = (SVECTOR){27000, 100, 28000, 0};
    s15c_valcan_position = (SVECTOR){-27000, 0, -28000, 0};
    map.hzd = &hazard;
    actor.map = GM_CurrentMap = 7;
    actor.field_4050 = fixture->mode;
    actor.copies = fixture->copies;
    next_object = next_target = 0;
    random_choice = fixture->random;
    for (i = 0; i < 72; i++)
    {
        ContainerEntry *entry = &actor.entries[i];
        entry->position = (SVECTOR){i * 71 - 1000, i * 23 - 700, i * 37 + 200, 0};
        entry->rotation = (SVECTOR){i * 3, i * 7, i * 11, 0};
        for (j = 0; j < 2; j++)
            entry->objects[j].objs = AllocateObject();
        actor.object_active[i][0] = 1;
    }
    for (i = 0; i < 8; i++) actor.panels[i].object.objs = AllocateObject();
    for (i = 0; i < 4; i++) actor.tops[i].object.objs = AllocateObject();
    for (i = 0; i < 4; i++)
    {
        int index = 8 * (selected[i] / 4) + selected[i] % 4;
        actor.field_3F00[i] = selected[i];
        actor.field_3F30[i] = 1;
        actor.field_3594[i][0] = index;
        actor.field_3594[i][1] = index + 4;
        actor.field_3F40[i] = (SVECTOR){-31, -47, 59, 0};
        actor.field_3F60[i] = (SVECTOR){896, 1024, -512, 0};
        actor.fragments[i].object.objs = AllocateObject();
        actor.fragments[i].position = &actor.entries[index + 4].position;
        actor.fragments[i].rotation = &actor.entries[index + 4].rotation;
        actor.fragments[i].offset = (SVECTOR){-250, 1800, -250, 0};
        actor.fragments[i].state = fixture->fragment;
    }
    for (i = 0; i < 36; i++)
    {
        actor.entries[i].target = &targets[i];
        actor.models[i] = 100 + i;
        actor.field_3E70[i] = i % 6;
    }
    i = selected[fixture->group];
    actor.field_3CBC[i] = actor.field_3D4C[i] = fixture->damage;
    actor.saved_state[i] = fixture->saved;
    targets[i].damaged = fixture->hit;
    actor.field_3F20[fixture->group] = fixture->phase;
    actor.field_3F10[fixture->group] = fixture->countdown;
    for (i = 0; i < 3; i++) actor.save_procs[i] = 1000 + i;
    trace_hash = UINT32_C(2166136261);
    trace_calls = 0;
}

static uint32_t StateHash(void)
{
    uint32_t hash = UINT32_C(2166136261);
    int i;
    for (i = 0; i < 72; i++) HashBytes(&hash, &actor.entries[i].position, 16);
    HashBytes(&hash, actor.object_active, sizeof(actor.object_active));
    HashBytes(&hash, actor.panel_active, sizeof(actor.panel_active));
    for (i = 0; i < 4; i++)
    {
        HashBytes(&hash, &actor.fragments[i].step, 16);
        HashBytes(&hash, &actor.fragments[i].state, 4);
    }
    HashBytes(&hash, (char *)&actor + 0x3594, sizeof(actor) - 0x3594);
    for (i = 0; i < 36; i++) HashBytes(&hash, &targets[i].damaged, 2);
    HashBytes(&hash, s15c_container_available, 16);
    HashBytes(&hash, s15c_container_phase, 16);
    HashBytes(&hash, &s15c_container_destroy, 4);
    HashBytes(&hash, &GM_NoisePower, 4);
    HashBytes(&hash, &GM_NoiseLength, 4);
    HashBytes(&hash, &GM_NoisePosition, 8);
    return hash;
}

int main(void)
{
    unsigned i;
    for (i = 0; i < countof(fixtures); i++)
    {
        const Fixture *fixture = &fixtures[i];
        uint32_t state;
        int tick;
        Initialize(fixture);
        if (fixture->kind == 1)
            s15c_dyncon_800D8510(&actor);
        else if (fixture->kind == 2)
            s15c_dyncon_800D88C8(&actor);
        else if (fixture->kind == 3)
            s15c_dyncon_800D5A3C(&actor, fixture->group, 3, fixture->mode,
                                -112, 32, -80, -52, -80, -80, -240, -80);
        else
            for (tick = 0; tick < fixture->ticks; tick++)
                s15c_dyncon_800D6528(&actor);
        state = StateHash();
        if (state != fixture->state || trace_hash != fixture->trace || trace_calls != fixture->calls)
        {
            fprintf(stderr, "%s: state %08x/%08x trace %08x/%08x calls %d/%d\n",
                    fixture->name, state, fixture->state, trace_hash, fixture->trace, trace_calls, fixture->calls);
            return 1;
        }
    }
    printf("%u original-MIPS container state fixtures passed\n", (unsigned)countof(fixtures));
    return 0;
}
