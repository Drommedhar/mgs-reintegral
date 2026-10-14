#include "mgs_native.h"
#include "mgs_radar.h"
#include "../vendor/mgs/source/menu/radar.c"
#include "../vendor/mgs/source/overlays/s19b/menu/countdwn.c"
#include <assert.h>

int GM_GameStatus, GM_PlayerStatus, GM_PlayerMap, GM_AlertMode, GM_AlertLevel;
int GM_N_WhereList, GV_Time, GV_Clock, HZD_CurrentGroup;
CONTROL *GM_WhereList[96];
short linkvarbuf[MAX_LINKVARBUF];
unsigned long psyz_scratchpad[256];
MATRIX DG_ZeroMatrix = {{{4096, 0, 0}, {0, 4096, 0}, {0, 0, 4096}}, {0}};
char gDigit7Segment_8009E60C[] = {0x77, 0x24, 0x5d, 0x6d, 0x2e, 0x6b, 0x7b, 0x25, 0x7f, 0x6f};

static unsigned char primitives[8192];
static OT_TYPE ordering;
static MenuPrim prim;
static MenuWork work;
static CONTROL actors[7];
static HZD_SEG walls[6], door;
static HZD_SEG *doors[] = {&door};
static char flags[12], door_flags[2];
static HZD_GRP group;
static HZD_DEF definition;
static HZD_HDL hazard, dynamic_hazard;
static MAP map, other_map;
static int uploads, sounds, last_sound, callbacks, callback_seconds;
static DG_TEX warning_texture = {.w = 20, .h = 8};
static int owns_drawing;

int LoadImage(RECT *rect, u_long *pixels) { assert(rect && pixels); ++uploads; return 0; }
RPK_ITEM *menu_rpk_get_img_8003DDB4(int index) { (void)index; abort(); }
void DG_SetDefDrawEnv(DRAWENV *env, int x, int y, int w, int h)
{
    memset(env, 0, sizeof(*env));
    env->clip = (RECT){x, y, w, h};
}
void SetDrawEnv(DR_ENV *packet, DRAWENV *env)
{
    (void)env;
    memset(packet, 0, sizeof(*packet));
    setlen(packet, 1);
}
void SetDrawArea(DR_AREA *packet, RECT *rect)
{
    memset(packet, 0, sizeof(*packet));
    setlen(packet, 2);
    packet->code[0] = (unsigned short)rect->x | ((unsigned short)rect->y << 16);
    packet->code[1] = (unsigned short)rect->w | ((unsigned short)rect->h << 16);
}
void SetDrawTPage(DR_TPAGE *packet, int dfe, int dtd, int tpage)
{
    memset(packet, 0, sizeof(*packet));
    setlen(packet, 1);
    packet->code[0] = 0xe1000000 | tpage | (dfe << 10) | (dtd << 9);
}
TILE *menu_render_rect_8003DB2C(MenuPrim *target, int x, int y, int w, int h, int color)
{
    TILE *tile;
    _NEW_PRIM(tile, target);
    setTile(tile); setXY0(tile, x, y); setWH(tile, w, h);
    setRGB0(tile, color & 255, (color >> 8) & 255, (color >> 16) & 255);
    addPrim(target->ot, tile);
    return tile;
}
void GM_SeSet2(int pan, int volume, int sound)
{ assert(pan == 0 && volume == 63); ++sounds; last_sound = sound; }
HZD_HDL *GM_IterHazard(HZD_HDL *previous) { return previous ? NULL : &dynamic_hazard; }
void GV_DirVec2(int dir, int len, SVECTOR *vector)
{ *vector = (SVECTOR){len * rsin(dir) / 4096, 0, len * rcos(dir) / 4096, 0}; }
int GV_DiffDirU(int from, int to) { return (to - from) & 4095; }
void *GV_NewActor(int level, int size) { (void)level; return calloc(1, size); }
void GV_SetNamedActor(void *actor, void *act, void *die, const char *name)
{ GV_ACT *item = actor; item->act = act; item->die = die; item->filename = name; }
DG_TEX *DG_GetTexture(int name) { (void)name; return &warning_texture; }
void GCL_ForceExecProc(int proc, GCL_ARGS *args)
{ assert(proc == 42 && args->argc == 1); ++callbacks; callback_seconds = args->argv[0]; }
char *GCL_GetOption(char option) { (void)option; abort(); }
int GCL_GetNextInt(void) { abort(); }
void sub_8003FD50(MenuPrim *target, int x, int y, int digit, RadioUnknown *style, int flags_value)
{ assert(target == &prim && digit >= 0 && digit <= 9); (void)x; (void)y; (void)style; (void)flags_value; }

