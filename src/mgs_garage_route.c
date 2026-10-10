#include "mgs_native.h"
#include "mgs_garage_route.h"
#include "mgs_bonus_items.h"
#include "chara/snake/sna_init.h"
#include "overlays/s19a/guard/native.h"
#include "overlays/s19a/props_native.h"
#include "overlays/s19b/jeep_vehicles.h"
#include "overlays/s19b/takabe/jeep_srl_native.h"

extern SnaInitWork *sna_800ABBA0;

typedef struct {
    short x, z, radius;
} GarageWaypoint;

/* Centers follow cb81.h corridor/ramp zones, then the second boarding trigger. */
static const GarageWaypoint waypoints[] = {
    {14750, -3250, 500}, {13250, -3250, 500}, {11750, -3750, 400},
    {10625, -3750, 225}, {9875, -3750, 225}, {8750, -3750, 450},
    {7250, -3250, 450}, {6250, -3250, 200}, {5500, -3250, 350},
    {4250, -3250, 450}, {2250, -3250, 500}, {2000, -1500, 450},
    {0, -750, 450}, {-2250, -750, 450}, {-4250, -750, 450},
    {-5750, -750, 400}, {-5750, 1000, 300}, {-5750, 1800, 150}
};

typedef struct {
    const GarageJeep *jeep;
    const GarageGate *gate;
    const GarageDrum *drums[2];
    const GarageSnake *gunner;
    int guards;
} GarageActors;

typedef struct {
    const GV_ACT *head;
    const GarageDrum *drum_ids[2];
    int active, started, valid, failed, arrived, alternate;
    int phase, phases, ignition, guards, mounted, broken, driving;
    int drum_health[2], drum_damage, explosions, fire_pulses;
    int last_tick, moving_ticks, distance, last_heading, target_index;
    int aim, previous_aim, aim_velocity, aim_error;
    unsigned waypoint;
    SVECTOR previous_position;
} GarageRoute;

static GarageRoute route;

static int ScriptWord(unsigned offset)
{
    char token[4] = {0x11, 0, (char)(offset >> 8), (char)offset};
    int type, value;
    GCL_GetVar(token, &type, &value);
    return value;
}

static int AngleDifference(int target, int current)
{
    return ((target - current + 2048) & 4095) - 2048;
}

void MgsGarageRouteInit(void)
{
    memset(&route, 0, sizeof(route));
    route.active = 1;
    route.phase = route.last_tick = route.last_heading = route.target_index = -1;
    route.drum_health[0] = route.drum_health[1] = -1;
    puts("[garage-route] Authored hazard waypoints; movement, boarding and firing use SDL input.");
}

static GarageActors FindActors(void)
{
    GarageActors found = {0};
    if (!route.head && sna_800ABBA0 && GM_PlayerControl == &sna_800ABBA0->control) {
        route.head = &sna_800ABBA0->actor;
        while (route.head->prev)
            route.head = route.head->prev;
    }
    int drum = 0;
    for (const GV_ACT *actor = route.head; actor; actor = actor->next) {
        if (actor->act == (GV_ACTFUNC)Garage_800D8E8C)
            found.jeep = (const GarageJeep *)actor;
        else if (actor->act == (GV_ACTFUNC)Garage_800DC18C)
            found.gate = (const GarageGate *)actor;
        else if (actor->act == (GV_ACTFUNC)Garage_800D7E50) {
            if (!route.started && drum < 2)
                found.drums[drum++] = (const GarageDrum *)actor;
            else
                for (int i = 0; i < 2; ++i)
                    if (actor == (const GV_ACT *)route.drum_ids[i])
                        found.drums[i] = (const GarageDrum *)actor;
        }
    }
    for (unsigned i = 0; i < sizeof(S19_Command.watchers) / sizeof(S19_Command.watchers[0]); ++i) {
        const S19Work *guard = S19_Command.watchers[i].work;
        if (guard && guard->actor.act == (GV_ACTFUNC)s19a_800CD048)
            ++found.guards;
    }
    if (found.jeep && found.jeep->companion &&
        found.jeep->companion->act == (GV_ACTFUNC)Garage_800DA004)
        found.gunner = (const GarageSnake *)found.jeep->companion;
    return found;
}

