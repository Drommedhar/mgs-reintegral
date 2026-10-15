#ifndef MGS_GODOT_ACTORS_H
#define MGS_GODOT_ACTORS_H
#include <stdint.h>
typedef struct {
    uint32_t instance, parts, name, map;
} MgsGodotActorBinding;
typedef struct {
    int position[3];
    uint32_t tick;
    int phase, progress, duration;
    uint32_t visible;
} MgsGodotElevatorSample;
typedef struct {
    int position[3];
    uint32_t tick, visible;
} MgsGodotWallSample;
void MgsGodotWallCreate(const void *actor, const MgsGodotActorBinding *binding);
void MgsGodotWallUpdate(const void *actor, const MgsGodotWallSample *sample);
void MgsGodotElevatorCreate(const void *actor, const MgsGodotActorBinding *binding);
void MgsGodotElevatorUpdate(const void *actor, const MgsGodotElevatorSample *sample);
void MgsGodotActorRemove(const void *actor);
void MgsGodotPublishActors(void);
#endif
