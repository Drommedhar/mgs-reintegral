#include "gtemac.h"
#include <string.h>

MATRIX *MulMatrix0(MATRIX *left, MATRIX *right, MATRIX *output)
{
    MATRIX result = *left;
    SetRotMatrix(left);
    MulMatrix(&result, right);
    memcpy(output->m, result.m, sizeof(result.m));
    return output;
}

MATRIX *MulRotMatrix(MATRIX *matrix)
{
    MATRIX current;
    ReadRotMatrix(&current);
    return MulMatrix0(&current, matrix, matrix);
}

VECTOR *Square0(VECTOR *input, VECTOR *output)
{
    gte_ldlvl(input);
    Psyz_GteCommand(0x00A00428);
    output->vx = (int)Psyz_GteDataRead(25);
    output->vy = (int)Psyz_GteDataRead(26);
    output->vz = (int)Psyz_GteDataRead(27);
    return output;
}

VECTOR *ApplyMatrixLV(MATRIX *matrix, VECTOR *input, VECTOR *output)
{
    SetRotMatrix(matrix);
    return ApplyRotMatrixLV(input, output);
}

VECTOR *ApplyRotMatrixLV(VECTOR *input, VECTOR *output)
{
    const int coordinates[3] = {input->vx, input->vy, input->vz};
    unsigned int low[3], high_result[3];
    for (unsigned int i = 0; i < 3; ++i)
    {
        unsigned int magnitude = coordinates[i] < 0 ? 0u - (unsigned int)coordinates[i] : (unsigned int)coordinates[i];
        unsigned int high = magnitude >> 15;
        low[i] = magnitude & 0x7FFF;
        if (coordinates[i] < 0)
        {
            high = 0u - high;
            low[i] = 0u - low[i];
        }
        Psyz_GteDataWrite(9 + i, high);
    }
    Psyz_GteCommand(0x0041E012);
    for (unsigned int i = 0; i < 3; ++i)
    {
        high_result[i] = Psyz_GteDataRead(25 + i) << 3;
        Psyz_GteDataWrite(9 + i, low[i]);
    }
    Psyz_GteCommand(0x0049E012);
    output->vx = (int)(high_result[0] + Psyz_GteDataRead(25));
    output->vy = (int)(high_result[1] + Psyz_GteDataRead(26));
    output->vz = (int)(high_result[2] + Psyz_GteDataRead(27));
    return output;
}

SVECTOR *ApplyMatrixSV(MATRIX *matrix, SVECTOR *input, SVECTOR *output)
{
    SetRotMatrix(matrix);
    gte_ldv0(input);
    gte_rtv0();
    gte_stsv(output);
    return output;
}

MATRIX *MulMatrix2(MATRIX *left, MATRIX *right)
{
    return MulMatrix0(left, right, right);
}
