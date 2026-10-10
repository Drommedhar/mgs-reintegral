#ifndef MGS_FRAME_TIMING_H
#define MGS_FRAME_TIMING_H

#include <stdint.h>

enum { MGS_TIMING_CAPACITY = 256 };
typedef struct {
    uint64_t end_us[MGS_TIMING_CAPACITY];
    double frame_us[MGS_TIMING_CAPACITY];
    unsigned next, count;
    double fps, peak_us;
    int peak_enabled;
} MgsFrameTiming;

void MgsFrameTimingStartPeak(MgsFrameTiming *timing);
void MgsFrameTimingPush(MgsFrameTiming *timing, uint64_t now_us, double frame_us);
int MgsFrameTimingSlow(double frame_us, double target_us);

#endif
