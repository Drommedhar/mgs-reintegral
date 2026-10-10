typedef struct {
  int input[6];
  int output[4];
} RexClipFixture;

typedef struct {
  int input[4];
  short output[16];
} RexHatchFixture;

#include "mgs_rex_geometry_fixtures.h"

static void VerifyClipping(void) {
  size_t index;
  for (index = 0;
       index < sizeof(rex_clip_fixtures) / sizeof(rex_clip_fixtures[0]);
       ++index) {
    const RexClipFixture *fixture = &rex_clip_fixtures[index];
    const int *in = fixture->input;
    SVECTOR start = {in[0], in[1], in[2], 0}, clipped = {0};
    VECTOR destination = {in[3], in[4], in[5], 0};
    int length = RexLaserClip(&start, &destination, &clipped, 30000);
    int result[] = {clipped.vx, clipped.vy, clipped.vz, length};
    if (memcmp(result, fixture->output, sizeof(result))) {
      fprintf(stderr, "REX laser clipping fixture %zu failed\n", index);
      exit(1);
    }
  }
  printf("REX: %zu original-instruction laser clipping comparisons passed\n",
         index);
}

static void VerifyHatches(void) {
  size_t index;
  for (index = 0;
       index < sizeof(rex_hatch_fixtures) / sizeof(rex_hatch_fixtures[0]);
       ++index) {
    const RexHatchFixture *fixture = &rex_hatch_fixtures[index];
    const int *in = fixture->input;
    RexHatchWork work = {0};
    work.spin = (SVECTOR){in[3], -in[3], in[3] + 1, 0};
    work.position = (SVECTOR){1234, in[0], -2345, 0};
    work.rotation = (SVECTOR){-123, 234, -345, 0};
    work.velocity = (SVECTOR){in[1], in[2], -in[1], 0};
    RexHatchMove(&work);
    if (memcmp(&work.spin, fixture->output, sizeof(fixture->output))) {
      fprintf(stderr, "REX hatch motion fixture %zu failed\n", index);
      exit(1);
    }
  }
  printf("REX: %zu original-instruction hatch motion comparisons passed\n",
         index);
}
