#include <SDL3/SDL.h>
#include <psyz/video.h>
#include <psyz/input.h>
#include "mgs_native.h"
#include "game/game.h"
#include "chara/snake/sna_init.h"
#include "memcard/memcard.h"
#include "mgs_bonus_items.h"
#include "mgs_probe.h"
#include "mgs_escape_route.h"
#include "mgs_rex_probe.h"
#include "mgs_liquid_probe.h"
#include "mgs_garage_route.h"
#undef fprintf

extern MenuWork Work;
extern GV_PAD *GM_CurrentPadData;
extern int codec_freq_800AB638;
extern int dword_800ABB58;
extern int dword_800ABB80;
extern int str_tick_count;
extern SnaInitWork *sna_800ABBA0;

enum ProbePhase { PROBE_WAIT, PROBE_NEUTRAL, PROBE_MOVE, PROBE_SETTLE, PROBE_SAVE, PROBE_DONE };
enum { NEUTRAL_FRAMES = 60, MOVE_FRAMES = 60, NEW_GAME_MOVE_FRAMES = 240, SETTLE_FRAMES = 8 };

static SDL_JoystickID controller_id;
static SDL_Joystick *controller;
static enum ProbePhase phase;
static unsigned frame, phase_frames, attempt, input_frames;
static int codec_seen, movement_verified;
static SVECTOR neutral_position, before_position;
static int before_time;
static int new_game_mode;
static int dock_route_mode;
static int intro_mode, intro_verified;
static unsigned long long intro_video_frame;
static unsigned intro_video_samples;
static double intro_draw_total, intro_draw_max, intro_frame_total, intro_frame_max;
static int save_mode, save_verified;
static int load_mode, load_verified;
static unsigned short load_area;
static int stage_mode;
static int ending_mode;
static int completed_load_mode, escape_route_mode;
static int rex_mode, liquid_mode, garage_route_mode, garage_escape_mode;
static int disc_change_mode;
static int bonus_mode, bonus_verified, bonus_step, bonus_state;
static unsigned bonus_frames, bonus_ticks;
static int bonus_last_tick, bonus_model_flags;
static int escape_mode, escape_seen, escape_locked, escape_yaw, escape_previous_yaw;
static int escape_phase, escape_left_rotation, escape_right_rotation, escape_verified;
static int briefing_mode, briefing_phase, briefing_verified, briefing_intro_seen;
static int briefing_selector = -1, briefing_animation, briefing_timer, briefing_selection;
static int briefing_scene = -1, briefing_scene_state, briefing_scene_timer;
static unsigned escape_frames, escape_left_ticks, escape_right_ticks, escape_shots;
static unsigned observed_stages;
static unsigned movement_ticks, collision_ticks;
static int previous_time;
static SVECTOR previous_position;
static const char *new_game_stages[] = { "title", "d00a", "s00a" };
static const char *disc_change_stages[] = { "change", "s13a" };

static const SDL_GamepadButton directions[] = {
    SDL_GAMEPAD_BUTTON_DPAD_UP, SDL_GAMEPAD_BUTTON_DPAD_RIGHT,
    SDL_GAMEPAD_BUTTON_DPAD_DOWN, SDL_GAMEPAD_BUTTON_DPAD_LEFT
};
static const unsigned short direction_masks[] = { PAD_UP, PAD_RIGHT, PAD_DOWN, PAD_LEFT };
static const char *direction_names[] = { "up", "right", "down", "left" };

static void DestroyController(void)
{
    if (controller) {
        SDL_CloseJoystick(controller);
        controller = NULL;
    }
    if (controller_id) {
        if (!SDL_DetachVirtualJoystick(controller_id)) {
            fprintf(stderr, "[probe] Cannot detach virtual controller: %s\n", SDL_GetError());
        }
        controller_id = 0;
    }
}

static int ConfigureInput(void)
{
    const char *drivers[] = {
        SDL_HINT_JOYSTICK_HIDAPI, SDL_HINT_JOYSTICK_RAWINPUT,
        SDL_HINT_JOYSTICK_DIRECTINPUT, SDL_HINT_JOYSTICK_WGI,
        SDL_HINT_JOYSTICK_GAMEINPUT, SDL_HINT_XINPUT_ENABLED
    };
    for (unsigned i = 0; i < sizeof(drivers) / sizeof(drivers[0]); ++i) {
        if (!SDL_SetHintWithPriority(drivers[i], "0", SDL_HINT_OVERRIDE)) {
            return 0;
        }
    }
    if (!SDL_SetHintWithPriority(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS,
                                 "1", SDL_HINT_OVERRIDE)) {
        return 0;
    }
    return SDL_InitSubSystem(SDL_INIT_GAMEPAD);
}

