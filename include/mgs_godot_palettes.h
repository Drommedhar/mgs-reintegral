#ifndef MGS_GODOT_PALETTES_H
#define MGS_GODOT_PALETTES_H
#include <stdint.h>

typedef struct {
    unsigned char *data;
    uint32_t size, revision;
} MgsGodotPalette;

uint32_t MgsGodotPublishPalette(MgsGodotPalette *palette, uint32_t id, uint32_t kind,
                               const void *data, uint32_t size);
void MgsGodotRetirePalette(MgsGodotPalette *palette, uint32_t id, uint32_t kind);
void MgsGodotPaletteStatistics(void);
#endif
