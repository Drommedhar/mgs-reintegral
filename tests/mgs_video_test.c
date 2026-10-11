#include "mgs_video.h"
#include <libgpu.h>
#include <psyz.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

enum { WINDOW, SCALE, PRESENT, TRANSFORM, REGISTER, SYNC };
typedef struct { int kind; unsigned a, b; int c, d; } Event;
static Event events[256];
static unsigned event_count, checked;
static PsyzGpuCommandHandler command_handler;
static void *command_userdata;
static const u_long *pending;
static int framebuffer_sampling;
static int texture_alignment;

static int Record(int kind, unsigned a, unsigned b, int c, int d)
{
    assert(event_count < sizeof(events) / sizeof(events[0]));
    events[event_count++] = (Event){kind, a, b, c, d};
    return 0;
}

int Psyz_VideoConfigureWindow(unsigned w, unsigned h, int full)
{ return Record(WINDOW, w, h, full, 0); }
int Psyz_VideoSetInternalResolution(unsigned scale)
{ return Record(SCALE, scale, 0, 0, 0); }
int Psyz_VideoSetPresentation(unsigned w, unsigned h, unsigned rows)
{ return Record(PRESENT, w, h, (int)rows, 0); }
int Psyz_GpuSetFrameTransform(unsigned n, unsigned d, int centre, int clip)
{ return Record(TRANSFORM, n, d, centre, clip); }
int Psyz_GpuSetFramebufferSampling(int enabled)
{ framebuffer_sampling = enabled; return 0; }
int Psyz_GpuSetTextureAlignment(int enabled)
{ texture_alignment = enabled; return 0; }
int Psyz_GpuRegisterCommandHandler(unsigned opcode, PsyzGpuCommandHandler handler, void *userdata)
{
    command_handler = handler;
    command_userdata = userdata;
    return Record(REGISTER, opcode, 0, 0, 0);
}
int DrawSync(int mode)
{
    Record(SYNC, (unsigned)mode, 0, 0, 0);
    if (pending) {
        assert(command_handler(pending, 1, command_userdata) == 1);
        pending = NULL;
    }
    return 0;
}

static void Expect(int kind, unsigned a, unsigned b, int c, int d)
{
    assert(checked < event_count);
    const Event *event = &events[checked++];
    assert(event->kind == kind && event->a == a && event->b == b);
    assert(event->c == c && event->d == d);
}

static void CheckParse(void)
{
    static const char *invalid[] = {NULL, "", "2560", "2560x", "x1440", "2560X1440",
        " 2560x1440", "2560x1440 ", "+2560x1440", "2560x-1440", "2560x1440junk",
        "0x0", "319x240", "320x239", "7681x4320", "7680x4321", "4294967296x240",
        "320x4294967296", "999999999999999999999999x240", "320xx240"};
    static const struct { const char *text; unsigned w, h; } valid[] = {
        {"320x240", 320, 240}, {"2560x1440", 2560, 1440},
        {"7680x4320", 7680, 4320}, {"0320x0240", 320, 240}};
    for (unsigned i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
        MgsVideoOptions options = {17, 29, 1, 1};
        assert(!MgsVideoParseResolution(invalid[i], &options));
        assert(options.width == 17 && options.height == 29);
        assert(options.widescreen == 1 && options.fullscreen == 1);
    }
    for (unsigned i = 0; i < sizeof(valid) / sizeof(valid[0]); ++i) {
        MgsVideoOptions options = {0, 0, 1, 1};
        assert(MgsVideoParseResolution(valid[i].text, &options));
        assert(options.width == valid[i].w && options.height == valid[i].h);
        assert(options.widescreen == 1 && options.fullscreen == 1);
    }
}

static void CheckClip(short low, short high, short expected_low, short expected_high)
{
    MgsVideoExpandClip(&low, &high);
    assert(low == expected_low && high == expected_high);
}

static void CheckDefault(void)
{
    const MgsVideoOptions options = {0};
    DR_ENV packet = {0}, original;
    setlen(&packet, 1);
    packet.code[0] = 0xe3000000;
    original = packet;
    assert(MgsVideoConfigure(&options));
    assert(!MgsVideoCapturesOutput() && MgsVideoHalfWidth() == 160);
    assert(MgsVideoHorizontalScale() == 1.0f);
    CheckClip(-160, 159, -160, 159);
    MgsVideoTagChannel(&packet, 1);
    assert(memcmp(&packet, &original, sizeof(packet)) == 0);
    DR_TPAGE effect = {0};
    MgsVideoSetDrawMode(&effect, MGS_VIDEO_CANVAS);
    assert(getlen(&effect) == 0);
    MgsVideoBeginFrame(1);
    MgsVideoEndFrame();
    MgsVideoMovie(1);
    MgsVideoCodec(1);
    MgsVideoMovie(0);
    MgsVideoCodec(0);
    MgsVideoStage("title");
}