static void Begin(int collect)
{
    memset(primitives, 0, sizeof(primitives));
    memset(&ordering, 0, sizeof(ordering));
    prim = (MenuPrim){primitives, (u_long *)&ordering, primitives + sizeof(primitives), {primitives, primitives}};
    uploads = sounds = 0;
    MgsRadarBeginFrame(collect, owns_drawing);
}

static void Setup(void)
{
    memset(&work, 0, sizeof(work));
    memset(actors, 0, sizeof(actors));
    memset(flags, 0, sizeof(flags));
    work.prim = &prim;
    work.radar.display_flag = 1;
    group = (HZD_GRP){.n_walls = 6, .walls = walls, .wallsFlags = flags};
    definition = (HZD_DEF){.n_groups = 1, .groups = &group};
    hazard = (HZD_HDL){.def = &definition};
    dynamic_hazard = (HZD_HDL){.n_d_segs = 1, .max_d_segs = 1, .d_segs = doors, .d_seg_flag = door_flags};
    map = (MAP){.index = 1, .hzd = &hazard};
    other_map = (MAP){.index = 2, .hzd = &hazard};
    for (int i = 0; i < 6; ++i)
        walls[i] = (HZD_SEG){.p1 = {.x = -2000, .z = i * 600, .y = -200, .h = 1000},
                             .p2 = {.x = 2000, .z = i * 600, .y = -200, .h = 1000}};
    walls[1].p1.y = walls[1].p2.y = 7000;
    flags[6 + 2] = 0x80;
    flags[3] = 0x80;
    walls[4].p1.x = 20000; walls[4].p2.x = 22000;
    walls[5].p1.z = walls[5].p2.z = 20000;
    door = (HZD_SEG){.p1 = {.x = -1000, .z = -1000, .h = 1000},
                     .p2 = {.x = 1000, .z = -1000, .h = 1000}};
    for (int i = 0; i < 7; ++i) {
        actors[i].map = &map;
        actors[i].mov.vx = i * 300;
        actors[i].radar_atr = RADAR_VISIBLE;
        actors[i].radar_param = (RADAR_SIGHT_PARAM){1024, 4096, 1024, 0};
        GM_WhereList[i] = &actors[i];
    }
    actors[1].radar_atr |= RADAR_SIGHT;
    actors[2].mov.vy = -3000;
    actors[3].radar_atr |= RADAR_NOISE;
    actors[4].map = &other_map;
    actors[5].radar_atr = 0;
    actors[6].radar_atr |= RADAR_ALL_MAP | RADAR_UNK2 | RADAR_UNK3;
    actors[6].map = &other_map;
    actors[6].mov.vy = 5000;
    GM_N_WhereList = 7; GM_PlayerMap = HZD_CurrentGroup = 1;
    GM_GameStatus = GM_PlayerStatus = GM_Configuration = GV_Clock = 0;
    GM_AlertMode = GM_AlertLevel = GV_Time = 0;
    cons_current_x_800AB4B4 = cons_current_y_800AB4B0 = 0;
    MENU_SetRadarFunc(NULL);
    MENU_SetRadarScale(4096);
    callbacks = callback_seconds = 0;
}

