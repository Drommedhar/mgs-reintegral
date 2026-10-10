#include "../src/mgs_liquid_probe.c"
#undef fprintf
#include <assert.h>
#include <math.h>

MenuWork Work;
short linkvarbuf[0x60];
CONTROL *GM_PlayerControl;
SVECTOR GM_PlayerPosition;
int GM_LoadComplete, GM_LoadRequest, GM_GameOverTimer, GM_GameStatus, GM_PlayerStatus;
LiquidWork *liquid_camera_work;
SVECTOR liquid_position = {2500, 10000, 500, 0};

static int story = 277;
static char *stage = "s18a";

void liquid_800CA1A4(LiquidWork *boss, int tick)
{
    (void)boss;
    (void)tick;
    assert(0 && "The probe must not invoke gameplay callbacks");
}

void d18a_snake18_800D01D8(Snake18Work *snake, int tick)
{
    (void)snake;
    (void)tick;
    assert(0 && "The probe must not invoke gameplay callbacks");
}

int MgsBonusItemsEnabled(void) { return 0; }
int GetCountdownTime(void) { return 4500; }
char *GM_GetArea(int index) { assert(index == 0); return stage; }

char *GCL_GetVar(char *token, int *type, int *value)
{
    assert(token[3] == 10);
    *type = 1;
    *value = story;
    return token + 4;
}

long ratan2(long y, long x)
{
    return (long)lround(atan2(y, x) * 4096.0 / 6.283185307179586);
}

int rsin(int angle) { return (int)lround(sin(angle * 6.283185307179586 / 4096) * 4096); }
int rcos(int angle) { return rsin(angle + 1024); }

void GV_SubVec3(SVECTOR *first, SVECTOR *second, SVECTOR *result)
{
    result->vx = first->vx - second->vx;
    result->vy = first->vy - second->vy;
    result->vz = first->vz - second->vz;
}

static void CheckGetupKick(void)
{
    static const SVECTOR offsets[] = {
        {600, 0, 0, 0}, {-600, 0, 0, 0}, {0, 0, 600, 0}, {600, 0, 600, 0}
    };
    for (int action = 21; action <= 23; ++action) {
        for (unsigned i = 0; i < sizeof(offsets) / sizeof(offsets[0]); ++i) {
            LiquidWork boss = {0};
            boss.control.mov = offsets[i];
            boss.field_93C = action;
            boss.field_934 = 32;
            LiquidWork unchanged = boss;
            int heading = -1;
            assert(Fight(&boss, &heading) == 0 && heading >= 0);
            int toward = ratan2(offsets[i].vx, offsets[i].vz) & 4095;
            assert(((heading - toward) & 4095) == 2048);
            assert(memcmp(&boss, &unchanged, sizeof(boss)) == 0);
            boss.control.mov = (SVECTOR){1800, 0, 0, 0};
            heading = -1;
            assert(Fight(&boss, &heading) == 0 && heading == -1);
        }
    }
    LiquidWork recovered = {0};
    recovered.control.mov = (SVECTOR){0, 0, 600, 0};
    recovered.field_93C = 23;
    recovered.field_934 = 34;
    fight_frames = 0;
    int heading = -1;
    assert(Fight(&recovered, &heading) == PAD_CIRCLE && heading == 0);
    recovered.field_93C = 17;
    recovered.field_934 = 12;
    heading = -1;
    assert(Fight(&recovered, &heading) == 0 && heading == 2048);
    recovered.field_934 = 14;
    heading = -1;
    assert(Fight(&recovered, &heading) == PAD_CIRCLE && heading == 0);
}

static void CheckCompletion(void)
{
    LiquidWork boss = {0};
    Snake18Work player = {0};
    GM_PlayerControl = &player.control;
    liquid_camera_work = &boss;
    GM_LoadComplete = 1;
    GM_GameLevel = GM_LEVEL_NORMAL;
    GM_Vitality = GM_VitalityMax = 768;
    GM_Item = IT_None;
    GM_Weapon = WP_None;
    GM_StealthFlag = GM_BandanaFlag = -1;
    boss.field_988 = 255;
    short unchanged[0x60];
    memcpy(unchanged, linkvarbuf, sizeof(unchanged));
    int heading;
    MgsLiquidProbeInput(1, 1, &heading);
    assert(started && valid && !MgsLiquidProbeFinish());
    assert(memcmp(unchanged, linkvarbuf, sizeof(unchanged)) == 0);
    GM_PlayerStatus = PLAYER_ACT_ONLY;
    player.f8AC = d18a_snake18_800D01D8;
    Snake18Work untouched = player;
    assert(MgsLiquidProbeInput(8, 0, &heading) == PAD_UP && heading == -1);
    assert(MgsLiquidProbeInput(12, 0, &heading) == 0 && heading == -1);
    assert(memcmp(&player, &untouched, sizeof(player)) == 0);
    player.f8AC = NULL;
    assert(MgsLiquidProbeInput(16, 0, &heading) == 0);
    GM_PlayerStatus = 0;
    boss.field_988 = 0;
    MgsLiquidProbeInput(2, 1, &heading);
    story = 278;
    MgsLiquidProbeInput(3, 0, &heading);
    assert(!MgsLiquidProbeFinish());
    stage = "d18a";
    MgsLiquidProbeInput(4, 0, &heading);
    assert(MgsLiquidProbeFinish());
    failed = 1;
    assert(!MgsLiquidProbeFinish());
}

static void CheckClimbRecovery(void)
{
    LiquidWork boss = {0};
    boss.control.mov = (SVECTOR){5558, 10793, 464, 0};
    boss.field_988 = 4;
    boss.field_9A4 = 1;
    LiquidWork unchanged = boss;
    GM_PlayerPosition = (SVECTOR){5079, 11650, 464, 0};
    int heading = -1;
    assert(Fight(&boss, &heading) == 0);
    assert(heading > 2048 && heading < 4096);
    assert(memcmp(&boss, &unchanged, sizeof(boss)) == 0);
    GM_PlayerPosition = liquid_position;
    heading = -1;
    assert(Fight(&boss, &heading) == 0 && heading == -1);
    GM_PlayerPosition = (SVECTOR){5079, 11650, 464, 0};
    boss.field_9A4 = 0;
    fight_frames = 0;
    assert(Fight(&boss, &heading) == PAD_CIRCLE);
    GM_PlayerPosition = (SVECTOR){0};
}

static void CheckCharge(void)
{
    LiquidWork boss = {0};
    boss.action = liquid_800CA1A4;
    boss.field_934 = 1;
    boss.control.rot.vy = 2048;
    GM_PlayerPosition = (SVECTOR){5000, 12000, 500, 0};
    int heading = -1;
    assert(Fight(&boss, &heading) == 0 && heading == 3072);
    GM_PlayerPosition.vx = 2499;
    boss.field_934 = 42;
    assert(Fight(&boss, &heading) == 0 && heading == 3072);
    boss.field_934 = 44;
    assert(!AvoidCharge(&boss, &heading) && charge_side == 0);
    boss.field_934 = 1;
    assert(AvoidCharge(&boss, &heading) && heading == 1024);
    boss.action = NULL;
    assert(!AvoidCharge(&boss, &heading));
    GM_PlayerPosition = (SVECTOR){0};
}

int main(void)
{
#ifdef _WIN32
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif
    CheckGetupKick();
    CheckClimbRecovery();
    CheckCharge();
    CheckCompletion();
    puts("Liquid probe: kick avoidance, climb recovery and original handoff gates passed");
    return 0;
}
