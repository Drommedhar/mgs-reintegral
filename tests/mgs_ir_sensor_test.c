#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "../vendor/mgs/source/takabe/ir_cens.c"
#include <assert.h>
#include <math.h>
#include <stddef.h>

_Alignas(16) unsigned long psyz_scratchpad[256];
short linkvarbuf[MAX_LINKVARBUF];
int GM_CurrentMap, GM_GameStatus, GM_AlertMode, DG_CurrentGroupID = 1;
SVECTOR GM_PlayerPosition;
OBJECT *GM_PlayerBody;
static DG_TEX texture = {.id = 42, .w = 63, .h = 63, .tpage = 1 << 5};
static int parsed_position, target_hit, target_checks, alerts, procedures, sounds, removed;

void *GV_NewActor(int level, int size) { (void)level; return calloc(1, size); }
void GV_SetNamedActor(void *actor, void *act, void *die, const char *name)
{
    GV_ACT *value = actor;
    value->act = act; value->die = die; value->filename = name;
}
void GV_DestroyActor(void *actor) { free(actor); }
int GV_RandU(int limit) { assert(limit == 128); return 0; }
int GV_StrCode(const char *name)
{
    if (strcmp(name, "ripple") == 0) return 900;
    assert(strcmp(name, "lsight") == 0);
    return 42;
}
DG_TEX *DG_GetTexture(int id) { assert(id == 42); return &texture; }
char *GCL_GetOption(char option) { return option == 'p' ? "positions" : NULL; }
char *GCL_NextStr(void) { return "positions"; }
int GCL_StrToInt(char *value) { (void)value; return 0; }
int GCL_StrToSV(char *value, short *out)
{
    (void)value;
    out[0] = parsed_position++ ? 8000 : 0;
    out[1] = 0; out[2] = 2000;
    return 0;
}
int THING_Gcl_GetInt(char option) { assert(option == 'e'); return 9; }
int THING_Gcl_GetIntDefault(char option, int value) { assert(option == 's'); return value; }
void THING_Gcl_GetSVector(char option, SVECTOR *out) { assert(option == 'm'); *out = (SVECTOR){0}; }
int THING_Msg_CheckMessage(unsigned short name, int count, unsigned short *hashes)
{
    (void)name; (void)hashes; assert(count == 3); return -1;
}
int GCL_ExecProc(int proc, GCL_ARGS *args) { assert(proc == 9 && !args); ++procedures; return 0; }
void ENE_SetTopCommAL(int level) { assert(level == 255); ++alerts; }
void ENE_SetGopointLast(void) {}
void COM_CallBikkuriSe(SVECTOR *position, int volume)
{
    assert(position == &GM_PlayerPosition && volume == 128); ++sounds;
}
int GM_OnlineTargetCheck(SVECTOR *from, SVECTOR *to, int map, SVECTOR *hit, int side)
{
    assert(from->vx == 0 && to->vx == 8000 && map == 1 && side == ENEMY_SIDE);
    *hit = (SVECTOR){3500, 0, 2000, 0};
    ++target_checks;
    return target_hit;
}
void DG_SetPos(MATRIX *matrix) { assert(matrix); }
void DG_PutVector(SVECTOR *from, SVECTOR *to, int count)
{
    (void)from; assert(count == 1); *to = (SVECTOR){0, 0, 2000, 0};
}
void GV_AddVec3(SVECTOR *a, SVECTOR *b, SVECTOR *out)
{
    out->vx = a->vx + b->vx; out->vy = a->vy + b->vy; out->vz = a->vz + b->vz;
}
void GV_SubVec3(SVECTOR *a, SVECTOR *b, SVECTOR *out)
{
    out->vx = a->vx - b->vx; out->vy = a->vy - b->vy; out->vz = a->vz - b->vz;
}
int GV_VecLen3(SVECTOR *value)
{
    return (int)sqrt((double)value->vx * value->vx + (double)value->vy * value->vy + (double)value->vz * value->vz);
}
VECTOR *Square0(VECTOR *in, VECTOR *out)
{
    out->vx = in->vx * in->vx; out->vy = in->vy * in->vy; out->vz = in->vz * in->vz; return out;
}
long MgsSquareRoot0(long value) { return (long)sqrt((double)value); }
DG_PRIM *DG_MakePrim(int type, int count, int channel, SVECTOR *positions, RECT *rect)
{
    assert(type == DG_PRIM_LINE_GT2 && count == 8 && channel == 0 && !rect);
    DG_PRIM *prim = calloc(1, sizeof(*prim));
    prim->type = type; prim->prim_count = count; prim->pos = positions;
    prim->psize = sizeof(POLY_GT4); prim->voffset = offsetof(POLY_GT4, x0); prim->vstep = 12;
    prim->world.m[0][0] = prim->world.m[1][1] = prim->world.m[2][2] = 4096;
    prim->packs[0] = calloc(count, sizeof(POLY_GT4));
    prim->packs[1] = calloc(count, sizeof(POLY_GT4));
    return prim;
}
int DG_QueuePrim(DG_PRIM *prim) { assert(prim); return 0; }
void DG_DequeuePrim(DG_PRIM *prim) { MgsGodotRemoveEffect(prim); ++removed; }
void DG_FreePrim(DG_PRIM *prim) { free(prim->packs[0]); free(prim->packs[1]); free(prim); }

