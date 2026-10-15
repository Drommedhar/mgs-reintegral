#include "mgs_godot_palettes.h"
#include "transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { BYTE_LIMIT = 64 * 1024 * 1024 };
static uint32_t resident_bytes, snapshots;
static uint64_t sent_bytes, reused_bytes, allocations;

static void PaletteFailure(const char *message)
{
    fprintf(stderr, "Godot retained palette: %s\n", message);
    exit(EXIT_FAILURE);
}

static void SendPalette(const MgsGodotPalette *palette, uint32_t id, uint32_t kind,
                        uint32_t previous, int retiring)
{
    uint32_t size = retiring ? 0 : palette->size;
    uint32_t header[10] = {retiring ? 3 : previous ? 2 : 1, id, kind, previous,
                          retiring ? 0 : palette->revision, size};
    MgsGodotCopySessionId((unsigned char *)(header + 6));
    MgsGodotQueue(MGS_GODOT_PALETTE, header, sizeof(header), retiring ? NULL : palette->data, size);
}

uint32_t MgsGodotPublishPalette(MgsGodotPalette *palette, uint32_t id, uint32_t kind,
                               const void *data, uint32_t size)
{
    if (palette->size == size && palette->revision && !memcmp(palette->data, data, size)) {
        reused_bytes += size;
        return palette->revision;
    }
    if (!size || size > BYTE_LIMIT - (resident_bytes - palette->size) || palette->revision == UINT32_MAX)
        PaletteFailure("memory or revision limit exceeded");
    if (palette->size != size) {
        unsigned char *resized = realloc(palette->data, size);
        if (!resized) PaletteFailure("allocation failed");
        palette->data = resized;
        resident_bytes = resident_bytes - palette->size + size;
        palette->size = size;
        ++allocations;
    }
    uint32_t previous = palette->revision++;
    memcpy(palette->data, data, size);
    SendPalette(palette, id, kind, previous, 0);
    sent_bytes += size;
    return palette->revision;
}

void MgsGodotRetirePalette(MgsGodotPalette *palette, uint32_t id, uint32_t kind)
{
    if (!palette->revision) return;
    SendPalette(palette, id, kind, palette->revision, 1);
    resident_bytes -= palette->size;
    free(palette->data);
    *palette = (MgsGodotPalette){0};
}

void MgsGodotPaletteStatistics(void)
{
    if (++snapshots % 300 != 0) return;
    fprintf(stderr, "[godot-palettes] snapshots=%u sent=%llu reused=%llu resident=%u allocations=%llu\n",
            snapshots, (unsigned long long)sent_bytes, (unsigned long long)reused_bytes,
            resident_bytes, (unsigned long long)allocations);
}
