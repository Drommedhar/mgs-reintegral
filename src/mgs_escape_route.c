#include "mgs_native.h"
#include "game/game.h"
#include "overlays/s19b/jeep_vehicles.h"
#include "overlays/s19b/takabe/jeep_srl_native.h"
#include "mgs_escape_route.h"

extern const SVECTOR s19b_dword_800C3A48;
void EscapeState_800D32C4(EscapeJeepWork *work);

typedef struct EscapeRouteProbe
{
    int active, seen, completed, failed;
    int aim, aim_velocity, aim_tick, aim_seen, locked;
    int target_slot, target_heading, aim_error;
    int sequence, gate_turning, gates_passed, rival_seen, finale_seen;
    int previous_tick, previous_life, initial_kills;
    unsigned shots, events_seen, damage_releases, last_release;
} EscapeRouteProbe;

static EscapeRouteProbe route;

static int AngleDifference(int target, int current)
{
    return ((target - current + 2048) & 4095) - 2048;
}

void MgsEscapeRouteInit(void)
{
    memset(&route, 0, sizeof(route));
    route.active = 1;
    route.target_slot = route.sequence = -1;
    puts("[escape-route] Read-only encounter observations; aiming and firing use SDL controller input.");
}

void MgsEscapeRouteAim(int yaw, int locked)
{
    if (!route.active)
        return;
    route.aim_velocity = route.aim_seen ? AngleDifference(yaw, route.aim) : 0;
    route.aim = yaw;
    route.aim_seen = 1;
    route.aim_tick = GV_Time;
    route.locked = locked;
}

void MgsEscapeRouteShot(void)
{
    if (route.active)
        ++route.shots;
}

static SVECTOR GunOrigin(const EscapeJeepWork *jeep)
{
    const MATRIX *world = &jeep->field_A8.objs->world;
    const SVECTOR *mount = &s19b_dword_800C3A48;
    SVECTOR origin = {0};
    origin.vx = world->t[0] + (world->m[0][0] * mount->vx +
        world->m[0][1] * mount->vy + world->m[0][2] * mount->vz) / 4096;
    origin.vy = world->t[1] + (world->m[1][0] * mount->vx +
        world->m[1][1] * mount->vy + world->m[1][2] * mount->vz) / 4096;
    origin.vz = world->t[2] + (world->m[2][0] * mount->vx +
        world->m[2][1] * mount->vy + world->m[2][2] * mount->vz) / 4096;
    return origin;
}

static int TargetDistance(const TARGET *target, const SVECTOR *origin)
{
    if (target->side != ENEMY_SIDE || target->faint <= 0 || target->vital <= 0 ||
        target->class == TARGET_STALE ||
        !(target->map & GM_PlayerControl->map->index))
        return -1;
    return abs(target->center.vx - origin->vx) + abs(target->center.vz - origin->vz);
}

static const TARGET *ChooseTarget(const SVECTOR *origin)
{
    TARGET *targets;
    int count, selected = -1, best = 12000;
    GM_GetTargets(&count, &targets);
    for (int i = 0; i < count; ++i)
    {
        int distance = TargetDistance(&targets[i], origin);
        if (distance < 0)
            continue;
        if (i == route.target_slot)
            distance -= 1500;
        if (distance < best)
        {
            selected = i;
            best = distance;
        }
    }
    if (selected != route.target_slot)
        printf("[escape-route] Target slot=%d tick=%d.\n", selected, GV_Time);
    route.target_slot = selected;
    return selected < 0 ? NULL : &targets[selected];
}

static void ObserveEncounter(const EscapeJeepWork *jeep, const struct EscapeRoadWork *road)
{
    int sequence = (int)(road->sequence - EscapeRoadSequence[0]) / 8;
    int gate_turning = jeep->state == EscapeState_800D32C4;
    unsigned release = Takabe_JeepSystem.field_44;
    if (sequence != route.sequence)
    {
        printf("[escape-route] Road instruction=%d remaining=%d event=%d tick=%d.\n",
               sequence, road->remaining, Takabe_JeepSystem.field_40, GV_Time);
        route.sequence = sequence;
    }
    if (gate_turning && !route.gate_turning)
    {
        ++route.gates_passed;
        printf("[escape-route] Authored checkpoint departure=%d tick=%d kills=%d.\n",
               route.gates_passed, GV_Time, GM_EnemyKillCount - route.initial_kills);
    }
    route.gate_turning = gate_turning;
    if (Takabe_JeepSystem.field_40 > 0 && Takabe_JeepSystem.field_40 < 32)
        route.events_seen |= 1u << Takabe_JeepSystem.field_40;
    if (Takabe_JeepSystem.field_68 && !route.rival_seen)
    {
        route.rival_seen = 1;
        printf("[escape-route] Rival gunner present tick=%d.\n", GV_Time);
    }
    if (release > route.last_release)
    {
        route.damage_releases += release - route.last_release;
        printf("[escape-route] Original Liquid damage release=%u tick=%d.\n",
               route.damage_releases, GV_Time);
    }
    route.last_release = release;
    if (road->final_timer >= 71 && !route.finale_seen)
    {
        route.finale_seen = 1;
        printf("[escape-route] Authored finale timer=%d callback=%04x tick=%d.\n",
               road->final_timer, road->final_proc, GV_Time);
    }
}

