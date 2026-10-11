#include <SDL3/SDL.h>
#include <psyz/video.h>
#include <psyz/audio.h>
#include "mgs_native.h"
#include "game/game.h"
#include "libdg/libdg.h"
#include "mgs_cadence.h"
#include "mgs_input_movie.h"
#include "mgs_controller_ports.h"
#include "mgs_frame_timing.h"
#undef fprintf

extern int str_tick_count;

static FILE *output;
static Uint64 start_ns;
static unsigned vsync, demo_id, applied_count;
static int active, total_frames, desired_frame = -1, applied_frame = -1;
static MgsCadenceCamera camera;
static int overlay_enabled;
static MgsFrameTiming timing;
static Uint64 overlay_update_us;
static unsigned slow_frames;
static double total_frame_us, maximum_frame_us;
static double minimum_frame_us;
static PsyzAudioStats last_audio;
static int menu_ready;
static int hint_visible;
static int record_all_frames;

void MgsCadenceMenuReady(void)
{
    menu_ready = 1;
}

static int PeakTrackingReady(void)
{
    const char *stage = GM_GetArea(0);
    int campaign = (stage[0] == 's' || stage[0] == 'd') &&
                   stage[1] >= '0' && stage[1] <= '9';
    return menu_ready || (campaign && GM_LoadComplete > 0 && GM_LoadRequest == 0);
}

int MgsCadenceClose(void)
{
    if (!output)
        return 1;
    FILE *file = output;
    output = NULL;
    printf("[timing] %u frames, %u over budget + 2 ms; average %.2f FPS, min/max %.3f/%.3f ms; audio empty refills %u.\n",
           vsync, slow_frames, total_frame_us > 0 ? vsync * 1000000.0 / total_frame_us : 0,
           minimum_frame_us / 1000.0, maximum_frame_us / 1000.0, last_audio.empty_refills);
    if (fclose(file) != 0) {
        fputs("Cannot finish cadence CSV.\n", stderr);
        return 0;
    }
    return 1;
}

static void CloseAtExit(void)
{
    if (!MgsCadenceClose())
        fputs("Cadence recording is incomplete.\n", stderr);
}

int MgsCadenceConfigure(const char *path, int overlay)
{
    overlay_enabled = overlay;
    if (overlay && Psyz_VideoSetDebugText("FPS --  FRAME -- ms\nMAX -- ms") != 0) {
        fputs("This renderer does not support the performance overlay.\n", stderr);
        return 0;
    }
    if (!path)
        return 1;
    const char *all_frames = SDL_getenv("MGS_CADENCE_ALL_FRAMES");
    record_all_frames = all_frames && SDL_strcmp(all_frames, "1") == 0;
    if (fopen_s(&output, path, "wb") != 0) {
        fprintf(stderr, "Cannot create cadence CSV: %s\n", path);
        return 0;
    }
    if (atexit(CloseAtExit) != 0) {
        MgsCadenceClose();
        return 0;
    }
    if (fputs("vsync,elapsed_us,stage,game_tick,pause,game_status,frame_divisor,stream_tick,demo_id,demo_active,demo_total,desired_frame,applied_frame,applied_count,camera_x,camera_y,camera_z,target_x,target_y,target_z,draw_us,frame_us,input_sample,video_frame,target_us,audio_queued_frames,audio_empty_refills,audio_backlog_clears,audio_max_refill_gap_us,audio_paused,submit_us\n", output) < 0) {
        MgsCadenceClose();
        return 0;
    }
    start_ns = SDL_GetTicksNS();
    return 1;
}

void MgsCadenceDemoStart(int count)
{
    if (!output)
        return;
    ++demo_id;
    active = 1;
    total_frames = count;
    desired_frame = applied_frame = -1;
    applied_count = 0;
}

void MgsCadenceDemoDesired(int frame)
{
    if (output)
        desired_frame = frame;
}

