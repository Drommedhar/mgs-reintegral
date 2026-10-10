#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <psyz.h>
#include "mgs_mods.h"
#include "mgs_capture.h"
#include "mgs_probe.h"
#include "mgs_stages.h"
#include "mgs_disc.h"
#include "mgs_cadence.h"
#include "mgs_bonus_items.h"
#include "mgs_invulnerability.h"
#include "mgs_input_movie.h"
#include "mgs_controller_ports.h"
#include "mgs_mantis_memory.h"
#include "mgs_checkpoint.h"
#include "mgs_video.h"
#include "mgs_texture_correction.h"
#include "mgs_game_options.h"
#include "mgs_loading.h"
#include "mgs_language.h"
#include "mgs_safety.h"
#include "mgs_build.h"

extern int mgs_main(void);

typedef struct {
    const char *disc, *disc_two, *stage, *probe_mode, *mods_root, *cadence_path;
    const char *record_input, *replay_input, *input_identity;
    const char *load_checkpoint, *save_checkpoint;
    const char *text_pack, *voice_pack;
    int stage_explicit, stage_map, bonus_items, invulnerable;
    unsigned replay_tail_frames, mantis_memory_seed;
    int replay_fast, debug_overlay, auto_card, texture_correction, geometry_precision, depth_buffer;
    int fast_loading;
    MgsVideoOptions video;
} StartupOptions;

static const StartupOptions *active_options;
static int ValidateOutputPaths(const StartupOptions *options, const char *capture);

static unsigned int frame_limit;
static unsigned int frames;
static const char *capture_path;
static unsigned int capture_interval;
static int probe_enabled;

static int ParseFrameCount(const char *text, unsigned int *result)
{
    char *end;
    if (!text[0] || strspn(text, "0123456789") != strlen(text))
        return 0;
    errno = 0;
    unsigned long count = strtoul(text, &end, 10);
    if (!count || *end || errno == ERANGE)
        return 0;
    *result = count;
    return 1;
}

static int InitializeAudio(void)
{
    if (Psyz_AudioInit() != 0) {
        fputs("Cannot initialize native audio.\n", stderr);
        return 0;
    }
    if (atexit(Psyz_AudioDestroy) != 0) {
        Psyz_AudioDestroy();
        fputs("Cannot register audio shutdown.\n", stderr);
        return 0;
    }
    return 1;
}

static int CaptureIntermediateFrame(void)
{
    size_t capacity = strlen(capture_path) + 32;
    char *path = malloc(capacity);
    if (!path)
        return 0;
    int written = snprintf(path, capacity, "%s.%06u.bmp", capture_path, frames);
    int result = written > 0 && (size_t)written < capacity &&
        ValidateOutputPaths(active_options, path) && MgsCaptureFrame(path);
    free(path);
    return result;
}

static void OnVSync(void)
{
    int movie_status = MgsInputMovieVSync();
    if (!movie_status)
        exit(EXIT_FAILURE);
    if (!MgsCadenceVSync())
        exit(EXIT_FAILURE);
    if (movie_status == 2) {
        if (!MgsInputMovieClose() || !MgsCadenceClose() ||
            (active_options->save_checkpoint && !MgsCheckpointWrite(active_options->save_checkpoint)) ||
            (capture_path && !MgsCaptureFrame(capture_path)))
            exit(EXIT_FAILURE);
        exit(EXIT_SUCCESS);
    }
    if (probe_enabled && !MgsProbeVSync())
        exit(EXIT_FAILURE);
    if (!frame_limit)
        return;
    ++frames;
    if (capture_interval && frames < frame_limit && frames % capture_interval == 0 &&
        !CaptureIntermediateFrame())
        exit(EXIT_FAILURE);
    if (frames >= frame_limit)
    {
        if (!MgsCadenceClose() || !MgsInputMovieClose())
            exit(EXIT_FAILURE);
        if (capture_path && !MgsCaptureFrame(capture_path))
            exit(EXIT_FAILURE);
        printf("[native] Reached %u VSyncs.\n", frames);
        if (probe_enabled && !MgsProbeFinish())
            exit(EXIT_FAILURE);
        exit(EXIT_SUCCESS);
    }
}

