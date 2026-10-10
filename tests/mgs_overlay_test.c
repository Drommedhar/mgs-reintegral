#include <assert.h>
#include <stdio.h>
#include "mgs_overlay.h"

#include "mgs_overlay_regions.inc"

int OverlayActorAInitial(void);
int OverlayActorBInitial(void);
void OverlayActorAMutate(void);
void OverlayActorBMutate(void);

static int resident_state;

int main(void)
{
    size_t count = sizeof(overlay_regions) / sizeof(overlay_regions[0]);
    assert(count == 2);
    assert(MgsOverlayCapture(overlay_regions, count));
    assert(OverlayActorAInitial() && OverlayActorBInitial());
    OverlayActorAMutate();
    OverlayActorBMutate();
    resident_state = 123;
    assert(!OverlayActorAInitial() && !OverlayActorBInitial());

    MgsOverlayRestore(overlay_regions, stage_regions_a, 1);
    assert(OverlayActorAInitial() && !OverlayActorBInitial());
    OverlayActorAMutate();
    MgsOverlayRestore(overlay_regions, stage_regions_b, 1);
    assert(!OverlayActorAInitial() && OverlayActorBInitial());
    MgsOverlayRestore(overlay_regions, stage_regions_shared, 2);
    assert(OverlayActorAInitial() && OverlayActorBInitial());
    assert(resident_state == 123);

    MgsOverlayRelease(overlay_regions, count);
    assert(!overlay_regions[0].initial && !overlay_regions[1].initial);
    unsigned char invalid[2];
    MgsOverlayRegion reversed = {"invalid test range", invalid + 1, invalid, NULL};
    assert(!MgsOverlayCapture(&reversed, 1));
    puts("Overlay initialized data, BSS, locals, pointers, sharing and resident isolation passed.");
    return 0;
}
