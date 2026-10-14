#ifndef MGS_GODOT_CINEMATIC_H
#define MGS_GODOT_CINEMATIC_H
#include <stdint.h>

typedef struct {
    uint32_t generation, disc, sector, total;
    int32_t frame;
    uint32_t active;
} MgsGodotCinematic;

void MgsGodotCinematicSelect(unsigned kind, unsigned disc, unsigned sector);
void MgsGodotCinematicOpen(const void *owner, int streamed);
void MgsGodotCinematicStart(const void *owner, int total);
void MgsGodotCinematicApply(const void *owner, int frame);
void MgsGodotCinematicEnd(const void *owner);
MgsGodotCinematic MgsGodotCinematicState(void);
#endif
