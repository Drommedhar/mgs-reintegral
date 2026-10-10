#include "mgs_native.h"
#undef fprintf
#include <assert.h>
#include <psyz.h>
#include "libdg/trans.c"
#include "libdg/divide.c"

int GV_Clock;
unsigned long psyz_scratchpad[256];
M_Sys MemorySystems[MAX_MEMSYS];
OT_TYPE DG_DivideBuffer[256];
int MgsVideoHalfWidth(void) { return 160; }
void DG_Clip(RECT *rect, int distance) { (void)rect; SetGeomScreen(distance); }

static MATRIX transform = {{{4096, 0, 0}, {0, 4096, 0}, {0, 0, 4096}}, {0, 0, 0}};
static unsigned scale;

static void TransformFace(POLY_GT4 *packet, SVECTOR *vertices, unsigned int indices, int bothface)
{
    DG_MDL model = {.flag = bothface ? DG_MODEL_BOTHFACE : 0, .n_verts = 4,
                    .verts = vertices, .vindices = (unsigned char *)&indices};
    DG_OBJ object = {.model = &model, .n_packs = 1, .packs = {packet, packet}};
    SetRotMatrix(&transform);
    SetTransMatrix(&transform);
    SPAD->flags = 0;
    SPAD->vertices = vertices;
    DG_TransObj(&object, 0);
}

static void CheckThinFace(int precision)
{
    /* This subpixel strip crosses sample centers, but integer XY collapses it to a line. */
    SVECTOR vertices[12] = {{81, 80, 640, 0}, {241, 240, 640, 0},
                           {241, 243, 640, 0}, {81, 83, 640, 0}};
    POLY_GT4 packet = {0};
    setPolyGT4(&packet);
    setShadeTex(&packet, 1);
    packet.tpage = getTPage(2, 0, 640, 256);
    assert(MgsTextureCorrectionConfigure(1, precision, 0));
    MgsTextureCorrectionBegin(0);
    TransformFace(&packet, vertices, 0x03020100, 0);
    assert((packet.tag != 0) == precision);
    RECT area = {0, 0, 320, 224};
    ClearImage(&area, 0, 0, 0);
    if (packet.tag) {
        setlen(&packet, 12);
        termPrim(&packet);
        DrawOTag((OT_TYPE *)&packet);
    }
    DrawSync(0);
    int width, height;
    unsigned char *image = Psyz_VideoAllocPresentedFrame(&width, &height);
    assert(image && width == 320 * scale && height == 224 * scale);
    unsigned covered = 0;
    for (int i = 0; i < width * height; ++i) covered += image[i * 3] > 200;
    free(image);
    assert(precision ? covered >= 30 * scale : covered == 0);
    TransformFace(&packet, vertices, 0x01020300, 0);
    assert(packet.tag == 0);
    TransformFace(&packet, vertices, 0x01020300, 1);
    assert((packet.tag != 0) == precision);
    ++packet.x3;
    const void *xy[4] = {&packet.x0, &packet.x1, &packet.x2, &packet.x3};
    assert(MgsTextureCorrectionArea(xy, 123) == 123);
    vertices[2] = vertices[1];
    vertices[3] = vertices[0];
    TransformFace(&packet, vertices, 0x03020100, 1);
    assert(packet.tag == 0);
}

static void CheckLinkedJoint(void)
{
    SVECTOR parent_vertices[12] = {{40, 40, 321, 0}, {120, 40, 321, 0},
                                  {120, 120, 321, 0}, {40, 120, 321, 0}};
    SVECTOR child_vertices[12] = {{-100, -100, 500, offsetof(POLY_GT4, x2)},
                                 {-100, -100, 500, offsetof(POLY_GT4, x3)},
                                 {120, 180, 321, 0}, {40, 180, 321, 0}};
    POLY_GT4 parent = {0}, child = {0};
    MgsTextureCorrectionBegin(0);
    TransformFace(&parent, parent_vertices, 0x03020100, 0);
    SPAD->parent_packs = &parent;
    TransformFace(&child, child_vertices, 0x03028180, 0);
    const short *sources[] = {&parent.x2, &parent.x3};
    const short *copies[] = {&child.x0, &child.x1};
    for (unsigned i = 0; i < 2; ++i) {
        PsyzProjectedVertex source, copy;
        assert(MgsTextureCorrectionGet(sources[i], &source));
        assert(MgsTextureCorrectionGet(copies[i], &copy));
        assert(memcmp(&source, &copy, sizeof(source)) == 0);
        assert(memcmp(sources[i], copies[i], sizeof(DVECTOR)) == 0);
    }
}

