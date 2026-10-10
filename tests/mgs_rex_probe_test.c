#include "../src/mgs_rex_probe.c"
#undef fprintf
#include <assert.h>

MenuWork Work;
SnaInitWork *sna_800ABBA0;
TARGET *target_800BDF00;
int amissile_alive_8009F490;
short linkvarbuf[0x60];
CONTROL *GM_PlayerControl;
SVECTOR GM_PlayerPosition;
GM_SnakeCameraWork GM_SnakeCamera;
int GM_LoadComplete, GM_LoadRequest, GM_GameOverTimer, GM_GameStatus;
int GM_PlayerStatus, GV_Time, GV_PauseLevel;

static SnaInitWork snake;
static RexWork boss;
static GV_ACT list_start, list_end;
static TARGET radar, mouth;
static char *stage;
static int script_phase, script_story;

void RexAct(RexWork *work)
{
    (void)work;
    assert(0 && "A controller probe must not execute an actor callback");
}

char *GM_GetArea(int index)
{
    assert(index == 0);
    return stage;
}

char *GCL_GetVar(char *token, int *type, int *value)
{
    unsigned offset = ((unsigned char)token[2] << 8) | (unsigned char)token[3];
    assert(offset == 0xa || offset == 0x40e);
    *type = 1;
    *value = offset == 0xa ? script_story : script_phase;
    return token + 4;
}

long ratan2(long y, long x)
{
    return (int)lround(atan2(y, x) * 4096.0 / 6.283185307179586);
}

static void Reset(void)
{
    memset(linkvarbuf, 0, sizeof(linkvarbuf));
    memset(&Work, 0, sizeof(Work));
    memset(&snake, 0, sizeof(snake));
    memset(&boss, 0, sizeof(boss));
    memset(&radar, 0, sizeof(radar));
    memset(&mouth, 0, sizeof(mouth));
    memset(&GM_PlayerPosition, 0, sizeof(GM_PlayerPosition));
    memset(&GM_SnakeCamera, 0, sizeof(GM_SnakeCamera));
    GM_LoadComplete = 1;
    GM_LoadRequest = GM_GameOverTimer = GM_GameStatus = GM_PlayerStatus = GV_PauseLevel = 0;
    GM_GameLevel = GM_LEVEL_NORMAL;
    GM_Vitality = GM_VitalityMax = 768;
    GM_StingerFlag = GM_StingerMax = 35;
    GM_RationFlag = GM_RationMax = 5;
    GM_Weapon = WP_Stinger;
    GM_Item = IT_Ration;
    snake.actor.prev = &list_start;
    snake.actor.next = &boss.actor;
    list_start.next = &snake.actor;
    boss.actor.prev = &snake.actor;
    boss.actor.next = &list_end;
    boss.actor.act = (GV_ACTFUNC)RexAct;
    list_end.prev = &boss.actor;
    sna_800ABBA0 = &snake;
    GM_PlayerControl = &snake.control;
    boss.field_5BC = boss.field_5C4 = 1800;
    boss.field_196C = 1;
    boss.weakpoint_radar = &radar;
    radar.center.vz = 10000;
    radar.class = TARGET_SEEK | TARGET_POWER;
    mouth = radar;
    target_800BDF00 = &radar;
    stage = "s17a";
    script_phase = 1;
    script_story = 255;
    started = failed = completed = phases = radar_initial = mouth_initial = 0;
    radar_last = radar_defeated = radar_damage = mouth_last = mouth_defeated = mouth_damage = 0;
    last_phase = last_ammo = last_tick = -1;
    shots = amissile_alive_8009F490 = 0;
    shot_frame = next_shot_frame = 0;
    dodge_ticks = dodge_tick = dodge_x = dodge_z = dodge_distance = 0;
    memset(&chaff, 0, sizeof(chaff));
    disruption_active = disruption_phase = 0;
}

static unsigned short Tick(unsigned frame)
{
    short saved_vars[0x60];
    RexWork saved_boss = boss;
    SnaInitWork saved_snake = snake;
    memcpy(saved_vars, linkvarbuf, sizeof(saved_vars));
    ++GV_Time;
    int heading = 123;
    unsigned short buttons = MgsRexProbeInput(frame, &heading);
    assert(heading == -1);
    assert(memcmp(saved_vars, linkvarbuf, sizeof(saved_vars)) == 0);
    assert(memcmp(&saved_boss, &boss, sizeof(boss)) == 0);
    assert(memcmp(&saved_snake, &snake, sizeof(snake)) == 0);
    return buttons;
}