int MgsProbeInit(const char *mode)
{
    SDL_VirtualJoystickDesc desc;
    if (!mode || (strcmp(mode, "dock") != 0 && strcmp(mode, "new-game") != 0 &&
                  strcmp(mode, "save-menu") != 0 && strcmp(mode, "load-menu") != 0 &&
                  strcmp(mode, "stage") != 0 && strcmp(mode, "disc-change") != 0 &&
                  strcmp(mode, "escape") != 0 && strcmp(mode, "briefing") != 0 &&
                  strcmp(mode, "dock-route") != 0 && strcmp(mode, "new-game-route") != 0 &&
                  strcmp(mode, "intro") != 0 && strcmp(mode, "ending") != 0 && strcmp(mode, "bonus") != 0 &&
                  strcmp(mode, "completed-load") != 0 && strcmp(mode, "escape-route") != 0 &&
                  strcmp(mode, "rex-fight") != 0 && strcmp(mode, "liquid-fight") != 0 &&
                  strcmp(mode, "garage-route") != 0 && strcmp(mode, "garage-escape") != 0)) {
        fprintf(stderr, "[probe] Supported modes are dock, new-game, intro, dock-route, new-game-route, save-menu, load-menu, stage, disc-change, escape, briefing, ending, completed-load, escape-route, rex-fight, liquid-fight, garage-route, garage-escape, and bonus.\n");
        return 0;
    }
    escape_mode = strcmp(mode, "escape") == 0;
    bonus_mode = strcmp(mode, "bonus") == 0;
    if (bonus_mode && !MgsBonusItemsEnabled()) {
        fputs("[probe] The bonus probe requires --bonus-items 1.\n", stderr);
        return 0;
    }
    briefing_mode = strcmp(mode, "briefing") == 0;
    save_mode = strcmp(mode, "save-menu") == 0;
    load_mode = strcmp(mode, "load-menu") == 0;
    stage_mode = strcmp(mode, "stage") == 0;
    ending_mode = strcmp(mode, "ending") == 0;
    completed_load_mode = strcmp(mode, "completed-load") == 0;
    escape_route_mode = strcmp(mode, "escape-route") == 0;
    rex_mode = strcmp(mode, "rex-fight") == 0;
    liquid_mode = strcmp(mode, "liquid-fight") == 0;
    garage_route_mode = strcmp(mode, "garage-route") == 0;
    garage_escape_mode = strcmp(mode, "garage-escape") == 0;
    if (garage_route_mode || garage_escape_mode)
        MgsGarageRouteInit();
    if (escape_route_mode || garage_escape_mode)
        MgsEscapeRouteInit();
    disc_change_mode = strcmp(mode, "disc-change") == 0;
    intro_mode = strcmp(mode, "intro") == 0;
    new_game_mode = strcmp(mode, "new-game") == 0 || strcmp(mode, "new-game-route") == 0 || intro_mode;
    dock_route_mode = strcmp(mode, "dock-route") == 0 || strcmp(mode, "new-game-route") == 0;
    if (dock_route_mode)
    {
        MgsProbeDockRouteInit(new_game_mode);
    }
    if (dock_route_mode || rex_mode || liquid_mode || garage_route_mode || garage_escape_mode)
        Psyz_PadsSetKind(0, 0, PSYZ_CTRL_ANALOG_PAD);
    if (controller || !ConfigureInput()) {
        fprintf(stderr, "[probe] Cannot initialize virtual input: %s\n", SDL_GetError());
        return 0;
    }
    SDL_INIT_INTERFACE(&desc);
    desc.type = SDL_JOYSTICK_TYPE_GAMEPAD;
    desc.name = "MGS native boot probe";
    desc.naxes = SDL_GAMEPAD_AXIS_COUNT;
    desc.nbuttons = SDL_GAMEPAD_BUTTON_COUNT;
    desc.axis_mask = (1u << SDL_GAMEPAD_AXIS_COUNT) - 1;
    desc.button_mask = (1u << SDL_GAMEPAD_BUTTON_COUNT) - 1;
    controller_id = SDL_AttachVirtualJoystick(&desc);
    if (controller_id) {
        controller = SDL_OpenJoystick(controller_id);
    }
    if (!controller || !SDL_IsGamepad(controller_id) || atexit(DestroyController) != 0) {
        fprintf(stderr, "[probe] Cannot attach virtual controller: %s\n", SDL_GetError());
        DestroyController();
        return 0;
    }
    printf("[probe] Virtual controller attached; mode=%s.\n", mode);
    return 1;
}

