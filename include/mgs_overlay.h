#ifndef MGS_OVERLAY_H
#define MGS_OVERLAY_H

#include <stddef.h>

typedef struct {
    const char *name;
    unsigned char *begin;
    unsigned char *end;
    unsigned char *initial;
} MgsOverlayRegion;

int MgsOverlayCapture(MgsOverlayRegion *regions, size_t count);
void MgsOverlayRelease(MgsOverlayRegion *regions, size_t count);
void MgsOverlayRestore(MgsOverlayRegion *regions, const size_t *indices, size_t count);

#endif