static void CheckShade(Work *work, int shade)
{
    for (int buffer = 0; buffer < 2; ++buffer) {
        POLY_GT4 *poly = work->prim->packs[buffer];
        for (int face = 0; face < 8; ++face)
            assert(poly[face].r0 == shade && poly[face].r1 == shade &&
                   poly[face].g2 == shade && poly[face].b3 == shade);
    }
}

static void CheckPresentation(Work *work)
{
    DG_OBJS *queue[] = {(DG_OBJS *)work->prim};
    DG_CHANL channel = {.queue = queue, .queue_size = 1};
    channel.eye_inv.m[0][0] = channel.eye_inv.m[1][1] = channel.eye_inv.m[2][2] = 4096;
    unsigned char data[1600];
    uint32_t expected = 4;
#ifdef MGS_GODOT_SCENE
    expected += 8 * 196;
#endif
    assert(MgsGodotAppendEffects(&channel, 0, data, sizeof(data)) == expected);
    assert(MgsGodotAppendEffects(&channel, 1, data, sizeof(data)) == expected);
    GM_GameStatus = STATE_THERMG;
    IrCensAct_800D9EF8(work);
    CheckShade(work, 128);
    work->fF0 = 0;
    IrCensAct_800D9EF8(work);
    CheckShade(work, 0);
    work->fF0 = 1;
    GM_GameStatus = 0;
    GM_Item = IT_Cigs;
    struct { DG_OBJS group; DG_OBJ parts[7]; } body = {0};
    OBJECT object = {.objs = &body.group};
    GM_PlayerBody = &object;
    IrCensAct_800D9EF8(work);
    for (int buffer = 0; buffer < 2; ++buffer) {
        POLY_GT4 *poly = work->prim->packs[buffer];
        assert(poly[0].r0 == 128 && poly[0].r1 == 66 && poly[0].g0 == 0);
        assert(poly[1].r0 == 66 && poly[1].r1 == 3 && poly[2].r1 == 0);
    }
    GM_Item = -1;
    IrCensAct_800D9EF8(work);
    CheckShade(work, 0);
    GM_PlayerBody = NULL;
}

int main(void)
{
    GM_Item = -1;
    Work *work = NewIrSensor(123, 1, 0, NULL);
    assert(work && work->prim && work->prim->group_id == 1);
    IrCensAct_800D9EF8(work);
    CheckShade(work, 0);
    CheckPresentation(work);
    int before = target_checks;
    work->fF0 = 0;
    IrCensAct_800D9EF8(work);
    assert(target_checks == before);
    work->fF0 = 1;
    target_hit = 1;
    IrCensAct_800D9EF8(work);
    assert(target_checks == before + 1 && alerts == 1 && procedures == 1 && sounds == 1);
    assert(work->f30[7].vx == 3500 && work->f30[15].vx == 3500);
    GM_Item = IT_Stealth;
    IrCensAct_800D9EF8(work);
    assert(target_checks == before + 1 && procedures == 1);
    IrCensDie_800DA3DC(work);
    free(work);
    assert(removed == 1);
    puts("IR sensor native visibility, cigarette fade, endpoints, detection and Godot registration pass.");
    return 0;
}
