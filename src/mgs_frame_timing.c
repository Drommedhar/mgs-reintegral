#include "mgs_frame_timing.h"

void MgsFrameTimingStartPeak(MgsFrameTiming *timing)
{
    timing->peak_enabled = 1;
}

void MgsFrameTimingPush(MgsFrameTiming *timing, uint64_t now_us, double frame_us)
{
    unsigned slot = timing->next;
    timing->end_us[slot] = now_us;
    timing->frame_us[slot] = frame_us;
    timing->next = (slot + 1) % MGS_TIMING_CAPACITY;
    if (timing->count < MGS_TIMING_CAPACITY)
        ++timing->count;
    double sum = 0;
    unsigned count = 0;
    if (timing->peak_enabled && frame_us > timing->peak_us)
        timing->peak_us = frame_us;
    for (unsigned i = 0; i < timing->count; ++i) {
        if (now_us - timing->end_us[i] >= 1000000)
            continue;
        double duration = timing->frame_us[i];
        sum += duration;
        ++count;
    }
    timing->fps = sum > 0 ? count * 1000000.0 / sum : 0;
}

int MgsFrameTimingSlow(double frame_us, double target_us)
{
    return frame_us > target_us + 2000.0;
}
