#include "mgs_video.h"
#include <libgpu.h>
#include <psyz.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef MGS_GODOT_SCENE
#include "mgs_godot_scene.h"
#include "transport.h"
#endif

enum { VIDEO_COMMAND = 0xf3, FRAME_WIDTH = 320, FRAME_HEIGHT = 224 };
static unsigned view_numerator = 1, view_denominator = 1;
static int widescreen, frame_active, frame_centre, capture_output, movie_active;
static int codec_active, menu_stage;
static unsigned output_width, output_height;

int MgsVideoReferenceRequired(void)
{
    return movie_active || codec_active || menu_stage;
}

#ifdef MGS_GODOT_SCENE
static int GodotWorldCommand(const u_long *words, int available, void *userdata)
{
    (void)userdata;
    if (available < 3 || words[1] >= words[2] || words[2] > 65537 || (words[2] == 65537 && words[1] != 65536)) return -1;
    if (MgsGodotSceneEnabled()) MgsGodotWorldBegin(words[1], words[2]);
    return 3;
}
#endif

static int ParseDimension(const char **text, unsigned *result)
{
    const char *cursor = *text;
    unsigned value = 0;
    if (*cursor < '0' || *cursor > '9')
        return 0;
    do {
        unsigned digit = (unsigned)(*cursor++ - '0');
        if (value > (UINT32_MAX - digit) / 10)
            return 0;
        value = value * 10 + digit;
    } while (*cursor >= '0' && *cursor <= '9');
    *text = cursor;
    *result = value;
    return 1;
}

int MgsVideoParseResolution(const char *text, MgsVideoOptions *options)
{
    unsigned width, height;
    if (!text || !ParseDimension(&text, &width) || *text++ != 'x' ||
        !ParseDimension(&text, &height) || *text ||
        width < 320 || width > 7680 || height < 240 || height > 4320)
        return 0;
    options->width = width;
    options->height = height;
    return 1;
}

static unsigned GreatestCommonDivisor(unsigned first, unsigned second)
{
    while (second) {
        unsigned remainder = first % second;
        first = second;
        second = remainder;
    }
    return first;
}

static int SetChannelTransform(int mode)
{
    int original = movie_active || codec_active || menu_stage;
    if (Psyz_GpuSetFramebufferSampling(mode == MGS_VIDEO_CANVAS) != 0 ||
        Psyz_GpuSetTextureAlignment(mode != MGS_VIDEO_WORLD || original) != 0)
        return 0;
    if (mode == MGS_VIDEO_CANVAS || !widescreen || movie_active || codec_active || menu_stage)
        return Psyz_GpuSetFrameTransform(1, 1, frame_centre, 0) == 0;
    return Psyz_GpuSetFrameTransform(view_numerator, view_denominator,
                                    frame_centre, mode == MGS_VIDEO_HUD) == 0;
}

static int VideoCommand(const u_long *words, int available, void *userdata)
{
    (void)userdata;
    if (available < 1 || (words[0] & 0x00ffffffu) > MGS_VIDEO_BACKGROUND)
        return -1;
    if (frame_active && !SetChannelTransform((int)(words[0] & 0x00ffffffu)))
        return -1;
    return 1;
}

int MgsVideoConfigure(const MgsVideoOptions *options)
{
#ifdef MGS_GODOT_SCENE
    if (Psyz_GpuRegisterCommandHandler(0xf4, GodotWorldCommand, NULL) != 0)
        return 0;
#endif
    if (!options->width && !options->widescreen && !options->fullscreen)
        return 1;
    unsigned width = options->width ? options->width : 1280;
    unsigned height = options->height ? options->height : options->widescreen ? 720 : 960;
    unsigned source_height = options->widescreen ? FRAME_HEIGHT : 240;
    unsigned scale_x = (width + FRAME_WIDTH - 1) / FRAME_WIDTH;
    unsigned scale_y = (height + source_height - 1) / source_height;
    unsigned scale = scale_x > scale_y ? scale_x : scale_y;
    if (scale > PSYZ_INTERNAL_RES_MAX) {
        fprintf(stderr, "Resolution %ux%u requires %ux rendering; this renderer supports up to %ux.\n",
                width, height, scale, PSYZ_INTERNAL_RES_MAX);
        return 0;
    }
    if (options->widescreen && (width * 3 < height * 4 || width * 3 > height * 12)) {
        fputs("Widescreen aspect must be between 4:3 and 4:1.\n", stderr);
        return 0;
    }
#ifdef MGS_GODOT_SCENE
    /* Godot scales the output; the native transport keeps PS1 packet coordinates. */
    scale = 1;
#endif
    if (Psyz_VideoConfigureWindow(width, height, options->fullscreen) != 0 ||
        Psyz_VideoSetInternalResolution(scale) != 0) {
        fputs("Renderer cannot configure the requested output resolution.\n", stderr);
        return 0;
    }
    capture_output = 1;
    output_width = width;
    output_height = height;
    widescreen = options->widescreen;
    if (widescreen) {
        unsigned divisor = GreatestCommonDivisor(4 * height, 3 * width);
        view_numerator = 4 * height / divisor;
        view_denominator = 3 * width / divisor;
        if (Psyz_VideoSetPresentation(width, height, FRAME_HEIGHT) != 0) {
            fputs("Renderer does not support widescreen presentation.\n", stderr);
            return 0;
        }
    }
    if (Psyz_GpuSetFrameTransform(1, 1, 0, 0) != 0 ||
        Psyz_GpuSetFramebufferSampling(0) != 0 ||
        Psyz_GpuSetTextureAlignment(0) != 0 ||
        Psyz_GpuRegisterCommandHandler(VIDEO_COMMAND, VideoCommand, NULL) != 0) {
        fputs("Renderer does not support output-resolution drawing.\n", stderr);
        return 0;
    }
    printf("[video] %ux%u %s, %ux internal rendering%s.\n", width, height,
           widescreen ? "widescreen" : "original aspect", scale,
           options->fullscreen ? ", fullscreen" : "");
    return 1;
}

