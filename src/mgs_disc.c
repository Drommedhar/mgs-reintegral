#include "mgs_disc.h"
#include "mgs_safety.h"

#include <psyz/cd.h>
#include <stdio.h>
#include <stdlib.h>

static const char *second_disc;
static int changing_disc;

int MgsDiscConfigure(const char *initial_disc, const char *disc_two)
{
    second_disc = disc_two;
    changing_disc = 0;
    if (MgsSafetyConfigure(initial_disc) != 0)
        return -1;
    return Psyz_CdSetDiskPath(initial_disc);
}

void MgsDiscChangeOpen(void)
{
    if (!second_disc)
    {
        fputs("[native] The original campaign requested Disc 2. Supply --disc-two <Integral Disc 2.cue>.\n", stderr);
        exit(EXIT_FAILURE);
    }
    Psyz_CdShellOpen(1);
    changing_disc = 1;
    puts("[native] Original disc-change actor opened the virtual drive.");
}

void MgsDiscChangeClose(void)
{
    if (!changing_disc)
        return;
    if (MgsSafetyConfigure(second_disc) != 0 || Psyz_CdSetDiskPath(second_disc) != 0)
    {
        fprintf(stderr, "[native] Could not insert Disc 2: %s\n", second_disc);
        exit(EXIT_FAILURE);
    }
    changing_disc = 0;
    Psyz_CdShellOpen(0);
    puts("[native] Disc 2 inserted. Press Start at the original disc-change screen.");
}