static void Begin(unsigned frame, const GarageActors *actors)
{
    route.started = 1;
    route.alternate = strcmp(GM_GetArea(0), "s19ar") == 0;
    route.valid = ScriptWord(0xA) == 283 && ScriptWord(0x1EA) == 0 &&
        GM_GameLevel == GM_LEVEL_NORMAL && GM_VitalityMax == 768 &&
        !MgsBonusItemsEnabled() && GM_StealthFlag < 0 && GM_BandanaFlag < 0 &&
        actors->jeep->phase == 0 && !actors->gate->broken;
    route.previous_position = GM_PlayerPosition;
    route.drum_ids[0] = actors->drums[0];
    route.drum_ids[1] = actors->drums[1];
    printf("[garage-route] Entry frame=%u valid=%d story=%d stage=%s level=%d "
           "life=%d/%d weapon=%d item=%d rations=%d countdown=%d.\n",
           frame, route.valid, ScriptWord(0xA), GM_GetArea(0), GM_GameLevel,
           GM_Vitality, GM_VitalityMax, GM_Weapon, GM_Item, GM_RationFlag, ScriptWord(0x1EC));
    if (!route.valid)
        route.failed = 1;
}

static void ObserveDrums(const GarageActors *actors)
{
    for (int i = 0; i < 2; ++i) {
        const GarageDrum *drum = actors->drums[i];
        if (!drum)
            continue;
        int health = drum->target->vital;
        if (route.drum_health[i] >= 0 && health < route.drum_health[i]) {
            route.drum_damage += route.drum_health[i] - health;
            printf("[garage-route] Drum%d damage %d->%d tick=%d.\n",
                   i, route.drum_health[i], health, GV_Time);
        }
        route.drum_health[i] = health;
        if (drum->exploded && !(route.explosions & (1 << i))) {
            route.explosions |= 1 << i;
            printf("[garage-route] Original drum%d explosion tick=%d phase=%d.\n",
                   i, GV_Time, drum->phase);
        }
    }
}

static void Observe(unsigned frame, const GarageActors *actors)
{
    int phase = ScriptWord(0x1EA);
    if (phase != route.phase) {
        printf("[garage-route] Original scenario phase=%d previous=%d jeep=%d tick=%d.\n",
               phase, route.phase, actors->jeep->phase, GV_Time);
        if (phase < 0 || phase > 4 || (route.phase >= 0 && phase != route.phase + 1))
            route.failed = 1;
        else
            route.phases |= 1 << phase;
        route.phase = phase;
    }
    route.ignition |= GarageIgnition == 1;
    route.guards |= actors->guards > 0 && S19Activated;
    route.mounted |= actors->gunner && GM_PlayerControl == &actors->gunner->control;
    route.broken |= actors->gate && actors->gate->broken;
    route.driving |= actors->jeep->phase >= 4 && actors->jeep->control.mov.vz < -5500;
    if (GV_Time != route.last_tick) {
        int moved = abs(GM_PlayerPosition.vx - route.previous_position.vx) +
                    abs(GM_PlayerPosition.vz - route.previous_position.vz);
        if (route.last_heading >= 0 && !route.mounted && moved > 0) {
            route.distance += moved;
            ++route.moving_ticks;
        }
        if (actors->gunner) {
            route.aim = actors->gunner->aim.vy;
            route.aim_velocity = AngleDifference(route.aim, route.previous_aim);
            route.previous_aim = route.aim;
            if ((actors->gunner->field_92C & 1) && (GV_PadData[0].status & PAD_SQUARE))
                ++route.fire_pulses;
        }
        ObserveDrums(actors);
        route.previous_position = GM_PlayerPosition;
        route.last_tick = GV_Time;
    }
    if (frame % 300 == 0)
        printf("[garage-route] frame=%u tick=%d waypoint=%u phase=%d jeep=%d ignition=%d "
               "position=(%d,%d,%d) life=%d guards=%d mounted=%d gate=%d fire_pulses=%d "
               "target=%d aim=%d error=%d status=%x pause=%x game=%x.\n",
               frame, GV_Time, route.waypoint, phase, actors->jeep->phase, GarageIgnition,
               GM_PlayerPosition.vx, GM_PlayerPosition.vy, GM_PlayerPosition.vz,
               GM_Vitality, actors->guards, route.mounted, route.broken, route.fire_pulses,
               route.target_index, route.aim, route.aim_error, GM_PlayerStatus,
               GV_PauseLevel, GM_GameStatus);
}

