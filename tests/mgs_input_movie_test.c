#include "mgs_native.h"

#include "game/game.h"
#include "libgcl/libgcl.h"
#include "mgs_input_movie.h"
#include <psyz/clock.h>
#include <psyz/input.h>
#undef fprintf

short linkvarbuf[MAX_LINKVARBUF];
int GV_Time, GM_LoadComplete, GM_LoadRequest, GV_PauseLevel;
int GM_GameStatus, GM_PlayerStatus, GM_AlertMode, GM_DisableItem;
CONTROL *GM_PlayerControl;
SVECTOR GM_PlayerPosition;

static CONTROL player;
static PsyzPadPollHook hook;
static void *hook_context;
static int clock_calls, host_rumble = 1;
static unsigned checks;
static char *stage;
static const char identity[] = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

enum TestMode {
    RECORD, NORMAL, TAIL_ONE, TAIL_THREE, EARLY_CLOSE, MISMATCH_PACKET,
    MISMATCH_END, RECORD_TAIL, NO_MODE_TAIL, UNKNOWN_MODE
};

static const char *const mode_names[] = {
    "record", "normal", "tail1", "tail3", "early", "mismatch-p",
    "mismatch-e", "record-tail", "no-mode-tail"
};

static void Check(int condition, const char *expression, int line)
{
    ++checks;
    if (!condition) {
        fprintf(stderr, "Input movie test line %d: %s\n", line, expression);
        exit(72);
    }
}

#define CHECK(condition) Check((condition), #condition, __LINE__)

void Psyz_PadsSetPollHook(PsyzPadPollHook value, void *context)
{
    hook = value;
    hook_context = context;
}

int Psyz_PadsSupportsRumble(int port)
{
    return port == 0 ? host_rumble : 0;
}

int Psyz_ClockSetDeterministic(int enabled)
{
    CHECK(enabled == 1);
    ++clock_calls;
    return 0;
}

char *GM_GetArea(int index)
{
    CHECK(index == 0);
    return stage;
}

char *GCL_GetVar(char *token, int *type, int *value)
{
    const unsigned char stage_visit_token[4] = {0x12, 0, 0, 0};
    CHECK(memcmp(token, stage_visit_token, sizeof(stage_visit_token)) == 0);
    *type = 2;
    *value = 128;
    return token + sizeof(stage_visit_token);
}

static void SetState(int n)
{
    stage = n < 20 ? "s01a" : "s99x";
    GV_Time = 100 + n;
    GM_LoadComplete = 1;
    GM_LoadRequest = GV_PauseLevel = 0;
    GM_GameStatus = n * 3;
    GM_PlayerStatus = n * 8;
    GM_PlayerControl = &player;
    GM_PlayerPosition.vx = (short)(n * -120);
    GM_PlayerPosition.vy = (short)(1000 + n);
    GM_PlayerPosition.vz = (short)(n * 390);
    GM_Vitality = (short)(256 - n);
    GM_Item = n & 1 ? IT_Stealth : IT_None;
    GM_Weapon = WP_Socom;
    GM_Weapons[WP_Socom] = (short)(24 - n);
    GM_GameLevel = -1;
    GM_AlertMode = n;
    GM_Configuration = 256;
    GM_DisableItem = 0;
    GM_Items[IT_Stealth] = GM_Items[IT_Bandana] = 1;
}

static void Packet(int n, char frames[2][PSYZ_PAD_BUF_LEN], PsyzControllerKind kinds[2])
{
    kinds[0] = n ? PSYZ_CTRL_ANALOG_PAD : PSYZ_CTRL_DIGITAL_PAD;
    kinds[1] = n ? PSYZ_CTRL_ANALOG_STICK : PSYZ_CTRL_DISCONNECTED;
    for (int port = 0; port < 2; ++port)
        for (int i = 0; i < PSYZ_PAD_BUF_LEN; ++i)
            frames[port][i] = (char)(n * 81 + i * 7 + port * 91);
}