static int SetButtons(unsigned short buttons, int direction)
{
    if (!SDL_SetJoystickVirtualAxis(controller, SDL_GAMEPAD_AXIS_LEFTX, 0) ||
        !SDL_SetJoystickVirtualAxis(controller, SDL_GAMEPAD_AXIS_LEFTY, 0) ||
        !SDL_SetJoystickVirtualAxis(controller, SDL_GAMEPAD_AXIS_LEFT_TRIGGER,
                                   buttons & PAD_L2 ? 32767 : -32768) ||
        !SDL_SetJoystickVirtualAxis(controller, SDL_GAMEPAD_AXIS_RIGHT_TRIGGER,
                                   buttons & PAD_R2 ? 32767 : -32768))
        return 0;
    if (!SDL_SetJoystickVirtualButton(controller, SDL_GAMEPAD_BUTTON_SOUTH, (buttons & PAD_CROSS) != 0) ||
        !SDL_SetJoystickVirtualButton(controller, SDL_GAMEPAD_BUTTON_EAST, (buttons & PAD_CIRCLE) != 0) ||
        !SDL_SetJoystickVirtualButton(controller, SDL_GAMEPAD_BUTTON_WEST, (buttons & PAD_SQUARE) != 0) ||
        !SDL_SetJoystickVirtualButton(controller, SDL_GAMEPAD_BUTTON_NORTH, (buttons & PAD_TRIANGLE) != 0) ||
        !SDL_SetJoystickVirtualButton(controller, SDL_GAMEPAD_BUTTON_LEFT_SHOULDER, (buttons & PAD_L1) != 0) ||
        !SDL_SetJoystickVirtualButton(controller, SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER, (buttons & PAD_R1) != 0) ||
        !SDL_SetJoystickVirtualButton(controller, SDL_GAMEPAD_BUTTON_BACK, (buttons & PAD_SELECT) != 0) ||
        !SDL_SetJoystickVirtualButton(controller, SDL_GAMEPAD_BUTTON_START, (buttons & PAD_START) != 0)) {
        return 0;
    }
    for (unsigned i = 0; i < sizeof(directions) / sizeof(directions[0]); ++i) {
        if (!SDL_SetJoystickVirtualButton(controller, directions[i],
                                          (int)i == direction || (buttons & direction_masks[i]) != 0)) {
            return 0;
        }
    }
    return 1;
}

static int SetHeadingButtons(unsigned short buttons, int heading)
{
    if (!SetButtons(buttons, -1))
        return 0;
    if (heading < 0)
        return 1;
    heading = (heading - GV_GetPadOrigin()) & 4095;
    return SDL_SetJoystickVirtualAxis(controller, SDL_GAMEPAD_AXIS_LEFTX,
                                     (short)(rsin(heading) * 32767 / 4096)) &&
        SDL_SetJoystickVirtualAxis(controller, SDL_GAMEPAD_AXIS_LEFTY,
                                   (short)(rcos(heading) * 32767 / 4096));
}

static void ReportState(const char *event)
{
    printf("[probe] %s frame=%u stage=%s load=%d codec=%d/%d pause=%x "
           "game=%08x player=%08x position=(%d,%d,%d) pad=%04x raw=%04x\n",
           event, frame, GM_GetArea(0), GM_LoadComplete, Work.field_2A_state,
           Work.field_210_codec_state, GV_PauseLevel, GM_GameStatus, GM_PlayerStatus,
           GM_PlayerPosition.vx, GM_PlayerPosition.vy, GM_PlayerPosition.vz,
           GM_CurrentPadData ? GM_CurrentPadData[0].status : 0,
           GM_CurrentPadData ? GM_CurrentPadData[2].status : 0);
    if (save_mode || load_mode)
        printf("[probe] Save menu frequency=%d code=%x state=%d result=%x io=%d.\n",
               codec_freq_800AB638, MENU_GetRadioCode(14096), dword_800ABB80,
               dword_800ABB58, memcard_status());
}

static void ObserveStages(void)
{
    const char **stages = disc_change_mode ? disc_change_stages : new_game_stages;
    unsigned count = disc_change_mode ? 2 : 3;
    if ((!new_game_mode && !disc_change_mode) || observed_stages == count)
        return;
    if (GM_LoadComplete > 0 && GM_LoadRequest == 0 &&
        strcmp(GM_GetArea(0), stages[observed_stages]) == 0) {
        ++observed_stages;
        printf("[probe] %s transition %u/%u: %s loaded, game_level=%d frame=%u tick=%d.\n",
               disc_change_mode ? "Disc change" : "New Game", observed_stages, count,
               GM_GetArea(0), GM_GameLevel, frame, GV_Time);
    }
}

static int PlayerControlsReady(void)
{
    return GM_PlayerControl && GM_LoadComplete > 0 && GM_LoadRequest == 0 &&
        Work.field_2A_state == MENU_CLOSED && GV_PauseLevel == 0 &&
        !(GM_PlayerStatus & (PLAYER_NOT_PLAYABLE | PLAYER_PAD_OFF | PLAYER_ACT_ONLY)) &&
        !(GM_GameStatus & (STATE_PADRELEASE | STATE_PADMASK | STATE_PADDEMO | STATE_DEMO));
}

static int PlayerReady(void)
{
    int stage_ready = stage_mode || (disc_change_mode && observed_stages == 2 && strcmp(GM_GetArea(0), "s13a") == 0) ||
        (load_mode && load_verified && (unsigned short)GM_SaveArea == load_area) ||
        (!load_mode && !disc_change_mode && (save_mode ? MENU_GetRadioCode(14096) >= 0 :
                                     strcmp(GM_GetArea(0), "s00a") == 0));
    return (codec_seen || save_mode || load_mode || stage_mode || disc_change_mode) &&
        stage_ready && PlayerControlsReady();
}

static int HorizontalDistance(SVECTOR first, SVECTOR second)
{
    return abs((int)first.vx - second.vx) + abs((int)first.vz - second.vz);
}

