#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "gtemac.h"

typedef struct {
    SVECTOR angles;
    short yxz[9];
    short zyx[9];
    short xyz[9];
    short yxz_ir[4];
    short zyx_ir[4];
} RotationCase;

/* Results from PsyQ 4.7 RMAT_02/RMAT_00/RMAT_01 machine code and CSTBL. */
static const RotationCase cases[] = {
    {{0, 0, 0, 0},
     {4096, 0, 0, 0, 4096, 0, 0, 0, 4096},
     {4096, 0, 0, 0, 4096, 0, 0, 0, 4096},
     {4096, 0, 0, 0, 4096, 0, 0, 0, 4096},
     {0, 0, 0, 0}, {0, 0, 0, 0}},
    {{123, 456, 789, 0},
     {1567, -2758, 2590, 3764, 1419, -768, -381, 2674, 3078},
     {1105, -3590, 1631, 2932, 1881, 2153, -2637, 587, 3078},
     {1105, -2932, 2637, 3938, 957, -587, -195, 2693, 3078},
     {3833, 3764, 462, 549}, {3833, 2932, 462, 2423}},
    {{-17, 2048, -16384, 0},
     {-4096, 0, 0, 0, 4095, 107, 0, 107, -4095},
     {-4096, 0, 0, 0, 4095, 107, 0, 107, -4095},
     {-4096, 0, 0, 0, 4095, -107, 0, -107, -4095},
     {0, 0, 0, 0}, {0, 0, 0, 0}},
    {{3901, -2771, 923, 0},
     {-1351, 1637, 3504, 3867, 603, 1207, -35, 3705, -1744},
     {-282, -4034, -653, -1804, -466, 3649, -3667, 537, -1744},
     {-282, 1804, 3667, 3700, 1672, -537, -1733, 3275, -1744},
     {4047, 3867, -1069, 530}, {4047, -1804, -1069, 3462}},
    {{-32768, 32767, -999, 0},
     {157, 4093, -6, -4093, 157, 0, 1, 5, 4096},
     {157, 4093, -1, -4093, 157, 5, 6, 0, 4096},
     {157, 4093, -6, -4093, 157, 0, 1, 5, 4096},
     {-4093, -4093, 0, 0}, {-4093, -4093, 0, 5}}
};

static void CheckRotation(const RotationCase *test, MATRIX *(*build)(SVECTOR *, MATRIX *),
                          const short *expected, const short *expected_ir)
{
    MATRIX current = {{{100, -200, 300}, {-400, 500, -600}, {700, -800, 900}}, {11, -22, 33}};
    MATRIX result;
    SVECTOR angles = test->angles;
    unsigned int controls[31];

    SetRotMatrix(&current);
    SetTransMatrix(&current);
    for (unsigned int i = 0; i < 31; ++i)
        controls[i] = Psyz_GteCtrlRead(i);
    memset(&result, 0x5a, sizeof(result));
    result.t[0] = 12345;
    result.t[1] = -67890;
    result.t[2] = 24680;
    MATRIX *returned = build(&angles, &result);

    assert(returned == &result);
    assert(memcmp(result.m, expected, sizeof(result.m)) == 0);
    assert(result.t[0] == 12345 && result.t[1] == -67890 && result.t[2] == 24680);
    for (unsigned int i = 0; i < 31; ++i)
        assert(Psyz_GteCtrlRead(i) == controls[i]);
    for (unsigned int i = 0; i < 4; ++i)
        assert((short)Psyz_GteDataRead(8 + i) == expected_ir[i]);
}

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    for (unsigned int i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i)
    {
        CheckRotation(&cases[i], RotMatrixYXZ_gte, cases[i].yxz, cases[i].yxz_ir);
        CheckRotation(&cases[i], RotMatrixZYX_gte, cases[i].zyx, cases[i].zyx_ir);
        CheckRotation(&cases[i], RotMatrix_gte, cases[i].xyz, cases[i].zyx_ir);
    }
    puts("Rotation builders match SDK matrices and preserve GTE matrix state.");
    return 0;
}
