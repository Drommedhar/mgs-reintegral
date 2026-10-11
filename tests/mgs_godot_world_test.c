#include "mgs_native.h"
#include "mgs_godot_scene.h"
#include "libdg/libdg.h"
#include <assert.h>

typedef struct { O_TAG; u_long code, near_depth, far_depth; } Packet;
static int enabled = 1;
int MgsGodotSceneEnabled(void) { return enabled; }

static void Clear(OT_TYPE *table) {
    for (unsigned i = 0; i < 257; ++i) {
        setlen(&table[i], 0);
        setaddr(&table[i], i ? &table[i - 1] : NULL);
    }
}

static void Check(DG_CHANL *channel, int buffer, unsigned primitives) {
    OT_TYPE *table = channel->ot[buffer];
    void *packet = (void *)getaddr(table + 256);
    assert(((Packet *)packet)->code == 0xf4000000u);
    assert(((Packet *)packet)->near_depth == 65536 && ((Packet *)packet)->far_depth == 65537);
    unsigned walked = 0, found = 0, background = 0;
    while (packet != table) {
        assert(++walked <= 780);
        if (getlen(packet)) {
            const Packet *node = packet;
            if (node->code == 0xf4000000u) {
                assert(node->near_depth < node->far_depth);
                if (node->near_depth == 65536) ++background;
            } else {
                assert(node->code == 0x20000000u);
                ++found;
            }
        }
        packet = (void *)getaddr(packet);
    }
    assert(found == primitives && background == 1);
}

int main(void) {
    OT_TYPE tables[2][257];
    Packet primitives[2][3] = {0};
    DG_CHANL channel = {0};
    for (int buffer = 0; buffer < 2; ++buffer) {
        channel.ot[buffer] = tables[buffer];
        Clear(tables[buffer]);
        MgsGodotSortWorld(&channel, buffer);
        Check(&channel, buffer, 0);
        for (int repeat = 0; repeat < 3; ++repeat) {
            MgsGodotSortWorld(&channel, buffer);
            Check(&channel, buffer, 0);
        }
        const unsigned buckets[] = {1, 10, 256};
        for (unsigned i = 0; i < 3; ++i) {
            Packet *node = &primitives[buffer][i];
            setlen(node, 3);
            node->code = 0x20000000u;
            addPrim(tables[buffer] + buckets[i], node);
        }
        for (int repeat = 0; repeat < 3; ++repeat) {
            MgsGodotSortWorld(&channel, buffer);
            Check(&channel, buffer, 3);
        }
        enabled = 0;
        MgsGodotSortWorld(&channel, buffer);
        enabled = 1;
        MgsGodotSortWorld(&channel, buffer);
        Check(&channel, buffer, 3);
    }
    puts("PASS: background ordering, native packets and repeated sorting across pause/buffers");
    return 0;
}