static void FinishAttempt(void)
{
    int distance = HorizontalDistance(before_position, GM_PlayerPosition);
    movement_verified = PlayerReady() && distance >= 32 && input_frames >= 8 &&
        movement_ticks >= (new_game_mode ? 16u : 8u) && GV_Time > before_time;
    printf("[probe] %s direction=%s before=(%d,%d,%d) after=(%d,%d,%d) "
           "horizontal_delta=%d input_frames=%u game_ticks=%d movement_ticks=%u collision_ticks=%u\n",
           movement_verified ? "PASS movement" : "NO movement", direction_names[attempt],
           before_position.vx, before_position.vy, before_position.vz,
           GM_PlayerPosition.vx, GM_PlayerPosition.vy, GM_PlayerPosition.vz,
           distance, input_frames, GV_Time - before_time, movement_ticks, collision_ticks);
    if (movement_verified || ++attempt == sizeof(directions) / sizeof(directions[0])) {
        phase = PROBE_DONE;
    } else {
        phase = PROBE_NEUTRAL;
        phase_frames = 0;
        neutral_position = GM_PlayerPosition;
    }
}

static void ObserveMovement(void)
{
    if (!PlayerReady() || !GM_CurrentPadData || !(GM_CurrentPadData[0].status & direction_masks[attempt]))
        return;
    ++input_frames;
    if (GV_Time == previous_time)
        return;
    int delta = HorizontalDistance(previous_position, GM_PlayerPosition);
    if (delta > 1)
        ++movement_ticks;
    if (delta <= 2 && GM_PlayerControl->n_touches > 0 &&
        (GM_PlayerControl->step.vx || GM_PlayerControl->step.vz))
        ++collision_ticks;
    previous_position = GM_PlayerPosition;
    previous_time = GV_Time;
}

static int WaitForPlayer(void)
{
    if (disc_change_mode && strcmp(GM_GetArea(0), "change") == 0)
        return SetButtons(frame % 60 < 8 ? PAD_START : 0, -1);
    if (load_mode && Work.field_210_codec_state == 14) {
        if (!load_verified && (unsigned int)dword_800ABB58 == 0xc1000001 && memcard_status() == 0) {
            load_verified = 1;
            load_area = (unsigned short)GM_SaveArea;
            ReportState("PASS original load menu accepted save data");
            printf("[probe] Expected restored area=%04x.\n", load_area);
        }
        return SetButtons(frame % 60 < 8 ? PAD_CIRCLE : 0, -1);
    }
    if ((new_game_mode || load_mode) && strcmp(GM_GetArea(0), "title") == 0)
        return SetButtons(frame % 60 < 8 ? PAD_START | PAD_CIRCLE : 0, -1);
    if (Work.field_2A_state == MENU_CODEC_OPEN) {
        codec_seen = 1;
        return SetButtons(frame % 24 < 8 ? PAD_CROSS : 0, -1);
    }
    if (GM_GameStatus & STATE_DEMO)
        return SetButtons(frame % 60 < 8 ? PAD_START : 0, -1);
    if (stage_mode && GM_LoadComplete > 0 && GM_LoadRequest == 0 &&
        Work.field_2A_state == MENU_CLOSED &&
        (GM_GameStatus & (STATE_VOX_STREAM | STATE_PADDEMO)) &&
        (GM_GameStatus & (STATE_PADRELEASE | STATE_PADDEMO)))
        return SetButtons(frame % 60 < 8 ? PAD_CROSS : 0, -1);
    if (load_mode && load_verified && !GM_PlayerControl && GM_LoadRequest == 0)
        return SetButtons(frame % 60 < 8 ? PAD_CROSS : 0, -1);
    if (PlayerReady()) {
        phase = save_mode ? PROBE_SAVE : PROBE_NEUTRAL;
        phase_frames = 0;
        neutral_position = GM_PlayerPosition;
        ReportState(save_mode ? "Gameplay ready; opening save Codec" : "Codec closed; neutral baseline");
    }
    return SetButtons(0, -1);
}

static int AdvanceSave(void)
{
    unsigned short pulse = frame % 60 < 8;
    if (Work.field_210_codec_state == 12 && (unsigned int)dword_800ABB58 == 0xc1000001 &&
        memcard_status() == 0) {
        save_verified = 1;
        phase = PROBE_DONE;
        ReportState("PASS original save menu completed write");
        return SetButtons(0, -1);
    }
    if (Work.field_2A_state == MENU_CLOSED)
        return SetButtons(pulse ? PAD_SELECT : 0, -1);
    if (Work.field_210_codec_state == 1) {
        if (codec_freq_800AB638 != 14096)
            return SetButtons(0, codec_freq_800AB638 < 14096 ? 1 : 3);
        return SetButtons(pulse ? PAD_CIRCLE : 0, -1);
    }
    if (Work.field_210_codec_state == 12 || Work.field_210_codec_state == 16)
        return SetButtons(pulse ? PAD_CIRCLE : 0, -1);
    return SetButtons(frame % 24 < 8 ? PAD_CROSS : 0, -1);
}

enum { ESCAPE_WAIT, ESCAPE_NEUTRAL, ESCAPE_LEFT, ESCAPE_LEFT_SETTLE,
       ESCAPE_RIGHT, ESCAPE_RIGHT_SETTLE, ESCAPE_FIRE, ESCAPE_DONE };

