#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "libdg/libdg.h"
#undef fprintf

enum { WEAPON_LIGHT_LIMIT = 128, TEMP_LIGHT_LIMIT = 8, ALARM_LIGHT_LIMIT = 64 };
typedef struct {
    DG_PRIM *prim;
    uint32_t identity;
} WeaponLight;
typedef struct {
    DG_OBJS *beam;
    uint32_t identity, fill_identity;
} AlarmLight;
typedef struct {
    uint32_t identity, kind;
    float position[3], direction[3], radius, cutoff;
} SceneLight;
_Static_assert(sizeof(SceneLight) == 40, "Godot event light layout");

static WeaponLight weapons[WEAPON_LIGHT_LIMIT];
static AlarmLight alarms[ALARM_LIGHT_LIMIT];
static uint32_t next_identity = TEMP_LIGHT_LIMIT;

static void LightFailure(const char *message) {
    fprintf(stderr, "Godot event lights: %s\n", message);
    exit(EXIT_FAILURE);
}

void MgsGodotRegisterWeaponLight(DG_PRIM *prim) {
    if (!prim) return;
    for (unsigned i = 0; i < WEAPON_LIGHT_LIMIT; ++i)
        if (weapons[i].prim == prim) return;
    for (unsigned i = 0; i < WEAPON_LIGHT_LIMIT; ++i) {
        if (weapons[i].prim) continue;
        if (next_identity == UINT32_MAX) LightFailure("identity exhausted");
        weapons[i] = (WeaponLight){prim, ++next_identity};
        return;
    }
    LightFailure("weapon light capacity exceeded");
}

void MgsGodotRemoveWeaponLight(DG_PRIM *prim) {
    for (unsigned i = 0; i < WEAPON_LIGHT_LIMIT; ++i)
        if (weapons[i].prim == prim) weapons[i].prim = NULL;
}

void MgsGodotRegisterAlarmLight(DG_OBJS *beam, int fill) {
    if (!beam) return;
    for (unsigned i = 0; i < ALARM_LIGHT_LIMIT; ++i)
        if (alarms[i].beam == beam) return;
    for (unsigned i = 0; i < ALARM_LIGHT_LIMIT; ++i) {
        if (alarms[i].beam) continue;
        if (next_identity > UINT32_MAX - (fill ? 2u : 1u)) LightFailure("identity exhausted");
        alarms[i] = (AlarmLight){beam, ++next_identity, 0};
        if (fill) alarms[i].fill_identity = ++next_identity;
        beam->flag |= MGS_GODOT_LEGACY_GLOW;
        return;
    }
    LightFailure("alarm light capacity exceeded");
}

void MgsGodotRemoveAlarmLight(DG_OBJS *beam) {
    for (unsigned i = 0; i < ALARM_LIGHT_LIMIT; ++i)
        if (alarms[i].beam == beam) alarms[i].beam = NULL;
}

static SceneLight AlarmState(const AlarmLight *alarm) {
    const MATRIX *world = &alarm->beam->world;
    const float axes[] = {1, -1, -1};
    SceneLight light = {0};
    light.identity = alarm->identity;
    light.kind = 3;
    for (int row = 0; row < 3; ++row) {
        /* pat_spt1 starts 122 units along the beacon's local +X axis. */
        light.direction[row] = axes[row] * world->m[row][0] / 4096.0f;
        light.position[row] = axes[row] * world->t[row] / 1000.0f + light.direction[row] * 0.122f;
    }
    return light;
}

static SceneLight WeaponState(const WeaponLight *weapon) {
    const DG_PRIM *prim = weapon->prim;
    const MATRIX *world = &prim->world;
    const SVECTOR *point = prim->pos;
    const float axes[] = {1, -1, -1};
    SceneLight light = {0};
    light.identity = weapon->identity;
    light.kind = 2;
    for (int row = 0; row < 3; ++row) {
        float position = world->t[row] + (world->m[row][0] * point->vx +
            world->m[row][1] * point->vy + world->m[row][2] * point->vz) / 4096.0f;
        light.position[row] = axes[row] * position / 1000.0f;
        /* The FAMAS barrel points along the attachment's negative Y axis. */
        light.direction[row] = axes[row] * -world->m[row][1] / 4096.0f;
    }
    return light;
}

uint32_t MgsGodotAppendLights(unsigned char *destination, uint32_t capacity) {
    SceneLight lights[TEMP_LIGHT_LIMIT + WEAPON_LIGHT_LIMIT + ALARM_LIGHT_LIMIT * 2];
    DG_LIT temporary[TEMP_LIGHT_LIMIT];
    unsigned count = 0;
    const unsigned temporary_count = MgsGodotCopyTemporaryLights(temporary, TEMP_LIGHT_LIMIT);
    for (unsigned i = 0; i < temporary_count; ++i) {
        const DG_LIT *source = &temporary[i];
        if (source->r_range <= 0 || source->e_range <= 0) continue;
        lights[count++] = (SceneLight){i + 1, 1,
            {source->point.vx / 1000.0f, -source->point.vy / 1000.0f, -source->point.vz / 1000.0f},
            {0, 0, 0}, source->r_range / 1000.0f, source->e_range / 1000.0f};
    }
    for (unsigned i = 0; i < WEAPON_LIGHT_LIMIT; ++i) {
        const DG_PRIM *prim = weapons[i].prim;
        if (!prim || (prim->type & DG_PRIM_INVISIBLE)) continue;
        if (prim->group_id && !(prim->group_id & DG_CurrentGroupID)) continue;
        SceneLight light = WeaponState(&weapons[i]);
        float length_squared = 0;
        for (int axis = 0; axis < 3; ++axis)
            length_squared += light.direction[axis] * light.direction[axis];
        if (length_squared < 0.0001f) continue;
        lights[count++] = light;
    }
    for (unsigned i = 0; i < ALARM_LIGHT_LIMIT; ++i) {
        const DG_OBJS *beam = alarms[i].beam;
        if (!beam || (beam->flag & DG_FLAG_INVISIBLE)) continue;
        if (beam->group_id && !(beam->group_id & DG_CurrentGroupID)) continue;
        lights[count++] = AlarmState(&alarms[i]);
        if (alarms[i].fill_identity) {
            const MATRIX *world = &beam->world;
            lights[count++] = (SceneLight){alarms[i].fill_identity, 4,
                {world->t[0] / 1000.0f, -world->t[1] / 1000.0f, -world->t[2] / 1000.0f},
                {0, 0, 0}, 0, 0};
        }
    }
    const uint32_t bytes = 4 + count * sizeof(SceneLight);
    if (bytes > capacity) LightFailure("scene capacity exceeded");
    memcpy(destination, &count, 4);
    memcpy(destination + 4, lights, bytes - 4);
    return bytes;
}
