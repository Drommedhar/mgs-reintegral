#include "mgs_visibility.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    short *mode;
    short classic_mode;
} VisibilityEntry;

static VisibilityEntry *entries;
static size_t count;
static size_t capacity;
static int active;

void MgsVisibilityBegin(int enabled)
{
    count = 0;
    active = enabled;
}

static void ReserveEntry(void)
{
    size_t next = capacity ? capacity * 2 : 256;
    VisibilityEntry *grown;

    if (next < capacity || next > SIZE_MAX / sizeof(*entries))
    {
        fputs("Native visibility snapshot capacity overflow\n", stderr);
        exit(EXIT_FAILURE);
    }
    grown = realloc(entries, next * sizeof(*entries));
    if (!grown)
    {
        fputs("Cannot allocate native visibility snapshots\n", stderr);
        exit(EXIT_FAILURE);
    }
    entries = grown;
    capacity = next;
}

void MgsVisibilityRemember(short *mode, int classic_mode)
{
    if (!active)
        return;
    if (count == capacity)
        ReserveEntry();
    entries[count].mode = mode;
    entries[count].classic_mode = (short)classic_mode;
    ++count;
}

void MgsVisibilityEnd(void)
{
    size_t index;

    for (index = 0; index < count; ++index)
        *entries[index].mode = entries[index].classic_mode;
    count = 0;
    active = 0;
}
