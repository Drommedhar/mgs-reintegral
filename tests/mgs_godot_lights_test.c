#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "libdg/libdg.h"
#include <assert.h>
#include <math.h>

int DG_CurrentGroupID = 1;
static DG_LIT temporary[8];
static unsigned temporary_count;

unsigned MgsGodotCopyTemporaryLights(void *destination, unsigned capacity) {
    assert(temporary_count <= capacity);
    memcpy(destination, temporary, temporary_count * sizeof(DG_LIT));
    return temporary_count;
}

static uint32_t ReadInteger(const unsigned char *data, unsigned offset) {
    uint32_t value;
    memcpy(&value, data + offset, sizeof(value));
    return value;
}

static float ReadFloat(const unsigned char *data, unsigned offset) {
    float value;
    memcpy(&value, data + offset, sizeof(value));
    return value;
}

static void CheckAlarmPair(void) {
    unsigned char data[124];
    DG_OBJS beams[2] = {0};
    for (int i = 0; i < 2; ++i) {
        beams[i].world.m[0][0] = i ? -4096 : 4096;
        beams[i].world.t[0] = 1000;
        beams[i].world.t[1] = 2000;
        beams[i].world.t[2] = 3000;
        MgsGodotRegisterAlarmLight(&beams[i], i == 0);
        MgsGodotRegisterAlarmLight(&beams[i], i == 0);
        assert(beams[i].flag & MGS_GODOT_LEGACY_GLOW);
    }
    assert(MgsGodotAppendLights(data, sizeof(data)) == 124 && ReadInteger(data, 0) == 3);
    assert(ReadInteger(data, 8) == 3 && ReadInteger(data, 48) == 4 && ReadInteger(data, 88) == 3);
    assert(ReadInteger(data, 4) != ReadInteger(data, 44));
    assert(ReadInteger(data, 44) != ReadInteger(data, 84));
    assert(ReadFloat(data, 24) == 1 && ReadFloat(data, 104) == -1);
    assert(ReadFloat(data, 52) == 1 && ReadFloat(data, 56) == -2 && ReadFloat(data, 60) == -3);
    for (unsigned offset = 64; offset < 84; offset += 4) assert(ReadFloat(data, offset) == 0);
    assert(fabsf(ReadFloat(data, 12) - 1.122f) < 0.0001f);
    assert(ReadFloat(data, 16) == -2 && ReadFloat(data, 20) == -3);
    for (int i = 0; i < 2; ++i) {
        beams[i].world.m[0][0] = 0;
        beams[i].world.m[2][0] = i ? -4096 : 4096;
    }
    assert(MgsGodotAppendLights(data, sizeof(data)) == 124);
    assert(ReadFloat(data, 32) == -1 && ReadFloat(data, 112) == 1);
    assert(ReadFloat(data, 52) == 1 && ReadFloat(data, 56) == -2 && ReadFloat(data, 60) == -3);
    beams[0].flag |= DG_FLAG_INVISIBLE;
    beams[1].group_id = 2;
    assert(MgsGodotAppendLights(data, sizeof(data)) == 4);
    beams[0].flag &= ~DG_FLAG_INVISIBLE;
    beams[1].group_id = 1;
    assert(MgsGodotAppendLights(data, sizeof(data)) == 124);
    for (int i = 0; i < 2; ++i) MgsGodotRemoveAlarmLight(&beams[i]);
    assert(MgsGodotAppendLights(data, sizeof(data)) == 4);
}

int main(void) {
    unsigned char data[5500];
    SVECTOR position = {0, -400, 60, 0};
    DG_PRIM weapon = {0};
    weapon.pos = &position;
    MgsGodotRegisterWeaponLight(&weapon);
    assert(MgsGodotAppendLights(data, sizeof(data)) == 4);
    weapon.world.m[0][0] = 4096;
    weapon.world.m[1][2] = 4096;
    weapon.world.m[2][1] = -4096;
    weapon.world.t[0] = 1000;
    weapon.world.t[1] = 2000;
    weapon.world.t[2] = 3000;
    MgsGodotRegisterWeaponLight(&weapon);
    MgsGodotRegisterWeaponLight(&weapon);
    assert(MgsGodotAppendLights(data, sizeof(data)) == 44);
    assert(ReadInteger(data, 0) == 1 && ReadInteger(data, 8) == 2);
    uint32_t identity = ReadInteger(data, 4);
    assert(identity > 8);
    assert(fabsf(ReadFloat(data, 12) - 1.0f) < 0.0001f);
    assert(fabsf(ReadFloat(data, 16) + 2.06f) < 0.0001f);
    assert(fabsf(ReadFloat(data, 20) + 3.4f) < 0.0001f);
    assert(ReadFloat(data, 24) == 0 && ReadFloat(data, 28) == 0 && ReadFloat(data, 32) == -1);
    weapon.type |= DG_PRIM_INVISIBLE;
    assert(MgsGodotAppendLights(data, sizeof(data)) == 4);
    weapon.type &= ~DG_PRIM_INVISIBLE;
    weapon.group_id = 2;
    assert(MgsGodotAppendLights(data, sizeof(data)) == 4);
    weapon.group_id = 1;
    temporary[0].point = (SVECTOR){3000, 4000, 5000, 0};
    temporary[0].r_range = 512;
    temporary[0].e_range = 1000;
    temporary_count = 1;
    assert(MgsGodotAppendLights(data, sizeof(data)) == 84);
    assert(ReadInteger(data, 0) == 2 && ReadInteger(data, 4) == 1 && ReadInteger(data, 8) == 1);
    assert(ReadFloat(data, 12) == 3 && ReadFloat(data, 16) == -4 && ReadFloat(data, 20) == -5);
    assert(fabsf(ReadFloat(data, 36) - 0.512f) < 0.0001f && ReadFloat(data, 40) == 1);
    temporary_count = 0;
    MgsGodotRemoveWeaponLight(&weapon);
    assert(MgsGodotAppendLights(data, sizeof(data)) == 4);
    MgsGodotRegisterWeaponLight(&weapon);
    assert(MgsGodotAppendLights(data, sizeof(data)) == 44 && ReadInteger(data, 4) > identity);
    MgsGodotRemoveWeaponLight(&weapon);
    CheckAlarmPair();
    return 0;
}