static void CheckMissileInputs(void)
{
    Reset();
    assert(Tick(100) == PAD_SQUARE);
    assert(Tick(102) == PAD_SQUARE);
    assert(Tick(104) == 0);
    assert(Tick(110) == 0);
    amissile_alive_8009F490 = 1;
    assert(Tick(170) == 0);
    amissile_alive_8009F490 = 0;
    radar.class = TARGET_AVAIL;
    assert(Tick(200) == 0);
    radar.class = TARGET_POWER | TARGET_SEEK;
    target_800BDF00 = NULL;
    assert(Tick(210) == 0);
    radar.center = (SVECTOR){1000, 1000, 1000, 0};
    assert(Tick(220) == (PAD_LEFT | PAD_UP));
    GM_Configuration |= GM_CONFIG_SHUKAN_REVERSE;
    assert(Tick(230) == (PAD_LEFT | PAD_DOWN));
}

static void CheckInventoryInputs(void)
{
    struct {
        Menu_Item_Unknown_Main main;
        PANEL panels[1];
    } inventory = {0};
    Reset();
    GM_Weapon = WP_None;
    assert(Tick(100) == PAD_R2);
    Work.field_2A_state = MENU_RIGHT_OPEN;
    Work.field_1F0_menu_weapon.field_10_state = 1;
    Work.field_1F0_menu_weapon.field_C_alloc = (Menu_Item_Unknown *)&inventory;
    inventory.main.field_0_array_count = 1;
    inventory.panels[0].field_0_id = WP_Stinger;
    assert(Tick(110) == 0);
    Reset();
    GM_Item = IT_None;
    assert(Tick(100) == PAD_L2);
    Work.field_2A_state = MENU_LEFT_OPEN;
    Work.field_1DC_menu_item.field_10_state = 1;
    Work.field_1DC_menu_item.field_C_alloc = (Menu_Item_Unknown *)&inventory;
    inventory.panels[0].field_0_id = IT_Ration;
    assert(Tick(110) == 0);
}

static void CheckAimRange(void)
{
    Reset();
    Tick(100);
    radar.center = (SVECTOR){0, 10001, 10000, 0};
    int in_range;
    AimAt(&radar, &in_range);
    assert(in_range);
    radar.center.vy = 11000;
    assert(Tick(114) == PAD_R1 && dodge_ticks == 36);
    assert(GM_PlayerPosition.vx == 0 && GM_PlayerPosition.vz == 0);
    GM_GameStatus = STATE_DEMO;
    script_phase = 2;
    Tick(120);
    assert(dodge_ticks == 0 && shot_frame == 0 && next_shot_frame == 0);
}

static void CheckEvasion(void)
{
    Reset();
    script_phase = 5;
    started = 1;
    boss.field_196C = 3;
    boss.weakpoint_radar = NULL;
    boss.weakpoint_mouth = &mouth;
    radar.center.vz = mouth.center.vz = -10000;
    Tick(100);
    boss.field_5C4 = 1544;
    assert(Tick(114) == PAD_R1);
    GM_Weapon = WP_None;
    snake.field_91C_weapon_idx = WP_None;
    int heading = -1;
    ++GV_Time;
    assert(MgsRexProbeInput(120, &heading) == 0);
    assert(heading > 2560 && heading < 3072 && dodge_ticks == 35);
    assert(GM_PlayerPosition.vx == 0 && GM_PlayerPosition.vz == 0);
    assert(GM_Weapon == WP_None && boss.field_5C4 == 1544);
    GM_PlayerStatus = PLAYER_DOWNED | PLAYER_GROUND;
    assert(Tick(128) == PAD_CROSS);
    assert(Tick(130) == 0);
    GM_PlayerStatus |= PLAYER_DAMAGED;
    assert(Tick(136) == 0);
}

static void CheckEvasionSeparation(void)
{
    static const SVECTOR positions[] = {
        {3161, 995, -7606, 0}, {-3161, 995, -7606, 0},
        {0, 995, -7606, 0}, {10675, 995, -8555, 0}
    };
    static const SVECTOR targets[] = {
        {1685, 8231, -14357, 0}, {-1685, 8231, -14357, 0},
        {0, 8231, -7606, 0}, {3618, 8231, -15771, 0}
    };
    for (unsigned index = 0; index < sizeof(positions) / sizeof(positions[0]); ++index) {
        Reset();
        GM_PlayerPosition = positions[index];
        mouth.center = targets[index];
        BeginEvasion(&mouth);
        double dx = positions[index].vx - targets[index].vx;
        double dz = positions[index].vz - targets[index].vz;
        double step_x = dodge_x - positions[index].vx;
        double step_z = dodge_z - positions[index].vz;
        double initial_squared = dx * dx + dz * dz;
        double final_x = dodge_x - targets[index].vx;
        double final_z = dodge_z - targets[index].vz;
        double height = targets[index].vy - positions[index].vy;
        assert(final_x * final_x + final_z * final_z > height * height);
        assert(final_x * final_x + final_z * final_z < 12000.0 * 12000.0);
        if (initial_squared > height * height) {
            double nearest = -(dx * step_x + dz * step_z) / (step_x * step_x + step_z * step_z);
            if (nearest < 0) nearest = 0;
            if (nearest > 1) nearest = 1;
            double near_x = dx + nearest * step_x, near_z = dz + nearest * step_z;
            assert(near_x * near_x + near_z * near_z > height * height);
        }
        assert(memcmp(&GM_PlayerPosition, &positions[index], sizeof(SVECTOR)) == 0);
        assert(memcmp(&mouth.center, &targets[index], sizeof(SVECTOR)) == 0);
    }
}