void MgsProbeEscapeAim(int yaw, int locked)
{
    int delta;
    if (escape_route_mode || garage_escape_mode)
        MgsEscapeRouteAim(yaw, locked);
    if (!escape_mode)
        return;
    delta = ((yaw - escape_previous_yaw + 2048) & 4095) - 2048;
    escape_previous_yaw = escape_yaw = yaw;
    escape_seen = 1;
    escape_locked = locked;
    if (locked)
        return;
    if (escape_phase == ESCAPE_LEFT && (GV_PadData[0].status & PAD_LEFT)) {
        escape_left_rotation += delta;
        ++escape_left_ticks;
    }
    if (escape_phase == ESCAPE_RIGHT && (GV_PadData[0].status & PAD_RIGHT)) {
        escape_right_rotation += delta;
        ++escape_right_ticks;
    }
}

void MgsProbeEscapeShot(void)
{
    if (escape_route_mode || garage_escape_mode)
        MgsEscapeRouteShot();
    if (escape_mode && escape_phase == ESCAPE_FIRE && !escape_locked &&
        (GV_PadData[0].status & PAD_SQUARE))
        ++escape_shots;
}

static int EscapeReady(void)
{
    const char *area = GM_GetArea(0);
    return escape_seen && !escape_locked && GM_PlayerControl &&
        (strcmp(area, "s19b") == 0 || strcmp(area, "s19br") == 0) &&
        GM_LoadComplete > 0 && GM_LoadRequest == 0 && GV_PauseLevel == 0 &&
        Work.field_2A_state == MENU_CLOSED && GM_Vitality > 0 &&
        !(GM_GameStatus & STATE_DEMO);
}

static int AdvanceEscape(void)
{
    static const unsigned durations[] = {0, 60, 120, 30, 120, 30, 90};
    if (escape_phase == ESCAPE_DONE)
        return SetButtons(0, -1);
    if (!EscapeReady())
        return SetButtons(0, -1);
    if (escape_phase == ESCAPE_WAIT) {
        escape_phase = ESCAPE_NEUTRAL;
        escape_frames = 0;
        printf("[probe] Mounted controls ready; relative aim=%d.\n", escape_yaw);
    }
    if (++escape_frames >= durations[escape_phase]) {
        ++escape_phase;
        escape_frames = 0;
        if (escape_phase == ESCAPE_DONE) {
            escape_verified = escape_left_ticks >= 8 && escape_right_ticks >= 8 &&
                escape_left_rotation >= 128 && escape_right_rotation <= -128 &&
                escape_shots >= 3;
            printf("[probe] %s mounted controls: left=%d/%u ticks right=%d/%u ticks successful player bullets=%u.\n",
                   escape_verified ? "PASS" : "FAIL", escape_left_rotation, escape_left_ticks,
                   escape_right_rotation, escape_right_ticks, escape_shots);
            return SetButtons(0, -1);
        }
        printf("[probe] Mounted input phase=%d relative aim=%d.\n", escape_phase, escape_yaw);
    }
    if (escape_phase == ESCAPE_LEFT)
        return SetButtons(0, 3);
    if (escape_phase == ESCAPE_RIGHT)
        return SetButtons(0, 1);
    return SetButtons(escape_phase == ESCAPE_FIRE ? PAD_SQUARE : 0, -1);
}

static int AdvanceProbe(void)
{
    if (phase >= PROBE_NEUTRAL && phase <= PROBE_SETTLE && !PlayerReady()) {
        phase = PROBE_WAIT;
        phase_frames = input_frames = 0;
        movement_ticks = collision_ticks = 0;
        ReportState("Controls interrupted; restarting movement baseline");
        return WaitForPlayer();
    }
    switch (phase) {
    case PROBE_WAIT:
        return WaitForPlayer();
    case PROBE_NEUTRAL:
        if (HorizontalDistance(neutral_position, GM_PlayerPosition) > 1) {
            neutral_position = GM_PlayerPosition;
            phase_frames = 0;
        } else if (++phase_frames >= NEUTRAL_FRAMES) {
            phase = PROBE_MOVE;
            phase_frames = 0;
            input_frames = 0;
            movement_ticks = collision_ticks = 0;
            before_position = GM_PlayerPosition;
            before_time = GV_Time;
            previous_position = before_position;
            previous_time = before_time;
            ReportState(direction_names[attempt]);
        }
        break;
    case PROBE_MOVE:
        ObserveMovement();
        if (++phase_frames < (new_game_mode ? NEW_GAME_MOVE_FRAMES : MOVE_FRAMES)) {
            return SetButtons(0, (int)attempt);
        }
        phase = PROBE_SETTLE;
        phase_frames = 0;
        break;
    case PROBE_SETTLE:
        if (++phase_frames >= SETTLE_FRAMES) {
            FinishAttempt();
        }
        break;
    case PROBE_SAVE:
        return AdvanceSave();
    case PROBE_DONE:
        break;
    }
    return SetButtons(0, -1);
}