static void MapData(void)
{
    Setup(); Begin(1); GV_Time = 2; GM_PlayerStatus = PLAYER_WATCH;
    actors[0].mov.vx = -1000;
    menu_radar_update_8003B350(&work, (u_long *)&ordering);
    const MgsRadarView *view = MgsRadarGetView();
    assert(view->frame.active && view->frame.map_visible && view->frame.scale == 13);
    assert(view->contact_count == 5 && view->sight_count == 3 && view->wall_count == 4);
    assert(view->contacts[0].kind == MGS_RADAR_PLAYER);
    assert(view->contacts[1].actor_index == 1 && view->contacts[1].position.x == 3);
    assert(view->contacts[2].kind == MGS_RADAR_OTHER_FLOOR);
    assert(view->contacts[3].kind == MGS_RADAR_NOISE);
    assert(view->contacts[4].actor_index == 6 && view->contacts[4].kind == MGS_RADAR_NEAR_CONTACT);
    assert(view->walls[0].points[0].x == -4 && view->walls[0].points[1].x == 9);
    assert(view->walls[0].kind == MGS_RADAR_WALL && !view->walls[0].dynamic);
    assert(view->walls[1].kind == MGS_RADAR_OTHER_FLOOR_WALL);
    assert(view->walls[2].kind == MGS_RADAR_SPECIAL_WALL);
    assert(view->walls[3].dynamic && view->walls[3].points[0].y == -4);
    for (unsigned i = 0; i < 16; ++i) {
        MgsRadarPoint p = view->contacts[3].noise[i];
        assert(p.x >= 3 && p.x <= 6 && p.y >= -2 && p.y <= 1);
    }
    Begin(1); GV_Time = 0;
    menu_radar_update_8003B350(&work, (u_long *)&ordering);
    assert(view->frame.map_visible && !view->contact_count && !view->sight_count && view->wall_count == 4);
    Begin(1); GM_GameStatus = STATE_DEMO;
    menu_radar_update_8003B350(&work, (u_long *)&ordering);
    assert(view->frame.active && !view->frame.map_visible && !view->wall_count);
    Begin(1); GM_GameStatus = 0; actors[0].map = NULL;
    menu_radar_update_8003B350(&work, (u_long *)&ordering);
    assert(view->frame.active && !view->frame.map_visible);
}

typedef struct {
    int status, counter, previous, y, console_x, console_y, random, sound_count, upload_count;
    unsigned hash;
} Trace;
static Trace baseline[100];

static unsigned PrimitiveHash(void)
{
    unsigned hash = 2166136261u;
    for (const unsigned char *p = primitives; p < prim.next; ++p) hash = (hash ^ *p) * 16777619u;
    return hash;
}

static void Behavior(int collect)
{
    Setup(); srand(12345);
    for (int tick = 0; tick < 100; ++tick) {
        Begin(collect); GV_Time = tick;
        if (tick == 9) { GM_AlertMode = ALERT_ACTIVE; GM_AlertLevel = 255; }
        if (tick == 20) { GM_AlertMode = ALERT_EVASION; GM_AlertLevel = 180; }
        if (tick == 29) { GM_AlertMode = ALERT_OFF; GM_GameStatus = STATE_JAMMING; }
        if (tick == 35) GM_GameStatus = 0;
        int counter_before = work.radar.counter;
        menu_radar_update_8003B350(&work, (u_long *)&ordering);
        Trace trace = {GM_GameStatus, work.radar.counter, work.radar.prev_mode, work.radar.pos_y,
            cons_current_x_800AB4B4, cons_current_y_800AB4B0, rand(), sounds, uploads, PrimitiveHash()};
        if (!collect) baseline[tick] = trace;
        else {
            if (owns_drawing) {
                assert(prim.next == primitives && ordering.tag == 0 && uploads == 0);
                trace.upload_count = baseline[tick].upload_count;
                trace.hash = baseline[tick].hash;
            }
            assert(memcmp(&trace, &baseline[tick], sizeof(trace)) == 0);
            const MgsRadarFrame *frame = &MgsRadarGetView()->frame;
            assert(frame->active && frame->tick == tick && frame->recovery_counter == counter_before);
            assert(frame->mode == (tick < 9 || tick >= 35 ? MGS_RADAR_MAP : tick < 20 ? MGS_RADAR_ALERT :
                                  tick < 29 ? MGS_RADAR_EVASION : MGS_RADAR_JAMMING));
            if (tick == 9) assert(frame->alert_level == 255 && frame->console_x == 0);
            if (tick == 35) assert(frame->recovery_counter == 93 && sounds == 1 && last_sound == SE_RADAR_CHIME);
            if (tick >= 35 && tick < 70) assert(frame->has_noise);
            if (tick == 99) assert(!frame->has_noise && frame->map_visible);
        }
    }
}

