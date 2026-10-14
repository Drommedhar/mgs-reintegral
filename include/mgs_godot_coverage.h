#ifndef MGS_GODOT_COVERAGE_H
#define MGS_GODOT_COVERAGE_H

#include <stdint.h>
struct _DG_CHANL;
typedef struct {
    uint32_t godot_meshes, compatibility_meshes, suppressed_meshes;
    uint32_t godot_effects, compatibility_effects, suppressed_effects;
    uint32_t compatibility_primitive_types;
} MgsGodotWorldCoverage;

MgsGodotWorldCoverage MgsGodotCountWorldCoverage(struct _DG_CHANL *channel, int buffer);
void MgsGodotReportWorldCoverage(struct _DG_CHANL *channel, int buffer);

#endif
