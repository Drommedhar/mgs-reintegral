#include "mgs_godot_cinematic.h"
#include <assert.h>
#include <stdio.h>

static uint32_t epoch = 1;
uint32_t MgsGodotSceneEpoch(void) { return epoch; }

int main(void)
{
    int owner, other;
    MgsGodotCinematicSelect(5, 1, 0);
    MgsGodotCinematicOpen(&owner, 1);
    MgsGodotCinematicStart(&owner, 240);
    MgsGodotCinematic state = MgsGodotCinematicState();
    assert(state.active && state.sector == 0 && state.frame == -1);
    MgsGodotCinematicApply(&owner, 43);
    MgsGodotCinematicApply(&other, 44);
    assert(MgsGodotCinematicState().frame == 43);
    MgsGodotCinematicEnd(&other);
    assert(MgsGodotCinematicState().active);
    MgsGodotCinematicEnd(&owner);
    assert(!MgsGodotCinematicState().active);
    MgsGodotCinematicOpen(&other, 1);
    MgsGodotCinematicStart(&other, 100);
    assert(!MgsGodotCinematicState().active);
    MgsGodotCinematicSelect(5, 2, 0x1234);
    MgsGodotCinematicOpen(&owner, 1);
    MgsGodotCinematicStart(&owner, 100);
    MgsGodotCinematicApply(&owner, 80);
    state = MgsGodotCinematicState();
    assert(state.active && state.disc == 2 && state.sector == 0x1234 && state.generation == 3);
    ++epoch;
    assert(!MgsGodotCinematicState().active);
    MgsGodotCinematicOpen(&other, 0);
    MgsGodotCinematicStart(&other, 100);
    assert(!MgsGodotCinematicState().active);
    puts("Godot cinematic source, frame and lifetime tests passed");
    return 0;
}