static void CheckEvasionHealingPriority(void)
{
    Reset();
    Tick(100);
    GM_BodyArmorFlag = 1;
    GM_Item = IT_BodyArmor;
    GM_Vitality = 512;
    dodge_ticks = 36;
    assert(Tick(120) == PAD_L2);
    assert(dodge_ticks == 36 && GM_RationFlag == 5 && GM_Vitality == 512);
    GM_Vitality = 768;
    GM_Weapon = WP_None;
    snake.field_91C_weapon_idx = WP_None;
    GV_PauseLevel = GV_PAUSE_MENU;
    for (unsigned frame = 121; frame < 181; ++frame)
        assert(Tick(frame) == 0);
    assert(dodge_ticks == 36);
}

static void CheckChaffInputs(void)
{
    Reset();
    GM_ChaffGrenadeFlag = 9;
    GM_ChaffGrenadeMax = 27;
    assert(Tick(100) == PAD_R2);
    GM_Weapon = WP_ChaffGrenade;
    snake.field_91C_weapon_idx = WP_ChaffGrenade;
    assert(Tick(110) == PAD_SQUARE);
    assert(Tick(116) == 0);
    --GM_ChaffGrenadeFlag;
    assert(Tick(117) == PAD_R2);
    assert(chaff.wait_ticks == 180);
    GM_GameStatus |= STATE_CHAFF;
    GM_Weapon = WP_Stinger;
    assert(Tick(120) == PAD_SQUARE);
    assert(chaff.wait_ticks == 0);
}

static void CheckChaffClock(void)
{
    Reset();
    chaff.wait_ticks = 180;
    chaff.wait_tick = GV_Time;
    GV_PauseLevel = GV_PAUSE_MENU;
    for (int i = 0; i < 1000; ++i) {
        ++GV_Time;
        AdvanceGrenadeWait(&chaff);
        assert(chaff.wait_ticks == 180);
    }
    GV_PauseLevel = 0;
    static const int suspended_states[] = {STATE_PADRELEASE, STATE_PADDEMO, STATE_DEMO};
    for (unsigned i = 0; i < sizeof(suspended_states) / sizeof(suspended_states[0]); ++i) {
        GM_GameStatus = suspended_states[i];
        ++GV_Time;
        AdvanceGrenadeWait(&chaff);
        assert(chaff.wait_ticks == 180);
    }
    GM_GameStatus = 0;
    GM_PlayerStatus = PLAYER_PAD_OFF;
    ++GV_Time;
    AdvanceGrenadeWait(&chaff);
    assert(chaff.wait_ticks == 180);
    GM_PlayerStatus = 0;
    for (int i = 0; i < 180; ++i) {
        AdvanceGrenadeWait(&chaff);
        assert(chaff.wait_ticks == 180 - i);
        ++GV_Time;
        AdvanceGrenadeWait(&chaff);
        assert(chaff.wait_ticks == 179 - i);
    }
    ++GV_Time;
    AdvanceGrenadeWait(&chaff);
    assert(chaff.wait_ticks == 0);
}

static void CheckGrenadeStartupGate(void)
{
    Reset();
    GM_ChaffGrenadeFlag = 9;
    GM_ChaffGrenadeMax = 27;
    boss.field_196C = 0;
    assert(Tick(100) == 0);
    boss.field_196C = 1;
    radar.center = (SVECTOR){0};
    assert(Tick(110) == 0);
    radar.center.vz = 10000;
    radar.class = 0;
    assert(Tick(120) == 0);
    radar.class = TARGET_POWER | TARGET_SEEK;
    assert(Tick(130) == PAD_R2);
}

static void CheckDisruptionSidestep(void)
{
    Reset();
    Tick(100);
    GM_GameStatus = STATE_CHAFF;
    boss.field_1988 = 1;
    assert(Tick(114) == PAD_R1 && dodge_ticks == 36);
    GM_Weapon = WP_None;
    snake.field_91C_weapon_idx = WP_None;
    int heading = -1;
    ++GV_Time;
    assert(MgsRexProbeInput(120, &heading) == 0);
    assert(heading >= 0 && dodge_ticks == 35);
    ++GV_Time;
    MgsRexProbeInput(122, &heading);
    assert(dodge_ticks == 34);
    assert(GM_PlayerPosition.vx == 0 && GM_PlayerPosition.vz == 0);
    assert(boss.field_1988 == 1 && GM_GameStatus == STATE_CHAFF);
}

