#include "mgs_native.h"
#include "../vendor/mgs/source/equip/kogaku2.c"
#include <assert.h>
#include <stdlib.h>

int GV_Clock, GM_GameStatus;
static int published, restored, packets_freed;
static float transition;
static unsigned tint;

void *GV_NewActor(int level, int size) { (void)level; return calloc(1, size); }
void GV_SetNamedActor(void *actor, void *act, void *die, const char *name)
{
    GV_ACT *target = actor;
    target->act = act;
    target->die = die;
    target->filename = name;
}
void DG_SetPos(MATRIX *matrix) { (void)matrix; }
void DG_WriteObjPacketUV(DG_OBJ *object, int buffer) { (void)object; (void)buffer; ++restored; }
void DG_FreeObjsPacket(DG_OBJS *objects, int buffer) { (void)objects; (void)buffer; ++packets_freed; }
long RotTransPers3(SVECTOR *a, SVECTOR *b, SVECTOR *c, int *x, int *y, int *z, int *p, int *flags)
{
    *x = (uint32_t)(unsigned short)a->vy << 16;
    *y = (uint32_t)(unsigned short)b->vy << 16;
    *z = (uint32_t)(unsigned short)c->vy << 16;
    *p = *flags = 0;
    return 0;
}
#ifdef MGS_GODOT_SCENE
void MgsGodotSetCamouflage(DG_OBJS *objects, float amount, unsigned color)
{
    assert(objects && amount >= 0 && amount <= 1);
    published = 1;
    transition = amount;
    tint = color & 0xffffff;
}
void MgsGodotClearCamouflage(DG_OBJS *objects) { assert(objects); published = 0; }
#endif

static void CheckState(int enabled, float amount, unsigned color)
{
#ifdef MGS_GODOT_SCENE
    assert(published == enabled);
    if (enabled) assert(transition == amount && tint == color);
#else
    (void)enabled; (void)amount; (void)color;
    assert(!published && !transition && !tint);
#endif
}

int main(void)
{
    struct { DG_OBJS group; DG_OBJ part; } actor = {0};
    DG_DEF definition = {.ly = -500, .uy = 500};
    actor.group.def = &definition;
    actor.group.n_models = 1;
    actor.group.flag = DG_FLAG_SHADE | DG_FLAG_BOUND;
    OBJECT parent = {.objs = &actor.group};
    CONTROL control = {.name = SNAKE_NAME};
    Work *work = NewKogaku2(&control, &parent, 0);
    assert(work && actor.group.flag == DG_FLAG_GBOUND);
    CheckState(1, 1, 0x60a080);
    Act(work);
    CheckState(1, 1, 0x60a080);
    GM_GameStatus = STATE_THERMG;
    Act(work);
    CheckState(0, 0, 0);
    assert(packets_freed == 2 && actor.group.flag == (DG_FLAG_SHADE | DG_FLAG_BOUND));
    Act2(work);
    GM_GameStatus = 0;
    Act2(work);
    CheckState(1, 1, 0x60a080);
    Die(work);
    CheckState(0, 0, 0);
    assert(restored == 2 && actor.group.flag == (DG_FLAG_SHADE | DG_FLAG_BOUND));
    free(work);
    control.name = 0;
    work = NewKogaku3(&control, &parent, 0);
    CheckState(1, 0, 0x808080);
    for (int frame = 1; frame <= 10; ++frame) {
        Act(work);
        CheckState(1, frame / 10.0f, 0x808080);
    }
    GM_GameStatus = STATE_THERMG;
    Act(work);
    Die2(work);
    CheckState(0, 0, 0);
    free(work);
    puts("Camouflage native constructors, transition, thermal switching and cleanup pass.");
    return 0;
}
