#include "mgs_native.h"
#include "game/game.h"
#include "libgcl/libgcl.h"
#include "chara/snake/sna_init.h"
#include "overlays/s17a/rex_native.h"
#include "mgs_rex_probe.h"
#include <math.h>

extern MenuWork Work;
extern SnaInitWork *sna_800ABBA0;
extern TARGET *target_800BDF00;
extern int amissile_alive_8009F490;

static int started, failed, completed, phases, last_phase = -1;
static int radar_initial, radar_last, radar_defeated, radar_damage;
static int mouth_initial, mouth_last, mouth_defeated, mouth_damage;
static int last_ammo = -1, shots, last_tick = -1;
static unsigned shot_frame, next_shot_frame;
static int dodge_ticks, dodge_tick, dodge_x, dodge_z, dodge_distance;
static SVECTOR dodge_previous;
typedef struct {
    unsigned press_frame;
    int ammo, wait_ticks, wait_tick;
} GrenadeInputState;

static GrenadeInputState chaff;
static int disruption_active, disruption_phase;

static int ScriptWord(unsigned offset)
{
    char token[4] = {0x11, 0, (char)(offset >> 8), (char)offset};
    int type, value;
    GCL_GetVar(token, &type, &value);
    return value;
}

static const RexWork *FindRex(void)
{
    if (!sna_800ABBA0 || !GM_PlayerControl || &sna_800ABBA0->control != GM_PlayerControl)
        return NULL;
    const GV_ACT *actor = &sna_800ABBA0->actor;
    while (actor->prev)
        actor = actor->prev;
    for (; actor; actor = actor->next)
        if (actor->act == (GV_ACTFUNC)RexAct)
            return (const RexWork *)actor;
    return NULL;
}

static void BeginEvasion(const TARGET *target)
{
    int dx = GM_PlayerPosition.vx - target->center.vx;
    int dz = GM_PlayerPosition.vz - target->center.vz;
    int distance = (int)sqrt((double)dx * dx + (double)dz * dz);
    if (!distance) {
        dz = 1;
        distance = 1;
    }
    int separation = target->center.vy - GM_PlayerPosition.vy + 1000;
    if (separation < 8000)
        separation = 8000;
    int retreat = separation - distance;
    int side = dx >= 0 ? 1 : -1;
    dodge_x = GM_PlayerPosition.vx + (dx * retreat - dz * side * 3000) / distance;
    dodge_z = GM_PlayerPosition.vz + (dz * retreat + dx * side * 3000) / distance;
    dodge_ticks = 36;
    dodge_tick = GV_Time;
    dodge_previous = GM_PlayerPosition;
    dodge_distance = 0;
    printf("[rex] Evading toward (%d,%d); weakpoint distance=%d.\n",
           dodge_x, dodge_z, distance);
}

static const TARGET *ActiveTarget(const RexWork *rex)
{
    int combat_state = last_phase == 1 ? 1 : last_phase == 5 ? 3 : -1;
    const TARGET *target = last_phase == 1 ? rex->weakpoint_radar : rex->weakpoint_mouth;
    if (rex->field_196C != combat_state || !target ||
        !(target->class & (TARGET_AVAIL | TARGET_POWER | TARGET_SEEK)) ||
        !(target->center.vx || target->center.vy || target->center.vz))
        return NULL;
    return target;
}

static void ObserveDisruption(const RexWork *rex)
{
    const TARGET *target = ActiveTarget(rex);
    int active = target && rex->field_1988 > 0;
    if (disruption_phase != last_phase) {
        disruption_active = 0;
        disruption_phase = last_phase;
    }
    if (active && !disruption_active) {
        printf("[rex] %s disrupted targeting; frozen aim=(%d,%d,%d) counter=%d.\n",
               last_phase == 1 ? "Chaff" : "Stun", rex->aim_position.vx,
               rex->aim_position.vy, rex->aim_position.vz, rex->field_1988);
        BeginEvasion(target);
    }
    disruption_active = active;
}

