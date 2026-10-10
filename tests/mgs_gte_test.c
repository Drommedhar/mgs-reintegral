#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include "gtemac.h"

static void check_short_transform(void)
{
    static const short components[] = {-32768, -1, 0, 1, 32767};
    static const int translations[] = {-65536, -1, 0, 1, 65536};
    MATRIX matrix = {{{4096, 0, 0}, {0, 4096, 0}, {0, 0, 4096}}, {0}};
    for (size_t i = 0; i < 5; ++i)
    {
        for (size_t j = 0; j < 5; ++j)
        {
            int flag;
            SVECTOR vector = {components[i], components[4 - i], components[j], 1234};
            short expected[3];
            unsigned int expected_flag = 0;
            const int values[3] = {vector.vx, vector.vy, vector.vz};
            matrix.t[0] = translations[j];
            matrix.t[1] = translations[4 - j];
            matrix.t[2] = translations[i];
            for (int axis = 0; axis < 3; ++axis)
            {
                int result = values[axis] + matrix.t[axis];
                if (result < -32768 || result > 32767)
                    expected_flag |= 0x01000000u >> axis;
                expected[axis] = result < -32768 ? -32768 : result > 32767 ? 32767 : result;
            }
            if (expected_flag & 0x01800000u)
                expected_flag |= 0x80000000u;
            SetRotMatrix(&matrix);
            SetTransMatrix(&matrix);
            RotTransSV(&vector, &vector, &flag);
            assert(vector.vx == expected[0] && vector.vy == expected[1] && vector.vz == expected[2]);
            assert(vector.pad == (expected[2] < 0 ? -1 : 0));
            assert((unsigned int)flag == expected_flag);
        }
    }
}

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    check_short_transform();
    MATRIX identity = {{{4096, 0, 0}, {0, 4096, 0}, {0, 0, 4096}}, {11, 22, 33}};
    VECTOR large = {100000, -250000, 300000, 99};
    ApplyMatrixLV(&identity, &large, &large);
    assert(large.vx == 100000 && large.vy == -250000 && large.vz == 300000 && large.pad == 99);

    VECTOR square = {3, -4, 12, 0};
    Square0(&square, &square);
    assert(square.vx == 9 && square.vy == 16 && square.vz == 144);

    square = (VECTOR){65539, -65540, 49572, 73};
    Square0(&square, &square);
    assert(square.vx == 9 && square.vy == 16 && square.vz == 254849296);
    assert(square.pad == 73);
    assert(Psyz_GteDataRead(25) == 9 && Psyz_GteDataRead(27) == 254849296);
    assert(Psyz_GteDataRead(11) == 32767);

    square = (VECTOR){-2065, 4095, 17, 73};
    gte_ldlvl(&square);
    gte_sqr12();
    gte_stlvnl(&square);
    assert(square.vx == 1041 && square.vy == 4094 && square.vz == 0);
    assert(square.pad == 73);

    MATRIX quarter_turn = {{{0, -4096, 0}, {4096, 0, 0}, {0, 0, 4096}}, {7, 8, 9}};
    MulMatrix0(&quarter_turn, &quarter_turn, &quarter_turn);
    assert(quarter_turn.m[0][0] == -4096 && quarter_turn.m[1][1] == -4096);
    assert(quarter_turn.m[2][2] == 4096 && quarter_turn.t[0] == 7 && quarter_turn.t[2] == 9);

    SetRotMatrix(&quarter_turn);
    SetTransMatrix(&identity);
    SVECTOR zero = {0, 0, 0, 0};
    MATRIX generated, current;
    RotMatrixYXZ_gte(&zero, &generated);
    ReadRotMatrix(&current);
    assert(current.m[0][0] == -4096 && current.t[2] == 33);
    MulRotMatrix(&generated);
    assert(generated.m[0][0] == -4096 && generated.m[2][2] == 4096);

    SVECTOR input = {-100, 250, -300, 0}, output = {0};
    ApplyMatrixSV(&identity, &input, &output);
    assert(output.vx == -100 && output.vy == 250 && output.vz == -300);
    gte_ldlzc(0x00008000);
    unsigned int leading;
    gte_stlzc(&leading);
    assert(leading == 16);
    gte_ldlzc(0xFFFFFFFF);
    gte_stlzc(&leading);
    assert(leading == 32);
    gte_ldlzc(0x80000000);
    gte_stlzc(&leading);
    assert(leading == 1);
    gte_ldfcdir(-100, 200, -300);
    assert((int)Psyz_GteCtrlRead(21) == -100 && (int)Psyz_GteCtrlRead(23) == -300);
    SetLightMatrix(&identity);
    gte_ldv0(&input);
    gte_ll();
    gte_stsv(&output);
    assert(output.vx == 0 && output.vy == 250 && output.vz == 0);
    gte_ldv0(&input);
    gte_llv0();
    gte_stsv(&output);
    assert(output.vx == -100 && output.vy == 250 && output.vz == -300);
    input = (SVECTOR){1024, 2048, 4096, 0};
    gte_ldsv(&input);
    gte_ldfcdir(0, 0, 0);
    Psyz_GteDataWrite(8, 2048);
    gte_intpl_b();
    gte_stsv(&output);
    assert(output.vx == 512 && output.vy == 1024 && output.vz == 2048);
    puts("GTE adapter large vectors, aliasing, matrix state and register operations passed.");
    return 0;
}