static void CheckOriginalCanvas(const u_long *marker)
{
    assert(texture_alignment);
    assert(MgsVideoHalfWidth() == 160);
    assert(MgsVideoHorizontalScale() == 1.0f);
    CheckClip(-160, 159, -160, 159);
    MgsVideoBeginFrame(0);
    Expect(TRANSFORM, 1, 1, 160, 0);
    assert(command_handler(marker, 1, command_userdata) == 1);
    Expect(TRANSFORM, 1, 1, 160, 0);
    MgsVideoEndFrame();
    Expect(SYNC, 0, 0, 0, 0);
    Expect(TRANSFORM, 1, 1, 0, 0);
    assert(texture_alignment);
    assert(checked == event_count);
}

static void CheckCodec(const u_long *marker)
{
    MgsVideoBeginFrame(1);
    Expect(TRANSFORM, 3, 4, 480, 1);
    pending = marker;
    MgsVideoCodec(1);
    Expect(SYNC, 0, 0, 0, 0);
    Expect(TRANSFORM, 3, 4, 480, 0);
    Expect(TRANSFORM, 1, 1, 0, 0);
    Expect(PRESENT, 4, 3, 224, 0);
    CheckOriginalCanvas(marker);
    MgsVideoMovie(1);
    Expect(PRESENT, 4, 3, 224, 0);
    MgsVideoCodec(0);
    Expect(PRESENT, 4, 3, 224, 0);
    CheckOriginalCanvas(marker);
    MgsVideoCodec(1);
    Expect(PRESENT, 4, 3, 224, 0);
    MgsVideoMovie(0);
    Expect(PRESENT, 4, 3, 224, 0);
    CheckOriginalCanvas(marker);
    MgsVideoCodec(0);
    Expect(PRESENT, 2560, 1440, 224, 0);
    assert(MgsVideoHalfWidth() == 214);
    assert(MgsVideoHorizontalScale() == 0.75f);
    CheckClip(-160, 159, -214, 213);
    MgsVideoBeginFrame(0);
    Expect(TRANSFORM, 3, 4, 160, 1);
    MgsVideoEndFrame();
    Expect(SYNC, 0, 0, 0, 0);
    Expect(TRANSFORM, 1, 1, 0, 0);
}

static void CheckEffects(void)
{
    DR_TPAGE canvas = {0}, hud = {0}, world = {0}, background = {0};
    MgsVideoSetDrawMode(&canvas, MGS_VIDEO_CANVAS);
    MgsVideoSetDrawMode(&hud, MGS_VIDEO_HUD);
    MgsVideoSetDrawMode(&world, MGS_VIDEO_WORLD);
    MgsVideoSetDrawMode(&background, MGS_VIDEO_BACKGROUND);
    assert(getlen(&canvas) == 1 && canvas.code[0] == 0xf3000002);
    for (int which = 0; which < 2; ++which) {
        int centre = 160 + which * 320;
        MgsVideoBeginFrame(which);
        Expect(TRANSFORM, 3, 4, centre, 1);
        assert(command_handler(canvas.code, 1, command_userdata) == 1);
        assert(framebuffer_sampling);
        Expect(TRANSFORM, 1, 1, centre, 0);
        assert(command_handler(world.code, 1, command_userdata) == 1);
        assert(!framebuffer_sampling);
        assert(!texture_alignment);
        Expect(TRANSFORM, 3, 4, centre, 0);
        assert(command_handler(background.code, 1, command_userdata) == 1);
        assert(!framebuffer_sampling && texture_alignment);
        Expect(TRANSFORM, 3, 4, centre, 0);
        assert(command_handler(world.code, 1, command_userdata) == 1);
        assert(!framebuffer_sampling && !texture_alignment);
        Expect(TRANSFORM, 3, 4, centre, 0);
        assert(command_handler(canvas.code, 1, command_userdata) == 1);
        Expect(TRANSFORM, 1, 1, centre, 0);
        assert(command_handler(hud.code, 1, command_userdata) == 1);
        assert(!framebuffer_sampling);
        assert(texture_alignment);
        Expect(TRANSFORM, 3, 4, centre, 1);
        pending = canvas.code;
        MgsVideoEndFrame();
        Expect(SYNC, 0, 0, 0, 0);
        Expect(TRANSFORM, 1, 1, centre, 0);
        Expect(TRANSFORM, 1, 1, 0, 0);
        assert(!framebuffer_sampling);
        assert(!texture_alignment);
    }
}

