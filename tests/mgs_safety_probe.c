#include <stdlib.h>
#include "mgs_safety.h"

int main(int argc, char **argv)
{
    if (argc != 5)
        return 64;
    if (MgsSafetyConfigure(argv[1]) != 0)
        return 2;
    return SafetyCheck(atoi(argv[2]), atoi(argv[3]), atoi(argv[4])) == 0 ? 0 : 3;
}
