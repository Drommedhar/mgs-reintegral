#include "mgs_native.h"
#include "game/game.h"
#include "libgcl/libgcl.h"
#include "mgs_probe.h"

typedef struct DockWaypoint {
    short x, z;
    unsigned char crawl;
    const char *name;
} DockWaypoint;

static const DockWaypoint waypoints[] = {
    {-8000, -1300, 0, "west of the starting crates"},
    {-8000, -2100, 0, "southern pipe approach"},
    {-8000, -4500, 1, "crawl beyond the west pipe"},
    {-8000, -8375, 0, "west loading corridor"},
    {500, -8375, 0, "cross into the central aisle"},
    {500, -10500, 0, "follow the southern patrol"},
    {500, -15500, 0, "central aisle"},
    {500, -22500, 0, "north end of the central aisle"},
    {3000, -22500, 0, "east of the noisy puddles"},
    {3000, -26000, 0, "north of the noisy puddles"},
    {1000, -26000, 0, "elevator approach"},
    {1000, -28800, 0, "authored elevator boarding volume"}
};

static unsigned waypoint, stance_cooldown, navigation_pause, travel_ticks, moving_ticks, blocked_ticks;
static int from_title, previous_time, dock_seen, heliport_seen, cinematic_seen;
static int completed, failed, ready_ticks, passing_patrol, previous_alert = -1;
static SVECTOR previous_position;
static char last_stage[16];

void MgsProbeDockRouteInit(int title_start)
{
    from_title = title_start;
    printf("[route] %s; all navigation uses SDL controller input.\n",
           from_title ? "Title New Game opening route" : "Explicit dock development entry");
}

static void ObserveStage(int player_ready)
{
    const char *stage = GM_GetArea(0);
    if (GM_LoadComplete <= 0 || GM_LoadRequest != 0)
        return;
    if (strcmp(stage, last_stage)) {
        snprintf(last_stage, sizeof(last_stage), "%s", stage);
        printf("[route] Loaded stage=%s at game tick=%d.\n", stage, GV_Time);
    }
    if (!strcmp(stage, "s00a"))
        dock_seen = 1;
    if (dock_seen && (!strcmp(stage, "d00a") || !strcmp(stage, "d01a")))
        cinematic_seen = 1;
    if (dock_seen && !strcmp(stage, "s01a")) {
        heliport_seen = 1;
        if (player_ready && GV_Time != previous_time)
            ++ready_ticks;
        if (ready_ticks >= 90 && !completed) {
            completed = 1;
            printf("[route] PASS authored dock-to-heliport transition; heliport controllable for %d ticks.\n",
                   ready_ticks);
        }
    }
}

static void ObserveMotion(void)
{
    int distance;
    if (GV_Time == previous_time)
        return;
    distance = abs(GM_PlayerPosition.vx - previous_position.vx) +
               abs(GM_PlayerPosition.vz - previous_position.vz);
    ++travel_ticks;
    if (distance > 1)
        ++moving_ticks;
    else if (GM_PlayerControl->n_touches > 0 &&
             (GM_PlayerControl->step.vx || GM_PlayerControl->step.vz))
        ++blocked_ticks;
    previous_position = GM_PlayerPosition;
    previous_time = GV_Time;
}

static int HeadingToward(const DockWaypoint *target)
{
    int dx = target->x - GM_PlayerPosition.vx;
    int dz = target->z - GM_PlayerPosition.vz;
    dx = dx < -400 ? -400 : dx > 400 ? 400 : dx;
    dz = dz < -400 ? -400 : dz > 400 ? 400 : dz;
    return ratan2(dx, dz) & 4095;
}

static int SetStance(const DockWaypoint *target, unsigned short *buttons)
{
    int low = (GM_PlayerStatus & (PLAYER_SQUAT | PLAYER_GROUND)) != 0;
    if (stance_cooldown) {
        if (stance_cooldown > 26)
            *buttons = PAD_CROSS;
        --stance_cooldown;
        return 0;
    }
    if (low != target->crawl && !(GM_PlayerStatus & PLAYER_INTRUDE)) {
        *buttons = PAD_CROSS;
        stance_cooldown = 30;
        printf("[route] CROSS requests %s at (%d,%d,%d).\n",
               target->crawl ? "crawl" : "standing", GM_PlayerPosition.vx,
               GM_PlayerPosition.vy, GM_PlayerPosition.vz);
        return 0;
    }
    return 1;
}

