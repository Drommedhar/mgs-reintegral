#include "mgs_native.h"
#include "mgs_godot_geometry.h"

static int SameVertex(const DG_MDL *model, unsigned a, unsigned b) {
    if (a == b) return 1;
    if ((a & 0x80) != (b & 0x80)) return 0;
    const SVECTOR *left = &model->verts[a & 0x7f];
    const SVECTOR *right = &model->verts[b & 0x7f];
    if (a & 0x80) return left->pad == right->pad;
    return left->vx == right->vx && left->vy == right->vy && left->vz == right->vz;
}

int MgsGodotDegenerateFace(const DG_MDL *model, int face) {
    const unsigned char *v = model->vindices + face * 4;
    /* Repeated corners stay collapsed under animation; bind-pose collinearity does not. */
    return (SameVertex(model, v[0], v[3]) || SameVertex(model, v[0], v[1]) ||
            SameVertex(model, v[3], v[1])) &&
           (SameVertex(model, v[1], v[3]) || SameVertex(model, v[1], v[2]) ||
            SameVertex(model, v[3], v[2]));
}
