#include "mgs_sight.h"

#include <libgpu.h>
#include <stdint.h>
#include <string.h>

size_t MgsSightCopyPacket(void *destination, size_t capacity,
                         const void *source, size_t available)
{
    uint32_t tag;
    size_t payload;
    size_t size;

    if (available < sizeof(tag))
    {
        return 0;
    }
    memcpy(&tag, source, sizeof(tag));
    payload = (tag >> 24) * sizeof(uint32_t);
    size = offsetof(P_TAG, r0) + payload;
    if (payload == 0 || available - sizeof(tag) < payload || capacity < size)
    {
        return 0;
    }
    setaddr(destination, NULL);
    setlen(destination, tag >> 24);
    memcpy((char *)destination + offsetof(P_TAG, r0),
           (const char *)source + sizeof(tag), payload);
    return size;
}
