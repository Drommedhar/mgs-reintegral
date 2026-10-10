#include "mgs_native.h"
#include "mgs_bonus_items.h"
#include "mgs_probe.h"
#include "game/game.h"
#include "libgcl/libgcl.h"
#include "memcard/memcard.h"

extern MenuWork Work;
extern int dword_800ABB58;

enum { LOAD_WAIT, LOAD_NEUTRAL, LOAD_MOVE, LOAD_SETTLE, LOAD_DONE };
static const char *stages[] = {"title", "abst", "d00a", "s00a"};
static const unsigned short directions[] = {PAD_UP, PAD_RIGHT, PAD_DOWN, PAD_LEFT};
static unsigned stage_count, phase_frames, direction, movement_ticks;
static int phase, loaded, load_valid, initial_checked, initial_clean, moved;
static int completions, clear_flag, difficulty, bandana, stealth, previous_tick;
static SVECTOR baseline, before, previous;

static int Story(void)
{
    char token[4] = {0x11, 0, 0, 10};
    int type, value;
    GCL_GetVar(token, &type, &value);
    return value;
}

static int Distance(SVECTOR first, SVECTOR second)
{
    return abs((int)first.vx - second.vx) + abs((int)first.vz - second.vz);
}

static int Preserved(void)
{
    return loaded && GM_UnkFlag00 == completions && GM_ClearFlag == clear_flag &&
           GM_GameLevel == difficulty && GM_BandanaFlag == bandana &&
           GM_StealthFlag == stealth && !MgsBonusItemsEnabled();
}

static void ObserveLoad(unsigned frame)
{
    if (loaded || strcmp(GM_GetArea(0), "abst") || Work.field_210_codec_state != 14 ||
        (unsigned)dword_800ABB58 != 0xc1000001 || memcard_status() != 0)
        return;
    loaded = 1;
    completions = GM_UnkFlag00;
    clear_flag = GM_ClearFlag;
    difficulty = GM_GameLevel;
    bandana = GM_BandanaFlag;
    stealth = GM_StealthFlag;
    load_valid = initial_clean && completions == 1 && difficulty == GM_LEVEL_NORMAL &&
                 GM_SaveArea == 0 && Story() == 0 &&
                 ((clear_flag == 1 && bandana == 1 && stealth == -1) ||
                  (clear_flag == 2 && bandana == -1 && stealth == 1));
    printf("[completed-load] Original load accepted: frame=%u completions=%d clear=%d "
           "difficulty=%d bandana=%d stealth=%d valid=%d.\n",
           frame, completions, clear_flag, difficulty, bandana, stealth, load_valid);
}

static void ObserveStage(unsigned frame)
{
    if (!initial_checked && !strcmp(GM_GetArea(0), "title")) {
        initial_checked = 1;
        initial_clean = GM_UnkFlag00 == 0 && GM_ClearFlag == 0 && !MgsBonusItemsEnabled();
    }
    if (stage_count < 4 && !strcmp(GM_GetArea(0), stages[stage_count])) {
        printf("[completed-load] Stage %u/4: %s frame=%u story=%d.\n",
               stage_count + 1, stages[stage_count], frame, Story());
        ++stage_count;
    }
}

static void ObserveMovement(void)
{
    if (GV_Time != previous_tick) {
        if ((GV_PadData[0].status & directions[direction]) &&
            Distance(previous, GM_PlayerPosition) > 0)
            ++movement_ticks;
        previous_tick = GV_Time;
        previous = GM_PlayerPosition;
    }
}

static unsigned short Move(void)
{
    if (phase == LOAD_WAIT) {
        phase = LOAD_NEUTRAL;
        phase_frames = 0;
        baseline = GM_PlayerPosition;
    }
    if (phase == LOAD_NEUTRAL) {
        if (Distance(baseline, GM_PlayerPosition) > 1) {
            baseline = GM_PlayerPosition;
            phase_frames = 0;
        } else if (++phase_frames >= 60) {
            phase = LOAD_MOVE;
            phase_frames = movement_ticks = 0;
            before = previous = GM_PlayerPosition;
            previous_tick = GV_Time;
        }
    } else if (phase == LOAD_MOVE) {
        ObserveMovement();
        if (++phase_frames < 60)
            return directions[direction];
        phase = LOAD_SETTLE;
        phase_frames = 0;
    } else if (phase == LOAD_SETTLE && ++phase_frames >= 8) {
        int distance = Distance(before, GM_PlayerPosition);
        moved = movement_ticks >= 8 && distance >= 128 && Preserved();
        printf("[completed-load] Movement direction=%u distance=%d ticks=%u preserved=%d.\n",
               direction, distance, movement_ticks, Preserved());
        phase = moved || ++direction == 4 ? LOAD_DONE : LOAD_WAIT;
    }
    return 0;
}

unsigned short MgsProbeCompletedLoadInput(unsigned frame, int player_ready)
{
    if (GM_LoadComplete <= 0 || GM_LoadRequest != 0)
        return 0;
    ObserveStage(frame);
    ObserveLoad(frame);
    if (phase == LOAD_DONE)
        return 0;
    if (Work.field_210_codec_state == 14)
        return frame % 60 < 8 ? PAD_CIRCLE : 0;
    if (!strcmp(GM_GetArea(0), "title"))
        return frame % 60 < 8 ? PAD_START | PAD_CIRCLE : 0;
    if (!player_ready || !loaded || stage_count != 4) {
        phase = LOAD_WAIT;
        if (Work.field_2A_state == MENU_CODEC_OPEN)
            return frame % 24 < 8 ? PAD_CROSS : 0;
        if (GM_GameStatus & STATE_DEMO)
            return frame % 60 < 8 ? PAD_START : 0;
        if (loaded && !GM_PlayerControl)
            return frame % 60 < 8 ? PAD_CROSS : 0;
        return 0;
    }
    return Move();
}

int MgsProbeCompletedLoadFinish(void)
{
    int complete = load_valid && stage_count == 4 && moved && Preserved();
    printf("[completed-load] %s loaded=%d valid=%d stages=%u/4 movement=%d "
           "preserved=%d completions=%d clear=%d bandana=%d stealth=%d.\n",
           complete ? "PASS" : "FAIL", loaded, load_valid, stage_count, moved,
           Preserved(), GM_UnkFlag00, GM_ClearFlag, GM_BandanaFlag, GM_StealthFlag);
    return complete;
}