static void Poll(int n, int replay)
{
    char expected[2][PSYZ_PAD_BUF_LEN], actual[2][PSYZ_PAD_BUF_LEN];
    PsyzControllerKind expected_kinds[2], kinds[2];
    Packet(n, expected, expected_kinds);
    memcpy(actual, expected, sizeof(actual));
    memcpy(kinds, expected_kinds, sizeof(kinds));
    if (replay) {
        memset(actual, 0xd7, sizeof(actual));
        kinds[0] = kinds[1] = PSYZ_CTRL_DIGITAL_PAD;
    }
    CHECK(hook != NULL);
    hook(actual, kinds, hook_context);
    CHECK(memcmp(actual, expected, sizeof(actual)) == 0);
    CHECK(memcmp(kinds, expected_kinds, sizeof(kinds)) == 0);
}

static void BadCheckpoint(enum TestMode mode)
{
    char frames[2][PSYZ_PAD_BUF_LEN], before[2][PSYZ_PAD_BUF_LEN];
    PsyzControllerKind kinds[2] = {PSYZ_CTRL_DIGITAL_PAD, PSYZ_CTRL_DIGITAL_PAD};
    ++GM_Vitality;
    if (mode == MISMATCH_PACKET) {
        memset(frames, 0xd7, sizeof(frames));
        memcpy(before, frames, sizeof(before));
        hook(frames, kinds, hook_context);
        CHECK(memcmp(before, frames, sizeof(frames)) == 0);
    }
    CHECK(MgsInputMovieVSync() == 0);
    CHECK(!MgsInputMovieClose());
    CHECK(hook == NULL);
}

static void CheckTail(unsigned count, int early)
{
    CHECK(MgsInputMovieVSync() == 1);
    host_rumble = 0;
    CHECK(MgsInputMovieSupportsRumble(0) == 1);
    for (unsigned i = 1; i <= count; ++i) {
        SetState(100 + (int)i);
        /* Poll count varies independently from VSync count. */
        for (unsigned p = 0; p < i % 3; ++p)
            Poll(1, 1);
        int result = MgsInputMovieVSync();
        CHECK(result == (i == count ? 0 : 1));
        CHECK(result != 2);
        if (early)
            break;
    }
    CHECK(!MgsInputMovieClose());
    CHECK(hook == NULL);
}

static void RejectConfiguration(enum TestMode mode, const char *path)
{
    const char *record = mode == RECORD_TAIL ? path : NULL;
    CHECK(!MgsInputMovieConfigure(record, NULL, identity, 3));
    CHECK(clock_calls == 0 && hook == NULL);
    FILE *file = fopen(path, "rb");
    CHECK(file == NULL);
}

static void RunMovie(enum TestMode mode, const char *path)
{
    int record = mode == RECORD;
    unsigned tail = mode == NORMAL || record ? 0 : mode == TAIL_ONE ? 1 : 3;
    CHECK(MgsInputMovieConfigure(record ? path : NULL, record ? NULL : path, identity, tail));
    CHECK(clock_calls == 1);
    if (mode == MISMATCH_PACKET) {
        BadCheckpoint(mode);
        return;
    }
    Poll(0, !record);
    SetState(1);
    CHECK(MgsInputMovieVSync() == 1);
    Poll(1, !record);
    SetState(2);
    if (mode == MISMATCH_END) {
        BadCheckpoint(mode);
    } else if (record || !tail) {
        CHECK(MgsInputMovieVSync() == (record ? 1 : 2));
        CHECK(MgsInputMovieClose());
        CHECK(hook == NULL);
    } else {
        CheckTail(tail, mode == EARLY_CLOSE);
    }
}

static enum TestMode ParseMode(const char *name)
{
    for (unsigned i = 0; i < sizeof(mode_names) / sizeof(mode_names[0]); ++i)
        if (!strcmp(name, mode_names[i]))
            return (enum TestMode)i;
    return UNKNOWN_MODE;
}

int main(int argc, char **argv)
{
    if (argc != 3)
        return 2;
    enum TestMode mode = ParseMode(argv[1]);
    if (mode == UNKNOWN_MODE) {
        fprintf(stderr, "Unknown input movie test case: %s\n", argv[1]);
        return 2;
    }
    SetState(0);
    if (mode == RECORD_TAIL || mode == NO_MODE_TAIL)
        RejectConfiguration(mode, argv[2]);
    else
        RunMovie(mode, argv[2]);
    printf("TESTCASE_OK %s checks=%u\n", argv[1], checks);
    fflush(stdout);
    return 0;
}
