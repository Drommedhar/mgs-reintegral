#include "mgs_native.h"
#include "mgs_godot_geometry.h"
#include <assert.h>

int main(void) {
    SVECTOR vertices[] = {{0, 35, 125, -1}, {0, 35, 125, -1},
                          {0, 325, 240, -1}, {0, 325, 240, -1}};
    unsigned char indices[] = {0, 1, 2, 3};
    DG_MDL model = {0};
    model.verts = vertices;
    model.vindices = indices;
    assert(MgsGodotDegenerateFace(&model, 0));
    vertices[1].vx = 40;
    assert(!MgsGodotDegenerateFace(&model, 0));
    vertices[1].vx = 0;
    indices[1] |= 0x80;
    vertices[1].pad = 12;
    assert(!MgsGodotDegenerateFace(&model, 0));
    indices[0] |= 0x80;
    vertices[0].pad = 12;
    assert(MgsGodotDegenerateFace(&model, 0));
    vertices[0].pad = 24;
    assert(!MgsGodotDegenerateFace(&model, 0));
    return 0;
}