static int AdvanceDockRoute(void)
{
    unsigned short buttons = 0;
    int heading = -1;
    int ready = PlayerControlsReady() && (codec_seen || strcmp(GM_GetArea(0), "s00a"));
    if (!MgsProbeDockRouteUpdate(frame, ready, &buttons, &heading))
        return WaitForPlayer();
    return SetHeadingButtons(buttons, heading);
}

static void ObserveIntroTiming(void)
{
    PsyzVideoStats stats;
    if (Psyz_VideoStats(&stats) == 0 && stats.total_frames != intro_video_frame) {
        intro_video_frame = stats.total_frames;
        ++intro_video_samples;
        intro_draw_total += stats.last_draw_time_us;
        intro_frame_total += stats.last_frame_time_us;
        if (stats.last_draw_time_us > intro_draw_max)
            intro_draw_max = stats.last_draw_time_us;
        if (stats.last_frame_time_us > intro_frame_max)
            intro_frame_max = stats.last_frame_time_us;
    }
    if (frame % 300 == 0 && intro_video_samples) {
        printf("[intro-timing] vsync=%u stage=%s game_tick=%d sound_tick=%d video=%llu samples=%u draw_ms=%.3f/%.3f frame_ms=%.3f/%.3f\n",
               frame, GM_GetArea(0), GV_Time, str_tick_count, intro_video_frame,
               intro_video_samples, intro_draw_total / intro_video_samples / 1000.0,
               intro_draw_max / 1000.0, intro_frame_total / intro_video_samples / 1000.0,
               intro_frame_max / 1000.0);
        intro_video_samples = 0;
        intro_draw_total = intro_draw_max = intro_frame_total = intro_frame_max = 0.0;
    }
}

static int AdvanceIntro(void)
{
    ObserveIntroTiming();
    if (!strcmp(GM_GetArea(0), "title"))
        return SetButtons(frame % 60 < 8 ? PAD_START | PAD_CIRCLE : 0, -1);
    if (observed_stages == 3 && Work.field_2A_state == MENU_CODEC_OPEN && !intro_verified) {
        intro_verified = 1;
        puts("[probe] PASS unskipped New Game stage chain reached the dock Codec; no input sent after title.");
    }
    return SetButtons(0, -1);
}

enum { BONUS_WAIT, BONUS_SELECT, BONUS_EQUIPPED, BONUS_REMOVE, BONUS_DONE };
enum { BONUS_MODEL_MASK = DG_FLAG_SHADE | DG_FLAG_BOUND | DG_FLAG_GBOUND };
static const int bonus_items[] = {IT_Stealth, IT_Bandana};
static const char *bonus_actors[] = {"kogaku2.c", "bandana.c"};

static SnaInitWork *BonusSnake(void)
{
    if (!GM_PlayerControl || !sna_800ABBA0 ||
        &sna_800ABBA0->control != GM_PlayerControl ||
        &sna_800ABBA0->body != GM_PlayerBody || !sna_800ABBA0->body.objs)
        return NULL;
    return sna_800ABBA0;
}

static int BonusActorReady(const SnaInitWork *snake, int equipped)
{
    const GV_ACT *actor = snake->field_9A4_item_actor;
    int item = equipped ? bonus_items[bonus_step] : IT_None;
    if (GM_Item != item || snake->field_9A8_current_item != item)
        return 0;
    if (!equipped)
        return !actor && (snake->body.objs->flag & BONUS_MODEL_MASK) == bonus_model_flags;
    if (!actor || !actor->act || !actor->filename || strcmp(actor->filename, bonus_actors[bonus_step]))
        return 0;
    return item != IT_Stealth || (snake->body.objs->flag & BONUS_MODEL_MASK) == DG_FLAG_GBOUND;
}

static int AdvanceBonusMenu(void)
{
    const Menu_Inventory *menu = &Work.field_1DC_menu_item;
    const Menu_Item_Unknown *panels = menu->field_C_alloc;
    if (Work.field_2A_state == MENU_LEFT_OPEN && menu->field_10_state == 1 && panels) {
        int selected = panels->field_0_main.field_4_selected_idx;
        if (selected >= 0 && selected < panels->field_0_main.field_0_array_count) {
            const PANEL *panel = &panels->field_20_array[selected];
            if (panel->field_0_id == bonus_items[bonus_step] && panel->field_4_pos == 0 &&
                panels->field_0_main.field_10 == 0) {
                bonus_state = BONUS_EQUIPPED;
                bonus_frames = bonus_ticks = 0;
                bonus_last_tick = GV_Time;
                printf("[probe] Bonus menu selected item=%d; releasing L2.\n", panel->field_0_id);
                return SetButtons(0, -1);
            }
        }
    }
    return SetButtons(PAD_L2, Work.field_2A_state == MENU_LEFT_OPEN &&
                      menu->field_10_state == 1 && bonus_frames % 24 < 6 ? 1 : -1);
}

