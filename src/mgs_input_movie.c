#include <stdint.h>
#include <psyz/clock.h>
#include <psyz/input.h>
#include "mgs_native.h"
#include "game/game.h"
#include "libgcl/libgcl.h"
#include "mgs_input_log.h"
#include "mgs_input_movie.h"
#undef fprintf

static MgsInputLog movie;
static MgsInputSample next, checkpoint;
static MgsInputSample held_input;
static unsigned samples, vsync;
static unsigned tail_limit, tail_start;
static int active, recording, failed, finished, next_type, checkpoint_valid;
static int tail_active;
static int rumble[2];

unsigned MgsInputMovieSamples(void)
{
    return samples;
}

static const char *const state_names[MGS_INPUT_STATE_FIELDS] = {
    "game tick", "load complete", "load request", "pause", "game flags",
    "player flags", "player present", "x", "y", "z", "health", "item",
    "weapon", "ammo", "difficulty", "stage visit byte", "rumble port 1", "rumble port 2",
    "alert", "configuration", "inventory checksum", "disabled items"
};

int MgsInputMovieReplaying(void)
{
    return active && !recording;
}

int MgsInputMovieSupportsRumble(int port)
{
    if (MgsInputMovieReplaying())
        return port >= 0 && port < 2 ? rumble[port] : 0;
    return Psyz_PadsSupportsRumble(port);
}

static uint32_t InventoryChecksum(void)
{
    uint32_t hash = 2166136261u;
    for (int i = 0; i < 24; ++i)
        hash = (hash ^ (uint16_t)GM_Items[i]) * 16777619u;
    for (int i = 0; i < 10; ++i) {
        hash = (hash ^ (uint16_t)GM_Weapons[i]) * 16777619u;
        hash = (hash ^ (uint16_t)GM_WeaponsMax[i]) * 16777619u;
    }
    return hash;
}

static void CaptureState(MgsInputSample *sample)
{
    char stage_visit_token[4] = {0x12, 0, 0, 0};
    int type, stage_visit;
    GCL_GetVar(stage_visit_token, &type, &stage_visit);
    sample->sample = samples;
    sample->vsync = vsync;
    snprintf(sample->stage, sizeof(sample->stage), "%s", GM_GetArea(0));
    int values[MGS_INPUT_STATE_FIELDS] = {
        GV_Time, GM_LoadComplete, GM_LoadRequest, GV_PauseLevel,
        GM_GameStatus, GM_PlayerStatus, GM_PlayerControl != NULL,
        GM_PlayerPosition.vx, GM_PlayerPosition.vy, GM_PlayerPosition.vz,
        GM_Vitality, GM_Item, GM_Weapon,
        GM_Weapon >= 0 && GM_Weapon < 10 ? GM_Weapons[GM_Weapon] : -1,
        GM_GameLevel, stage_visit, MgsInputMovieSupportsRumble(0),
        MgsInputMovieSupportsRumble(1), GM_AlertMode, GM_Configuration,
        (int)InventoryChecksum(), (int)GM_DisableItem
    };
    memcpy(sample->state, values, sizeof(values));
}

static int Fail(const char *reason)
{
    if (!failed)
        fprintf(stderr, "[input] FAIL at sample=%u vsync=%u: %s\n", samples, vsync, reason);
    failed = 1;
    return 0;
}

static int CompareCheckpoint(const MgsInputSample *actual, const MgsInputSample *expected)
{
    if (actual->sample != expected->sample || actual->vsync != expected->vsync ||
        strcmp(actual->stage, expected->stage)) {
        fprintf(stderr, "[input] Expected sample=%u vsync=%u stage=%s; actual=%u/%u/%s.\n",
                expected->sample, expected->vsync, expected->stage,
                actual->sample, actual->vsync, actual->stage);
        return Fail("input timing or stage diverged");
    }
    for (unsigned i = 0; i < MGS_INPUT_STATE_FIELDS; ++i) {
        if (actual->state[i] != expected->state[i]) {
            fprintf(stderr, "[input] %s: expected=%d actual=%d.\n",
                    state_names[i], expected->state[i], actual->state[i]);
            return Fail("game checkpoint diverged");
        }
    }
    return 1;
}

