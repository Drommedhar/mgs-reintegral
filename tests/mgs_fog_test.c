#include <assert.h>
#include <stdio.h>
#include "mgs_fog_gte.h"

int main(void)
{
    POLY_GT4 packet;
    POLY_GT4 expected;
    memset(&packet, 0x5a, sizeof(packet));
    setRGB0(&packet, 16, 32, 48);
    setRGB1(&packet, 64, 80, 96);
    setRGB2(&packet, 112, 128, 144);
    setRGB3(&packet, 160, 176, 192);
    expected = packet;
    setRGB1(&expected, 32, 40, 48);
    setRGB2(&expected, 56, 64, 72);
    setRGB3(&expected, 80, 88, 96);

    InitGeom();
    SetFarColor(0, 0, 0);
    Psyz_GteDataWrite(8, 2048);
    Psyz_GteDataWrite(6, 0x5a000000);
    gte_ldrgb_f1_t(&packet);
    gte_ldrgb_f2_t(&packet);
    gte_ldrgb_f3_t(&packet);
    gte_dpct();
    gte_strgb_s3_t(&packet);
    assert(memcmp(&packet, &expected, sizeof(packet)) == 0);

    gte_ldrgb_s0(&packet);
    gte_dpcs_b();
    gte_strgb_s0(&packet);
    setRGB0(&expected, 8, 16, 24);
    assert(memcmp(&packet, &expected, sizeof(packet)) == 0);
    puts("Fog GTE interpolation and native packet field offsets passed.");
    return 0;
}