static void ReportEncounter(unsigned frame, const EscapeJeepWork *jeep,
                            const struct EscapeRoadWork *road, const TARGET *target)
{
    if (frame % 300 != 0 && GM_Vitality == route.previous_life)
        return;
    route.previous_life = GM_Vitality;
    printf("[escape-route] frame=%u tick=%d life=%d/%d shots=%u kills=%d "
           "sequence=%d remaining=%d gate=%d speed=%d aim=%d error=%d lock=%d "
           "target=%d hp=%d homing=%d releases=%u finale=%d.\n",
           frame, GV_Time, GM_Vitality, GM_VitalityMax, route.shots,
           GM_EnemyKillCount - route.initial_kills, route.sequence, road->remaining,
           jeep->field_3DC, jeep->field_3D0, route.aim, route.aim_error, route.locked,
           route.target_slot, target ? target->vital : -1, Takabe_JeepSystem.field_5C,
           route.damage_releases, road->final_timer);
}

static int ObserveStage(void)
{
    const char *stage = GM_GetArea(0);
    if (GM_LoadComplete <= 0 || GM_LoadRequest != 0)
        return 0;
    if (!strcmp(stage, "s19b") || !strcmp(stage, "s19br"))
    {
        if (!route.seen)
        {
            route.seen = 1;
            route.initial_kills = GM_EnemyKillCount;
            route.previous_life = GM_Vitality;
            printf("[escape-route] Incoming stage=%s life=%d/%d rations=%d item=%d level=%d.\n",
                   stage, GM_Vitality, GM_VitalityMax, GM_RationFlag, GM_Item, GM_GameLevel);
        }
        return 1;
    }
    if (route.seen && !route.completed && !route.failed)
    {
        route.completed = route.gates_passed == 2 && route.rival_seen && route.finale_seen &&
            (!strcmp(stage, "s20a") || !strcmp(stage, "s20ar"));
        route.failed = !route.completed;
        printf("[escape-route] %s authored loaded-stage handoff=%s gates=%d rival=%d finale=%d.\n",
               route.completed ? "PASS" : "FAIL", stage, route.gates_passed,
               route.rival_seen, route.finale_seen);
    }
    return 0;
}

unsigned short MgsEscapeRouteInput(unsigned frame, int *direction)
{
    const EscapeJeepWork *jeep;
    const struct EscapeRoadWork *road;
    const TARGET *target;
    SVECTOR origin;
    *direction = -1;
    if (!route.active || route.completed || route.failed || !ObserveStage())
        return 0;
    if (GM_Vitality <= 0 || GM_GameOverTimer != 0)
    {
        route.failed = 1;
        printf("[escape-route] FAIL player died at tick=%d sequence=%d gates=%d.\n",
               GV_Time, route.sequence, route.gates_passed);
        return 0;
    }
    jeep = s19b_dword_800DE64C;
    road = s19b_dword_800DE5B0;
    if (!jeep || !road || !GM_PlayerControl || !jeep->field_A8.objs ||
        Takabe_JeepSystem.control != &jeep->control || !route.aim_seen)
        return 0;
    if (GV_Time != route.previous_tick)
    {
        ObserveEncounter(jeep, road);
        route.previous_tick = GV_Time;
    }
    origin = GunOrigin(jeep);
    target = ChooseTarget(&origin);
    if (target)
    {
        route.target_heading = ratan2(target->center.vx - origin.vx,
                                     target->center.vz - origin.vz) & 4095;
        route.aim_error = AngleDifference(route.target_heading,
            route.aim + jeep->control.rot.vy + route.aim_velocity * 3);
    }
    ReportEncounter(frame, jeep, road, target);
    if (GV_PauseLevel || route.locked || GV_Time - route.aim_tick > 2 ||
        (GM_GameStatus & (STATE_PADRELEASE | STATE_PADMASK | STATE_PADDEMO | STATE_DEMO)))
        return 0;
    if (target)
    {
        if (route.aim_error > 24)
            *direction = 3;
        else if (route.aim_error < -24)
            *direction = 1;
        return PAD_SQUARE;
    }
    return 0;
}

int MgsEscapeRouteFinish(void)
{
    printf("[escape-route] %s gates=%d rival=%d releases=%u finale=%d shots=%u "
           "events=%08x sequence=%d stage=%s.\n",
           route.completed ? "PASS complete" : "FAIL incomplete", route.gates_passed,
           route.rival_seen, route.damage_releases, route.finale_seen, route.shots,
           route.events_seen, route.sequence, GM_GetArea(0));
    return route.completed && !route.failed;
}
