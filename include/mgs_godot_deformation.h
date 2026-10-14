#ifndef MGS_GODOT_DEFORMATION_H
#define MGS_GODOT_DEFORMATION_H
#include <stdint.h>

struct _DG_DEF;
void MgsGodotCaptureVertexOwners(struct _DG_DEF *definition, int part);
void MgsGodotTrackDeformation(struct _DG_DEF *definition);
void MgsGodotDeformationChanged(struct _DG_DEF *definition);
const float *MgsGodotDeformation(struct _DG_DEF *definition, uint32_t *size, uint64_t *version);
#endif
