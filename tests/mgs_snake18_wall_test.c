#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/d18a/animal/snake18/native_00.c"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

int Snake18WallDirection, Snake18WallSide, Snake18FloorHeight,
    Snake18PadDirection;
char *Snake18WallFlags;
SVECTOR *Snake18WallVector;
HZD_FLR *Snake18Wall, *Snake18Floors[2];
Snake18Init Snake18MoveInit;
short Snake18PitchLimit;
int GM_PlayerStatus;
GM_CameraSystemWork GM_Camera;
GM_SnakeCameraWork GM_SnakeCamera;

void HZD_GetLevelHazard(HZD_FLR **flr) { abort(); }
int GV_VecDir2(SVECTOR *vec) { abort(); }
int GV_DiffDirAbs(int from, int to) { abort(); }
int GV_DiffDirS(int from, int to) { abort(); }
void DG_PutVector(SVECTOR *from, SVECTOR *to, int n) { abort(); }
int HZD_LevelHazardCheck(HZD_HDL *hzd, SVECTOR *from, int chk_flag) { abort(); }
void HZD_GetLevelHeight(int *lvl_ptr) { abort(); }
int HZD_SlopeFloorLevel(SVECTOR *from, HZD_FLR *flr) { abort(); }
long MgsSquareRoot0(long value) { abort(); }
MATRIX *ReadRotMatrix(MATRIX *m) { abort(); }
void DG_TransposeMatrix(MATRIX *in, MATRIX *out) { abort(); }
MATRIX *MulMatrix0(MATRIX *m0, MATRIX *m1, MATRIX *m2) { abort(); }
void DG_MatrixRotZYX(MATRIX *mat, SVECTOR *vec) { abort(); }
void SetRotMatrix(MATRIX *m) { abort(); }
int GV_NearPhase(int from, int to) { abort(); }
int GV_NearSpeed(int from, int to, int speed) { abort(); }

