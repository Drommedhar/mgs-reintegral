#ifndef MGS_NATIVE_H
#define MGS_NATIVE_H

#include <psyz/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mgs_stages.h"
#include "mgs_math.h"
#include "mgs_invulnerability.h"
#include "mgs_texture_correction.h"

typedef unsigned int u_int;

int mgs_fprintf(int channel, const char *format, ...);

#define fprintf mgs_fprintf
#define cprintf printf
#define SquareRoot0 MgsSquareRoot0

_Static_assert(sizeof(void *) == 4, "MGS native currently requires 32-bit pointers");
_Static_assert(sizeof(long) == 4, "MGS data requires 32-bit long values");

#endif