static int ObserveStage(unsigned frame)
{
    const char *stage = GM_GetArea(0);
    if (GM_LoadComplete <= 0 || GM_LoadRequest != 0)
        return 0;
    if (!strcmp(stage, "s19a") || !strcmp(stage, "s19ar"))
        return 1;
    if (route.started) {
        route.head = NULL;
        if (strcmp(stage, route.alternate ? "s19br" : "s19b")) {
            route.failed = 1;
            printf("[garage-route] FAIL unexpected stage=%s.\n", stage);
        } else if (s19b_dword_800DE64C && s19b_dword_800DE5B0 && GM_PlayerControl &&
                   Takabe_JeepSystem.control == &s19b_dword_800DE64C->control) {
            route.arrived = 1;
            printf("[garage-route] Authored arrival frame=%u stage=%s story=%d "
                   "countdown=%d life=%d; escape jeep, road and player are live.\n",
                   frame, stage, ScriptWord(0xA), ScriptWord(0x1EC), GM_Vitality);
        }
    }
    return 0;
}

static unsigned short Walk(int *heading)
{
    unsigned count = sizeof(waypoints) / sizeof(waypoints[0]);
    if (route.waypoint >= count || (route.waypoint == count - 1 && route.phase < 2))
        return 0;
    const GarageWaypoint *target = &waypoints[route.waypoint];
    int dx = target->x - GM_PlayerPosition.vx;
    int dz = target->z - GM_PlayerPosition.vz;
    if (abs(dx) + abs(dz) <= target->radius) {
        printf("[garage-route] Reached hazard waypoint=%u at(%d,%d,%d) tick=%d.\n",
               route.waypoint, GM_PlayerPosition.vx, GM_PlayerPosition.vy,
               GM_PlayerPosition.vz, GV_Time);
        ++route.waypoint;
    } else {
        *heading = ratan2(dx, dz) & 4095;
        route.last_heading = *heading;
    }
    return 0;
}

static int ClearAimObstruction(const MATRIX *gun, const TARGET *drum, int desired)
{
    int dx = drum->center.vx - gun->t[0];
    int dy = drum->center.vy - gun->t[1];
    int dz = drum->center.vz - gun->t[2];
    long long nearest = (long long)dx * dx + (long long)dy * dy + (long long)dz * dz;
    int direction = desired;
    for (unsigned i = 0; i < sizeof(S19_Command.watchers) / sizeof(S19_Command.watchers[0]); ++i) {
        const S19Work *guard = S19_Command.watchers[i].work;
        if (!guard || guard->actor.act != (GV_ACTFUNC)s19a_800CD048 ||
            !guard->target || guard->target->vital <= 0 || !guard->hom ||
            !guard->hom->used || guard->hom->flag != 1 ||
            !(guard->control.map->index & drum->map))
            continue;
        const MATRIX *head = guard->hom->world;
        dx = head->t[0] - gun->t[0];
        dy = head->t[1] - gun->t[1];
        dz = head->t[2] - gun->t[2];
        long long distance = (long long)dx * dx + (long long)dy * dy + (long long)dz * dz;
        int angle = ratan2(dx, dz);
        if (distance < nearest && distance < 6000LL * 6000 &&
            abs(AngleDifference(angle, desired)) < 128) {
            nearest = distance;
            direction = angle;
            route.target_index = 2 + (int)i;
        }
    }
    return direction;
}

