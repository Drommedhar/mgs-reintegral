#include "mgs_native.h"
#include "mgs_liquid_probe.h"
#include "mgs_bonus_items.h"
#include "animal/liquid/liquid_native.h"
#include "overlays/d18a/animal/snake18/native.h"

extern MenuWork Work;

static int started, valid, last_health = 255, damage_events, victory, arrived, failed;
static int last_player_health;
static unsigned fight_frames;
static int charge_side;

static int Story(void)
{
    char token[4] = {0x11, 0, 0, 10};
    int type, value;
    GCL_GetVar(token, &type, &value);
    return value;
}

static void ObserveFight(unsigned frame, const LiquidWork *boss)
{
    if (!started) {
        started = 1;
        last_player_health = GM_Vitality;
        valid = GM_GameLevel == GM_LEVEL_NORMAL && GM_VitalityMax == 768 &&
                boss->field_988 == 255 && GM_Item == IT_None && GM_Weapon == WP_None &&
                GM_StealthFlag < 0 && GM_BandanaFlag < 0 && !MgsBonusItemsEnabled();
        printf("[liquid-fight] Started frame=%u valid=%d difficulty=%d health=%d/%d boss=%d.\n",
               frame, valid, GM_GameLevel, GM_Vitality, GM_VitalityMax, boss->field_988);
    }
    if (GM_Vitality < last_player_health)
        printf("[liquid-fight] Snake hit frame=%u health=%d->%d boss=%d action=%d timer=%d climb=%d.\n",
               frame, last_player_health, GM_Vitality, boss->field_988,
               boss->field_93C, boss->field_934, boss->field_9A4);
    last_player_health = GM_Vitality;
    if (boss->field_988 < last_health) {
        ++damage_events;
        printf("[liquid-fight] Damage frame=%u boss=%d->%d snake=%d action=%d timer=%d.\n",
               frame, last_health, boss->field_988, GM_Vitality, boss->field_93C, boss->field_934);
    }
    last_health = boss->field_988;
    if (frame % 300 == 0)
        printf("[liquid-fight] frame=%u snake=(%d,%d,%d) health=%d status=%x "
               "boss=(%d,%d,%d) health=%d action=%d timer=%d countdown=%d.\n",
               frame, GM_PlayerPosition.vx, GM_PlayerPosition.vy, GM_PlayerPosition.vz,
               GM_Vitality, GM_PlayerStatus, boss->control.mov.vx, boss->control.mov.vy,
               boss->control.mov.vz, boss->field_988, boss->field_93C, boss->field_934,
               GetCountdownTime());
}

static int AvoidCharge(const LiquidWork *boss, int *heading)
{
    if (boss->action != liquid_800CA1A4 || boss->field_934 > 43) {
        charge_side = 0;
        return 0;
    }
    if (!charge_side) {
        int side = (boss->control.rot.vy + 1024) & 4095;
        int x = liquid_position.vx - GM_PlayerPosition.vx;
        int z = liquid_position.vz - GM_PlayerPosition.vz;
        charge_side = rsin(side) * x + rcos(side) * z < 0 ? -1024 : 1024;
    }
    *heading = (boss->control.rot.vy + charge_side) & 4095;
    return 1;
}

static unsigned short Fight(const LiquidWork *boss, int *heading)
{
    SVECTOR delta, position = boss->control.mov;
    int distance;
    if (boss->field_9A4) {
        GV_SubVec3(&liquid_position, &GM_PlayerPosition, &delta);
        if (abs(delta.vx) + abs(delta.vz) > 400)
            *heading = ratan2(delta.vx, delta.vz) & 4095;
        return 0;
    }
    GV_SubVec3(&position, &GM_PlayerPosition, &delta);
    distance = abs(delta.vx) + abs(delta.vz);
    ++fight_frames;
    if (AvoidCharge(boss, heading))
        return 0;
    if ((boss->field_93C == 17 && boss->field_934 <= 13) ||
        boss->field_93C == 21 || boss->field_93C == 22 ||
        (boss->field_93C == 23 && boss->field_934 <= 33)) {
        if ((int)delta.vx * delta.vx + (int)delta.vz * delta.vz < 1800 * 1800)
            *heading = ratan2(-delta.vx, -delta.vz) & 4095;
        return 0;
    }
    if (distance > 400)
        *heading = ratan2(delta.vx, delta.vz) & 4095;
    if (distance < 750)
        return fight_frames % 8 < 4 ? PAD_CIRCLE : 0;
    return 0;
}

static unsigned short ClimbInput(unsigned frame)
{
    if (!(GM_PlayerStatus & PLAYER_ACT_ONLY))
        return 0;
    const Snake18Work *snake = (const Snake18Work *)
        ((const char *)GM_PlayerControl - offsetof(Snake18Work, control));
    if (snake->f8AC == d18a_snake18_800D01D8)
        return frame % 8 < 4 ? PAD_UP : 0;
    return 0;
}

unsigned short MgsLiquidProbeInput(unsigned frame, int player_ready, int *heading)
{
    const char *stage = GM_GetArea(0);
    int story = Story();
    *heading = -1;
    if (failed || arrived || GM_LoadComplete <= 0 || GM_LoadRequest != 0)
        return 0;
    if (GM_GameOverTimer || (started && GM_Vitality <= 0)) {
        failed = 1;
        printf("[liquid-fight] FAIL player died frame=%u health=%d.\n", frame, GM_Vitality);
        return 0;
    }
    if (started && story == 278)
        victory = damage_events > 0 && last_health < 3;
    if (victory && (!strcmp(stage, "d18a") || !strcmp(stage, "d18ar"))) {
        arrived = 1;
        printf("[liquid-fight] Authored victory handoff frame=%u stage=%s story=%d.\n",
               frame, stage, story);
        return 0;
    }
    if (Work.field_2A_state == MENU_CODEC_OPEN)
        return frame % 24 < 8 ? PAD_CROSS : 0;
    if (GM_GameStatus & STATE_DEMO)
        return frame % 60 < 8 ? PAD_START : 0;
    if (story != 277 || (strcmp(stage, "s18a") && strcmp(stage, "s18ar")) ||
        !GM_PlayerControl || !liquid_camera_work)
        return 0;
    if (player_ready) {
        ObserveFight(frame, liquid_camera_work);
        return Fight(liquid_camera_work, heading);
    }
    if (started) {
        ObserveFight(frame, liquid_camera_work);
        return ClimbInput(frame);
    }
    return 0;
}

int MgsLiquidProbeFinish(void)
{
    int complete = valid && damage_events > 0 && victory && arrived && !failed;
    printf("[liquid-fight] %s valid=%d damage_events=%d health=%d victory=%d handoff=%d failed=%d.\n",
           complete ? "PASS" : "FAIL", valid, damage_events, last_health, victory, arrived, failed);
    return complete;
}