static void CheckOriginalOutput(void)
{
    DR_TPAGE canvas = {0};
    MgsVideoSetDrawMode(&canvas, MGS_VIDEO_CANVAS);
    assert(getlen(&canvas) == 1);
    MgsVideoBeginFrame(1);
    Expect(TRANSFORM, 1, 1, 480, 0);
    assert(command_handler(canvas.code, 1, command_userdata) == 1);
    Expect(TRANSFORM, 1, 1, 480, 0);
    assert(framebuffer_sampling);
    pending = canvas.code;
    MgsVideoEndFrame();
    Expect(SYNC, 0, 0, 0, 0);
    Expect(TRANSFORM, 1, 1, 480, 0);
    Expect(TRANSFORM, 1, 1, 0, 0);
    assert(!framebuffer_sampling);
    assert(!texture_alignment);
    MgsVideoStage("title");
    assert(texture_alignment);
    MgsVideoBeginFrame(0);
    Expect(TRANSFORM, 1, 1, 160, 0);
    MgsVideoEndFrame();
    Expect(SYNC, 0, 0, 0, 0);
    Expect(TRANSFORM, 1, 1, 0, 0);
    assert(texture_alignment);
    MgsVideoStage("s00a");
    assert(!texture_alignment);
}

static void CheckMenuStages(const u_long *marker)
{
    const char *stages[] = {"init", "init_ve", "init_tux", "title", "option",
        "preope", "change", "abst", "brf", "rank", "roll", "camera",
        "demosel", "sound", "select", "select1", "select2", "select3", "select4", "selectd"};
    for (unsigned index = 0; index < sizeof(stages) / sizeof(stages[0]); ++index) {
        MgsVideoStage(stages[index]);
        Expect(PRESENT, 4, 3, 224, 0);
        CheckOriginalCanvas(marker);
    }
    MgsVideoCodec(1);
    Expect(PRESENT, 4, 3, 224, 0);
    MgsVideoStage("s00a");
    Expect(PRESENT, 4, 3, 224, 0);
    CheckOriginalCanvas(marker);
    MgsVideoCodec(0);
    Expect(PRESENT, 2560, 1440, 224, 0);
    assert(MgsVideoHalfWidth() == 214);
    MgsVideoStage("opening");
    Expect(PRESENT, 2560, 1440, 224, 0);
    MgsVideoStage("d00a");
    Expect(PRESENT, 2560, 1440, 224, 0);
    MgsVideoBeginFrame(0);
    Expect(TRANSFORM, 3, 4, 160, 1);
    MgsVideoStage("title");
    Expect(SYNC, 0, 0, 0, 0);
    Expect(TRANSFORM, 1, 1, 0, 0);
    Expect(PRESENT, 4, 3, 224, 0);
    CheckOriginalCanvas(marker);
}