static void InputSample(char frames[2][PSYZ_PAD_BUF_LEN],
                        PsyzControllerKind kinds[2], void *context)
{
    MgsInputSample sample = {0};
    (void)context;
    if (failed)
        return;
    if (tail_active) {
        memcpy(frames, held_input.pads, sizeof(held_input.pads));
        kinds[0] = (PsyzControllerKind)held_input.kinds[0];
        kinds[1] = (PsyzControllerKind)held_input.kinds[1];
        ++samples;
        return;
    }
    if (!recording) {
        if (next_type != 1) {
            Fail("unexpected input sample after the recorded stream");
            return;
        }
        rumble[0] = next.state[16];
        rumble[1] = next.state[17];
    }
    CaptureState(&sample);
    if (recording) {
        memcpy(sample.pads, frames, sizeof(sample.pads));
        sample.kinds[0] = kinds[0];
        sample.kinds[1] = kinds[1];
        if (!MgsInputLogWriteSample(&movie, &sample)) {
            Fail(MgsInputLogError(&movie));
            return;
        }
    } else {
        if (!CompareCheckpoint(&sample, &next))
            return;
        memcpy(frames, next.pads, sizeof(next.pads));
        kinds[0] = (PsyzControllerKind)next.kinds[0];
        kinds[1] = (PsyzControllerKind)next.kinds[1];
        held_input = next;
        next_type = MgsInputLogReadNext(&movie, &next);
        if (!next_type)
            Fail(MgsInputLogError(&movie));
    }
    ++samples;
}

int MgsInputMovieVSync(void)
{
    if (!active)
        return 1;
    if (failed)
        return 0;
    ++vsync;
    if (tail_active) {
        if (vsync - tail_start >= tail_limit)
            return Fail("diagnostic held-input tail ended; recording completion remains unverified");
        return 1;
    }
    CaptureState(&checkpoint);
    checkpoint_valid = 1;
    if (!recording && next_type == 2 && vsync >= next.vsync) {
        if (!CompareCheckpoint(&checkpoint, &next))
            return 0;
        if (tail_limit) {
            tail_active = 1;
            tail_start = vsync;
            fprintf(stderr, "[input] DIAGNOSTIC: verified prefix through %u samples/%u VSyncs. "
                    "Holding the last recorded controller packets for %u unrecorded VSyncs; "
                    "checkpoint checks are suspended and this run cannot report replay success.\n",
                    samples, vsync, tail_limit);
            return 1;
        }
        finished = 1;
        printf("[input] PASS replay: %u input samples, %u VSyncs; final stage=%s.\n",
               samples, vsync, checkpoint.stage);
        return 2;
    }
    return 1;
}

int MgsInputMovieClose(void)
{
    if (!active)
        return !failed;
    Psyz_PadsSetPollHook(NULL, NULL);
    if (recording && !failed) {
        if (!checkpoint_valid || !samples || checkpoint.sample != samples)
            Fail("recording stopped without a complete input boundary");
        else {
            checkpoint.kinds[0] = checkpoint.kinds[1] = PSYZ_CTRL_DISCONNECTED;
            if (!MgsInputLogWriteEnd(&movie, &checkpoint))
                Fail(MgsInputLogError(&movie));
        }
    } else if (!recording && !finished && !failed) {
        Fail(tail_active ? "diagnostic held-input tail stopped; recording completion remains unverified" :
                          "replay stopped before its verified endpoint");
    }
    if (!MgsInputLogClose(&movie))
        Fail(MgsInputLogError(&movie));
    active = 0;
    if (recording && !failed)
        printf("[input] Recorded %u samples through VSync %u.\n", samples, vsync);
    return !failed;
}

static void CloseAtExit(void)
{
    if (!MgsInputMovieClose()) {
        fputs("[input] Input movie did not complete successfully.\n", stderr);
        _Exit(EXIT_FAILURE);
    }
}

int MgsInputMovieConfigure(const char *record, const char *replay, const char *identity,
                          unsigned diagnostic_tail_frames)
{
    if (diagnostic_tail_frames && (!replay || record))
        return Fail("diagnostic held-input tails require replay mode");
    if (!record && !replay)
        return identity == NULL;
    if ((record && replay) || !identity || active)
        return Fail("choose record or replay with an input identity");
    if (Psyz_ClockSetDeterministic(1) != 0)
        return Fail("this backend cannot run the deterministic input clock");
    recording = record != NULL;
    tail_limit = diagnostic_tail_frames;
    int opened = recording ? MgsInputLogOpenWrite(&movie, record, identity) :
        MgsInputLogOpenRead(&movie, replay, identity);
    if (!opened)
        return Fail(MgsInputLogError(&movie));
    active = 1;
    if (atexit(CloseAtExit) != 0)
        return Fail("cannot register input movie shutdown");
    if (!recording) {
        next_type = MgsInputLogReadNext(&movie, &next);
        if (next_type != 1)
            return Fail("replay contains no input samples");
    }
    Psyz_PadsSetPollHook(InputSample, NULL);
    printf("[input] %s: %s\n", recording ? "Recording" : "Replaying", record ? record : replay);
    return 1;
}
