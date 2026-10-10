#include <stddef.h>

static int initialized = 44;
static int tentative;
static int *relocated = &initialized;
static _Alignas(16) unsigned char aligned_data[32] = {3, 9};

int OverlayActorALocal(int increment)
{
    static int local;
    local += increment;
    return local;
}

int OverlayActorAInitial(void)
{
    return initialized == 44 && tentative == 0 && relocated == &initialized &&
           aligned_data[0] == 3 && aligned_data[1] == 9 && OverlayActorALocal(0) == 0;
}

void OverlayActorAMutate(void)
{
    initialized = 91;
    tentative = 7;
    relocated = NULL;
    aligned_data[0] = 19;
    OverlayActorALocal(10);
}
