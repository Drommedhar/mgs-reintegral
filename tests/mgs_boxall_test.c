#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include <assert.h>
#include <math.h>

CONTROL *GM_PlayerControl;
SVECTOR GM_PlayerPosition;
GM_CameraSystemWork GM_Camera;
DG_CHANL DG_Chanls[3];
int GV_Clock;

void MENU_Color(int red, int green, int blue)
{ (void)red; (void)green; (void)blue; assert(0); }
void MENU_Locate(int x, int y, int flags)
{ (void)x; (void)y; (void)flags; assert(0); }
int MENU_Printf(const char *format, ...) { (void)format; assert(0); return 0; }
void GV_SubVec3(SVECTOR *a, SVECTOR *b, SVECTOR *out)
{ out->vx = a->vx - b->vx; out->vy = a->vy - b->vy; out->vz = a->vz - b->vz; }
int GV_VecLen3(SVECTOR *v)
{ return (int)sqrt(v->vx * v->vx + v->vy * v->vy + v->vz * v->vz); }

#include "boxall_helpers.inc"

int main(void)
{
    Work box = {0};
    CONTROL player = {0};
    _set_error_mode(_OUT_TO_STDERR);
    box.control.mov = (SVECTOR){-1200, 207, 2900, 0};
    GM_PlayerPosition = box.control.mov;
    for (int first_person = 0; first_person <= 2; ++first_person) {
        GM_Camera.first_person = first_person;
        GM_PlayerControl = NULL;
        box.f104 = 35;
        DrawItemText(&box);
        assert(box.f104 == 0 && !HasCollectedItem(&box));
        GM_PlayerControl = &player;
        player.mov = GM_PlayerPosition;
        DrawItemText(&box);
        assert(box.f104 == (first_person != 0));
        assert(HasCollectedItem(&box));
    }
    GM_PlayerPosition.vx += 500;
    assert(!HasCollectedItem(&box));
    GM_PlayerPosition.vx--;
    assert(HasCollectedItem(&box));
    GM_PlayerPosition.vy += 1000;
    assert(!HasCollectedItem(&box));
    GM_PlayerPosition.vy--;
    assert(HasCollectedItem(&box));
    puts("Item box tolerates absent cutscene players and retains pickup distances.");
    return 0;
}