static int ScriptByte(unsigned offset)
{
    char token[4] = {0x12, 0, (char)(offset >> 8), (char)offset};
    int type, value;
    GCL_GetVar(token, &type, &value);
    return value & 255;
}

static void ReportProgress(unsigned frame)
{
    if (frame % 300 == 0 || GM_AlertMode != previous_alert) {
        printf("[route] waypoint=%u/%u position=(%d,%d,%d) tick=%d alert=%d life=%d "
               "script2d=%02x script67=%02x script6c=%02x moving=%u contact=%u.\n",
               waypoint, (unsigned)(sizeof(waypoints) / sizeof(waypoints[0])),
               GM_PlayerPosition.vx, GM_PlayerPosition.vy, GM_PlayerPosition.vz,
               GV_Time, GM_AlertMode, GM_Vitality, ScriptByte(0x2d),
               ScriptByte(0x67), ScriptByte(0x6c), moving_ticks, blocked_ticks);
        previous_alert = GM_AlertMode;
        for (int i = 0; i < GM_N_WhereList; ++i) {
            const CONTROL *guard = GM_WhereList[i];
            if (guard->name != 0x1466 && guard->name != 0x1467 && guard->name != 0x13e8)
                continue;
            printf("[route] guard=%04x position=(%d,%d,%d) sight=%d/%d/%d.\n",
                   guard->name, guard->mov.vx, guard->mov.vy, guard->mov.vz,
                   guard->radar_param.dir, guard->radar_param.dis, guard->radar_param.range);
        }
    }
}

static int WaitForPatrol(void)
{
    int crossing = waypoint == 4 && GM_PlayerPosition.vx < -6500;
    int passing = waypoint == 6 && !passing_patrol;
    if (!crossing && !passing)
        return 0;
    for (int i = 0; i < GM_N_WhereList; ++i) {
        const CONTROL *guard = GM_WhereList[i];
        if (guard->name != 0x1467)
            continue;
        if (crossing)
            return guard->mov.vz > -11500;
        passing_patrol = guard->mov.vx >= 5000 && guard->mov.vz <= -12000;
        return !passing_patrol;
    }
    return 1;
}

int MgsProbeDockRouteUpdate(unsigned frame, int player_ready,
                           unsigned short *buttons, int *heading)
{
    const DockWaypoint *target;
    ObserveStage(player_ready);
    if (completed || failed)
        return 1;
    if (dock_seen && (GM_Vitality <= 0 || (GM_PlayerStatus & PLAYER_GAME_OVER))) {
        failed = 1;
        puts("[route] FAIL player died during ordinary navigation.");
        return 1;
    }
    if (!player_ready)
        return 0;
    if (strcmp(GM_GetArea(0), "s00a")) {
        previous_time = GV_Time;
        return 0;
    }
    ObserveMotion();
    ReportProgress(frame);
    if (waypoint == 0 && !(ScriptByte(0x67) & 0x10))
        return 1;
    if (navigation_pause) {
        --navigation_pause;
        return 1;
    }
    if (waypoint == sizeof(waypoints) / sizeof(waypoints[0]))
        return 1;
    if (WaitForPatrol())
        return 1;
    target = &waypoints[waypoint];
    if (abs(target->x - GM_PlayerPosition.vx) < 80 &&
        abs(target->z - GM_PlayerPosition.vz) < 80) {
        printf("[route] Reached waypoint %u: %s at (%d,%d,%d).\n", waypoint,
               target->name, GM_PlayerPosition.vx, GM_PlayerPosition.vy, GM_PlayerPosition.vz);
        ++waypoint;
        navigation_pause = 16;
        return 1;
    }
    if (SetStance(target, buttons))
        *heading = HeadingToward(target);
    return 1;
}

int MgsProbeDockRouteFinish(void)
{
    printf("[route] %s origin=%s waypoints=%u/%u moving=%u ticks=%u collision=%u "
           "dock=%d heliport=%d cinematic=%d controllable_ticks=%d.\n",
           completed ? "PASS" : "FAIL incomplete", from_title ? "title" : "direct dock",
           waypoint, (unsigned)(sizeof(waypoints) / sizeof(waypoints[0])), moving_ticks,
           travel_ticks, blocked_ticks, dock_seen, heliport_seen, cinematic_seen, ready_ticks);
    return completed;
}