void MgsCadenceDemoApplied(int frame, const MgsCadenceCamera *view)
{
    if (!output)
        return;
    applied_frame = frame;
    camera = *view;
    ++applied_count;
}

void MgsCadenceDemoEnd(void)
{
    if (output)
        active = 0;
}

static int UpdateOverlay(const PsyzVideoStats *stats)
{
    Uint64 now_us = SDL_GetTicksNS() / 1000;
    MgsFrameTimingPush(&timing, now_us, stats->last_frame_time_us);
    if (!timing.peak_enabled && PeakTrackingReady()) {
        MgsFrameTimingStartPeak(&timing);
        overlay_update_us = 0;
        printf("[timing] Overlay MAX armed after %s became ready; startup frames excluded.\n", GM_GetArea(0));
    }
    if (now_us - overlay_update_us < 250000)
        return 1;
    char text[256];
    char peak[32] = "--";
    if (timing.peak_us > 0)
        snprintf(peak, sizeof(peak), "%.2f", timing.peak_us / 1000.0);
    const char *hint = MgsControllerPortsHint();
    snprintf(text, sizeof(text), "FPS %5.1f  FRAME %6.2f ms\nMAX %s ms%s%s",
             timing.fps, stats->last_frame_time_us / 1000.0, peak,
             *hint ? "\n" : "", hint);
    overlay_update_us = now_us;
    return Psyz_VideoSetDebugText(text) == 0;
}

int MgsCadenceVSync(void)
{
    PsyzVideoStats stats = {0};
    PsyzAudioStats audio = {0};
    if (!overlay_enabled) {
        const char *hint = MgsControllerPortsHint();
        if ((*hint || hint_visible) && Psyz_VideoSetDebugText(hint) != 0) {
            fputs("Cannot display the controller-port prompt.\n", stderr);
            return 0;
        }
        hint_visible = *hint != 0;
    }
    if (!output && !overlay_enabled)
        return 1;
    if (Psyz_VideoStats(&stats) != 0 || Psyz_AudioStats(&audio) != 0 ||
        (overlay_enabled && !UpdateOverlay(&stats))) {
        fputs("Cannot sample performance diagnostics.\n", stderr);
        return 0;
    }
    if (!output)
        return 1;
    ++vsync;
    last_audio = audio;
    total_frame_us += stats.last_frame_time_us;
    if (vsync == 1 || stats.last_frame_time_us < minimum_frame_us)
        minimum_frame_us = stats.last_frame_time_us;
    if (stats.last_frame_time_us > maximum_frame_us)
        maximum_frame_us = stats.last_frame_time_us;
    int slow = MgsFrameTimingSlow(stats.last_frame_time_us, stats.target_frame_time_us);
    slow_frames += slow;
    if (!slow && !record_all_frames)
        return 1;
    int result = fprintf(output,
        "%u,%llu,%s,%d,%d,%u,%d,%d,%u,%d,%d,%d,%d,%u,%d,%d,%d,%d,%d,%d,%.3f,%.3f,%u,%llu,%.3f,%u,%u,%u,%.3f,%d,%.3f\n",
        vsync, (SDL_GetTicksNS() - start_ns) / 1000, GM_GetArea(0), GV_Time,
        GV_PauseLevel, (unsigned)GM_GameStatus, DG_FrameRate, str_tick_count,
        demo_id, active, total_frames, desired_frame, applied_frame, applied_count,
        camera.eye[0], camera.eye[1], camera.eye[2],
        camera.target[0], camera.target[1], camera.target[2],
        stats.last_draw_time_us, stats.last_frame_time_us, MgsInputMovieSamples(),
        stats.total_frames, stats.target_frame_time_us, audio.queued_frames,
        audio.empty_refills, audio.backlog_clears, audio.max_refill_gap_us, audio.paused,
        stats.last_submit_time_us);
    if (result < 0 || (!record_all_frames && fflush(output) != 0)) {
        fputs("Cannot write cadence CSV.\n", stderr);
        return 0;
    }
    return 1;
}
