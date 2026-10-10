#include <assert.h>
#include <math.h>
#include "mgs_frame_timing.h"

int main(void)
{
    MgsFrameTiming timing = {0};
    MgsFrameTimingPush(&timing, 100000, 400000);
    MgsFrameTimingPush(&timing, 200000, 100000);
    assert(timing.peak_us == 0 && timing.fps > 0);
    MgsFrameTimingStartPeak(&timing);
    MgsFrameTimingPush(&timing, 1200000, 16683);
    assert(timing.peak_us == 16683);
    assert(fabs(timing.fps - 1000000.0 / 16683) < 0.001);
    MgsFrameTimingStartPeak(&timing);
    assert(timing.peak_us == 16683);
    timing = (MgsFrameTiming){0};
    MgsFrameTimingStartPeak(&timing);
    MgsFrameTimingPush(&timing, 1000000, 40000);
    for (unsigned i = 1; i <= 59; ++i)
        MgsFrameTimingPush(&timing, 1000000 + i * 16683, 16683);
    assert(timing.peak_us == 40000);
    assert(timing.fps < 59);
    MgsFrameTimingPush(&timing, 2000000, 16683);
    assert(timing.peak_us == 40000);
    assert(fabs(timing.fps - 1000000.0 / 16683) < 0.001);
    for (unsigned i = 1; i < 500; ++i)
        MgsFrameTimingPush(&timing, 2000000 + i * 16683, 16683);
    assert(timing.peak_us == 40000 && timing.count == MGS_TIMING_CAPACITY);
    assert(!MgsFrameTimingSlow(16684, 16683));
    assert(!MgsFrameTimingSlow(18683, 16683));
    assert(MgsFrameTimingSlow(18684, 16683));
    assert(!MgsFrameTimingSlow(22000, 20000));
    assert(MgsFrameTimingSlow(22001, 20000));
    return 0;
}
