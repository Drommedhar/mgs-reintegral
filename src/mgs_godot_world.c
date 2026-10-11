#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "libdg/libdg.h"

typedef struct { O_TAG; u_long code, near_depth, far_depth; } WorldMarker;
static WorldMarker world_markers[2][513];

static void LinkWorldMarker(WorldMarker *marker, void *previous, unsigned near_depth, unsigned far_depth) {
    setlen(marker, 3);
    marker->code = 0xf4000000u;
    marker->near_depth = near_depth;
    marker->far_depth = far_depth;
    addPrim(previous, marker);
}

void MgsGodotSortWorld(DG_CHANL *channel, int buffer_index) {
    if (!MgsGodotSceneEnabled()) return;
    WorldMarker *marker = world_markers[buffer_index];
    void *previous = channel->ot[buffer_index] + 256;
    const uintptr_t first = (uintptr_t)marker;
    const uintptr_t last = (uintptr_t)(marker + 513);
    while (previous != channel->ot[buffer_index]) {
        void *next = (void *)getaddr(previous);
        if ((uintptr_t)next >= first && (uintptr_t)next < last)
            setaddr(previous, getaddr(next));
        else
            previous = next;
    }
    unsigned far_depth = 65536;
    for (int index = 255; index >= 0; --index) {
        OT_TYPE *bucket = channel->ot[buffer_index] + 1 + index;
        void *end = bucket - 1;
        void *tail = bucket;
        while ((void *)getaddr(tail) != end) tail = (void *)getaddr(tail);
        if (tail == bucket) continue;
        unsigned upper = (index + 1u) * 256u;
        if (upper < far_depth) LinkWorldMarker(marker++, bucket, upper, far_depth);
        LinkWorldMarker(marker++, tail, index * 256u, upper);
        far_depth = index * 256u;
    }
    if (far_depth) LinkWorldMarker(marker++, channel->ot[buffer_index] + 1, 0, far_depth);
    LinkWorldMarker(marker, channel->ot[buffer_index] + 256, 65536, 65537);
}
