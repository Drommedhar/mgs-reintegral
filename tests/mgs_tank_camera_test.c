#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include <assert.h>
#include <stddef.h>

GM_CameraSystemWork GM_Camera;
GM_SnakeCameraWork GM_SnakeCamera;
SVECTOR GM_PlayerPosition;
int GM_GameStatus;
int GM_CurrentMap;
int GV_PauseLevel;
static int callback_calls, freed, dispatched;
const char s05a_dword_800E35E4[] = "nosubject";

static void CheckTankCameraCallback(void);
void s05a_800E1AA8(void) { CheckTankCameraCallback(); }
void s05a_800E1C14(void) { CheckTankCameraCallback(); }
void s05a_800E1D7C(void) { CheckTankCameraCallback(); }
void s05a_800E1F0C(void) { CheckTankCameraCallback(); }
void s05a_800E1A68(void);

void GM_SetCameraCallbackFunc(int index, TGMCameraFunc callback)
{
    GM_Camera.callback[index] = callback;
}

void sub_800309B4(int first, int second)
{
    (void)first; (void)second;
    assert(!"Unexpected camera transition");
}

void sub_8007EF34(SVECTOR *position, SVECTOR *rotation, MATRIX *matrix)
{
    (void)position; (void)rotation; (void)matrix;
    assert(!"Unexpected model read");
}

void *NewCinemaScreen(int time, int type)
{
    (void)time; (void)type;
    assert(!"Unexpected cinema screen creation");
    return NULL;
}

void *NewCinemaScreenClose(void *screen)
{
    (void)screen;
    assert(!"Unexpected cinema screen closure");
    return NULL;
}

int GV_StrCode(const char *text)
{
    (void)text;
    assert(!"Unexpected hazard lookup");
    return 0;
}

#include "tank_camera_helpers.inc"

_Static_assert(sizeof(Camera) == 0x90, "Retail Tank camera layout");
_Static_assert(offsetof(CamActor, field_D54) == 0xd54, "Tank lifecycle mode");

static void CheckTankCameraCallback(void)
{
    assert(s05a_dword_800C362C != NULL);
    assert(s05a_dword_800C38CC != NULL);
    ++callback_calls;
}

static void OtherCamera(void) { ++callback_calls; }

static void FreeCamera(void *camera)
{
    assert(s05a_dword_800C38CC == NULL);
    memset(camera, 0xdd, sizeof(Camera));
    ++freed;
}

static void Dispatch(GV_ACT *actor)
{
    (void)actor;
    ++dispatched;
    for (int slot = 0; slot < 2; ++slot)
        if (GM_Camera.callback[slot])
            GM_Camera.callback[slot]();
}

static void CheckLifetime(int state, TGMCameraFunc callback, int foreign)
{
    Camera camera = {0};
    CamActor tank = {0};
    GV_ACT dispatcher = {0};
    GV_InitActorSystem();
    memset(&GM_Camera, 0, sizeof(GM_Camera));
    callback_calls = freed = dispatched = 0;
    tank.field_D54 = state == 1 ? 6 : 5;
    tank.field_ED0 = 2;
    camera.field_60 = 3;
    s05a_dword_800C362C = state == 0 ? NULL : &tank;
    s05a_dword_800C38CC = &camera;
    GM_Camera.flag = 0x202 | 0x40;
    GM_Camera.callback[0] = foreign ? OtherCamera : callback;
    GM_Camera.callback[1] = callback;
    GV_InitActor(GV_ACTOR_USER, &camera, FreeCamera);
    GV_SetNamedActor(&camera, s05a_800E1448, s05a_800E1A68, "tank-camera");
    GV_InitActor(GV_ACTOR_USER, &dispatcher, NULL);
    GV_SetNamedActor(&dispatcher, Dispatch, NULL, "camera-dispatch");
    GV_ExecActorSystem();
    const int retired = state != 2;
    assert(dispatched == 1 && freed == 0);
    assert(callback_calls == (retired ? foreign : 2));
    if (retired) {
        assert(GM_Camera.callback[1] == NULL);
        assert(GM_Camera.callback[0] == (foreign ? OtherCamera : NULL));
        assert(GM_Camera.flag == (foreign ? 0x240 : 0x40));
        GV_ExecActorSystem();
        assert(dispatched == 2 && freed == 1);
    } else {
        assert(s05a_dword_800C38CC == &camera && GM_Camera.flag == 0x242);
        GV_DestroyActor(&camera);
        GV_ExecActorSystem();
        assert(freed == 1 && dispatched == 2);
        assert(callback_calls == 2 + foreign);
    }
}

static void RetireDirector(GV_ACT *actor)
{
    s05a_ClearTankCameraCallbacks();
    s05a_dword_800C362C = NULL;
    actor->act = NULL;
}

static void CheckCameraRunsFirst(void)
{
    CamActor tank = {0};
    Camera camera = {0};
    GV_ACT dispatcher = {0}, director = {0};
    GV_InitActorSystem();
    callback_calls = freed = dispatched = 0;
    s05a_dword_800C362C = &tank;
    s05a_dword_800C38CC = &camera;
    GM_Camera.flag = 0x202;
    GM_Camera.callback[0] = GM_Camera.callback[1] = s05a_800E1D7C;
    GV_InitActor(GV_ACTOR_ASSIST, &dispatcher, NULL);
    GV_SetNamedActor(&dispatcher, Dispatch, NULL, "camera-system");
    GV_InitActor(GV_ACTOR_USER, &director, NULL);
    GV_SetNamedActor(&director, RetireDirector, NULL, "tank-director");
    GV_InitActor(GV_ACTOR_USER, &camera, FreeCamera);
    GV_SetNamedActor(&camera, s05a_800E1448, s05a_800E1A68, "tank-camera");
    GV_ExecActorSystem();
    assert(callback_calls == 2 && freed == 0 && dispatched == 1);
    GV_ExecActorSystem();
    assert(callback_calls == 2 && freed == 1 && dispatched == 2);
    assert(GM_Camera.flag == 0);
}

int main(void)
{
    const TGMCameraFunc callbacks[] = {
        s05a_800E1AA8, s05a_800E1C14, s05a_800E1D7C, s05a_800E1F0C
    };
    for (unsigned i = 0; i < sizeof(callbacks) / sizeof(callbacks[0]); ++i)
        for (int state = 0; state < 3; ++state)
            for (int foreign = 0; foreign < 2; ++foreign)
                CheckLifetime(state, callbacks[i], foreign);
    CheckCameraRunsFirst();
    puts("PASS: 24 camera lifetime cases and camera-before-director scheduling.");
    return 0;
}
