#include "mgs_native.h"
#undef fprintf
#include "overlays/s17a/rex_native.h"
#include <stddef.h>
#include <stdio.h>
#include <string.h>

SVECTOR DG_ZeroVector;

static int random_value;

int GV_RandU(int limit) {
  if (limit == 32)
    return 11;
  if (limit != 2)
    abort();
  return random_value;
}

int GV_RandS(int limit) {
  if (limit != 128)
    abort();
  return -5;
}

#include "rex_helpers.inc"

typedef struct {
  int input[7];
  int output[3];
} RexFixture;

#include "mgs_rex_fixtures.h"
#include "mgs_rex_geometry_checks.h"
#include "mgs_rex_particle_checks.h"

static void VerifyFixture(const RexFixture *fixture, size_t index) {
  RexWork work = {0};
  const int *in = fixture->input;
  int result[3] = {0};
  SVECTOR position = {(short)in[1], 0, (short)in[2], 0};
  work.body.m_ctrl = &work.body_motion;
  work.left_leg.m_ctrl = &work.left_motion;
  work.right_leg.m_ctrl = &work.right_motion;
  if (in[0] == 0)
    result[0] = RexNearAngle(in[1], in[2], in[3]);
  else if (in[0] == 1) {
    random_value = in[3];
    result[0] = RexChoosePatrolWaypoint(&work, &position);
    result[1] = work.patrol_index;
    result[2] = work.patrol_direction;
  } else {
    work.body_motion.info1.frames_left = in[1];
    work.body_motion.info1.frame = in[2];
    work.body_motion.info1.field_14 = in[3];
    work.left_motion.info1.field_14 = in[4];
    work.right_motion.info1.field_14 = in[5];
    if (in[0] == 2)
      RexResumeMotion(&work);
    else
      RexPauseMotion(&work);
    result[0] = work.body_motion.info1.field_14;
    result[1] = work.left_motion.info1.field_14;
    result[2] = work.right_motion.info1.field_14;
  }
  if (memcmp(result, fixture->output, sizeof(result)) != 0) {
    fprintf(stderr, "REX fixture %zu: got {%d,%d,%d}, expected {%d,%d,%d}\n",
            index, result[0], result[1], result[2], fixture->output[0],
            fixture->output[1], fixture->output[2]);
    exit(1);
  }
}

int main(void) {
  size_t index;
  _Static_assert(sizeof(RexWork) == 6904, "original REX Work layout");
  _Static_assert(offsetof(RexWork, patrol_index) == 0x1a50,
                 "original patrol state offset");
  for (index = 0; index < sizeof(rex_fixtures) / sizeof(rex_fixtures[0]);
       ++index)
    VerifyFixture(&rex_fixtures[index], index);
  printf("REX: %zu original-instruction helper comparisons passed\n", index);
  for (index = 0;
       index < sizeof(rex_particle_fixtures) / sizeof(rex_particle_fixtures[0]);
       ++index)
    VerifyParticle(&rex_particle_fixtures[index], index);
  printf("REX: %zu original-instruction particle comparisons passed\n", index);
  VerifyClipping();
  VerifyHatches();
  return 0;
}
