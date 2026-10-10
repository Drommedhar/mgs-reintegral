#ifndef MGS_TEXTURE_CORRECTION_H
#define MGS_TEXTURE_CORRECTION_H

#include <libgte.h>
#include <psyz/gpu.h>

int MgsTextureCorrectionConfigure(int textures, int precision, int depth);
void MgsTextureCorrectionBegin(int frame);
void MgsTextureCorrectionSelect(int frame);
void MgsTextureCorrectionCapture(const SVECTOR *vertices, int count, const DVECTOR *xy);
void MgsTextureCorrectionProject(const void *xy, const SVECTOR *vertex);
void MgsTextureCorrectionCopy(const void *destination, const void *source);
void MgsTextureCorrectionMidpoint(const void *destination, const void *first, const void *second);
int MgsTextureCorrectionGet(const void *xy, PsyzProjectedVertex *vertex);
int MgsTextureCorrectionArea(const void *const xy[4], int original);

#endif