static unsigned char *DrawFaces(POLY_GT4 *packets, int count)
{
    RECT area = {0, 0, 320, 224};
    ClearImage(&area, 0, 0, 0);
    for (int i = 0; i < count; ++i) {
        setlen(&packets[i], 12);
        termPrim(&packets[i]);
        DrawOTag((OT_TYPE *)&packets[i]);
    }
    DrawSync(0);
    int width, height;
    unsigned char *image = Psyz_VideoAllocPresentedFrame(&width, &height);
    assert(image && width == 320 * scale && height == 224 * scale);
    return image;
}

static void CheckSubdivision(int threshold)
{
    SVECTOR vertices[12] = {{20, 20, 160, 0}, {121, 31, 160, 0},
                           {141, 101, 160, 0}, {40, 90, 160, 0}};
    unsigned int indices = 0x03020100;
    POLY_GT4 original = {0}, divided[64] = {0};
    setPolyGT4(&original);
    setShadeTex(&original, 1);
    original.tpage = getTPage(2, 0, 640, 256);
    MgsTextureCorrectionBegin(0);
    TransformFace(&original, vertices, indices, 0);
    unsigned long tag = original.tag;
    unsigned char *expected = DrawFaces(&original, 1);
    original.tag = tag;
    DG_MDL model = {.n_verts = 4, .verts = vertices, .vindices = (unsigned char *)&indices};
    DG_OBJ object = {.model = &model, .n_packs = 1, .packs = {&original, &original}};
    DG_DivideMem *memory = GetDivideMem();
    *memory = (DG_DivideMem){.ot = DG_DivideBuffer, .field_10 = 1, .field_14 = threshold,
                            .field_18 = 8192, .n_packs = 64, .pDataStart = divided,
                            .size = sizeof(divided)};
    DG_InitRVector(&object, 0);
    int count = 64 - memory->n_packs;
    assert(count >= 4);
    unsigned char *actual = DrawFaces(divided, count);
    size_t bytes = (size_t)320 * 224 * scale * scale * 3;
    assert(memcmp(expected, actual, bytes) == 0);
    free(expected);
    free(actual);
}

int main(int argc, char **argv)
{
#ifdef _WIN32
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif
    assert(argc == 2);
    scale = (unsigned)atoi(argv[1]);
    assert(scale == 1 || scale == 4);
    assert(Psyz_VideoConfigureWindow(320 * scale, 224 * scale, 0) == 0);
    assert(Psyz_VideoSetPresentation(320, 224, 224) == 0);
    assert(Psyz_VideoSetInternalResolution(scale) == 0);
    ResetGraph(0);
    Psyz_VideoSetDitheringMode(PSYZ_DITHER_OFF);
    DRAWENV draw;
    DISPENV display;
    SetDefDrawEnv(&draw, 0, 0, 320, 224);
    draw.dtd = 0;
    SetDefDispEnv(&display, 0, 0, 320, 240);
    PutDispEnv(&display);
    PutDrawEnv(&draw);
    SetDispMask(1);
    InitGeom();
    SetGeomScreen(160);
    SetGeomOffset(0, 0);
    uint16_t red[2] = {31, 31};
    RECT texture = {640, 256, 2, 1};
    LoadImage(&texture, (u_long *)red);
    CheckThinFace(0);
    CheckThinFace(1);
    CheckLinkedJoint();
    CheckSubdivision(2048);
    CheckSubdivision(256);
    printf("Joint geometry %ux: thin faces, winding, linked vertices and subdivision coverage passed.\n", scale);
    return 0;
}
