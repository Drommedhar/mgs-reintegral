#include "mgs_native.h"
#undef fprintf
#include "mgs_video.h"
#include "libgcl/libgcl.h"
#include "game/game.h"
#include <assert.h>

int GV_Clock, GM_CurrentMap, GM_GameStatus;
DG_CHANL DG_Chanls[3];
MATRIX DG_ZeroMatrix;
static int halfwidth = 160, yaw;
static DG_IMG panorama;
static DG_TEX textures[8];
static OT_TYPE ordering;
int MgsVideoHalfWidth(void) { return halfwidth; }
void MgsVideoSetDrawMode(void *packet, int mode)
{
    assert(mode == MGS_VIDEO_WORLD || mode == MGS_VIDEO_BACKGROUND);
    setlen(packet, 1);
    ((DR_TPAGE *)packet)->code[0] = 0xf3000000 | mode;
}
int GV_VecDir2(SVECTOR *vector) { (void)vector; return yaw; }
void *GV_GetCache(int id) { (void)id; return &panorama; }
int GV_CacheID(int id, int ext) { (void)ext; return id; }
DG_TEX *DG_GetTexture(int id) { assert(id < 8); return &textures[id]; }
char *GCL_GetOption(char option) { (void)option; return NULL; }
char *GCL_NextStr(void) { return NULL; }
int GCL_StrToInt(char *option) { (void)option; return 0; }
int GCL_StrToSV(char *option, short *color)
{ (void)option; color[0] = color[1] = color[2] = 128; return 0; }
int DG_QueuePrim(DG_PRIM *prim) { (void)prim; return 0; }
DG_PRIM *DG_MakePrim(int type, int count, int channel, SVECTOR *pos, RECT *rect)
{
    (void)channel; (void)pos; (void)rect;
    assert(type == (DG_PRIM_SORTONLY | DG_PRIM_POLY_FT4));
    DG_PRIM *prim = calloc(1, sizeof(*prim));
    assert(prim);
    prim->n_prims = count;
    for (int i = 0; i < 2; ++i) {
        prim->packs[i] = calloc((size_t)count, sizeof(POLY_FT4));
        assert(prim->packs[i]);
    }
    return prim;
}

#include "wide_environment_helpers.inc"

#if MGS_ENVIRONMENT < 2
static int texture_at(Work *work, int x, int y)
{
    POLY_FT4 *poly = (POLY_FT4 *)work->prim->packs[GV_Clock] + 1;
    for (int i = 0; i < work->prim->n_prims - 2; ++i, ++poly) {
        assert(poly->x1 - poly->x0 == panorama.tile_width);
        assert(poly->y2 - poly->y0 == panorama.tile_height);
        if (x >= poly->x0 && x < poly->x1 && y >= poly->y0 && y < poly->y2)
            return poly->tpage * 256 + poly->u0 + x - poly->x0;
    }
    assert(!"Uncovered panorama pixel");
    return -1;
}

static void check_panorama(void)
{
    static unsigned short ids[] = {8, 0, 1, 2, 3, 4, 5, 6, 7};
    DG_IMG_ATTRIB attributes[8];
    unsigned char tilemap[64];
    for (int i = 0; i < 8; ++i) {
        attributes[i] = (DG_IMG_ATTRIB){(u_char)i, 0, 0, 0};
        textures[i].tpage = (u_short)i;
    }
    for (int i = 0; i < 64; ++i) tilemap[i] = i % 8;
    panorama = (DG_IMG){512, 512, 64, 64, ids, attributes, tilemap};
    static const int widths[] = {160, 214, 280, 427};
    int reference[320];
    for (yaw = 0; yaw < 4096; yaw += 17) {
        for (unsigned w = 0; w < sizeof(widths) / sizeof(widths[0]); ++w) {
            Work work = {0};
            halfwidth = widths[w];
            assert(GetResources(&work, 1) == 0);
            Act(&work);
            POLY_FT4 *packets = work.prim->packs[GV_Clock];
            DR_TPAGE *restore = (DR_TPAGE *)packets;
            DR_TPAGE *begin = (DR_TPAGE *)(packets + work.prim->n_prims - 1);
            assert(getlen(begin) == 1 && begin->code[0] == (0xf3000000 | MGS_VIDEO_BACKGROUND));
            assert(getlen(restore) == 1 && restore->code[0] == (0xf3000000 | MGS_VIDEO_WORLD));
            for (int i = 0; i < work.prim->n_prims; ++i)
                assert(*(unsigned short *)&packets[i] == 63000);
            for (int x = -halfwidth; x < halfwidth; ++x) {
                int texel = texture_at(&work, x, 0);
                texture_at(&work, x, -112);
                texture_at(&work, x, 111);
                if (x < -160 || x >= 160) continue;
                if (w) assert(texel == reference[x + 160]);
                else reference[x + 160] = texel;
            }
            free(work.prim->packs[0]);
            free(work.prim->packs[1]);
            free(work.prim);
        }
    }
}
#else
static int cross(int ax, int ay, int bx, int by, int x, int y)
{ return (bx - ax) * (y - ay) - (by - ay) * (x - ax); }

static int inside_border(const POLY_F4 *p, int x, int y)
{
    int edges[] = {cross(p->x0, p->y0, p->x1, p->y1, x, y),
                   cross(p->x1, p->y1, p->x3, p->y3, x, y),
                   cross(p->x3, p->y3, p->x2, p->y2, x, y),
                   cross(p->x2, p->y2, p->x0, p->y0, x, y)};
    int positive = 0, negative = 0;
    for (int i = 0; i < 4; ++i) {
        positive |= edges[i] > 0;
        negative |= edges[i] < 0;
    }
    return !(positive && negative);
}

static void check_vignette(void)
{
    GasEfctPrims prims = {0};
    Work work = {0};
    work.prims = &prims;
    work.f5C = 80;
    work.f64 = 3205;
    d11c_800C49A4(&work, prims.poly[GV_Clock]);
    POLY_G4 reference[16];
    memcpy(reference, prims.poly[GV_Clock], sizeof(reference));
    static const int widths[] = {160, 161, 214, 280, 427};
    for (unsigned w = 0; w < sizeof(widths) / sizeof(widths[0]); ++w) {
        halfwidth = widths[w];
        termPrim(&ordering);
        ExtendVignette(&work, &ordering);
        assert(!memcmp(reference, prims.poly[GV_Clock], sizeof(reference)));
        if (halfwidth == 160) { assert(isendprim(&ordering)); continue; }
        for (int x = -halfwidth; x < halfwidth; ++x) {
            for (int y = -112; y < 112; ++y) {
                int in_ring = 1, covered = 0;
                for (int i = 0; i < 16; ++i) {
                    POLY_G4 *p = &reference[i];
                    in_ring &= cross(p->x2,p->y2,p->x3,p->y3,x,y) >= 0;
                    covered |= inside_border(&prims.border[GV_Clock][i], x, y);
                }
                assert(in_ring || covered);
            }
        }
    }
}
#endif

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    for (GV_Clock = 0; GV_Clock < 2; ++GV_Clock) {
#if MGS_ENVIRONMENT < 2
        check_panorama();
#else
        check_vignette();
#endif
    }
    puts("Widescreen environment coverage preserves the original center on both buffers.");
    return 0;
}
