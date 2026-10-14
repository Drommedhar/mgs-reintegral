#ifndef MGS_SAVE_MENU_H
#define MGS_SAVE_MENU_H

#include <stdint.h>

enum { MGS_SAVE_UP = 1, MGS_SAVE_DOWN = 2, MGS_SAVE_ACCEPT = 4, MGS_SAVE_CANCEL = 8 };
typedef struct { int ready, value; } MgsSaveResponse;

/* Adapts the native worker's requests; never reads or writes save payloads. */
MgsSaveResponse MgsSaveMenuStep(uint32_t request, int storage, unsigned input);

#endif