static int ObserveBonusEquipment(const SnaInitWork *snake)
{
    int equipped = bonus_state == BONUS_EQUIPPED;
    if (!PlayerReady() || !BonusActorReady(snake, equipped)) {
        bonus_ticks = 0;
        return SetButtons(!equipped && bonus_frames % 60 < 8 ? PAD_L1 : 0, -1);
    }
    if (GV_Time != bonus_last_tick) {
        bonus_last_tick = GV_Time;
        ++bonus_ticks;
    }
    if (bonus_ticks < 8)
        return SetButtons(0, -1);
    printf("[probe] PASS bonus item=%d %s: GM_Item=%d snake_item=%d actor=%s "
           "model_flags=%lx ticks=%u stealth_selector=%d ammo_actor=%d weapon=%d magazine=%d.\n",
           bonus_items[bonus_step], equipped ? "equipped" : "unequipped", GM_Item,
           snake->field_9A8_current_item, snake->field_9A4_item_actor ?
           snake->field_9A4_item_actor->filename : "none", snake->body.objs->flag,
           bonus_ticks, GM_Item == IT_Stealth, equipped && GM_Item == IT_Bandana,
           GM_Weapon, GM_Magazine);
    bonus_frames = bonus_ticks = 0;
    if (equipped) {
        bonus_state = BONUS_REMOVE;
        return SetButtons(PAD_L1, -1);
    }
    if (++bonus_step == (int)(sizeof(bonus_items) / sizeof(bonus_items[0]))) {
        bonus_state = BONUS_DONE;
        bonus_verified = 1;
        puts("[probe] PASS bonus inventory: original L2 menu equips both actors; L1 removes both. "
             "Enemy detection and ammo consumption were not exercised.");
    } else {
        bonus_state = BONUS_SELECT;
    }
    return SetButtons(0, -1);
}

static int AdvanceBonus(void)
{
    SnaInitWork *snake;
    if (bonus_state == BONUS_DONE)
        return SetButtons(0, -1);
    if (bonus_state == BONUS_WAIT) {
        if (!PlayerReady() || !(snake = BonusSnake()))
            return WaitForPlayer();
        if (GM_Item != IT_None || snake->field_9A4_item_actor)
            return SetButtons(frame % 60 < 8 ? PAD_L1 : 0, -1);
        if (GM_Items[IT_Stealth] <= 0 || GM_Items[IT_Bandana] <= 0) {
            fputs("[probe] FAIL bonus inventory: both granted items must be available.\n", stderr);
            bonus_state = BONUS_DONE;
            return SetButtons(0, -1);
        }
        bonus_model_flags = snake->body.objs->flag & BONUS_MODEL_MASK;
        bonus_state = BONUS_SELECT;
        puts("[probe] Bonus inventory ready; opening the original item menu with L2.");
    }
    if (++bonus_frames > 600) {
        fprintf(stderr, "[probe] FAIL bonus timeout: item=%d phase=%d menu=%d GM_Item=%d.\n",
                bonus_items[bonus_step], bonus_state, Work.field_2A_state, GM_Item);
        bonus_state = BONUS_DONE;
        return SetButtons(0, -1);
    }
    if (bonus_state == BONUS_SELECT)
        return AdvanceBonusMenu();
    snake = BonusSnake();
    return snake ? ObserveBonusEquipment(snake) : SetButtons(0, -1);
}

void MgsProbeBriefingSelector(int state, int animation, int timer, int selection)
{
    if (!briefing_mode)
        return;
    if (briefing_selector != state)
        printf("[probe] Briefing selector state=%d animation=%d timer=%d selection=%d.\n",
               state, animation, timer, selection);
    briefing_selector = state;
    briefing_animation = animation;
    briefing_timer = timer;
    briefing_selection = selection;
}

void MgsProbeBriefingGraph(int scene, int state, int timer)
{
    if (!briefing_mode)
        return;
    if (briefing_scene != scene || briefing_scene_state != state)
        printf("[probe] Briefing graph scene=%d state=%d timer=%d.\n", scene, state, timer);
    briefing_scene = scene;
    briefing_scene_state = state;
    briefing_scene_timer = timer;
    if (scene == 16 && timer >= 60)
        briefing_intro_seen = 1;
}

static int AdvanceBriefing(void)
{
    int pulse = frame % 60 < 8;
    if (strcmp(GM_GetArea(0), "brf") != 0 || GM_LoadComplete <= 0 ||
        GM_LoadRequest != 0 || briefing_verified)
        return SetButtons(0, -1);
    if (briefing_phase == 0) {
        if (briefing_intro_seen && briefing_selector == 5 && briefing_animation == 0) {
            briefing_phase = 1;
            puts("[probe] Briefing authored intro cancellation reached the selector.");
        } else {
            return SetButtons(briefing_intro_seen && briefing_selector == 2 &&
                briefing_timer >= 50 && pulse ? PAD_CROSS : 0, -1);
        }
    }
    if (briefing_phase == 1) {
        if (briefing_selector == 9 && briefing_animation == 0) {
            briefing_phase = 2;
            puts("[probe] Briefing RIGHT entered the unlocked topic list.");
        } else {
            return SetButtons(0, briefing_selector == 5 && pulse ? 1 : -1);
        }
    }
    if (briefing_phase == 2) {
        if (briefing_selector == 27 && briefing_scene == 0 && briefing_scene_timer >= 90) {
            briefing_verified = 1;
            puts("[probe] PASS briefing: intro 16, authored selector, RIGHT/CIRCLE selection, scene 0 playback.");
        }
        return SetButtons(briefing_selector == 9 && briefing_animation == 0 && pulse ? PAD_CIRCLE : 0, -1);
    }
    return SetButtons(0, -1);
}