int MgsVideoHalfWidth(void)
{
    if (movie_active || codec_active || menu_stage)
        return 160;
    return (int)((160 * view_denominator + view_numerator - 1) / view_numerator);
}

float MgsVideoHorizontalScale(void)
{
    return MgsVideoReferenceRequired() ? 1.0f : (float)view_numerator / view_denominator;
}

int MgsVideoCapturesOutput(void)
{
    return capture_output;
}

void MgsVideoExpandClip(short *minimum, short *maximum)
{
    if (!widescreen || movie_active || codec_active || menu_stage)
        return;
    int low = *minimum * (int)view_denominator;
    int high = (*maximum + 1) * (int)view_denominator;
    int divisor = (int)view_numerator;
    *minimum = (short)(low >= 0 ? low / divisor : -((-low + divisor - 1) / divisor));
    *maximum = (short)((high >= 0 ? (high + divisor - 1) / divisor : -(-high / divisor)) - 1);
}

void MgsVideoTagChannel(void *environment, int world)
{
    if (!capture_output)
        return;
    DR_ENV *packet = environment;
    unsigned length = getlen(packet);
    if (length >= sizeof(packet->code) / sizeof(packet->code[0])) {
        fputs("Drawing environment has no room for its widescreen state.\n", stderr);
        exit(EXIT_FAILURE);
    }
    memmove(packet->code + 1, packet->code, length * sizeof(packet->code[0]));
    packet->code[0] = ((u_long)VIDEO_COMMAND << 24) | (world != 0);
    setlen(packet, length + 1);
}

void MgsVideoSetDrawMode(void *packet, int mode)
{
    DR_TPAGE *command = packet;
    setlen(command, capture_output ? 1 : 0);
    command->code[0] = ((u_long)VIDEO_COMMAND << 24) | (unsigned)mode;
}

void MgsVideoBeginFrame(int which)
{
    if (!capture_output)
        return;
    frame_centre = which * FRAME_WIDTH + FRAME_WIDTH / 2;
    frame_active = 1;
    if (!SetChannelTransform(0)) {
        fputs("Renderer cannot begin widescreen frame.\n", stderr);
        exit(EXIT_FAILURE);
    }
}

void MgsVideoEndFrame(void)
{
    if (!frame_active)
        return;
    DrawSync(0);
    frame_active = 0;
    if (Psyz_GpuSetFrameTransform(1, 1, 0, 0) != 0 ||
        Psyz_GpuSetFramebufferSampling(0) != 0 ||
        Psyz_GpuSetTextureAlignment(movie_active || codec_active || menu_stage) != 0) {
        fputs("Renderer cannot restore normal VRAM drawing.\n", stderr);
        exit(EXIT_FAILURE);
    }
}

static void SetCanvasPresentation(void)
{
    MgsVideoEndFrame();
    int original = movie_active || codec_active || menu_stage;
    unsigned width = original ? 4 : output_width;
    unsigned height = original ? 3 : output_height;
    if (Psyz_GpuSetTextureAlignment(original) != 0 ||
        (widescreen && Psyz_VideoSetPresentation(width, height, FRAME_HEIGHT) != 0)) {
        fputs("Renderer cannot change canvas presentation.\n", stderr);
        exit(EXIT_FAILURE);
    }
}

void MgsVideoMovie(int active)
{
    if (!capture_output)
        return;
    MgsVideoEndFrame();
    movie_active = active != 0;
    SetCanvasPresentation();
}

void MgsVideoCodec(int active)
{
    if (!capture_output)
        return;
    MgsVideoEndFrame();
    codec_active = active != 0;
    SetCanvasPresentation();
}

void MgsVideoStage(const char *name)
{
    static const char *const canvases[] = {
        "init", "init_ve", "init_tux", "title", "preope", "option", "change",
        "abst", "brf", "rank", "roll", "camera", "demosel", "sound",
        "select", "select1", "select2", "select3", "select4", "selectd"
    };
    if (!capture_output)
        return;
    MgsVideoEndFrame();
    menu_stage = 0;
    for (size_t index = 0; index < sizeof(canvases) / sizeof(canvases[0]); ++index)
        if (strcmp(name, canvases[index]) == 0) {
            menu_stage = 1;
            break;
        }
    SetCanvasPresentation();
}
