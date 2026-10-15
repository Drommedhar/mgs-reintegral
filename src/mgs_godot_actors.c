#include "mgs_godot_actors.h"
#include "mgs_godot_context.h"
#include "mgs_godot_declarations.h"
#include "transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    uint32_t schema, action, slot, generation, epoch, instance, parts, name, map, provider, tick, phase;
    MgsGodotDeclaration origin;
    float position[3];
    int32_t progress, duration;
    uint32_t visible;
    unsigned char session[16];
} ActorPacket;
_Static_assert(sizeof(ActorPacket) == 136, "Godot actor record layout");

typedef struct {
    const void *actor;
    ActorPacket packet;
    int published, dirty, retiring;
} Actor;
static Actor actors[128];

static void ActorFailure(const char *reason)
{
    fprintf(stderr, "Godot actor bridge: %s\n", reason);
    exit(EXIT_FAILURE);
}

static Actor *FindActor(const void *actor)
{
    for (unsigned i = 0; i < 128; ++i)
        if (actors[i].actor == actor && !actors[i].retiring) return &actors[i];
    return NULL;
}

static void CreateActor(const void *owner, const MgsGodotActorBinding *binding, uint32_t provider)
{
    if (!MgsGodotHasCapability(128)) return;
    if (!owner || FindActor(owner)) ActorFailure("invalid or duplicate actor");
    for (unsigned i = 0; i < 128; ++i) {
        Actor *actor = &actors[i];
        if (actor->actor) continue;
        uint32_t generation = actor->packet.generation;
        if (generation == UINT32_MAX) ActorFailure("actor generation exhausted");
        *actor = (Actor){0};
        actor->actor = owner;
        ActorPacket *packet = &actor->packet;
        packet->schema = 1;
        packet->slot = i + 1;
        packet->generation = generation + 1;
        packet->epoch = MgsGodotSceneEpoch();
        packet->instance = binding->instance;
        packet->parts = binding->parts;
        packet->name = binding->name;
        packet->map = binding->map;
        packet->provider = provider;
        MgsGodotCurrentDeclaration(&packet->origin);
        MgsGodotCopySessionId(packet->session);
        return;
    }
    ActorFailure("actor capacity exceeded");
}

void MgsGodotElevatorCreate(const void *owner, const MgsGodotActorBinding *binding)
{
    CreateActor(owner, binding, 0x2abc);
}

void MgsGodotWallCreate(const void *owner, const MgsGodotActorBinding *binding)
{
    if (MgsGodotSelectedMinor() >= 32) CreateActor(owner, binding, 0xec77);
}

void MgsGodotWallUpdate(const void *owner, const MgsGodotWallSample *sample)
{
    if (!MgsGodotHasCapability(128) || MgsGodotSelectedMinor() < 32) return;
    Actor *actor = FindActor(owner);
    if (!actor) ActorFailure("unregistered wall update");
    ActorPacket *packet = &actor->packet;
    for (unsigned i = 0; i < 3; ++i) packet->position[i] = sample->position[i] / 1000.0f;
    packet->tick = sample->tick;
    packet->visible = sample->visible;
    actor->dirty = 1;
}

void MgsGodotElevatorUpdate(const void *owner, const MgsGodotElevatorSample *sample)
{
    if (!MgsGodotHasCapability(128)) return;
    Actor *actor = FindActor(owner);
    if (!actor) ActorFailure("unregistered elevator update");
    ActorPacket *packet = &actor->packet;
    for (unsigned i = 0; i < 3; ++i) packet->position[i] = sample->position[i] / 1000.0f;
    packet->tick = sample->tick;
    packet->phase = (uint32_t)sample->phase;
    packet->progress = sample->progress;
    packet->duration = sample->duration;
    packet->visible = sample->visible;
    actor->dirty = 1;
}

void MgsGodotActorRemove(const void *owner)
{
    if (!MgsGodotHasCapability(128)) return;
    Actor *actor = FindActor(owner);
    if (!actor) return;
    if (!actor->published) actor->actor = NULL;
    else actor->retiring = 1;
}

void MgsGodotPublishActors(void)
{
    if (!MgsGodotHasCapability(128)) return;
    for (unsigned i = 0; i < 128; ++i) {
        Actor *actor = &actors[i];
        if (!actor->actor || (!actor->dirty && !actor->retiring)) continue;
        actor->packet.action = actor->retiring ? 3 : actor->published ? 2 : 1;
        MgsGodotQueue(MGS_GODOT_ACTOR, &actor->packet, sizeof(actor->packet), NULL, 0);
        actor->published = 1;
        actor->dirty = 0;
        if (actor->retiring) actor->actor = NULL;
    }
}
