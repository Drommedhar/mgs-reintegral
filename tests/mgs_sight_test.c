#include "mgs_sight.h"

#include <assert.h>
#include <libgpu.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    const uint32_t polygon[] = {
        0x05000005, 0x28030201, 0x00020001, 0x00040003, 0x00060005, 0x00080007
    };
    const uint32_t text[] = {0xff, 0x00404040};
    POLY_F4 packet;
    POLY_F4 before;

    memset(&packet, 0xa5, sizeof(packet));
    before = packet;
    assert(MgsSightCopyPacket(&packet, sizeof(packet) - 1,
                              polygon, sizeof(polygon)) == 0);
    assert(MgsSightCopyPacket(&packet, sizeof(packet),
                              polygon, sizeof(polygon) - 1) == 0);
    assert(MgsSightCopyPacket(&packet, sizeof(packet), polygon, 3) == 0);
    assert(MgsSightCopyPacket(&packet, sizeof(packet), text, sizeof(text)) == 0);
    assert(memcmp(&packet, &before, sizeof(packet)) == 0);

    assert(MgsSightCopyPacket(&packet, sizeof(packet),
                              polygon, sizeof(polygon)) == sizeof(packet));
    assert(getlen(&packet) == 5);
    assert(getaddr(&packet) == 0);
    assert(memcmp(&packet.r0, polygon + 1, sizeof(polygon) - 4) == 0);
    assert(packet.x3 == 7 && packet.y3 == 8);
    puts("Sight retail packet conversion and bounds passed.");
    return 0;
}