static void ObserveHealth(const RexWork *rex, int phase)
{
    int mouth = phase == 5;
    if (phase != 1 && !mouth)
        return;
    int health = mouth ? rex->field_5C4 : rex->field_5BC;
    int *initial = mouth ? &mouth_initial : &radar_initial;
    int *previous = mouth ? &mouth_last : &radar_last;
    int *damage = mouth ? &mouth_damage : &radar_damage;
    if (!*initial && health > 0) {
        *initial = *previous = health;
        if (health != 1800) {
            failed = 1;
            printf("[rex] FAIL unexpected initial %s HP=%d; Normal fixture requires 1800.\n",
                   mouth ? "cockpit" : "radar", health);
        }
    }
    if (*initial && health < *previous) {
        *damage += *previous - (health > 0 ? health : 0);
        printf("[rex] %s damage: HP=%d previous=%d total=%d tick=%d.\n",
               mouth ? "cockpit" : "radar", health, *previous, *damage, GV_Time);
        *previous = health;
        const TARGET *target = mouth ? rex->weakpoint_mouth : rex->weakpoint_radar;
        if (health > 0 && mouth && target)
            BeginEvasion(target);
    }
    if (*initial && health <= 0) {
        if (mouth)
            mouth_defeated = 1;
        else
            radar_defeated = 1;
    }
}

static void ObservePhase(int phase)
{
    if (phase >= 1 && phase <= 5)
        phases |= 1 << phase;
    if (phase != last_phase) {
        printf("[rex] Original scenario phase=%d story=%d tick=%d.\n",
               phase, ScriptWord(0xa), GV_Time);
        last_phase = phase;
        dodge_ticks = 0;
        shot_frame = next_shot_frame = 0;
    }
    if (last_ammo >= 0 && GM_StingerFlag < last_ammo && GM_StingerFlag >= 0) {
        shots += last_ammo - GM_StingerFlag;
        printf("[rex] Player missile consumed; ammo=%d total shots=%d.\n", GM_StingerFlag, shots);
    }
    last_ammo = GM_StingerFlag;
}

static int ValidateEntry(int phase)
{
    started = 1;
    failed = ScriptWord(0xa) != 255 || phase != 1 || GM_GameLevel != GM_LEVEL_NORMAL ||
             GM_VitalityMax != 768 || GM_StingerMax != 35 || GM_RationMax != 5 ||
             GM_StingerFlag < 1 || GM_StingerFlag > 35 || GM_RationFlag < 0 ||
             GM_RationFlag > 5 || GM_StealthFlag > 0 || GM_BandanaFlag > 0 ||
             GM_ChaffGrenadeFlag > 27 ||
             (GM_ChaffGrenadeFlag > 0 && GM_ChaffGrenadeMax != 27) ||
             GM_StunGrenadeFlag > 9 ||
             (GM_StunGrenadeFlag > 0 && GM_StunGrenadeMax != 27);
    printf("[rex] %s incoming fixture: life=%d/%d Stinger=%d/%d rations=%d/%d difficulty=%d.\n",
           failed ? "FAIL" : "Accepted", GM_Vitality, GM_VitalityMax, GM_StingerFlag,
           GM_StingerMax, GM_RationFlag, GM_RationMax, GM_GameLevel);
    printf("[rex] Incoming finite Chaff=%d/%d Stun=%d/%d Body Armor=%d.\n",
           GM_ChaffGrenadeFlag, GM_ChaffGrenadeMax, GM_StunGrenadeFlag,
           GM_StunGrenadeMax, GM_BodyArmorFlag);
    return !failed;
}

