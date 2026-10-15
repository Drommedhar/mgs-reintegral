#include "mgs_native.h"
#include "mgs_godot_ui.h"
#include "transport.h"
#include "../vendor/mgs/source/equip/gglsight.c"
#define Work ManagerWork
#define _Work _ManagerWork
#define Act ManagerAct
#define Die ManagerDie
#include "../vendor/mgs/source/equip/gglmng.c"
#undef Work
#undef _Work
#undef Act
#undef Die
#include <assert.h>

int GM_PlayerStatus, GV_Clock, GV_PauseLevel;
short linkvarbuf[MAX_LINKVARBUF];
int dword_8009F604 = -1, dword_8009F46C;
CONTROL *GM_PlayerControl;
GM_CameraSystemWork GM_Camera;
GV_PAD GV_PadData[4];
#define pads GV_PadData
DG_CHANL DG_Chanls[3];
static unsigned capabilities, epoch = 1;
static unsigned char wire[68];
static int prints, scan_prints, sights, reverse, queued;
static OT_TYPE ordering;

bool MgsGodotHasCapability(unsigned bit) { return (capabilities & bit) != 0; }
int MgsGodotSceneEnabled(void) { return 1; }
unsigned MgsGodotSceneEpoch(void) { return epoch; }
void MgsGodotCopySessionId(unsigned char *data) { memset(data, 7, 16); }
void MgsGodotQueue(uint32_t operation, const void *header, uint32_t size, const void *data, uint32_t bytes)
{
    assert(operation == MGS_GODOT_UI && size == sizeof(wire) && !data && !bytes);
    memcpy(wire, header, size);
    ++queued;
}
void *GV_NewActor(int level, int size) { (void)level; return calloc(1, size); }
void GV_SetNamedActor(void *actor, void *act, void *die, const char *name)
{
    GV_ACT *target = actor;
    target->act = act; target->die = die; target->filename = name;
}
void GV_DestroyActor(void *actor) { free(actor); }
void GV_DestroyOtherActor(void *actor) { Die(actor); free(actor); }
void GM_CheckShukanReverse(unsigned short *status)
{
    if (reverse && (*status & PAD_UP)) *status = (*status & ~PAD_UP) | PAD_DOWN;
}
void *NewSight(int source, int root, short *active, short item, short *offset)
{
    (void)offset;
    assert(active[0] && item == IT_Scope && MgsGodotGogglesLayer(source) >= 0);
    dword_8009F604 = root;
    ++sights;
    return NULL;
}
void MENU_Locate(int x, int y, int flags) { (void)x; (void)y; (void)flags; }
void MENU_Color(int r, int g, int b) { (void)r; (void)g; (void)b; }
int MENU_Printf(const char *format, ...)
{
    ++prints;
    scan_prints += strcmp(format, "SCAN") == 0;
    return 0;
}
void SetDrawTPage(DR_TPAGE *page, int dfe, int dtd, int tpage)
{ (void)page; (void)dfe; (void)dtd; (void)tpage; }

static unsigned Word(unsigned offset)
{
    unsigned value;
    memcpy(&value, wire + offset, sizeof(value));
    return value;
}

static void CheckSight(int type, int owns)
{
    Work *work = NewGoggleSight(type);
    assert(work && work->type == type && work->scan_timer == -16);
    int expected_scan = -16;
    dword_8009F604 = -1;
    sights = 0;
    for (int tick = 1; tick <= 80; ++tick) {
        prints = scan_prints = 0;
        memset(&ordering, 0, sizeof(ordering));
        Act(work);
        assert(sights == 3 && work->timer == tick);
        assert((prints > 0) == (tick >= 6 && !owns));
        assert((getaddr(&ordering) != 0) == (tick >= 6 && !owns));
        assert(scan_prints == (tick >= 6 && expected_scan > 0 && !owns));
        if (owns) {
            MgsGodotPublishUi();
            assert(Word(0) == 1 && Word(4) == epoch && Word(8) == (type == IT_NVG ? 1u : 2u));
            assert(Word(12) == (1u | (tick >= 6 ? 2u : 0u) | (tick >= 6 && expected_scan > 0 ? 4u : 0u)));
            assert(Word(16) == 4095 && Word(20) == (unsigned)tick && wire[52] == 7 && wire[67] == 7);
        }
        if (tick >= 6 && ++expected_scan >= 17) expected_scan = -16;
        assert(work->scan_timer == expected_scan);
    }
    if (owns) {
        int layer = type == IT_NVG ? 1 : 4;
        MgsGodotGogglesLayerUpdate(layer, 1, -12, 20);
        MgsGodotPublishUi();
        assert(Word(24) == 2 && (int)Word(36) == -12 && Word(40) == 20);
        MgsGodotGogglesLayerUpdate((layer + 3) % 6, 0, 0, 0);
        MgsGodotPublishUi();
        assert(Word(24) == 2);
        MgsGodotGogglesLayerUpdate(layer, 0, 0, 0);
        MgsGodotPublishUi();
        assert(Word(24) == 0 && Word(36) == 0 && Word(40) == 0);
    }
    Die(work);
    free(work);
    if (owns) {
        MgsGodotPublishUi();
        assert(Word(8) == 0 && Word(12) == 0 && Word(24) == 0);
    }
}

