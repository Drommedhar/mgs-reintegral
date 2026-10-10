#include "mgs_math.h"
#include "gtemac.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static void check_original_results(void)
{
    static const struct { long input, result; unsigned int leading; } cases[] = {
        {0, 0, 32}, {1, 1, 31}, {2, 1, 30}, {4, 2, 29}, {9, 3, 28},
        {16, 4, 27}, {255, 15, 24}, {256, 16, 23}, {32767, 180, 17},
        {1073741824, 32768, 1}, {2147483647, 46152, 1},
        {INT32_MIN, 31584, 1}, {-2120157696, 31592, 1},
        {-1073741824, 14636, 2}, {-65536, 114, 16}, {-256, 7, 24},
        {-255, 7, 24}, {-4, 0, 30}, {-3, 0, 30}, {-2, 0, 31}, {-1, 0, 32}
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i)
    {
        assert(MgsSquareRoot0(cases[i].input) == cases[i].result);
        assert(Psyz_GteDataRead(30) == (uint32_t)cases[i].input);
        assert(Psyz_GteDataRead(31) == cases[i].leading);
    }
}

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    check_original_results();
    for (long value = 0; value < 100000; ++value)
        assert(MgsSquareRoot0(value) == SquareRoot0(value));
    puts("Integral square-root results and GTE register effects passed");
    return 0;
}