static unsigned short SelectInventory(unsigned frame, int item, int wanted)
{
    const Menu_Inventory *menu = item ? &Work.field_1DC_menu_item : &Work.field_1F0_menu_weapon;
    int open = item ? MENU_LEFT_OPEN : MENU_RIGHT_OPEN;
    unsigned short trigger = item ? PAD_L2 : PAD_R2;
    const Menu_Item_Unknown *panels = menu->field_C_alloc;
    if (Work.field_2A_state != open || menu->field_10_state != 1 || !panels)
        return trigger;
    int selected = panels->field_0_main.field_4_selected_idx;
    if (selected >= 0 && selected < panels->field_0_main.field_0_array_count) {
        const PANEL *panel = &panels->field_20_array[selected];
        if (panel->field_0_id == wanted && panel->field_4_pos == 0 &&
            panels->field_0_main.field_10 == 0)
            return 0;
    }
    return trigger | (frame % 24 < 6 ? PAD_RIGHT : 0);
}

static unsigned short AimAt(const TARGET *target, int *in_range)
{
    int dx = target->center.vx - GM_SnakeCamera.position.vx;
    int dy = target->center.vy - GM_SnakeCamera.position.vy;
    int dz = target->center.vz - GM_SnakeCamera.position.vz;
    int distance = (int)sqrt((double)dx * dx + (double)dz * dz);
    int yaw = ratan2(dx, dz);
    int pitch = ratan2(-dy, distance);
    *in_range = pitch >= -512 && pitch <= 512;
    int yaw_error = ((yaw - GM_PlayerControl->turn.vy + 2048) & 4095) - 2048;
    int pitch_error = ((pitch - GM_PlayerControl->turn.vx + 2048) & 4095) - 2048;
    unsigned short buttons = 0;
    if (yaw_error > 24)
        buttons |= PAD_LEFT;
    else if (yaw_error < -24)
        buttons |= PAD_RIGHT;
    if (pitch_error > 24)
        buttons |= PAD_DOWN;
    else if (pitch_error < -24)
        buttons |= PAD_UP;
    if (GM_Configuration & GM_CONFIG_SHUKAN_REVERSE) {
        unsigned short vertical = buttons & (PAD_UP | PAD_DOWN);
        buttons &= ~(PAD_UP | PAD_DOWN);
        if (vertical & PAD_UP)
            buttons |= PAD_DOWN;
        if (vertical & PAD_DOWN)
            buttons |= PAD_UP;
    }
    return buttons;
}

static unsigned short DodgeInput(unsigned frame, int *heading)
{
    if (Work.field_2A_state != MENU_CLOSED || GV_PauseLevel)
        return 0;
    if (GM_Weapon != WP_None)
        return frame % 6 < 2 ? PAD_R1 : 0;
    if (!sna_800ABBA0 || sna_800ABBA0->field_91C_weapon_idx != WP_None ||
        (GM_PlayerStatus & (PLAYER_PAD_OFF | PLAYER_DAMAGED | PLAYER_GROUND)))
        return 0;
    if (GV_Time != dodge_tick) {
        dodge_distance += abs(GM_PlayerPosition.vx - dodge_previous.vx) +
                          abs(GM_PlayerPosition.vz - dodge_previous.vz);
        dodge_previous = GM_PlayerPosition;
        dodge_tick = GV_Time;
        --dodge_ticks;
    }
    if (!dodge_ticks) {
        printf("[rex] Evasion moved %d horizontal units; re-equipping Stinger.\n", dodge_distance);
        return 0;
    }
    *heading = ratan2(dodge_x - GM_PlayerPosition.vx, dodge_z - GM_PlayerPosition.vz) & 4095;
    return 0;
}

static void AdvanceGrenadeWait(GrenadeInputState *grenade)
{
    if (GV_Time == grenade->wait_tick)
        return;
    grenade->wait_tick = GV_Time;
    if (grenade->wait_ticks > 0 && !GV_PauseLevel &&
        !(GM_GameStatus & (STATE_PADRELEASE | STATE_PADDEMO | STATE_DEMO)) &&
        !(GM_PlayerStatus & PLAYER_PAD_OFF))
        --grenade->wait_ticks;
}

