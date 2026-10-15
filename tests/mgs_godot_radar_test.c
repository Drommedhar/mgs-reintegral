#include "mgs_godot_radar.h"
#include "mgs_radar.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static int enabled = 1;
static bool capable = true;
static uint32_t epoch = 7, queued;
static unsigned char wire[120000];
static uint32_t wire_size;

int MgsGodotSceneEnabled(void) { return enabled; }
uint32_t MgsGodotSceneEpoch(void) { return epoch; }
bool MgsGodotHasCapability(unsigned capability)
{
    assert(capability == MGS_GODOT_RADAR_CAPABILITY);
    return capable;
}
void MgsGodotCopySessionId(unsigned char destination[16]) { memset(destination, 3, 16); }
void MgsGodotQueue(uint32_t operation, const void *header, uint32_t header_bytes,
                   const void *data, uint32_t data_bytes)
{
    assert(operation == MGS_GODOT_RADAR && header_bytes == 104);
    wire_size = header_bytes + data_bytes;
    assert(wire_size <= sizeof(wire));
    memcpy(wire, header, header_bytes);
    memcpy(wire + header_bytes, data, data_bytes);
    ++queued;
}
static uint32_t Word(unsigned offset)
{
    uint32_t value;
    memcpy(&value, wire + offset, sizeof(value));
    return value;
}

int main(void)
{
    MgsRadarFrame frame = {.active = 1, .mode = MGS_RADAR_ALERT, .tick = 123, .alert_level = 255};
    MgsRadarContact contact = {.position = {2, -3}, .actor_index = 4};
    MgsRadarSight sight = {.color = 0x808000};
    MgsRadarWall wall = {.points = {{-8, -9}, {10, 11}}, .dynamic = 1};
    MgsGodotResetRadar();
    assert(MgsRadarOwnsDrawing());
    MgsRadarPresent(frame);
    MgsRadarAddContact(&contact);
    MgsRadarAddSight(&sight);
    MgsRadarAddWall(&wall);
    MgsGodotPublishRadar();
    assert(queued == 1 && wire_size == 320);
    assert(Word(0) == 1 && Word(4) == 7 && Word(8) == 1 && Word(12) == 1 && Word(16) == 1);
    assert(Word(20) == 152 && Word(24) == 40 && Word(28) == 24);
    for (unsigned i = 32; i < 48; ++i) assert(wire[i] == 3);
    assert(memcmp(wire + 48, &frame, sizeof(frame)) == 0);
    assert(memcmp(wire + 104, &contact, sizeof(contact)) == 0);
    assert(memcmp(wire + 256, &sight, sizeof(sight)) == 0);
    assert(memcmp(wire + 296, &wall, sizeof(wall)) == 0);
    ++epoch;
    MgsGodotPublishRadar();
    assert(queued == 2 && wire_size == 104 && Word(4) == 8 && Word(48) == 0);
    capable = false;
    MgsGodotResetRadar();
    assert(!MgsRadarOwnsDrawing());
    MgsGodotPublishRadar();
    assert(queued == 2);
    capable = true;
    enabled = 0;
    MgsGodotResetRadar();
    assert(!MgsRadarOwnsDrawing());
    MgsGodotPublishRadar();
    assert(queued == 2);
    puts("Radar wire: records, session, epoch clearing and negotiated ownership pass.");
    return 0;
}
