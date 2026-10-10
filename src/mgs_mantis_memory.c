#include "mgs_mantis_memory.h"

static unsigned int profile_seed;

void MgsMantisMemoryConfigure(unsigned int seed)
{
    profile_seed = seed;
}

unsigned int MgsMantisMemorySeed(void)
{
    return profile_seed;
}
