#include "mgs_texture_correction.h"
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>

static MATRIX transform = {{{4096, 0, 0}, {0, 4096, 0}, {0, 0, 4096}}, {0, 0, 0}};
static PsyzGeometryCallback callback;
static int resets;

int Psyz_GpuConfigureGeometry(PsyzGeometryCallback value, int textures, int precision, int depth)
{
    assert(!value || textures || precision || depth);
    callback = value;
    return 0;
}

void Psyz_GpuResetGeometryDepth(void) { ++resets; }
MATRIX *ReadRotMatrix(MATRIX *output) { *output = transform; return output; }
unsigned Psyz_GteCtrlRead(unsigned reg) { return reg == 26 ? 160 : 0; }

int main(void)
{
    uint32_t packed = 0, copied = 0;
    SVECTOR vertex = {1, -1, 300, 0};
    PsyzProjectedVertex result;
    assert(MgsTextureCorrectionConfigure(1, 1, 1));
    MgsTextureCorrectionBegin(0);
    MgsTextureCorrectionProject(&packed, &vertex);
    assert(callback(&packed, &result));
    assert(fabsf(result.x - 160.0f / 300) < 0.00001f);
    assert(fabsf(result.y + 160.0f / 300) < 0.00001f && result.depth == 300);
    MgsTextureCorrectionCopy(&copied, &packed);
    assert(callback(&copied, &result));
    ++packed;
    assert(!callback(&packed, &result));
    MgsTextureCorrectionBegin(1);
    assert(!callback(&copied, &result));
    vertex.vz = 900;
    MgsTextureCorrectionProject(&copied, &vertex);
    MgsTextureCorrectionSelect(0);
    assert(callback(&copied, &result) && result.depth == 300 && resets == 1);
    MgsTextureCorrectionSelect(1);
    assert(callback(&copied, &result) && result.depth == 900);
    MgsTextureCorrectionBegin(0);
    assert(!callback(&copied, &result));
    uint32_t points[8192] = {0};
    for (unsigned i = 0; i < 8192; ++i) {
        vertex.vz = (short)(1000 + i);
        MgsTextureCorrectionProject(&points[i], &vertex);
    }
    for (unsigned i = 0; i < 8192; ++i)
        assert(callback(&points[i], &result) && result.depth == 1000 + i);
    vertex.vz = 0;
    MgsTextureCorrectionProject(&copied, &vertex);
    assert(!callback(&copied, &result));
    vertex.vz = 50;
    MgsTextureCorrectionProject(&copied, &vertex);
    assert(!callback(&copied, &result));
    assert(MgsTextureCorrectionConfigure(0, 0, 0) && !callback);
    assert(!MgsTextureCorrectionGet(&points[0], &result));
    puts("Projected geometry: subpixel projection, copy, invalidation, double buffering and growth passed.");
    return 0;
}