static void CheckCockpitChaffInputs(void)
{
    Reset();
    GM_StunGrenadeFlag = 9;
    GM_StunGrenadeMax = 27;
    Tick(100);
    script_phase = 5;
    boss.field_196C = 3;
    boss.weakpoint_radar = NULL;
    boss.weakpoint_mouth = target_800BDF00 = &mouth;
    GM_ChaffGrenadeFlag = 9;
    GM_ChaffGrenadeMax = 27;
    assert(Tick(110) == PAD_R2);
    GM_Weapon = WP_ChaffGrenade;
    snake.field_91C_weapon_idx = WP_ChaffGrenade;
    assert(Tick(112) == PAD_SQUARE);
    assert(Tick(118) == 0);
    --GM_ChaffGrenadeFlag;
    assert(Tick(119) == PAD_R2 && chaff.wait_ticks == 180);
    assert(DisruptionInput(119, &boss) == -1);
    GM_GameStatus = STATE_CHAFF;
    assert(Tick(120) == PAD_R2);
    assert(DisruptionInput(120, &boss) == -1 && chaff.wait_ticks == 0);
    GM_Weapon = WP_Stinger;
    snake.field_91C_weapon_idx = WP_Stinger;
    assert(Tick(132) == PAD_SQUARE);
    assert(GM_StunGrenadeFlag == 9);
    Reset();
    GM_StunGrenadeFlag = GM_StunGrenadeMax = 99;
    assert(Tick(140) == 0 && failed);
}

static void CheckArmorInputs(void)
{
    struct {
        Menu_Item_Unknown_Main main;
        PANEL panels[1];
    } inventory = {0};
    Reset();
    GM_BodyArmorFlag = 1;
    assert(Tick(100) == PAD_L2);
    GM_Item = IT_BodyArmor;
    assert(Tick(110) == PAD_SQUARE);
    GM_Vitality = 512;
    assert(Tick(120) == PAD_L2);
    Work.field_2A_state = MENU_LEFT_OPEN;
    Work.field_1DC_menu_item.field_10_state = 1;
    Work.field_1DC_menu_item.field_C_alloc = (Menu_Item_Unknown *)&inventory;
    inventory.main.field_0_array_count = 1;
    inventory.panels[0].field_0_id = IT_Ration;
    assert(Tick(128) == (PAD_L2 | PAD_CIRCLE));
    assert(Tick(130) == PAD_L2);
    GM_Vitality = 768;
    GM_Item = IT_Ration;
    inventory.panels[0].field_0_id = IT_BodyArmor;
    assert(Tick(140) == 0);
    GM_Vitality = 128;
    GM_RationFlag = 0;
    assert(Tick(150) == 0);
}

static void CheckCompletionContract(void)
{
    Reset();
    Tick(100);
    --GM_StingerFlag;
    boss.field_5BC = 0;
    Tick(110);
    GM_GameStatus = STATE_DEMO;
    for (script_phase = 2; script_phase < 5; ++script_phase)
        Tick(120 + script_phase);
    script_story = 257;
    GM_GameStatus = 0;
    boss.weakpoint_radar = NULL;
    boss.weakpoint_mouth = target_800BDF00 = &mouth;
    Tick(150);
    --GM_StingerFlag;
    boss.field_5C4 = 0;
    Tick(160);
    stage = "d18a";
    script_story = 259;
    assert(Tick(170) == 0 && MgsRexProbeFinish());
    Reset();
    Tick(100);
    stage = "d18a";
    script_story = 258;
    assert(Tick(170) == 0 && !MgsRexProbeFinish());
    Reset();
    Tick(100);
    GM_Vitality = 0;
    assert(Tick(110) == 0 && !MgsRexProbeFinish());
    Reset();
    GM_BandanaFlag = 1;
    assert(Tick(100) == 0 && !MgsRexProbeFinish());
}

int main(void)
{
#ifdef _WIN32
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif
    CheckMissileInputs();
    CheckInventoryInputs();
    CheckAimRange();
    CheckEvasion();
    CheckEvasionSeparation();
    CheckEvasionHealingPriority();
    CheckChaffInputs();
    CheckChaffClock();
    CheckGrenadeStartupGate();
    CheckDisruptionSidestep();
    CheckCockpitChaffInputs();
    CheckArmorInputs();
    CheckCompletionContract();
    puts("REX probe: aim, release-to-fire, menus, read-only state and strict completion checks passed");
    return 0;
}
