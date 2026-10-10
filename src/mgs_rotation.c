#include "gtemac.h"

static SVECTOR GteScaleVector(int scale, int x, int y, int z)
{
    SVECTOR result;
    Psyz_GteDataWrite(8, scale);
    Psyz_GteDataWrite(9, x);
    Psyz_GteDataWrite(10, y);
    Psyz_GteDataWrite(11, z);
    Psyz_GteCommand(0x0198003d);
    result.vx = (short)Psyz_GteDataRead(9);
    result.vy = (short)Psyz_GteDataRead(10);
    result.vz = (short)Psyz_GteDataRead(11);
    result.pad = 0;
    return result;
}

MATRIX *RotMatrixYXZ_gte(SVECTOR *rotation, MATRIX *matrix)
{
    const int sx = rsin(rotation->vx), cx = rcos(rotation->vx);
    const int sy = rsin(rotation->vy), cy = rcos(rotation->vy);
    const int sz = rsin(rotation->vz), cz = rcos(rotation->vz);
    const SVECTOR a = GteScaleVector(cy, sx, sz, cz);
    const SVECTOR b = GteScaleVector(sy, sx, sz, cz);
    const SVECTOR c = GteScaleVector(cz, cx, b.vx, a.vx);
    const SVECTOR d = GteScaleVector(sz, cx, b.vx, a.vx);

    matrix->m[0][0] = a.vz + d.vy;
    matrix->m[0][1] = c.vy - a.vy;
    matrix->m[0][2] = (cx * sy) >> 12;
    matrix->m[1][0] = d.vx;
    matrix->m[1][1] = c.vx;
    matrix->m[1][2] = -sx;
    matrix->m[2][0] = d.vz - b.vz;
    matrix->m[2][1] = c.vz + b.vy;
    matrix->m[2][2] = (cx * cy) >> 12;
    return matrix;
}

MATRIX *RotMatrixZYX_gte(SVECTOR *rotation, MATRIX *matrix)
{
    const int sx = rsin(rotation->vx), cx = rcos(rotation->vx);
    const int sy = rsin(rotation->vy), cy = rcos(rotation->vy);
    const int sz = rsin(rotation->vz), cz = rcos(rotation->vz);
    const SVECTOR a = GteScaleVector(cx, sy, sz, cz);
    const SVECTOR b = GteScaleVector(sx, sy, sz, cz);
    const SVECTOR c = GteScaleVector(cz, cy, b.vx, a.vx);
    const SVECTOR d = GteScaleVector(sz, cy, b.vx, a.vx);

    matrix->m[0][0] = c.vx;
    matrix->m[0][1] = c.vy - a.vy;
    matrix->m[0][2] = c.vz + b.vy;
    matrix->m[1][0] = d.vx;
    matrix->m[1][1] = d.vy + a.vz;
    matrix->m[1][2] = d.vz - b.vz;
    matrix->m[2][0] = -sy;
    matrix->m[2][1] = (cy * sx) >> 12;
    matrix->m[2][2] = (cy * cx) >> 12;
    return matrix;
}

MATRIX *RotMatrix_gte(SVECTOR *rotation, MATRIX *matrix)
{
    const int sx = rsin(rotation->vx), cx = rcos(rotation->vx);
    const int sy = rsin(rotation->vy), cy = rcos(rotation->vy);
    const int sz = rsin(rotation->vz), cz = rcos(rotation->vz);
    const SVECTOR a = GteScaleVector(cx, sy, sz, cz);
    const SVECTOR b = GteScaleVector(sx, sy, sz, cz);
    const SVECTOR c = GteScaleVector(cz, cy, b.vx, a.vx);
    const SVECTOR d = GteScaleVector(sz, cy, b.vx, a.vx);

    matrix->m[0][0] = c.vx;
    matrix->m[0][1] = -d.vx;
    matrix->m[0][2] = sy;
    matrix->m[1][0] = c.vy + a.vy;
    matrix->m[1][1] = a.vz - d.vy;
    matrix->m[1][2] = -((cy * sx) >> 12);
    matrix->m[2][0] = b.vy - c.vz;
    matrix->m[2][1] = b.vz + d.vz;
    matrix->m[2][2] = (cy * cx) >> 12;
    return matrix;
}
