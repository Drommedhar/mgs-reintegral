#include "mgs_native.h"
#include "mgs_godot_deformation.h"
#include "libdg/libdg.h"
#include <assert.h>
#include <stdio.h>

int MgsGodotSceneEnabled(void) { return 1; }

int main(void)
{
    struct { DG_DEF definition; DG_MDL parts[3]; } asset = {0};
    SVECTOR root[] = {{10, 20, 30, -1}, {100, 200, 300, -1}};
    SVECTOR child[] = {{1, 2, 3, 1}, {4, 5, 6, -1}};
    SVECTOR grandchild[] = {{7, 8, 9, 0}, {10, 11, 12, -1}};
    unsigned char indices[3][4] = {{0, 1, 0, 1}, {0, 1, 0, 1}, {0, 1, 0, 1}};
    SVECTOR *vertices[] = {root, child, grandchild};
    asset.definition.n_models = 2;
    asset.definition.n_x_models = 3;
    for (int part = 0; part < 3; ++part) {
        asset.parts[part] = (DG_MDL){.n_faces = 1, .n_verts = 2, .parent = part - 1,
            .extend = -1, .verts = vertices[part], .vindices = indices[part]};
    }
    asset.parts[1].extend = 2;
    for (int part = 0; part < 3; ++part) {
        MgsGodotCaptureVertexOwners(&asset.definition, part);
        if (part) {
            vertices[part][0].pad = 52;
            indices[part][0] |= 0x80;
        }
    }
    MgsGodotTrackDeformation(&asset.definition);
    uint32_t size;
    uint64_t first, second;
    const float *deltas = MgsGodotDeformation(&asset.definition, &size, &first);
    assert(size == 12 * 3 * sizeof(float) && first);
    for (unsigned i = 0; i < 36; ++i) assert(deltas[i] == 0);
    root[1].vy += 500;
    child[1].vx -= 250;
    grandchild[1].vz += 1000;
    MgsGodotDeformationChanged(&asset.definition);
    deltas = MgsGodotDeformation(&asset.definition, &size, &second);
    assert(second > first);
    assert(deltas[3 + 1] == -0.5f && deltas[12 + 1] == -0.5f && deltas[24 + 1] == -0.5f);
    assert(deltas[15] == -0.25f && deltas[27 + 2] == -1.0f);
    MgsGodotTrackDeformation(&asset.definition);
    MgsGodotDeformation(&asset.definition, &size, &first);
    assert(first == second);
    root[1].vy -= 500;
    child[1].vx += 250;
    grandchild[1].vz -= 1000;
    MgsGodotDeformationChanged(&asset.definition);
    deltas = MgsGodotDeformation(&asset.definition, &size, &second);
    for (unsigned i = 0; i < 36; ++i) assert(deltas[i] == 0);
    for (int part = 0; part < 3; ++part) {
        if (part) { vertices[part][0].pad = part == 1 ? 1 : 0; indices[part][0] &= 0x7f; }
        MgsGodotCaptureVertexOwners(&asset.definition, part);
    }
    assert(!MgsGodotDeformation(&asset.definition, &size, &first) && !size && !first);
    puts("Native deformation preserves linked ownership, extension corners, restoration and model address reuse.");
    return 0;
}
