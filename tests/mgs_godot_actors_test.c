#include "mgs_godot_actors.h"
#include "mgs_godot_declarations.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static unsigned count;
static unsigned minor = 32;
static unsigned char message[136];
bool MgsGodotHasCapability(unsigned capability) { return capability == 128; }
unsigned MgsGodotSelectedMinor(void) { return minor; }
uint32_t MgsGodotSceneEpoch(void) { return 3; }
void MgsGodotCopySessionId(unsigned char out[16]) { memset(out, 0x5a, 16); }
void MgsGodotQueue(uint32_t op, const void *header, uint32_t bytes, const void *data, uint32_t size)
{
    assert(op == MGS_GODOT_ACTOR && bytes == 136 && !data && !size);
    memcpy(message, header, bytes);
    ++count;
}
static uint32_t Word(unsigned offset) { uint32_t result; memcpy(&result, message+offset, 4); return result; }

int main(void)
{
    unsigned char script[40] = {0};
    script[10] = 0x60; script[13] = 0x99; script[14] = 0x06;
    MgsGodotDeclaration origin = {6*65536u+0xea54, 0, "s00a", {0x12}}, result;
    MgsGodotSetScriptSource(script, sizeof(script), &origin);
    const void *previous = MgsGodotCommandScope(script+13);
    assert(!previous && MgsGodotCurrentDeclaration(&result) && result.offset == 10);
    const void *outer = MgsGodotCommandScope(script+39);
    assert(!MgsGodotCurrentDeclaration(&result));
    MgsGodotCommandScope(outer);
    assert(MgsGodotCurrentDeclaration(&result) && result.offset == 10);
    MgsGodotActorBinding binding = {8, 5, 0xb15b, 1};
    MgsGodotElevatorSample sample = {{1000,4000,-28800}, 20, 3, 225, 450, 1};
    int owner;
    MgsGodotElevatorCreate(&owner, &binding);
    MgsGodotPublishActors();
    assert(count == 0);
    MgsGodotElevatorUpdate(&owner, &sample);
    MgsGodotPublishActors();
    assert(count == 1 && Word(4) == 1 && Word(12) == 1 && Word(52) == 10);
    assert(Word(16) == 3 && Word(20) == 8 && Word(108) == 225 && message[120] == 0x5a);
    float position[3]; memcpy(position, message+96, sizeof(position));
    assert(position[0] == 1.0f && position[1] == 4.0f);
    MgsGodotPublishActors();
    assert(count == 1);
    sample.progress = 224;
    MgsGodotElevatorUpdate(&owner, &sample);
    MgsGodotPublishActors();
    assert(count == 2 && Word(4) == 2 && Word(108) == 224);
    MgsGodotActorRemove(&owner);
    MgsGodotPublishActors();
    assert(count == 3 && Word(4) == 3);
    MgsGodotElevatorCreate(&owner, &binding);
    MgsGodotElevatorUpdate(&owner, &sample);
    MgsGodotPublishActors();
    assert(count == 4 && Word(4) == 1 && Word(12) == 2);
    MgsGodotActorRemove(&owner);
    MgsGodotPublishActors();
    MgsGodotCommandScope(previous);
    assert(!MgsGodotCurrentDeclaration(&result) && result.offset == UINT32_MAX);
    MgsGodotWallSample wall = {{0, 1500, 0}, 25, 1};
    unsigned before = count;
    minor = 31;
    MgsGodotWallCreate(&owner, &binding);
    MgsGodotWallUpdate(&owner, &wall);
    MgsGodotPublishActors();
    assert(count == before);
    minor = 32;
    MgsGodotCommandScope(script+13);
    MgsGodotWallCreate(&owner, &binding);
    MgsGodotWallUpdate(&owner, &wall);
    MgsGodotPublishActors();
    assert(count == before+1 && Word(36) == 0xec77 && Word(52) == 10);
    assert(Word(44) == 0 && Word(108) == 0 && Word(112) == 0);
    wall.visible = 0;
    MgsGodotWallUpdate(&owner, &wall);
    MgsGodotPublishActors();
    assert(Word(4) == 2 && Word(116) == 0);
    MgsGodotActorRemove(&owner);
    MgsGodotPublishActors();
    assert(Word(4) == 3);
    puts("Godot actor lifetime and declaration tests passed");
    return 0;
}
