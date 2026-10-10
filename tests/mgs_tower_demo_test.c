#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include "libgcl/libgcl.h"
#include "takabe/fadeio.h"
#include "takabe/spark2.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>

short linkvarbuf[MAX_LINKVARBUF];
int GM_GameStatus, GM_CurrentMap, GM_PadVibration, GM_PadVibration2;
SVECTOR GM_PlayerPosition;
UnkCameraStruct2 gUnkCameraStruct2_800B7868;
static uint32_t random_state, boundary_trace, random_calls;

static void Trace(uint32_t value)
{
    boundary_trace = (boundary_trace * 33 + value) & 0x7fffffffu;
}

int GV_RandU(int range)
{
    int result;
    assert(range > 0 && (range & (range - 1)) == 0);
    random_state = random_state * 1664525u + 1013904223u;
    result = (random_state >> 16) & (range - 1);
    ++random_calls;
    Trace(1);
    Trace(range);
    Trace(result);
    return result;
}

void GM_SeSet2(int pan, int volume, int sound)
{
    Trace(2); Trace(pan); Trace(volume); Trace(sound);
}

void GM_SeSetMode(SVECTOR *position, int sound, int mode)
{
    Trace(3); Trace(position->vx); Trace(position->vy); Trace(position->vz);
    Trace(sound); Trace(mode);
}

void GV_DestroyActor(void *actor)
{
    assert(actor);
    Trace(4);
}

void *NewFadeInOut(int mode, int shade)
{
    Trace(5); Trace(mode); Trace(shade);
    return NULL;
}

int GV_StrCode(const char *name) { assert(strcmp(name, "stn_fr") == 0); return 0; }
void GM_InitObject(OBJECT *object, int model, int flag, int motion)
{
    assert(object && model == 0 && flag == 101 && motion == 0);
}
void GM_ConfigObjectJoint(OBJECT *object) { assert(object); }
void GM_ConfigObjectLight(OBJECT *object, MATRIX *light) { assert(object && light); }
char *GCL_GetOption(char option) { assert(option == 'p'); return NULL; }
int GCL_StrToInt(char *text) { assert(text); return 0; }

static void SmokeTrace(int kind, SVECTOR *position)
{
    Trace(kind); Trace(position->vx); Trace(position->vy); Trace(position->vz);
}
void AN_Unknown_800D6F6C(SVECTOR *position) { SmokeTrace(8, position); }
void AN_Unknown_800D7028(SVECTOR *position, int script)
{
    SmokeTrace(9, position); Trace(script);
}
void AN_Unknown_800D70E4(SVECTOR *position, char r, char g, char b)
{
    SmokeTrace(10, position); Trace(r); Trace(g); Trace(b);
}
void *NewSpark2_800CA714(MATRIX *world)
{
    assert(!world && "Spark modes are outside this physics fixture");
    return NULL;
}
void DG_SetPos2(SVECTOR *position, SVECTOR *rotation)
{
    assert(!position && !rotation && "Spark transforms are outside this physics fixture");
}

#include "tower_demo_helpers.inc"
#include "mgs_tower_demo_fixtures.h"

_Static_assert(sizeof(Stage11BWork) == 0x6b0c, "Tower cinematic actor layout");

static int Stage11BInitPrim(Stage11BWork *work) { assert(work); return 0; }
static void Stage11BDebris(Stage11BWork *work)
{
    for (int i = 0; i < 16; ++i)
        assert(work->debris_state[i] == 3);
}
static void Stage11BUpdatePackets(Stage11BWork *work) { assert(work); Trace(6); }
static void Stage11BCamera(Stage11BWork *work) { assert(work); Trace(7); }