static void CheckInput(void)
{
    Work *work = NewGoggleSight(IT_NVG);
    GM_PlayerStatus = PLAYER_NORMAL_WATCH;
    pads[0].status = PAD_RIGHT | PAD_UP;
    for (int tick = 0; tick < 10; ++tick) Act(work);
    assert(work->field_2C_4Array[1].vx == 0);
    Act(work);
    assert(work->field_2C_4Array[1].vx == 2 && work->field_2C_4Array[1].vy == -2);
    assert(work->field_2C_4Array[2].vx == -1);
    reverse = 1;
    Act(work);
    assert(work->field_2C_4Array[1].vy == 0);
    reverse = 0;
    GV_PauseLevel = 1;
    Act(work);
    assert(work->field_2C_4Array[1].vx == 2 && work->field_2C_4Array[2].vx == -1);
    GV_PauseLevel = 0;
    GM_PlayerStatus = PLAYER_NORMAL_WATCH | PLAYER_SECOND_CONTROLLER;
    pads[1].status = PAD_LEFT | PAD_DOWN;
    Act(work);
    assert(work->field_2C_4Array[1].vx == 0 && work->field_2C_4Array[1].vy == 2);
    GM_PlayerStatus |= PLAYER_PAD_OFF;
    Act(work);
    assert(work->field_2C_4Array[1].vy == 0);
    Die(work);
    free(work);
    GM_PlayerStatus = 0;
    pads[0].status = pads[1].status = 0;
}

static void CheckManager(void)
{
    ManagerWork *work = NewGoggleManager(IT_ThermG);
    GM_Camera.first_person = 1;
    for (int tick = 0; tick < 7; ++tick) ManagerAct(work);
    assert(!work->sight && work->time == 7);
    ManagerAct(work);
    assert(work->sight && work->time == 8);
    Act((Work *)work->sight);
    GM_Camera.first_person = 0;
    ManagerAct(work);
    assert(!work->sight && work->time == 0);
    GM_Camera.first_person = 1;
    GM_Weapon = WP_Stinger;
    for (int tick = 0; tick < 9; ++tick) ManagerAct(work);
    assert(!work->sight && work->time == 0);
    GM_Weapon = WP_None;
    GM_PlayerStatus = PLAYER_NOT_SIGHT;
    ManagerAct(work);
    assert(!work->sight && work->time == 0);
    GM_PlayerStatus = 0;
    for (int tick = 0; tick < 8; ++tick) ManagerAct(work);
    assert(work->sight);
    ManagerDie(work);
    free(work);
}

int main(void)
{
    CONTROL control = {0};
    control.rot.vy = -1;
    GM_PlayerControl = &control;
    DG_Chanls[2].ot[0] = &ordering;
    capabilities = MGS_GODOT_UI_CAPABILITY;
    int owns = 0;
#ifdef MGS_GODOT_SCENE
    owns = 1;
#endif
    CheckSight(IT_NVG, owns);
    CheckSight(IT_ThermG, owns);
    CheckInput();
    CheckManager();
    ++epoch;
    MgsGodotPublishUi();
    assert(Word(4) == epoch && Word(8) == 0);
    capabilities = 0;
    int before = queued;
    MgsGodotPublishUi();
    assert(queued == before);
    CheckSight(IT_NVG, 0);
    assert(MgsGodotGogglesLayer(0x8504) == 0 && MgsGodotGogglesLayer(0x84dd) == 5 && MgsGodotGogglesLayer(0x1234) == -1);
    puts("Goggles UI ownership, native timing, manager lifecycle and input pass.");
    return 0;
}
