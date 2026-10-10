#ifndef MGS_MODS_H
#define MGS_MODS_H

#include <stddef.h>

int MgsModsConfigure(const char *root);
int MgsModsSetStage(const char *stage);

/* Returns 1 for replacement, 0 for disabled/missing, and -1 for failure. */
int MgsModsApply(unsigned int id, int extension, void *data, size_t size);

#endif