int MgsProbeVSync(void)
{
    if (!controller) {
        return 1;
    }
    ++frame;
    if (garage_escape_mode) {
        int heading = -1, direction = -1;
        unsigned short buttons = MgsGarageRouteInput(frame, PlayerControlsReady(), &heading);
        buttons |= MgsEscapeRouteInput(frame, &direction);
        if (direction >= 0)
            buttons |= direction_masks[direction];
        return SetHeadingButtons(buttons, heading);
    }
    if (rex_mode || liquid_mode || garage_route_mode) {
        int heading = -1;
        unsigned short buttons = rex_mode ? MgsRexProbeInput(frame, &heading) :
            liquid_mode ? MgsLiquidProbeInput(frame, PlayerControlsReady(), &heading) :
            MgsGarageRouteInput(frame, PlayerControlsReady(), &heading);
        return SetHeadingButtons(buttons, heading);
    }
    if (completed_load_mode)
        return SetButtons(MgsProbeCompletedLoadInput(frame, PlayerControlsReady()), -1);
    if (escape_route_mode) {
        int direction = -1;
        unsigned short buttons = MgsEscapeRouteInput(frame, &direction);
        return SetButtons(buttons, direction);
    }
    if (ending_mode) {
        unsigned short buttons = MgsProbeEndingInput(frame);
        return SetButtons(buttons, buttons & PAD_RIGHT ? 1 : -1);
    }
    ObserveStages();
    if (frame % 300 == 0) {
        ReportState("progress");
    }
    if (!(bonus_mode ? AdvanceBonus() : intro_mode ? AdvanceIntro() : dock_route_mode ? AdvanceDockRoute() : briefing_mode ? AdvanceBriefing() :
          escape_mode ? AdvanceEscape() : AdvanceProbe())) {
        fprintf(stderr, "[probe] Virtual controller update failed: %s\n", SDL_GetError());
        return 0;
    }
    return 1;
}

int MgsProbeFinish(void)
{
    if (garage_escape_mode) {
        int garage_complete = MgsGarageRouteFinish();
        int escape_complete = MgsEscapeRouteFinish();
        return garage_complete && escape_complete;
    }
    if (rex_mode)
        return MgsRexProbeFinish();
    if (liquid_mode)
        return MgsLiquidProbeFinish();
    if (garage_route_mode)
        return MgsGarageRouteFinish();
    if (completed_load_mode)
        return MgsProbeCompletedLoadFinish();
    if (escape_route_mode)
        return MgsEscapeRouteFinish();
    if (ending_mode)
        return MgsProbeEndingFinish();
    int complete = (bonus_mode ? bonus_verified : intro_mode ? intro_verified : dock_route_mode ? MgsProbeDockRouteFinish() : briefing_mode ? briefing_verified :
        escape_mode ? escape_verified : save_mode ? save_verified : movement_verified) &&
        (!new_game_mode || observed_stages == 3) && (!load_mode || load_verified) &&
        (!disc_change_mode || observed_stages == 2);
    ReportState(complete ? "PASS completed automated input probe" : "FAIL incomplete");
    if (bonus_mode)
        printf("[probe] Bonus equipment=%s; completed items=%d/2; phase=%d; original menu/actor checks only.\n",
               bonus_verified ? "verified" : "unverified", bonus_step, bonus_state);
    if (briefing_mode)
        printf("[probe] Briefing intro=%d phase=%d selector=%d selection=%d scene=%d/%d timer=%d.\n",
               briefing_intro_seen, briefing_phase, briefing_selector, briefing_selection,
               briefing_scene, briefing_scene_state, briefing_scene_timer);
    if (escape_mode)
        printf("[probe] Mounted aim left=%d/%u ticks right=%d/%u ticks; player bullets=%u; seen=%d locked=%d.\n",
               escape_left_rotation, escape_left_ticks, escape_right_rotation, escape_right_ticks,
               escape_shots, escape_seen, escape_locked);
    if (intro_mode)
        printf("[probe] Unskipped intro stages=%u/3; dock Codec=%s; post-title input=none.\n",
               observed_stages, intro_verified ? "observed" : "unverified");
    if (new_game_mode && !dock_route_mode && !intro_mode)
        printf("[probe] Transitions=%u/3; sustained movement=%s; collision contact ticks=%u.\n",
               observed_stages, movement_verified ? "observed" : "unverified", collision_ticks);
    if (save_mode)
        printf("[probe] Original save menu completion=%s.\n", save_verified ? "observed" : "unverified");
    if (load_mode)
        printf("[probe] Original load menu acceptance=%s; restored-stage movement=%s.\n",
               load_verified ? "observed" : "unverified", movement_verified ? "observed" : "unverified");
    if (disc_change_mode)
        printf("[probe] Disc change transitions=%u/2; furnace movement=%s.\n",
               observed_stages, movement_verified ? "observed" : "unverified");
    return complete;
}
