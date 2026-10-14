#include "mgs_godot_palettes.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static unsigned messages;
static uint32_t last[10];

void MgsGodotCopySessionId(unsigned char destination[16])
{
    memset(destination, 0x5a, 16);
}

void MgsGodotQueue(uint32_t operation, const void *header, uint32_t header_bytes,
                   const void *data, uint32_t data_bytes)
{
    assert(operation == MGS_GODOT_PALETTE && header_bytes == sizeof(last));
    memcpy(last, header, header_bytes);
    assert(last[5] == data_bytes && last[6] == 0x5a5a5a5a);
    assert(!data_bytes || data);
    ++messages;
}

int main(void)
{
    MgsGodotPalette palette = {0};
    unsigned char bytes[] = {1, 2, 3, 4};
    assert(MgsGodotPublishPalette(&palette, 7, 1, bytes, sizeof(bytes)) == 1);
    assert(messages == 1 && last[0] == 1 && last[3] == 0 && last[4] == 1);
    assert(MgsGodotPublishPalette(&palette, 7, 1, bytes, sizeof(bytes)) == 1 && messages == 1);
    bytes[0] = 9;
    assert(palette.data[0] == 1);
    assert(MgsGodotPublishPalette(&palette, 7, 1, bytes, sizeof(bytes)) == 2);
    assert(messages == 2 && last[0] == 2 && last[3] == 1 && last[4] == 2);
    MgsGodotRetirePalette(&palette, 7, 1);
    assert(messages == 3 && last[0] == 3 && last[3] == 2 && last[4] == 0);
    assert(!palette.data && !palette.size && !palette.revision);
    MgsGodotRetirePalette(&palette, 7, 1);
    assert(messages == 3);
    assert(MgsGodotPublishPalette(&palette, 8, 1, bytes, sizeof(bytes)) == 1);
    assert(last[1] == 8 && last[0] == 1 && last[3] == 0);
    MgsGodotRetirePalette(&palette, 8, 1);
    puts("Retained palette lifecycle passed.");
    return 0;
}
