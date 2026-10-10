#ifndef MGS_SIGHT_H
#define MGS_SIGHT_H

#include <stddef.h>

size_t MgsSightCopyPacket(void *destination, size_t capacity,
                         const void *source, size_t available);

#endif