static unsigned short Shoot(const GarageActors *actors)
{
    if (route.phase != 3 || route.broken)
        return 0;
    const GarageDrum *target = NULL;
    int best = 20000;
    const MATRIX *gun = &actors->gunner->field_8E4;
    for (int i = 0; i < 2; ++i) {
        const GarageDrum *drum = actors->drums[i];
        if (!drum || drum->exploded || drum->phase || drum->target->vital < 0)
            continue;
        int distance = abs(drum->target->center.vx - gun->t[0]) +
                       abs(drum->target->center.vz - gun->t[2]);
        if (distance < best) {
            target = drum;
            best = distance;
            route.target_index = i;
        }
    }
    if (!target)
        return 0;
    int desired = ratan2(target->target->center.vx - gun->t[0],
                        target->target->center.vz - gun->t[2]);
    desired = ClearAimObstruction(gun, target->target, desired);
    route.aim_error = AngleDifference(desired,
        route.aim + actors->jeep->control.rot.vy + route.aim_velocity * 3);
    unsigned short buttons = PAD_SQUARE;
    if (route.aim_error > 24)
        buttons |= PAD_LEFT;
    else if (route.aim_error < -24)
        buttons |= PAD_RIGHT;
    return buttons;
}

static int MountedReady(const GarageSnake *gunner)
{
    return GM_PlayerControl == &gunner->control && !gunner->field_950 &&
        !gunner->field_940 && !GV_PauseLevel &&
        !(GM_GameStatus & (STATE_PADRELEASE | STATE_PADMASK | STATE_PADDEMO | STATE_DEMO));
}

unsigned short MgsGarageRouteInput(unsigned frame, int player_ready, int *heading)
{
    *heading = -1;
    if (!route.active || route.failed || route.arrived || !ObserveStage(frame))
        return 0;
    GarageActors actors = FindActors();
    if (!actors.jeep)
        return 0;
    if (!route.started) {
        if (!actors.gate || !actors.drums[0] || !actors.drums[1])
            return 0;
        Begin(frame, &actors);
    }
    Observe(frame, &actors);
    route.last_heading = -1;
    if (GM_GameOverTimer || GM_Vitality <= 0) {
        route.failed = 1;
        printf("[garage-route] FAIL player died frame=%u health=%d.\n", frame, GM_Vitality);
    }
    if (route.failed)
        return 0;
    if (actors.gunner)
        return MountedReady(actors.gunner) ? Shoot(&actors) : 0;
    return player_ready ? Walk(heading) : 0;
}

int MgsGarageRouteFinish(void)
{
    int complete = route.valid && !route.failed && route.arrived && route.phases == 31 &&
        route.ignition && route.guards && route.mounted && route.broken && route.driving &&
        route.explosions && route.drum_damage > 0 && route.fire_pulses > 0 &&
        route.moving_ticks >= 30 && route.distance > 10000;
    printf("[garage-route] %s valid=%d phases=%x ignition=%d guards=%d mounted=%d "
           "drum_damage=%d explosions=%x gate=%d driving=%d fire_pulses=%d "
           "moving_ticks=%d distance=%d arrival=%d failed=%d.\n",
           complete ? "PASS" : "FAIL", route.valid, route.phases, route.ignition,
           route.guards, route.mounted, route.drum_damage, route.explosions, route.broken,
           route.driving, route.fire_pulses, route.moving_ticks, route.distance, route.arrived, route.failed);
    return complete;
}
