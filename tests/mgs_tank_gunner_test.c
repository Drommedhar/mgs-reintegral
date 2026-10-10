#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include "chara/snake/sna_init.h"
#include <assert.h>

int GM_PlayerStatus;
int GM_CurrentMap;
short GM_uTenageMotion;
CONTROL *GM_PlayerControl;

int HZD_LevelHazardCheckOne(HZD_FLR *floor, SVECTOR *from)
{
    (void)floor;
    (void)from;
    return 0;
}

void GM_SeSetPan(SVECTOR *pos, int sound, int volume)
{
    (void)pos;
    (void)sound;
    (void)volume;
    assert(!"Unexpected tank sound in target retirement fixture");
}

#define UNUSED_COLLISION(name) \
    void name(CONTROL *control, HZD_HDL *hzd) { \
        (void)control; (void)hzd; assert(!"Unexpected collision path"); \
    }
UNUSED_COLLISION(s05a_800E0D38)
UNUSED_COLLISION(s05a_800E0E28)
UNUSED_COLLISION(s05a_800E0F64)
UNUSED_COLLISION(s05a_800E1014)

void GV_NearExp4PV(void *from, void *to, int n)
{
    (void)from; (void)to; (void)n;
    assert(!"Unexpected interpolation");
}

void GV_NearTimePV(void *from, void *to, int time, int n)
{
    (void)time;
    GV_NearExp4PV(from, to, n);
}

void HZD_EnterTrap(HZD_HDL *hzd, HZD_EVT *event)
{
    (void)hzd; (void)event;
    assert(!"Unexpected trap entry");
}

void DG_SetPos2(SVECTOR *position, SVECTOR *rotation)
{
    (void)position; (void)rotation;
    assert(!"Unexpected matrix update");
}

#include "tank_gunner_helpers.inc"

static void CheckAim(CamActor *tank, SnaInitWork *snake, TARGET *target)
{
    tank->field_DF4 = 1024;
    tank->field_DF8 = 11000;
    for (int far = 0; far < 2; ++far) {
        tank->control.mov.vz = target->center.vz = far ? 9000 : 4000;
        for (int direction = 0; direction < 3; ++direction) {
            static const int rotations[] = {600, 0, -600};
            static const int motions[] = {2, 0, 1};
            snake->control.rot.vy = rotations[direction];
            assert(s05a_800E00EC(&snake->actor) == 0);
            assert(GM_uTenageMotion == motions[direction] + far * 3);
        }
    }
}

int main(void)
{
    CamActor tank = {0};
    CamEb0 gunner = {0};
    TARGET target = {0}, parts[10] = {0};
    SnaInitWork snake = {0};
    s05a_dword_800C362C = &tank;
    GM_PlayerControl = &snake.control;
    for (int i = 0; i < 10; ++i)
        tank.field_718[i] = &parts[i];
    CheckAim(&tank, &snake, &target);
    tank.field_EB0 = &gunner;
    CheckAim(&tank, &snake, &target);
    u_short flags = 0;
    assert(s05a_800DF834(0, &target.center, &flags) == 0 && flags == 0);
    for (int mode = 0; mode < 2; ++mode) {
        tank.field_ED0 = mode;
        tank.field_F4C = 1;
        for (int i = 0; i < 10; ++i) {
            parts[i].vital = 7;
            parts[i].damage = parts[i].damaged = 3;
        }
        assert(s05a_800DF9C8(&target, 4) == mode);
        for (int i = 0; i < 10; ++i)
            assert(parts[i].vital == 10000 && !parts[i].damage && !parts[i].damaged);
    }
    gunner.field_1C0 = &target;
    CheckAim(&tank, &snake, &target);
    snake.control.rot.vy = 0;
    target.center = (SVECTOR){4000, 0, 4000, 0};
    tank.control.mov = (SVECTOR){0, 0, 4000, 0};
    assert(s05a_800E00EC(&snake.actor) == 0 && GM_uTenageMotion == 1);
    gunner.field_1C0 = NULL;
    assert(s05a_800E00EC(&snake.actor) == 0 && GM_uTenageMotion == 0);
    puts("PASS: absent, dying and live gunner aim; retired target blast hooks.");
    return 0;
}
