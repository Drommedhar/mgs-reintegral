#include "mgs_native.h"
#include "game/game.h"
#include "libgcl/libgcl.h"
#include "memcard/memcard.h"
#include "overlays/rank/chara/pocket/pocket_native.h"
#include "mgs_probe.h"

extern MenuWork Work;
extern int dword_800ABB58;
extern int dword_800ABB48;

static unsigned ending_states, roll_phases;
static int ending_seen, rank_seen, saved, returned_to_title, earned_item;
static int initial_completions, companion, completion_verified;
static int fixture_valid;
static unsigned pocket_prompt_frames;

static int ScriptValue(int code, unsigned offset)
{
    char token[4] = {(char)code, 0, (char)(offset >> 8), (char)offset};
    int type, value;
    GCL_GetVar(token, &type, &value);
    return value;
}

static void ObserveEnding(void)
{
    if (!ending_seen) {
        ending_seen = 1;
        initial_completions = GM_UnkFlag00;
        fixture_valid = initial_completions == 0 && GM_ClearFlag == 0 &&
                        GM_GameLevel >= GM_LEVEL_EASY && GM_GameLevel <= GM_LEVEL_EXTREME;
        companion = (ScriptValue(0x12, 0x5c) >> 3) & 1;
        printf("[ending] Entry: companion=%s completions=%d difficulty=%d.\n",
               companion ? "Otacon" : "Meryl", initial_completions, GM_GameLevel);
    }
    int story = ScriptValue(0x11, 0xa);
    if (story == 293 || story == 294) {
        unsigned bit = 1u << (story - 293);
        if (!(ending_states & bit)) {
            ending_states |= bit;
            printf("[ending] Original scenario advanced story=%d.\n", story);
        }
    }
}

static void ObserveRoll(void)
{
    int phase = ScriptValue(0x12, 0x3d7);
    if (phase >= 0 && phase <= 4 && !(roll_phases & (1u << phase))) {
        roll_phases |= 1u << phase;
        printf("[ending] Original credits sequence phase=%d.\n", phase);
    }
}

static void ObserveRank(void)
{
    if (!rank_seen) {
        rank_seen = 1;
        int expected = initial_completions < 9999 ? initial_completions + 1 : 9999;
        completion_verified = ending_seen && GM_UnkFlag00 == expected &&
                              GM_ClearFlag == (companion ? 2 : 1);
        printf("[ending] Ranking reached: completions=%d unlock=%d verified=%d.\n",
               GM_UnkFlag00, GM_ClearFlag, completion_verified);
    }
    if (!earned_item && ScriptValue(0x11, 0xa) == 0 &&
        (companion ? GM_StealthFlag : GM_BandanaFlag) == 1) {
        earned_item = 1;
        puts("[ending] Original completed-mission procedure granted its bonus item.");
    }
    if (!saved && Work.field_210_codec_state == 14 && dword_800ABB48 == 0 &&
        (unsigned)dword_800ABB58 == 0xc1000001 && memcard_status() == 0) {
        saved = 1;
        puts("[ending] Original memory-card menu completed the save write.");
    }
}

static unsigned short RankButtons(unsigned frame)
{
    if (saved && Work.field_2A_state == MENU_CLOSED) {
        for (const PocketNode *node = PocketEntryNodes; node; node = node->next) {
            if (node->id == 0 && node->enabled == 1 && node->phase == 1 && node->time >= 2) {
                unsigned pulse = pocket_prompt_frames++ % 120;
                if (!pulse)
                    puts("[ending] Selecting No in the original PocketStation prompt.");
                if (pulse < 8)
                    return PAD_RIGHT;
                return pulse >= 30 && pulse < 38 ? PAD_CIRCLE : 0;
            }
        }
    }
    pocket_prompt_frames = 0;
    return frame % 60 < 8 ? PAD_CIRCLE : 0;
}

unsigned short MgsProbeEndingInput(unsigned frame)
{
    if (GM_LoadComplete <= 0 || GM_LoadRequest != 0)
        return 0;
    const char *stage = GM_GetArea(0);
    if (!strcmp(stage, "ending") || !strcmp(stage, "endingr"))
        ObserveEnding();
    else if (!strcmp(stage, "roll"))
        ObserveRoll();
    else if (!strcmp(stage, "rank")) {
        ObserveRank();
        return RankButtons(frame);
    } else if (saved && !returned_to_title && !strcmp(stage, "title")) {
        returned_to_title = 1;
        puts("[ending] Original save callback returned to the title.");
    }
    return 0;
}

int MgsProbeEndingFinish(void)
{
    int complete = fixture_valid && ending_states == 3 && roll_phases == 31 && completion_verified &&
                   earned_item && saved && returned_to_title;
    printf("[ending] %s fixture=%d ending_states=%x credits_phases=%x rank=%d completion=%d "
           "earned_item=%d saved=%d title=%d; fixture entry, no cinematic skip input.\n",
           complete ? "PASS" : "FAIL", fixture_valid, ending_states, roll_phases, rank_seen,
           completion_verified, earned_item, saved, returned_to_title);
    return complete;
}