static void Visibility(void)
{
    Setup(); GV_Time = 2;
    const MgsRadarView *view = MgsRadarGetView();
    for (int hidden = 0; hidden < 6; ++hidden) {
        Begin(1);
        work.radar.display_flag = hidden != 0;
        work.field_2A_state = hidden == 1 ? 1 : MENU_CLOSED;
        GM_GameStatus = hidden == 2 ? STATE_RADAR_OFF : hidden == 3 ? STATE_CAMERA_ACTIVE : 0;
        GM_PlayerStatus = hidden == 4 ? PLAYER_INTRUDE : 0;
        GM_Configuration = hidden == 5 ? GM_CONFIG_RADAR_OFF : 0;
        menu_radar_update_8003B350(&work, (u_long *)&ordering);
        assert(!view->frame.active && !view->contact_count && !view->wall_count);
    }
    GM_Configuration = GM_PlayerStatus = 0;
    work.radar.pos_y = 0; GM_GameStatus = STATE_RADAR_OFF_REQ;
    for (int step = 1; step <= 4; ++step) {
        Begin(1); menu_radar_update_8003B350(&work, (u_long *)&ordering);
        assert(work.radar.pos_y == -16 * step);
        assert(view->frame.active == (step < 4));
        if (step < 4) assert(view->frame.y == -16 * step);
    }
    GM_GameStatus |= STATE_RADAR_ON_REQ;
    for (int step = 1; step <= 4; ++step) {
        Begin(1); GV_Clock = step % 2;
        menu_radar_update_8003B350(&work, (u_long *)&ordering);
        assert(view->frame.active && view->frame.y == -64 + step * 16 && view->frame.x == 0);
    }
    assert(!(GM_GameStatus & (STATE_RADAR_OFF | STATE_RADAR_ON_REQ)));
    Begin(0); menu_radar_update_8003B350(&work, (u_long *)&ordering);
    assert(!view->frame.active && !view->contact_count && !view->wall_count);
}

static void Countdown(void)
{
    Setup();
    GV_ACT *actor = NewCountdown(2, 42);
    assert(actor);
    const MgsRadarView *view = MgsRadarGetView();
    Begin(1); menu_radar_update_8003B350(&work, (u_long *)&ordering);
    assert(view->frame.mode == MGS_RADAR_COUNTDOWN && view->frame.countdown == 2);
    assert(countdown_time == 1 && callbacks == 0 && !view->frame.map_visible);
    Begin(1); work.field_2A_state = 1;
    menu_radar_update_8003B350(&work, (u_long *)&ordering);
    assert(!view->frame.active && countdown_time == 1 && callbacks == 0);
    Begin(1); work.field_2A_state = MENU_CLOSED;
    menu_radar_update_8003B350(&work, (u_long *)&ordering);
    assert(view->frame.countdown == 1 && countdown_time == 0 && callbacks == 1 && callback_seconds == 0);
    Begin(1); menu_radar_update_8003B350(&work, (u_long *)&ordering);
    assert(view->frame.countdown == 0 && callbacks == 1);
    actor->die(actor); free(actor);
    assert(callbacks == 1 && gFn_radar_800AB48C == NULL);
    actor = NewCountdown(95, 42);
    actor->die(actor); free(actor);
    assert(callbacks == 2 && callback_seconds == 3);
}

static void LargeMap(void)
{
    HZD_SEG segments[600];
    char attributes[1200] = {0};
    Setup();
    for (int i = 0; i < 600; ++i) segments[i] = walls[0];
    group.n_walls = 600;
    group.walls = segments;
    group.wallsFlags = attributes;
    Begin(1);
    menu_radar_update_8003B350(&work, (u_long *)&ordering);
    assert(MgsRadarGetView()->wall_count == 601);
    assert(prim.next == primitives && ordering.tag == 0 && uploads == 0);
}

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    MapData(); Behavior(0); Behavior(1); Visibility(); Countdown();
    owns_drawing = 1;
    Behavior(1); Countdown(); LargeMap();
    puts("Radar snapshots and ownership: filtering, RNG/state parity, zero legacy draws, large maps and countdown pass.");
    return 0;
}
