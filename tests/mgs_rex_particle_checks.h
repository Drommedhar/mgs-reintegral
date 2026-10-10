typedef struct
{
    int input[6];
    int output[22];
} RexParticleFixture;

#include "mgs_rex_particle_fixtures.h"

static void VerifyParticle(const RexParticleFixture *fixture, size_t index)
{
    RexParticleWork work = {0};
    DG_TEX texture = {0};
    POLY_FT4 packet = {0};
    const int *in = fixture->input;
    int result[22];
    int field;
    SVECTOR *position = &work.vertices[0];
    SVECTOR *speed = &work.speeds[0];
    RexParticleState *state = &work.states[0];
    work.kind = in[0];
    work.texture = &texture;
    texture.off_x = 17;
    texture.off_y = 33;
    texture.w = 127;
    texture.h = 63;
    *position = (SVECTOR){123, in[4], -234, in[5]};
    *speed = (SVECTOR){-31, -40, 29, 15};
    *state = (RexParticleState){in[1], in[2], work.kind == REX_DRUM_SMOKE ? 0 : in[3], 0};
    RexParticleStep(&work, 0, &packet);
    result[0] = position->vx;
    result[1] = position->vy;
    result[2] = position->vz;
    result[3] = position->pad;
    result[4] = speed->vx;
    result[5] = speed->vy;
    result[6] = speed->vz;
    result[7] = speed->pad;
    result[8] = state->life;
    result[9] = state->frame;
    result[10] = state->fade;
    result[11] = packet.r0;
    result[12] = packet.g0;
    result[13] = packet.b0;
    result[14] = packet.u0;
    result[15] = packet.v0;
    result[16] = packet.u1;
    result[17] = packet.v1;
    result[18] = packet.u2;
    result[19] = packet.v2;
    result[20] = packet.u3;
    result[21] = packet.v3;
    for (field = 0; field < 22; ++field)
    {
        if (result[field] != fixture->output[field])
        {
            fprintf(stderr, "REX particle %zu field %d: got %d, expected %d\n", index, field, result[field],
                    fixture->output[field]);
            exit(1);
        }
    }
}
