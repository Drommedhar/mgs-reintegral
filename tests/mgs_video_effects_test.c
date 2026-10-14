#include "mgs_native.h"
#undef fprintf
#include "mgs_video.h"
#include "libgv/libgv.h"
#include "libdg/libdg.h"
#include "game/game.h"
#include "strcode.h"
#include <assert.h>

typedef DR_STP DR_PRIO;
enum { OT_LEN = 256 };
static unsigned scratch[256];
#undef SCRPAD_ADDR
#define SCRPAD_ADDR ((unsigned char *)scratch)
static OT_TYPE ordering[2][2][OT_LEN];
static int wide;
DG_CHANL DG_Chanls[3];
int GV_Clock, GV_PauseLevel = 1;

void *GV_Malloc(int size) { return calloc(1, (size_t)size); }
void GV_DelayedFree(void *data) { free(data); }
void GV_DestroyActor(void *actor) { (void)actor; assert(0); }
GV_MSG *GM_CheckMessage(void *work, int name, int code)
{ (void)work; (void)name; (void)code; return NULL; }
int GV_ReceiveMessage(int address, GV_MSG **message)
{ (void)address; (void)message; return 0; }
int GV_StrCode(const char *text) { (void)text; return 0; }
int GV_NearExp4(int from, int to) { (void)from; return to; }
int GV_RandS(int limit) { (void)limit; return 0; }
int rsin(int angle) { (void)angle; return 0; }
void DG_SetBackgroundPrim(void *packet) { setRGB0((TILE *)packet, 0, 0, 0); }
void SetSprt(SPRT *packet) { setSprt(packet); }
void SetTile(TILE *packet) { setTile(packet); }
u_short GetTPage(int tp, int abr, int x, int y) { return getTPage(tp, abr, x, y); }
void SetDrawTPage(DR_TPAGE *packet, int dfe, int dtd, int page)
{ setDrawTPage(packet, dfe, dtd, page); }
void SetDrawStp(DR_STP *packet, int stp)
{ setlen(packet, 1); packet->code[0] = 0xe6000000 | stp; }
void SetPriority(DR_PRIO *packet, int pbc, int pbw)
{ setlen(packet, 1); packet->code[0] = 0xe6000000 | pbc | (pbw << 1); }
void MgsVideoSetDrawMode(void *packet, int mode)
{
    assert((mode >= MGS_VIDEO_HUD && mode <= MGS_VIDEO_CANVAS) || mode == MGS_VIDEO_WATER_CANVAS);
    if (mode == MGS_VIDEO_WATER_CANVAS) mode = MGS_VIDEO_CANVAS;
    setlen(packet, wide);
    ((DR_TPAGE *)packet)->code[0] = 0xf3000000 | mode;
}

#include "video_effects_helpers.inc"

typedef struct { unsigned length; u_long words[12]; } Payload;
static Payload baseline[600];
static unsigned baseline_count;

static void CheckPackets(unsigned *index, int channel, int bucket)
{
    P_TAG *packet = (P_TAG *)&ordering[channel][GV_Clock][bucket];
    int mode = channel ? MGS_VIDEO_HUD : MGS_VIDEO_WORLD;
    unsigned transitions = 0, draws = 0, visited = 0;
    while (!isendprim(packet)) {
        assert(++visited < 600);
        packet = (P_TAG *)nextPrim(packet);
        unsigned length = getlen(packet);
        const u_long *words = ((DR_TPAGE *)packet)->code;
        if (!length) continue;
        if (words[0] >> 24 == 0xf3) {
            mode = words[0] & 0xffffff;
            assert(mode == (transitions == 0 ? MGS_VIDEO_CANVAS :
                            channel ? MGS_VIDEO_HUD : MGS_VIDEO_WORLD));
            ++transitions;
            continue;
        }
        assert(*index < sizeof(baseline) / sizeof(baseline[0]) && length <= 12);
        if (wide) {
            assert(baseline[*index].length == length);
            assert(!memcmp(baseline[*index].words, words, length * sizeof(*words)));
        } else {
            baseline[*index].length = length;
            memcpy(baseline[*index].words, words, length * sizeof(*words));
        }
        ++*index;
        if ((words[0] >> 24) >= 0x20 && (words[0] >> 24) < 0x80) {
            if (wide) assert(mode == MGS_VIDEO_CANVAS);
            ++draws;
        }
    }
    assert(mode == (channel ? MGS_VIDEO_HUD : MGS_VIDEO_WORLD));
    assert(transitions == (wide && draws ? 2u : 0u));
}

static void RunEffect(void)
{
    Work work = {0};
#if MGS_EFFECT == 0
    work.bound[0] = (SVECTOR){-100,-100,-100,0};
    work.bound[1] = (SVECTOR){100,100,100,0};
    work.color = (CVECTOR){74,128,84,0};
    assert(WaterViewCreatePrims(&work) == 0);
    work.has_alloc = 1;
    Act(&work);
    assert(work.prims->sprt[GV_Clock][0].x0 == -160);
    assert(work.prims->sprt2[GV_Clock][0].u0 == 32);
#elif MGS_EFFECT == 1
    POLY_FT4 polygons[8] = {0};
    work.f24[0].poly = polygons;
    work.f24[1].poly = polygons + 4;
    work.f20 = -1;
    work.f68 = 24;
    work.f6C = 40;
    Act(&work);
    assert(work.f24[GV_Clock].poly[0].x1 == 160);
    assert(work.f24[GV_Clock].poly[1].u0 == 32);
#elif MGS_EFFECT == 2
    work.prims = calloc(1, sizeof(*work.prims));
    assert(work.prims);
    work.name = -1;
    work.draw = 1;
    InitPrims(&work);
    Act(&work);
    assert(work.prims->sprt1[GV_Clock].u0 == 32);
    assert(work.prims->sprt2[GV_Clock].x0 == -160);
#else
    assert(FocusGetResources_800CEDA4(&work, 80 * 256, 20 * 256) == 0);
    FocusAct_800CEA70(&work);
    assert(work.prims->sprt1[GV_Clock].x0 == -162);
    assert(work.prims->sprt2[GV_Clock].u0 == 32);
#endif
    unsigned count = 0;
    for (int channel = 0; channel < 2; ++channel)
        for (int bucket = 0; bucket < OT_LEN; ++bucket)
            CheckPackets(&count, channel, bucket);
    assert(count > 4);
    if (wide) assert(count == baseline_count);
    else baseline_count = count;
#if MGS_EFFECT != 1
    free(work.prims);
#endif
}

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    for (GV_Clock = 0; GV_Clock < 2; ++GV_Clock)
        for (wide = 0; wide < 2; ++wide) {
            memset(ordering, 0, sizeof(ordering));
            memset(scratch, 0, sizeof(scratch));
            for (int channel = 0; channel < 2; ++channel)
                for (int frame = 0; frame < 2; ++frame) {
                    DG_Chanls[channel + 1].ot[frame] = ordering[channel][frame];
                    for (int bucket = 0; bucket < OT_LEN; ++bucket)
                        termPrim(&ordering[channel][frame][bucket]);
                }
            RunEffect();
        }
    puts("Framebuffer effects preserve packets and bracket canvas drawing on both buffers");
    return 0;
}