static int GrenadeInput(unsigned frame, int weapon, int active, GrenadeInputState *grenade)
{
    int ammo = GM_Weapons[weapon];
    if (grenade->press_frame && ammo < grenade->ammo) {
        printf("[rex] Player %s thrown; remaining=%d.\n",
               weapon == WP_ChaffGrenade ? "Chaff" : "Stun", ammo);
        grenade->press_frame = 0;
        grenade->wait_ticks = 180;
        grenade->wait_tick = GV_Time;
    }
    if (active) {
        grenade->wait_ticks = 0;
        return -1;
    }
    if (ammo <= 0 || grenade->wait_ticks > 0)
        return -1;
    if (GM_Weapon != weapon)
        return SelectInventory(frame, 0, weapon);
    if (Work.field_2A_state != MENU_CLOSED || GV_PauseLevel ||
        sna_800ABBA0->field_91C_weapon_idx != weapon ||
        (GM_PlayerStatus & (PLAYER_PAD_OFF | PLAYER_DAMAGED | PLAYER_GROUND)))
        return 0;
    if (!grenade->press_frame || frame - grenade->press_frame > 90) {
        grenade->press_frame = frame;
        grenade->ammo = ammo;
    }
    return frame - grenade->press_frame < 6 ? PAD_SQUARE : 0;
}

static int DisruptionInput(unsigned frame, const RexWork *rex)
{
    if (!ActiveTarget(rex))
        return -1;
    return GrenadeInput(frame, WP_ChaffGrenade, GM_GameStatus & STATE_CHAFF, &chaff);
}

static unsigned short CombatInput(unsigned frame, const RexWork *rex, int *heading)
{
    if (!(GM_PlayerStatus & (PLAYER_PAD_OFF | PLAYER_DAMAGED)) &&
        (GM_PlayerStatus & PLAYER_DOWNED))
        return frame % 8 < 2 ? PAD_CROSS : 0;
    if (GM_BodyArmorFlag > 0 && GM_RationFlag > 0 && GM_Vitality <= GM_VitalityMax - 256) {
        unsigned short buttons = SelectInventory(frame, 1, IT_Ration);
        return buttons ? buttons : PAD_L2 | (frame % 8 < 2 ? PAD_CIRCLE : 0);
    }
    int item = GM_BodyArmorFlag > 0 ? IT_BodyArmor : IT_Ration;
    if ((item == IT_BodyArmor || GM_RationFlag > 0) &&
        (GM_Item != item || Work.field_2A_state == MENU_LEFT_OPEN))
        return SelectInventory(frame, 1, item);
    if (dodge_ticks)
        return DodgeInput(frame, heading);
    int grenade_buttons = DisruptionInput(frame, rex);
    if (grenade_buttons >= 0)
        return (unsigned short)grenade_buttons;
    if (GM_Weapon != WP_Stinger) {
        if (GM_Weapon == WP_None && Work.field_1F0_menu_weapon.field_11 == WP_Stinger &&
            Work.field_2A_state == MENU_CLOSED)
            return frame % 6 < 2 ? PAD_R1 : 0;
        return SelectInventory(frame, 0, WP_Stinger);
    }
    if (Work.field_2A_state != MENU_CLOSED || GV_PauseLevel ||
        (GM_PlayerStatus & (PLAYER_PAD_OFF | PLAYER_DAMAGED | PLAYER_GROUND)))
        return 0;
    const TARGET *target = ActiveTarget(rex);
    if (!target || GM_StingerFlag <= 0)
        return 0;
    int in_range;
    unsigned short buttons = AimAt(target, &in_range);
    if (!in_range) {
        BeginEvasion(target);
        return DodgeInput(frame, heading);
    }
    if (shot_frame) {
        if (frame - shot_frame < 4)
            return buttons | PAD_SQUARE;
        shot_frame = 0;
        next_shot_frame = frame + 65;
        return buttons;
    }
    if (frame >= next_shot_frame && target_800BDF00 == target &&
        (target->class & TARGET_POWER) && !amissile_alive_8009F490) {
        shot_frame = frame;
        return buttons | PAD_SQUARE;
    }
    return buttons;
}