enum { STARTUP_PATH_BYTES = 4096, STARTUP_OUTPUT_COUNT = 4 };
typedef struct {
    char name[STARTUP_PATH_BYTES];
    BY_HANDLE_FILE_INFORMATION file;
    int exists;
} StartupPath;

static HANDLE OpenPathAncestor(char *path)
{
    for (;;) {
        HANDLE handle = CreateFileA(path, FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
            OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
        if (handle != INVALID_HANDLE_VALUE)
            return handle;
        DWORD error = GetLastError();
        if (error != ERROR_FILE_NOT_FOUND && error != ERROR_PATH_NOT_FOUND)
            return INVALID_HANDLE_VALUE;
        char *slash = strrchr(path, '\\');
        if (!slash || !slash[1])
            return INVALID_HANDLE_VALUE;
        if (slash == path + 2 && path[1] == ':')
            slash[1] = 0;
        else
            *slash = 0;
    }
}

static int ResolveStartupPath(const char *name, StartupPath *path)
{
    char absolute[STARTUP_PATH_BYTES], ancestor[STARTUP_PATH_BYTES];
    DWORD count = GetFullPathNameA(name, sizeof(absolute), absolute, NULL);
    if (!count || count >= sizeof(absolute))
        return 0;
    memcpy(ancestor, absolute, count + 1);
    HANDLE handle = OpenPathAncestor(ancestor);
    if (handle == INVALID_HANDLE_VALUE)
        return 0;
    size_t prefix = strlen(ancestor);
    path->exists = prefix == count;
    int valid = !path->exists || GetFileInformationByHandle(handle, &path->file);
    DWORD resolved = GetFinalPathNameByHandleA(handle, path->name, sizeof(path->name), FILE_NAME_NORMALIZED);
    CloseHandle(handle);
    size_t suffix = count - prefix;
    if (!valid || !resolved || resolved >= sizeof(path->name) ||
        suffix >= sizeof(path->name) - resolved)
        return 0;
    memcpy(path->name + resolved, absolute + prefix, suffix + 1);
    return 1;
}

static int SameStartupPath(const StartupPath *first, const StartupPath *second)
{
    return _stricmp(first->name, second->name) == 0 ||
        (first->exists && second->exists &&
         first->file.dwVolumeSerialNumber == second->file.dwVolumeSerialNumber &&
         first->file.nFileIndexHigh == second->file.nFileIndexHigh &&
         first->file.nFileIndexLow == second->file.nFileIndexLow);
}

static int OutputPathsDistinct(const StartupOptions *options, const StartupPath *paths,
                               const char *const *names, unsigned count)
{
    const char *movie = options->record_input ? options->record_input : options->replay_input;
    StartupPath session;
    if (movie) {
        char name[STARTUP_PATH_BYTES];
        int written = snprintf(name, sizeof(name), "%s.session", movie);
        if (written < 0 || (size_t)written >= sizeof(name) || !ResolveStartupPath(name, &session))
            return 0;
    }
    for (unsigned output = 0; output < STARTUP_OUTPUT_COUNT; ++output) {
        if (!names[output])
            continue;
        for (unsigned other = 0; other < count; ++other) {
            if (other != output && names[other] && SameStartupPath(&paths[output], &paths[other])) {
                fprintf(stderr, "Output path aliases another input or output: %s\n", names[output]);
                return 0;
            }
        }
        if (movie) {
            size_t length = strlen(session.name);
            if (_strnicmp(paths[output].name, session.name, length) == 0 &&
                (!paths[output].name[length] || paths[output].name[length] == '\\')) {
                fprintf(stderr, "Output path is inside the protected input session: %s\n", names[output]);
                return 0;
            }
        }
    }
    return 1;
}

static int ProtectCueImages(const char *cue, const StartupPath *outputs,
                             const char *const *names)
{
    char line[STARTUP_PATH_BYTES], image[STARTUP_PATH_BYTES], absolute[STARTUP_PATH_BYTES];
    DWORD length = GetFullPathNameA(cue, sizeof(absolute), absolute, NULL);
    if (!length || length >= sizeof(absolute))
        return 0;
    FILE *file = NULL;
    if (fopen_s(&file, cue, "rb") != 0)
        return 1;
    int valid = 1;
    while (valid && fgets(line, sizeof(line), file)) {
        char *text = line + strspn(line, " \t");
        if (strncmp(text, "FILE \"", 6))
            continue;
        char *end = strchr(text + 6, '"');
        const char *slash = strrchr(absolute, '\\');
        if (!end || !slash)
            continue;
        *end = 0;
        int written = snprintf(image, sizeof(image), "%.*s%s", (int)(slash + 1 - absolute),
                               absolute, text + 6);
        StartupPath target;
        if (written < 0 || (size_t)written >= sizeof(image) || !ResolveStartupPath(image, &target)) {
            valid = 0;
            break;
        }
        for (unsigned i = 0; i < STARTUP_OUTPUT_COUNT; ++i) {
            if (names[i] && SameStartupPath(&outputs[i], &target)) {
                fprintf(stderr, "Output path aliases a disc image: %s\n", names[i]);
                valid = 0;
            }
        }
    }
    if (ferror(file))
        valid = 0;
    fclose(file);
    return valid;
}

static int ValidateOutputPaths(const StartupOptions *options, const char *capture)
{
    const char *names[] = {options->record_input, options->cadence_path, capture,
                          options->save_checkpoint, options->replay_input,
                          options->load_checkpoint, options->disc, options->disc_two,
                          options->text_pack, options->voice_pack};
    StartupPath paths[sizeof(names) / sizeof(names[0])] = {0};
    if (!names[0] && !names[1] && !names[2] && !names[3])
        return 1;
    for (unsigned i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
        if (names[i] && !ResolveStartupPath(names[i], &paths[i])) {
            fprintf(stderr, "Cannot safely resolve startup path: %s\n", names[i]);
            return 0;
        }
    }
    if (!OutputPathsDistinct(options, paths, names, sizeof(names) / sizeof(names[0])))
        return 0;
    return ProtectCueImages(options->disc, paths, names) &&
        (!options->disc_two || ProtectCueImages(options->disc_two, paths, names));
}

static int ParseOption(StartupOptions *options, const char *name, const char *value)
{
    if (strcmp(name, "--resolution") == 0)
        return MgsVideoParseResolution(value, &options->video);
    const struct { const char *name; const char **destination; } strings[] = {
        {"--disc", &options->disc}, {"--disc-two", &options->disc_two},
        {"--mods-root", &options->mods_root}, {"--capture", &capture_path},
        {"--cadence-log", &options->cadence_path}, {"--probe", &options->probe_mode},
        {"--record-input", &options->record_input},
        {"--replay-input", &options->replay_input},
        {"--load-checkpoint", &options->load_checkpoint},
        {"--text-pack", &options->text_pack}, {"--voice-pack", &options->voice_pack},
        {"--save-checkpoint", &options->save_checkpoint},
        {"--input-identity", &options->input_identity}
    };
    for (unsigned i = 0; i < sizeof(strings) / sizeof(strings[0]); ++i) {
        if (strcmp(name, strings[i].name) == 0) {
            *strings[i].destination = value;
            return 1;
        }
    }
    if (strcmp(name, "--stage") == 0) {
        options->stage = value;
        options->stage_explicit = 1;
    } else if (strcmp(name, "--stage-map") == 0) {
        char *end;
        if (value[0] < '0' || value[0] > '9')
            return 0;
        errno = 0;
        unsigned long map = strtoul(value, &end, 0);
        if (end == value || *end || errno == ERANGE || map > 0xffffu)
            return 0;
        options->stage_map = (int)map;
    } else if (strcmp(name, "--bonus-items") == 0) {
        if (strcmp(value, "1") && strcmp(value, "0"))
            return 0;
        options->bonus_items = value[0] == '1';
    } else if (strcmp(name, "--invulnerable") == 0) {
        if (strcmp(value, "1") && strcmp(value, "0"))
            return 0;
        options->invulnerable = value[0] == '1';
    } else if (strcmp(name, "--auto-card") == 0) {
        if (strcmp(value, "1") && strcmp(value, "0"))
            return 0;
        options->auto_card = value[0] == '1';
    } else if (strcmp(name, "--replay-fast") == 0) {
        if (strcmp(value, "1") && strcmp(value, "0"))
            return 0;
        options->replay_fast = value[0] == '1';
    } else if (strcmp(name, "--fast-loading") == 0) {
        if (strcmp(value, "1") && strcmp(value, "0"))
            return 0;
        options->fast_loading = value[0] == '1';
    } else if (strcmp(name, "--mantis-memory") == 0) {
        return ParseFrameCount(value, &options->mantis_memory_seed) &&
               options->mantis_memory_seed <= 2147483647u;
    } else if (strcmp(name, "--replay-tail-frames") == 0) {
        return ParseFrameCount(value, &options->replay_tail_frames);
    } else if (strcmp(name, "--frames") == 0 || strcmp(name, "--capture-every") == 0) {
        unsigned int *count = strcmp(name, "--frames") == 0 ? &frame_limit : &capture_interval;
        return ParseFrameCount(value, count);
    } else {
        return 0;
    }
    return 1;
}

static int ParseOptions(StartupOptions *options, int argc, char **argv)
{
    for (int i = 1; i < argc;)
    {
        if (strcmp(argv[i], "--widescreen") == 0) {
            options->video.widescreen = 1;
            ++i;
            continue;
        }
        if (strcmp(argv[i], "--geometry-precision") == 0) {
            options->geometry_precision = 1;
            ++i;
            continue;
        }
        if (strcmp(argv[i], "--depth-buffer") == 0) {
            options->depth_buffer = 1;
            ++i;
            continue;
        }
        if (strcmp(argv[i], "--texture-correction") == 0) {
            options->texture_correction = 1;
            ++i;
            continue;
        }
        if (strcmp(argv[i], "--fullscreen") == 0) {
            options->video.fullscreen = 1;
            ++i;
            continue;
        }
        if (strcmp(argv[i], "--debug-overlay") == 0) {
            options->debug_overlay = 1;
            ++i;
            continue;
        }
        if (i + 1 >= argc || !ParseOption(options, argv[i], argv[i + 1]))
            return 0;
        i += 2;
    }
    const char *probe_mode = options->probe_mode;
    probe_enabled = probe_mode != NULL;
    if (!options->stage_explicit && probe_mode &&
        (strcmp(probe_mode, "dock") == 0 || strcmp(probe_mode, "bonus") == 0 ||
         strcmp(probe_mode, "dock-route") == 0))
        options->stage = "s00a";
    if (!options->disc ||
        ((options->replay_fast || options->replay_tail_frames) && !options->replay_input) ||
        ((capture_path || probe_enabled) && !frame_limit && !options->replay_input) ||
        (options->replay_input && (options->record_input || probe_enabled || frame_limit || capture_interval)) ||
        (options->save_checkpoint && (!options->replay_input || options->replay_tail_frames)) ||
        (options->load_checkpoint && (strcmp(options->stage, "title") || options->stage_map >= 0)) ||
        (capture_interval && !capture_path) ||
        (options->stage_map >= 0 && (!options->stage_explicit || strcmp(options->stage, "title") == 0)))
        return 0;
    return 1;
}

static void PrintUsage(FILE *stream)
{
    fputs("RE:INTEGRAL " MGS_RELEASE_VERSION " (" MGS_BUILD_COMMIT ")\n"
          "Usage: mgs-integral-native --disc <Integral disc.cue> [options]\n"
          "  --version | --check-disc 1|2 <disc.cue> (no game boot)\n"
          "  --widescreen --resolution WIDTHxHEIGHT --fullscreen --debug-overlay\n"
          "  --texture-correction --geometry-precision --depth-buffer (modern renderer)\n"
          "  --disc-two <Disc 2.cue> --mods-root <path> --bonus-items 0|1\n"
          "  --invulnerable 0|1\n"
          "  --auto-card 0|1\n"
          "  --fast-loading 0|1 (accelerate map loading only)\n"
          "  --text-pack <pack.mgslang> --voice-pack <pack.mgslang>\n"
          "  --check-language <pack.mgslang> (validate without game boot)\n"
          "  --mantis-memory SEED (1..2147483647; synthetic memory-card reading)\n"
          "  --stage <linked stage> [--stage-map id] --frames count\n"
          "  --record-input <path> | --replay-input <path>\n"
          "  --input-identity sha256 --replay-fast 0|1 --replay-tail-frames count\n"
          "  --load-checkpoint <path> --save-checkpoint <path>\n"
          "  --capture <frame.bmp> [--capture-every count] --cadence-log <samples.csv>\n"
          "  --probe <named development probe>\n"
          "Widescreen defaults to 1280x720; resolution alone keeps the original aspect.\n",
          stream);
}

int main(int argc, char **argv)
{
    if (argc == 3 && strcmp(argv[1], "--check-language") == 0)
        return MgsLanguageInspect(argv[2]) ? 0 : 2;
    if (argc == 2 && strcmp(argv[1], "--version") == 0) {
        puts("RE:INTEGRAL " MGS_RELEASE_VERSION " (" MGS_BUILD_COMMIT ")");
        return 0;
    }
    if (argc == 4 && strcmp(argv[1], "--check-disc") == 0) {
        int number = strcmp(argv[2], "1") == 0 ? 1 : strcmp(argv[2], "2") == 0 ? 2 : 0;
        if (!number || MgsSafetyConfigure(argv[3]) != 0)
            return 2;
        if (MgsSafetyDiscNumber() != number) {
            fprintf(stderr, "Expected Integral Disc %d; selected Disc %d.\n", number, MgsSafetyDiscNumber());
            return 2;
        }
        return 0;
    }
    if (argc == 2 && strcmp(argv[1], "--help") == 0) {
        PrintUsage(stdout);
        return 0;
    }
    StartupOptions options = {.stage = "title", .stage_map = -1};
    if (!ParseOptions(&options, argc, argv))
    {
        PrintUsage(stderr);
        return 2;
    }
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
    if (!ValidateOutputPaths(&options, capture_path))
        return 2;
    if (!MgsLanguageConfigure(options.text_pack, options.voice_pack))
        return 2;
    if (atexit(MgsLanguageClose) != 0) {
        MgsLanguageClose();
        return 1;
    }
    if (!MgsVideoConfigure(&options.video))
        return 2;
    if (!MgsTextureCorrectionConfigure(options.texture_correction, options.geometry_precision, options.depth_buffer)) {
        fputs("These geometry options require the modern renderer build.\n", stderr);
        return 2;
    }
    active_options = &options;
    setvbuf(stdout, NULL, _IONBF, 0);
    MgsBonusItemsConfigure(options.bonus_items);
    MgsInvulnerabilityConfigure(options.invulnerable);
    MgsGameOptionsConfigure(options.auto_card);
    MgsMantisMemoryConfigure(options.mantis_memory_seed);
    if (!MgsCheckpointConfigure(options.load_checkpoint))
        return 2;
    if (!MgsNativeConfigureStart(options.stage, options.stage_map))
        return 2;
    if (probe_enabled && !MgsProbeInit(options.probe_mode))
        return 1;
    if (MgsModsConfigure(options.mods_root) != 0)
        return 1;
    if (!MgsCadenceConfigure(options.cadence_path, options.debug_overlay))
        return 1;
    const char *initial_disc = MgsCheckpointDisc() == 2 ? options.disc_two : options.disc;
    if (!initial_disc) {
        fputs("The checkpoint requires --disc-two <Integral Disc 2.cue>.\n", stderr);
        return 2;
    }
    if (MgsDiscConfigure(initial_disc, options.disc_two) != 0)
    {
        fprintf(stderr, "Cannot open disc: %s\n", initial_disc);
        return 1;
    }
    if (!InitializeAudio())
        return 1;
    if (!MgsInputMovieConfigure(options.record_input, options.replay_input, options.input_identity,
                               options.replay_tail_frames))
        return 1;
    if (!MgsLoadingConfigure(options.fast_loading)) {
        fputs("Fast loading requires the deterministic game clock.\n", stderr);
        return 1;
    }
    MgsControllerPortsInit();
    if (options.replay_fast) {
        if (Psyz_VideoSetVsyncMode(PSYZ_VSYNC_LIMITLESS) != 0)
            return 1;
        Psyz_AudioPause();
        puts("[input] Fast replay: presentation audio muted; simulated sound and interrupts continue.");
    }
    printf("[native] RE:INTEGRAL " MGS_RELEASE_VERSION " (" MGS_BUILD_COMMIT "); stage: %s\n", options.stage);
    Psyz_SetVSyncCb(OnVSync);
    return mgs_main();
}
