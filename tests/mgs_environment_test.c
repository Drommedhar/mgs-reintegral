#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

_Alignas(16) unsigned long psyz_scratchpad[256];

#include "environment_helpers.inc"

static void TestCoordinates(void)
{
    SVECTOR normals[5] = {
        {4096, 0, 0, 0}, {-4096, 4096, 0, 0}, {1024, -2048, 0, 0},
        {0, 1024, 4096, 0}, {-1024, -4096, 0, 0}
    };
    static const unsigned char expected[10] = {191, 64, 65, 1, 143, 96, 128, 49, 112, 127};
    MATRIX scale = {{{63, 0, 0}, {0, 63, 0}, {0, 0, 63}}, {0, 0, 0}};
    DG_MDL model = {0};
    Envmap3Scratch *scratch = (Envmap3Scratch *)psyz_scratchpad;
    memset(psyz_scratchpad, 0x5a, sizeof(psyz_scratchpad));
    scratch->x = 128;
    scratch->y = 64;
    model.norms = normals;
    model.n_norms = 5;
    SetRotMatrix(&scale);
    Envmap3_800C9F14(&model);
    assert(memcmp(scratch->uv, expected, sizeof(expected)) == 0);
    assert(scratch->uv[10] == 0x5a && scratch->uv[11] == 0x5a);

    model.verts = normals;
    model.n_verts = 5;
    memset(scratch->uv, 0x5a, sizeof(scratch->uv));
    SubEfct_800CC798(&model);
    assert((unsigned char)scratch->uv[0] == 135);
    assert((unsigned char)scratch->uv[2] == 120);
    assert((unsigned char)scratch->uv[4] == 129);
    assert((unsigned char)scratch->uv[6] == 128);
    assert((unsigned char)scratch->uv[8] == 126);
    for (int i = 1; i < 10; i += 2)
        assert(scratch->uv[i] == 0x5a);
    assert(scratch->uv[10] == 0x5a);
}

static void TestPacketFields(void)
{
    POLY_GT4 packets[2], expected[2];
    unsigned int indices[2] = {0x03020100, 0x03020100};
    unsigned char *uv = (unsigned char *)psyz_scratchpad;
    memset(packets, 0x3c, sizeof(packets));
    packets[0].tag = 0x1234;
    packets[1].tag = 0xff001234;
    setlen(&packets[0], 12);
    setlen(&packets[1], 0);
    for (int i = 0; i < 8; i++) uv[i] = 70 + i;
    memcpy(expected, packets, sizeof(expected));
    setUV4(&expected[0], 70, 71, 72, 73, 76, 77, 74, 75);
    assert(Envmap3_800C9FF4(indices, packets, 2) == packets + 2);
    assert(memcmp(packets, expected, sizeof(expected)) == 0);

    for (int i = 0; i < 8; i++) uv[i] = 20 + i;
    expected[0].u0 = 20;
    expected[0].u1 = 22;
    expected[0].u2 = 26;
    expected[0].u3 = 24;
    assert(SubEfct_800CC860(indices, packets, 2) == packets + 2);
    assert(memcmp(packets, expected, sizeof(expected)) == 0);
}

int main(void)
{
    InitGeom();
    TestCoordinates();
    TestPacketFields();
    puts("Environment/submarine coordinates and native packet preservation passed.");
    return 0;
}