typedef struct {
  int base, flags, angle, expected;
} Fixture;
static const Fixture fixtures[] = {
    {-1, 0, -32768, -32768},
    {-1, 0, -1, -1},
    {-1, 0, 0, 0},
    {-1, 0, 1, 1},
    {-1, 0, 1023, 1023},
    {-1, 0, 1024, 1024},
    {-1, 0, 1025, 1025},
    {-1, 0, 2047, 2047},
    {-1, 0, 2048, 2048},
    {-1, 0, 3071, 3071},
    {-1, 0, 3072, 3072},
    {-1, 0, 3073, 3073},
    {-1, 0, 4095, 4095},
    {-1, 0, 4096, 4096},
    {-1, 0, 32767, 32767},
    {-1, 64, -32768, -32768},
    {-1, 64, -1, -1},
    {-1, 64, 0, 0},
    {-1, 64, 1, 1},
    {-1, 64, 1023, 1023},
    {-1, 64, 1024, 1024},
    {-1, 64, 1025, 1025},
    {-1, 64, 2047, 2047},
    {-1, 64, 2048, 2048},
    {-1, 64, 3071, 3071},
    {-1, 64, 3072, 3072},
    {-1, 64, 3073, 3073},
    {-1, 64, 4095, 4095},
    {-1, 64, 4096, 4096},
    {-1, 64, 32767, 32767},
    {0, 0, -32768, 1024},
    {0, 0, -1, -1024},
    {0, 0, 0, 1024},
    {0, 0, 1, 1024},
    {0, 0, 1023, 1024},
    {0, 0, 1024, 1024},
    {0, 0, 1025, 1025},
    {0, 0, 2047, 2047},
    {0, 0, 2048, 2048},
    {0, 0, 3071, 3071},
    {0, 0, 3072, 3072},
    {0, 0, 3073, -1024},
    {0, 0, 4095, -1024},
    {0, 0, 4096, 1024},
    {0, 0, 32767, -1024},
    {0, 64, -32768, -32768},
    {0, 64, -1, -1},
    {0, 64, 0, 0},
    {0, 64, 1, 1},
    {0, 64, 1023, 1023},
    {0, 64, 1024, 1024},
    {0, 64, 1025, 1025},
    {0, 64, 2047, 2047},
    {0, 64, 2048, 2048},
    {0, 64, 3071, 3071},
    {0, 64, 3072, 3072},
    {0, 64, 3073, 3073},
    {0, 64, 4095, 4095},
    {0, 64, 4096, 4096},
    {0, 64, 32767, 32767},
    {1024, 0, -32768, -32768},
    {1024, 0, -1, -1},
    {1024, 0, 0, 0},
    {1024, 0, 1, 0},
    {1024, 0, 1023, 0},
    {1024, 0, 1024, 2048},
    {1024, 0, 1025, 2048},
    {1024, 0, 2047, 2048},
    {1024, 0, 2048, 2048},
    {1024, 0, 3071, 3071},
    {1024, 0, 3072, 3072},
    {1024, 0, 3073, 3073},
    {1024, 0, 4095, 4095},
    {1024, 0, 4096, 4096},
    {1024, 0, 32767, 32767},
    {1024, 64, -32768, -32768},
    {1024, 64, -1, -1},
    {1024, 64, 0, 0},
    {1024, 64, 1, 1},
    {1024, 64, 1023, 1023},
    {1024, 64, 1024, 1024},
    {1024, 64, 1025, 1025},
    {1024, 64, 2047, 2047},
    {1024, 64, 2048, 2048},
    {1024, 64, 3071, 3071},
    {1024, 64, 3072, 3072},
    {1024, 64, 3073, 3073},
    {1024, 64, 4095, 4095},
    {1024, 64, 4096, 4096},
    {1024, 64, 32767, 32767},
    {2048, 0, -32768, -32768},
    {2048, 0, -1, -1},
    {2048, 0, 0, 0},
    {2048, 0, 1, 1},
    {2048, 0, 1023, 1023},
    {2048, 0, 1024, 1024},
    {2048, 0, 1025, 1024},
    {2048, 0, 2047, 1024},
    {2048, 0, 2048, 3072},
    {2048, 0, 3071, 3072},
    {2048, 0, 3072, 3072},
    {2048, 0, 3073, 3073},
    {2048, 0, 4095, 4095},
    {2048, 0, 4096, 4096},
    {2048, 0, 32767, 32767},
    {2048, 64, -32768, -32768},
    {2048, 64, -1, -1},
    {2048, 64, 0, 0},
    {2048, 64, 1, 1},
    {2048, 64, 1023, 1023},
    {2048, 64, 1024, 1024},
    {2048, 64, 1025, 1025},
    {2048, 64, 2047, 2047},
    {2048, 64, 2048, 2048},
    {2048, 64, 3071, 3071},
    {2048, 64, 3072, 3072},
    {2048, 64, 3073, 3073},
    {2048, 64, 4095, 4095},
    {2048, 64, 4096, 4096},
    {2048, 64, 32767, 32767},
    {4095, 0, -32768, 5119},
    {4095, 0, -1, 5119},
    {4095, 0, 0, 5119},
    {4095, 0, 1, 5119},
    {4095, 0, 1023, 1023},
    {4095, 0, 1024, 1024},
    {4095, 0, 1025, 1025},
    {4095, 0, 2047, 2047},
    {4095, 0, 2048, 2048},
    {4095, 0, 3071, 3071},
    {4095, 0, 3072, 3071},
    {4095, 0, 3073, 3071},
    {4095, 0, 4095, 5119},
    {4095, 0, 4096, 5119},
    {4095, 0, 32767, 5119},
    {4095, 64, -32768, -32768},
    {4095, 64, -1, -1},
    {4095, 64, 0, 0},
    {4095, 64, 1, 1},
    {4095, 64, 1023, 1023},
    {4095, 64, 1024, 1024},
    {4095, 64, 1025, 1025},
    {4095, 64, 2047, 2047},
    {4095, 64, 2048, 2048},
    {4095, 64, 3071, 3071},
    {4095, 64, 3072, 3072},
    {4095, 64, 3073, 3073},
    {4095, 64, 4095, 4095},
    {4095, 64, 4096, 4096},
    {4095, 64, 32767, 32767},
};

int main(void) {
  unsigned i;
  for (i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); ++i) {
    const Fixture *fixture = &fixtures[i];
    char flags = fixture->flags;
    Snake18WallDirection = fixture->base;
    Snake18WallFlags = fixture->base < 0 ? NULL : &flags;
    assert(d18a_snake18_800CAEC0(NULL, fixture->angle) == fixture->expected);
  }
  puts("Snake18 wall steering matches 150 original MIPS cases, including "
       "no-contact movement.");
  return 0;
}
