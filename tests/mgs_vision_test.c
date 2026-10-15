#include "mgs_native.h"
#include "mgs_godot_context.h"
#include "mgs_godot_cinematic.h"
#include "game/game.h"
#include "transport.h"
#include "../vendor/mgs/source/takabe/scn_mask.c"
#include <assert.h>

int GM_GameStatus, GV_Time, GV_PauseLevel, GV_PassageTime, GV_Clock;
DG_CHANL DG_Chanls[3];
static unsigned capabilities;
static unsigned minor = 34;
static int loading;
unsigned MgsGodotSelectedMinor(void) { return minor; }
int MgsLoadingActive(void) { return loading; }
const char *MgsLoadingStage(void) { return loading ? "opening" : ""; }
static int scene_enabled = 1;
static unsigned char context[96];
static unsigned context_size;
static OT_TYPE ordering;
bool MgsGodotHasCapability(unsigned bit) { return (capabilities & bit) != 0; }
int MgsGodotSceneEnabled(void) { return scene_enabled; }
int MgsSafetyDiscNumber(void) { return 1; }
void MgsGodotCopySessionId(unsigned char *data) { memset(data, 1, 16); }
MgsGodotCinematic MgsGodotCinematicState(void) { return (MgsGodotCinematic){0}; }
void MgsGodotQueue(uint32_t operation, const void *header, uint32_t size, const void *data, uint32_t bytes)
{
    assert(operation == MGS_GODOT_CONTEXT && size + bytes <= sizeof(context));
    memcpy(context, header, size);
    memcpy(context + size, data, bytes);
    context_size = size + bytes;
}
void *GV_Malloc(int size) { return calloc(1, size); }
void GV_DelayedFree(void *memory) { free(memory); }
void *GV_NewActor(int level, int size) { (void)level; return calloc(1, size); }
void GV_SetNamedActor(void *actor, void *act, void *die, const char *name)
{
    GV_ACT *target = actor;
    target->act = act; target->die = die; target->filename = name;
}
void GV_DestroyActor(void *actor) { free(actor); }

static uint32_t Word(unsigned offset)
{
    uint32_t result;
    memcpy(&result, context + offset, 4);
    return result;
}

static void CheckMask(int mode, int suppressed)
{
    Work *work = NewNightVisionScreen(mode);
    assert(work && work->mode == mode);
    memset(&ordering, 0, sizeof(ordering));
    Act(work);
#ifndef MGS_GODOT_SCENE
    suppressed = 0;
#endif
    assert((getaddr(&ordering) == 0) == suppressed);
    Die(work);
    free(work);
}

int main(void)
{
    DG_Chanls[1].ot[0] = &ordering;
    MgsGodotStageChanged("s00a");
    capabilities = 256 | 512 | 16384 | 32768;
    for (int mode = 0; mode < 3; ++mode) {
        GM_GameStatus = mode == 1 ? STATE_NVG : mode == 2 ? STATE_THERMG : 0;
        MgsGodotPublishContext();
        assert(context_size == 84 && Word(0) == 5 && Word(80) == mode);
        assert(MgsGodotOwnsNightVision() == (mode == 1));
        assert(MgsGodotOwnsThermalVision() == (mode == 2));
        CheckMask(mode == 2 ? SCREEN_MASK_IR_MODE : SCREEN_MASK_NV_MODE, mode != 0);
    }
    minor = 35;
    loading = 1;
    MgsGodotPublishContext();
    assert(context_size == 96 && Word(0) == 6 && Word(84) == 1);
    assert(strcmp((const char *)context + 88, "opening") == 0);
    loading = 0;
    MgsGodotPublishContext();
    assert(Word(84) == 0 && Word(88) == 0 && Word(92) == 0);
    GM_GameStatus = STATE_THERMG | STATE_NVG;
    assert(MgsGodotVisionMode() == 2 && MgsGodotOwnsThermalVision() && !MgsGodotOwnsNightVision());
    capabilities &= ~32768u;
    CheckMask(SCREEN_MASK_IR_MODE, 0);
    capabilities |= 32768u;
    scene_enabled = 0;
    CheckMask(SCREEN_MASK_IR_MODE, 0);
    GM_GameStatus = STATE_NVG;
    scene_enabled = 0;
    assert(!MgsGodotOwnsNightVision());
    CheckMask(SCREEN_MASK_NV_MODE, 0);
    scene_enabled = 1;
    capabilities = 256 | 512;
    assert(!MgsGodotOwnsNightVision());
    CheckMask(SCREEN_MASK_NV_MODE, 0);
    MgsGodotPublishContext();
    assert(context_size == 80 && Word(0) == 4);
    puts("Vision context, negotiated mask ownership and reference/Legacy preservation pass.");
    return 0;
}
