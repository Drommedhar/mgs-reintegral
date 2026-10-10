#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mgs_overlay.h"

void MgsOverlayRelease(MgsOverlayRegion *regions, size_t count)
{
    for (size_t i = 0; i < count; ++i)
    {
        free(regions[i].initial);
        regions[i].initial = NULL;
    }
}

int MgsOverlayCapture(MgsOverlayRegion *regions, size_t count)
{
    for (size_t i = 0; i < count; ++i)
    {
        MgsOverlayRegion *region = &regions[i];
        if (region->initial || (uintptr_t)region->end <= (uintptr_t)region->begin)
        {
            fprintf(stderr, "Invalid native overlay data range: %s\n", region->name);
            return 0;
        }
        size_t size = (uintptr_t)region->end - (uintptr_t)region->begin;
        region->initial = malloc(size);
        if (!region->initial)
        {
            fprintf(stderr, "Cannot snapshot native overlay data: %s\n", region->name);
            MgsOverlayRelease(regions, i);
            return 0;
        }
        memcpy(region->initial, region->begin, size);
    }
    return 1;
}

void MgsOverlayRestore(MgsOverlayRegion *regions, const size_t *indices, size_t count)
{
    for (size_t i = 0; i < count; ++i)
    {
        MgsOverlayRegion *region = &regions[indices[i]];
        if (!region->initial)
        {
            fprintf(stderr, "Native overlay data was not captured: %s\n", region->name);
            abort();
        }
        size_t size = (uintptr_t)region->end - (uintptr_t)region->begin;
        memcpy(region->begin, region->initial, size);
    }
}