static uint32_t HashBytes(const void *data, size_t size)
{
    const unsigned char *bytes = data;
    uint32_t hash = 2166136261u;
    for (size_t i = 0; i < size; ++i)
        hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static void CheckResources(void)
{
    Stage11BWork work = {0};
    GM_GameStatus = 0x10;
    GM_Item = IT_Scope;
    GM_Weapon = WP_Stinger;
    assert(Stage11BGetResources(&work, 0x1234, 0x5678) == 0);
    assert(HashBytes(&work, sizeof(work)) == stage11b_resource_hash);
    assert(GM_GameStatus == 0x104a0010 && GM_Item == IT_None && GM_Weapon == WP_None);
}

static void CheckCameraStates(void)
{
    static const int timers[] = {-1, 0, 20, 21, 39, 90};
    for (unsigned int index = 0; index < 96; ++index)
    {
        Stage11BWork work = {0};
        int64_t actual[5];
        random_state = index + 93;
        boundary_trace = random_calls = 0;
        work.map = 0x5678;
        for (int i = 0; i < 16; ++i)
            work.debris_state[i] = 3;
        work.state = index % 4;
        work.timer = timers[index / 4 % 6];
        work.flash = index % 5;
        work.camera_goal = (SVECTOR){3000, -2000, 5000, 0};
        work.target_goal = (SVECTOR){-6000, 4000, 9000, 0};
        work.camera = (SVECTOR){1234, -2345, 3456, 0};
        work.target = (SVECTOR){-4567, 5678, -6789, 0};
        gUnkCameraStruct2_800B7868.position = (SVECTOR){1000, 2000, 3000, 0};
        gUnkCameraStruct2_800B7868.target = (SVECTOR){-4000, 5000, 6000, 0};
        GM_PlayerPosition = (SVECTOR){777, 888, 999, 0};
        GM_PadVibration = -1;
        GM_PadVibration2 = -2;
        Stage11BAct(&work);
        actual[0] = HashBytes(&work, sizeof(work));
        actual[1] = random_calls;
        actual[2] = boundary_trace;
        actual[3] = GM_PadVibration;
        actual[4] = GM_PadVibration2;
        assert(memcmp(actual, stage11b_state_fixtures[index], sizeof(actual)) == 0);
    }
}

static void CheckRibbon(void)
{
    for (int index = 0; index < 640; ++index)
    {
        Stage11BWork work = {0};
        int group = index / 40;
        int current = index % 40;
        int previous = group * 40 + (current ? current - 1 : 39);
        SVECTOR position = {index * 5 - 1400, index * 19 - 1800, index * 23 - 2700, 51};
        work.ribbon_index[group] = current;
        work.vertices[previous * 4] =
            (SVECTOR){index * 13 - 3000, index * 7 - 900, index * 11 - 1200, 71};
        work.vertices[previous * 4 + 2] =
            (SVECTOR){index * 9 - 1000, index * 3 - 500, index * 17 - 2400, 93};
        Stage11BRibbon(&work, &position, group);
        assert(HashBytes(&work, sizeof(work)) == stage11b_ribbon_hashes[index]);
    }
}

static void CheckCrashSmoke(void)
{
    static const int timers[] = {-1, 0, 1, 15, 30, 31};
    for (int index = 0; index < 96; ++index)
    {
        CrashSmokeWork work = {0};
        boundary_trace = random_calls = 0;
        random_state = index + 200;
        work.map = 0x321;
        work.script = work.smoke_type = index % 4;
        work.effect = index % 2;
        work.timer = timers[index / 4 % 6];
        work.counter = index * 3;
        work.r = 17; work.g = 128; work.b = 255;
        for (int i = 0; i < 4; ++i)
        {
            work.velocities[i] = (SVECTOR){index * 97 % 32768 - 16000,
                index * 73 % 32768 - 10000, index * 59 % 32768 - 8000, 51};
            work.positions[i] = (SVECTOR){32700 - i * 100, -32700 + i * 31,
                index * 223 % 32768, 97};
        }
        CrashSmokeAct(&work);
        assert(HashBytes(&work, sizeof(work)) == crash_smoke_fixtures[index][0]);
        assert(boundary_trace == crash_smoke_fixtures[index][1]);
    }
}

int main(void)
{
    CheckResources();
    CheckCameraStates();
    CheckRibbon();
    CheckCrashSmoke();
    puts("Tower demo: 737 original-MIPS initialization, camera/state and ribbon cases passed.");
    puts("Crash smoke: 96 original-MIPS physics/effect cases passed.");
    return 0;
}
