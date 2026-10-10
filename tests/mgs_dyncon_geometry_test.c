#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/s15c/okajima/valcan/dyncon_geo.c"
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct
{
    const char *name;
    short rotation[9];
    long translation[3];
    SVECTOR minimum, maximum;
    short expected[80];
} Fixture;

#include "mgs_dyncon_geometry_fixtures.h"

static int matrix_calls, vector_calls;

void DG_SetPos(MATRIX *matrix)
{
    SetRotMatrix(matrix);
    SetTransMatrix(matrix);
    ++matrix_calls;
}

void DG_PutVector(SVECTOR *source, SVECTOR *destination, int count)
{
    assert(count == 8);
    for (int i = 0; i < count; ++i)
    {
        gte_ldv0(&source[i]);
        gte_rt();
        gte_stsv(&destination[i]);
    }
    ++vector_calls;
}

int main(void)
{
    _Static_assert(sizeof(HZD_SEG) == 16 && sizeof(HZD_FLR) == 48, "Hazard record layout");
    InitGeom();
    for (unsigned i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i)
    {
        const Fixture *fixture = &fixtures[i];
        MATRIX matrix;
        struct { HZD_SEG segments[4]; HZD_FLR floors[2]; } output;
        SVECTOR minimum = fixture->minimum, maximum = fixture->maximum;
        memcpy(matrix.m, fixture->rotation, sizeof(matrix.m));
        memcpy(matrix.t, fixture->translation, sizeof(matrix.t));
        memset(&output, 0xa5, sizeof(output));
        matrix_calls = vector_calls = 0;
        s15c_dyncon_800D3F24(output.segments, output.floors, &matrix, &minimum, &maximum);
        if (memcmp(&output, fixture->expected, sizeof(output)) != 0)
        {
            fprintf(stderr, "Original geometry mismatch: %s\n", fixture->name);
            return 1;
        }
        assert(matrix_calls == 1 && vector_calls == 1);
    }
    puts("Dynamic container geometry matches 8 original MIPS fixtures.");
    return 0;
}
