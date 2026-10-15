#include "mgs_native.h"
#include "mgs_godot_ui.h"
#include "transport.h"
#include "../vendor/mgs/source/thing/sight.c"
#include <assert.h>

int GM_PlayerStatus, GV_Clock, GV_PauseLevel, GM_CurrentMap;
DG_CHANL DG_Chanls[3];
static unsigned capabilities;
static unsigned char wire[68];
static int prints, resets, destroy_count;
static GV_MSG message;
static int message_count;
static OT_TYPE ordering;
static SightPrimBufInfoStruct indices[2] = {{0, 64, 0}, {0, 0, 24}};
static struct {
    uint32_t polygon[6];
    SightTextPseudoPrim text;
} artwork = {{5, 0x2a404040, 0x00020001, 0x00040003, 0x00060005, 0x00080007},
             {0xff, 64, 64, 64, 0, 8, 9, "text"}};
static SightPrimitiveBufferInfo layout = {.primitiveBufferSize = sizeof(artwork), .primCount = 2,
    .ancillaryInfo = indices, .primitiveBuffer = &artwork};

bool MgsGodotHasCapability(unsigned bit) { return (capabilities & bit) != 0; }
int MgsGodotSceneEnabled(void) { return 1; }
unsigned MgsGodotSceneEpoch(void) { return 1; }
void MgsGodotCopySessionId(unsigned char *data) { memset(data, 1, 16); }
void MgsGodotQueue(uint32_t operation, const void *header, uint32_t size, const void *data, uint32_t bytes)
{
    assert(operation == MGS_GODOT_UI && size == sizeof(wire) && !data && !bytes);
    memcpy(wire, header, size);
}
void *GV_NewActor(int level, int size) { (void)level; return calloc(1, size); }
void *GV_Malloc(int size) { return calloc(1, size); }
void GV_DelayedFree(void *memory) { free(memory); }
void GV_SetNamedActor(void *actor, void *act, void *die, const char *name)
{
    GV_ACT *target = actor;
    target->act = act; target->die = die; target->filename = name;
}
void GV_DestroyActor(void *actor) { (void)actor; ++destroy_count; }
void *GV_GetCache(int id) { (void)id; return &layout; }
int GV_CacheID(int name, int extension) { return name | (extension << 16); }
int GV_ReceiveMessage(int address, GV_MSG **messages)
{
    assert(address == 0x30da);
    *messages = &message;
    return message_count;
}
void MENU_Locate(int x, int y, int flags) { (void)x; (void)y; (void)flags; }
void MENU_Color(int r, int g, int b) { (void)r; (void)g; (void)b; }
int MENU_Printf(const char *format, ...) { (void)format; ++prints; return 0; }
int mgs_fprintf(int descriptor, const char *format, ...)
{ (void)descriptor; (void)format; assert(!"Invalid native sight packet"); return 0; }
void MENU_ResetText(void) { ++resets; }
void SetDrawTPage(DR_TPAGE *page, int dfe, int dtd, int tpage)
{ (void)dfe; (void)dtd; (void)tpage; memset(page, 0, sizeof(*page)); setlen(page, 1); }

static unsigned Word(int offset)
{
    unsigned value;
    memcpy(&value, wire + offset, sizeof(value));
    return value;
}

static void CheckSight(int source, int suppress)
{
    short equipped = IT_Scope, offset[] = {-12, 20};
    Work *work = NewSightFast(source, 0x9c26, &equipped, IT_Scope, offset);
    assert(work && dword_8009F600 == 1);
    MgsGodotGogglesUpdate(&layout, 1, 20, 1, 123);
#ifndef MGS_GODOT_SCENE
    suppress = 0;
#endif
    for (int hidden = 0; hidden < 3; ++hidden) {
        prints = resets = 0;
        memset(&ordering, 0, sizeof(ordering));
        GM_PlayerStatus = hidden == 2 ? PLAYER_NOT_SIGHT : 0;
        message.message[0] = hidden == 1 ? HASH_OFF : HASH_ON;
        message_count = 1;
        int frame = work->frameCount;
        Act(work);
        assert(prints == (!hidden && !suppress) && resets == 1);
        assert((getaddr(&ordering) != 0) == (!hidden && !suppress));
        assert(work->frameCount == frame + 1);
        if (suppress) {
            MgsGodotPublishUi();
            assert(Word(24) == (hidden ? 0u : 2u));
            assert((int)Word(36) == (hidden ? 0 : -12) && Word(40) == (hidden ? 0u : 20u));
        }
    }
    message_count = 0;
    GM_PlayerStatus = 0;
    GV_PauseLevel = 1;
    int frame = work->frameCount;
    Act(work);
    assert(work->frameCount == frame);
    GV_PauseLevel = 0;
    equipped = 0;
    destroy_count = 0;
    Act(work);
    assert(destroy_count == 1);
    Die(work);
    free(work);
    MgsGodotPublishUi();
    assert(Word(24) == 0 && dword_8009F600 == 0 && dword_8009F604 == -1);
    MgsGodotGogglesRemove(&layout);
}

int main(void)
{
    DG_Chanls[2].ot[0] = &ordering;
    capabilities = MGS_GODOT_UI_CAPABILITY;
    CheckSight(0x8505, 1);
    CheckSight(0x1234, 0);
    capabilities = 0;
    CheckSight(0x8505, 0);
    puts("Sight packet/text ownership, visibility messages, pause and lifetime pass.");
    return 0;
}