static void ReportCombat(unsigned frame, const RexWork *rex)
{
    if (frame % 300 != 0)
        return;
    const TARGET *target = rex->weakpoint_radar ? rex->weakpoint_radar : rex->weakpoint_mouth;
    printf("[rex] state=%d attack=%d life=%d ration=%d weapon=%d item=%d ammo=%d "
           "player=(%d,%d,%d) aim=(%d,%d) target=(%d,%d,%d) class=%x lock=%d missile=%d.\n",
           rex->field_196C, rex->field_6FC, GM_Vitality, GM_RationFlag, GM_Weapon, GM_Item,
           GM_StingerFlag, GM_PlayerPosition.vx, GM_PlayerPosition.vy, GM_PlayerPosition.vz,
           GM_PlayerControl->turn.vx, GM_PlayerControl->turn.vy,
           target ? target->center.vx : 0, target ? target->center.vy : 0,
           target ? target->center.vz : 0, target ? target->class : 0,
           target && target == target_800BDF00, amissile_alive_8009F490);
}

static void ObserveDeparture(const char *stage)
{
    if (started && (!strcmp(stage, "d18a") || !strcmp(stage, "d18ar"))) {
        int story = ScriptWord(0xa);
        completed = !failed && radar_defeated && mouth_defeated && phases == 0x3e &&
                    radar_damage >= 1800 && mouth_damage >= 1800 && shots >= 2 &&
                    (story == 258 || story == 259);
        printf("[rex] %s authored %s transition: radar=%d cockpit=%d phases=%x story=%d.\n",
               completed ? "PASS" : "FAIL", stage, radar_damage, mouth_damage, phases,
               story);
        if (!completed)
            failed = 1;
    }
}

unsigned short MgsRexProbeInput(unsigned frame, int *heading)
{
    *heading = -1;
    if (completed || failed || GM_LoadComplete <= 0 || GM_LoadRequest != 0)
        return 0;
    AdvanceGrenadeWait(&chaff);
    const char *stage = GM_GetArea(0);
    if (strcmp(stage, "s17a") && strcmp(stage, "s17ar")) {
        ObserveDeparture(stage);
        return 0;
    }
    int phase = ScriptWord(0x40e);
    if (!started && !ValidateEntry(phase))
        return 0;
    ObservePhase(phase);
    if (GM_GameOverTimer || GM_Vitality <= 0 || (GM_PlayerStatus & PLAYER_GAME_OVER)) {
        failed = 1;
        puts("[rex] FAIL player died; automatic retry is disabled.");
        return 0;
    }
    if (Work.field_2A_state == MENU_CODEC_OPEN)
        return frame % 24 < 8 ? PAD_CROSS : 0;
    if (GM_GameStatus & STATE_DEMO)
        return frame % 60 < 8 ? PAD_START : 0;
    const RexWork *rex = FindRex();
    if (!rex)
        return 0;
    if (GV_Time != last_tick) {
        ObserveHealth(rex, phase);
        ObserveDisruption(rex);
        last_tick = GV_Time;
    }
    ReportCombat(frame, rex);
    return failed ? 0 : CombatInput(frame, rex, heading);
}

int MgsRexProbeFinish(void)
{
    printf("[rex] %s complete encounter: radar damage=%d cockpit damage=%d shots=%d "
           "phase mask=%x departure=%d.\n", completed && !failed ? "PASS" : "FAIL",
           radar_damage, mouth_damage, shots, phases, completed);
    return completed && !failed;
}