static void CheckWide(void)
{
    struct { DR_ENV packet; unsigned canary; } storage = {0};
    DR_ENV hud = {0};
    u_long malformed = 0xf3000004;
    storage.canary = 0x6a173be9;
    setaddr(&storage.packet, 0x12345678);
    setlen(&storage.packet, 14);
    for (unsigned i = 0; i < 14; ++i)
        storage.packet.code[i] = 0xe3000000 + i;
    MgsVideoTagChannel(&storage.packet, 1);
    assert(getlen(&storage.packet) == 15 && getaddr(&storage.packet) == 0x12345678);
    assert(storage.packet.code[0] == 0xf3000001 && storage.canary == 0x6a173be9);
    for (unsigned i = 0; i < 14; ++i)
        assert(storage.packet.code[i + 1] == 0xe3000000 + i);
    MgsVideoTagChannel(&hud, 0);
    assert(getlen(&hud) == 1 && hud.code[0] == 0xf3000000);
    const DR_ENV tagged = storage.packet;
    assert(MgsVideoHalfWidth() == 214);
    CheckClip(-160, 159, -214, 213);
    CheckClip(-159, 157, -212, 210);
    CheckClip(-7, -3, -10, -3);
    CheckClip(3, 7, 4, 10);
    CheckClip(0, 0, 0, 1);
    assert(command_handler(NULL, 0, command_userdata) == -1);
    assert(command_handler(&malformed, 1, command_userdata) == -1);
    assert(command_handler(hud.code, 1, command_userdata) == 1);
    assert(checked == event_count);
    MgsVideoBeginFrame(0);
    assert(command_handler(storage.packet.code, 15, command_userdata) == 1);
    assert(command_handler(hud.code, 1, command_userdata) == 1);
    Expect(TRANSFORM, 3, 4, 160, 1);
    Expect(TRANSFORM, 3, 4, 160, 0);
    Expect(TRANSFORM, 3, 4, 160, 1);
    pending = storage.packet.code;
    MgsVideoEndFrame();
    Expect(SYNC, 0, 0, 0, 0);
    Expect(TRANSFORM, 3, 4, 160, 0);
    Expect(TRANSFORM, 1, 1, 0, 0);
    MgsVideoEndFrame();
    MgsVideoBeginFrame(1);
    Expect(TRANSFORM, 3, 4, 480, 1);
    MgsVideoMovie(1);
    Expect(SYNC, 0, 0, 0, 0);
    Expect(TRANSFORM, 1, 1, 0, 0);
    Expect(PRESENT, 4, 3, 224, 0);
    CheckOriginalCanvas(storage.packet.code);
    MgsVideoMovie(0);
    Expect(PRESENT, 2560, 1440, 224, 0);
    assert(MgsVideoHalfWidth() == 214);
    MgsVideoBeginFrame(1);
    assert(command_handler(storage.packet.code, 15, command_userdata) == 1);
    Expect(TRANSFORM, 3, 4, 480, 1);
    Expect(TRANSFORM, 3, 4, 480, 0);
    MgsVideoEndFrame();
    Expect(SYNC, 0, 0, 0, 0);
    Expect(TRANSFORM, 1, 1, 0, 0);
    CheckCodec(storage.packet.code);
    CheckEffects();
    CheckMenuStages(storage.packet.code);
    assert(memcmp(&tagged, &storage.packet, sizeof(tagged)) == 0);
}

int main(int argc, char **argv)
{
    assert(argc == 2);
    const char *mode = argv[1];
    if (!strcmp(mode, "parse")) CheckParse();
    else if (!strcmp(mode, "default")) CheckDefault();
    else {
        MgsVideoOptions options = {2560, 1440, 1, 1};
        if (!strcmp(mode, "auto")) options = (MgsVideoOptions){0, 0, 1, 0};
        else if (!strcmp(mode, "original")) options.widescreen = 0;
        else if (!strcmp(mode, "oversize")) options.width = 7680;
        else if (!strcmp(mode, "aspect")) options = (MgsVideoOptions){320, 720, 1, 0};
        else assert(!strcmp(mode, "wide") || !strcmp(mode, "capacity"));
        int rejected = !strcmp(mode, "oversize") || !strcmp(mode, "aspect");
        assert(MgsVideoConfigure(&options) == !rejected);
        if (!rejected) {
            unsigned w = options.width ? options.width : 1280;
            unsigned h = options.height ? options.height : 720;
            assert(MgsVideoCapturesOutput());
            Expect(WINDOW, w, h, options.fullscreen, 0);
            Expect(SCALE, options.width ? 8 : 4, 0, 0, 0);
            if (options.widescreen) {
                Expect(PRESENT, w, h, 224, 0);
                assert(command_handler && MgsVideoHalfWidth() == 214);
            } else assert(command_handler && MgsVideoHalfWidth() == 160);
            Expect(TRANSFORM, 1, 1, 0, 0);
            Expect(REGISTER, 0xf3, 0, 0, 0);
            if (!strcmp(mode, "wide")) CheckWide();
            if (!strcmp(mode, "original")) CheckOriginalOutput();
            if (!strcmp(mode, "capacity")) {
                DR_ENV packet = {0};
                setlen(&packet, 15);
                MgsVideoTagChannel(&packet, 1);
                return 72;
            }
        }
    }
    assert(checked == event_count);
    puts("Video contract PASS");
    return 0;
}
