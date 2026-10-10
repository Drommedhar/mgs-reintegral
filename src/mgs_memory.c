#include "mgs_native.h"
#include "libgv/libgv.h"

_Alignas(16) unsigned long psyz_scratchpad[256];
_Alignas(16) unsigned char
    mgs_main_ram[MGS_RESIDENT_HEADROOM + MGS_MAIN_RAM_SIZE + MGS_TOP_RAM_SIZE];
