#include "mgs_native.h"
#include "mgs_subtitles.h"
#include "mgs_godot_subtitles.h"
#include "transport.h"
#include "../vendor/mgs/source/menu/jimaku.c"
#include <assert.h>

short linkvarbuf[MAX_LINKVARBUF];
GV_PAD GV_PadData[4];
int GV_PauseLevel;
static int starts, stops, procedures, uploads, pauses, dims;
static char *continuation;
static unsigned char primitives[8192], font_buffer[8192];
static OT_TYPE ordering;
static MenuPrim prim;
static MenuWork work = {.prim = &prim};
static int owns, packets;
static uint32_t scene_epoch = 3;
static MgsGodotSubtitleHeader received;
static MgsTextGlyph received_glyph;

int MgsGodotSceneEnabled(void) { return owns; }
bool MgsGodotHasCapability(unsigned capability) { return capability == MGS_GODOT_SUBTITLES_CAPABILITY && owns; }
uint32_t MgsGodotSceneEpoch(void) { return scene_epoch; }
void MgsGodotCopySessionId(unsigned char session[16]) { memset(session, 7, 16); }
void MgsGodotQueue(uint32_t operation, const void *header, uint32_t size, const void *data, uint32_t bytes)
{
    assert(operation == MGS_GODOT_SUBTITLES && size == 128);
    memcpy(&received, header, size);
    assert(bytes == received.count * sizeof(MgsTextGlyph));
    if (bytes) memcpy(&received_glyph, data, sizeof(received_glyph));
    ++packets;
}

void DG_RestartMainChanlSystem(void) { ++starts; }
void DG_StopMainChanlSystem(void) { ++stops; }
char *GCL_GetString(char *text) { return text; }
char *GCL_NextStr(void) { char *text = continuation; continuation = NULL; return text; }
char *GCL_GetOption(char code) { assert(code == 'e'); return NULL; }
int GCL_StrToInt(char *text) { abort(); }
int GCL_ExecProc(int code, GCL_ARGS *args) { assert(code == 42 && !args); ++procedures; return 0; }
void *GV_AllocResidentMemory(long size) { assert(size <= sizeof(font_buffer)); return font_buffer; }
const char *MgsLanguageText(const char *text) { return strcmp(text, "localized") == 0 ? "Translation!" : text; }
void SetDrawTPage(DR_TPAGE *page, int dfe, int dtd, int tpage) { assert(dfe == 1 && dtd == 0); }

int font_init_kcb(KCB *font, RECT *rect, int x, int y)
{
    assert(rect->x == 960 && rect->y == 256 && rect->w == 64 && rect->h == 38);
    assert(x == 960 && y == 510);
    memset(font, 0, sizeof(*font));
    return 0;
}
int font_set_kcb(KCB *font, int w, int h, int cs, int ls, int ts, int flags)
{
    assert(w == -1 && h == -1 && cs == 0 && ls == 6 && ts == 2 && flags == 0);
    font->c_skip = cs;
    font->l_skip = ls;
    font->width = 252;
    font->row = 128;
    font->height = 38;
    return 0;
}
int font_get_buffer_size(KCB *font) { return sizeof(font_buffer); }
void font_set_buffer(KCB *font, void *buffer) { font->cbuffer = buffer; font->buffer = (char *)buffer + 32; }
void font_set_color(KCB *font, int code, int fore, int back) { assert(code == 0 && fore == 0x6739 && back == 0); }
void font_clut_update(KCB *font) { ++uploads; }
void font_update(KCB *font) { ++uploads; }
void font_print_string(KCB *font, const char *text)
{
    font->max_width = (char)(strlen(MgsLanguageText(text)) * 6);
    font->max_height = 20;
    unsigned char source[18] = {0x1b};
    MgsTextLayoutEmit(font->buffer, (MgsTextGlyph){.kind = MGS_TEXT_HALF, .code = text[0],
        .width = 6, .height = 12, .source_size = sizeof(source)}, source);
}

void _menu_number_draw_string2(MenuPrim *p, TextConfig *config, const char *text)
{
    assert(strcmp(text, "PAUSE") == 0 && config->color == 0x64C8C8C8);
    assert(config->xpos == 160 && config->ypos == 80 && config->flags == 0x12);
    ++pauses;
}

TILE *menu_render_rect_8003DB2C(MenuPrim *p, int x, int y, int w, int h, int rgb)
{
    static TILE tile;
    assert(x == 0 && y == 0 && w == 320 && h == 224 && rgb == 0);
    ++dims;
    return &tile;
}

static const MgsSubtitleView *Tick(int press)
{
    memset(&ordering, 0, sizeof(ordering));
    prim = (MenuPrim){primitives, (u_long *)&ordering, primitives + sizeof(primitives), {primitives, primitives}};
    GV_PadData[0].press = press;
    MgsSubtitlesBeginFrame();
    menu_jimaku_act(&work, (u_long *)&ordering);
    return MgsSubtitlesGetView();
}

static void TimedAndVisibility(void)
{
    MENU_JimakuWrite("localized", 2);
    assert(!Tick(0)->frame.active && JimState.field_2_timer == 2);
    assert(uploads == 3);
    const MgsSubtitleView *view = Tick(0);
    assert(view->frame.active && view->frame.visible && view->frame.timer == 2);
    assert(strcmp(view->text, "Translation!") == 0 && view->text_bytes == 12);
    assert(view->frame.x == 124 && view->frame.y == 194 && view->frame.text_width == 72);
    assert(view->frame.width == 256 && view->frame.height == 20 && view->frame.line_spacing == 6);
    assert(JimState.field_2_timer == 1 && JimState.field_0_active == 1);
    assert(Tick(0)->frame.active && JimState.field_0_active == 0);
    assert(!Tick(0)->frame.active);

    GM_Configuration |= GM_CONFIG_CAPTION_OFF;
    MENU_JimakuWrite("hidden", 1);
    Tick(0);
    view = Tick(0);
    assert(view->frame.active && !view->frame.visible && view->frame.kind == 0);
    assert(JimState.field_0_active == 0 && prim.next - primitives == sizeof(DR_TPAGE));
    MENU_JimakuWrite("forced", 10001);
    Tick(0);
    assert(Tick(0)->frame.visible && MgsSubtitlesGetView()->frame.kind == 2);
    assert(JimState.field_2_timer == 10000);
    MENU_JimakuClear();
    assert(!Tick(0)->frame.active);
    GM_Configuration = 0;
}

static void ModalAndContinuation(void)
{
    MENU_AreaNameWrite("area");
    Tick(0);
    const MgsSubtitleView *view = Tick(0);
    assert(view->frame.kind == 1 && view->frame.timer == 0 && view->frame.y == 102);
    assert(pauses == 1 && dims == 1 && JimState.field_0_active == 1);
    NewJimakuStr("confirm", 42);
    assert(stops == 1 && (GV_PauseLevel & GV_PAUSE_STOP));
    Tick(0);
    view = Tick(PAD_CIRCLE);
    assert(view->frame.active && view->frame.timer == -1 && strcmp(view->text, "confirm") == 0);
    assert(starts == 1 && procedures == 1 && !(GV_PauseLevel & GV_PAUSE_STOP));
    assert(!Tick(0)->frame.active);

    NewJimakuStr("first", -1);
    JimState.field_40 = "second";
    Tick(0);
    unsigned old_revision = Tick(PAD_CIRCLE)->text_revision;
    assert(starts == 1 && (GV_PauseLevel & GV_PAUSE_STOP));
    assert(!Tick(0)->frame.active);
    view = Tick(0);
    assert(view->text_revision != old_revision && strcmp(view->text, "second") == 0);
    Tick(PAD_CIRCLE);
    assert(starts == 2 && procedures == 1 && !(GV_PauseLevel & GV_PAUSE_STOP));
}

static void SuppressionAndPages(void)
{
    MENU_JimakuWrite("blocked", 20);
    work.field_2B = 2;
    assert(!Tick(0)->frame.active && JimState.field_38_str == NULL);
    work.field_2B = 0;
    assert(!Tick(0)->frame.active);
    MENU_JimakuWrite("visible", 20);
    Tick(0);
    assert(Tick(0)->frame.active);
    work.field_2B = 4;
    assert(!Tick(0)->frame.active && JimState.field_0_active == 0);
    work.field_2B = 0;

    MgsTextLayout *old = MgsSubtitlesPrepare("old");
    MgsTextLayoutBegin(old, font_buffer);
    MgsTextLayoutEmit(font_buffer, (MgsTextGlyph){.kind = MGS_TEXT_DASH, .width = 18, .height = 1}, NULL);
    MgsTextLayoutEnd(font_buffer, 252, 38);
    MgsSubtitlesPresent((MgsSubtitleFrame){.active = 1});
    MgsSubtitlesPrepare("a newly queued page");
    MgsSubtitlesPrepare("another replacement");
    assert(strcmp(MgsSubtitlesGetView()->text, "old") == 0);
    assert(MgsSubtitlesGetView()->layout == old && old->count == 1 && old->glyphs[0].kind == MGS_TEXT_DASH);
    MgsSubtitlesBeginFrame();
    assert(!MgsSubtitlesGetView()->frame.active && !MgsSubtitlesGetView()->text);
    MgsSubtitlesPresent((MgsSubtitleFrame){.active = 1});
    assert(strcmp(MgsSubtitlesGetView()->text, "another replacement") == 0);
    MgsSubtitlesBeginFrame();
    MgsSubtitlesPrepare("A\x90\x1d#N");
    MgsSubtitlesPresent((MgsSubtitleFrame){.active = 1});
    assert(MgsSubtitlesGetView()->text_bytes == 5);
    assert(memcmp(MgsSubtitlesGetView()->text, "A\x90\x1d#N", 6) == 0);
    MgsSubtitlesBeginFrame();
    MgsSubtitlesPrepare("");
    MgsSubtitlesPresent((MgsSubtitleFrame){.active = 1});
    assert(MgsSubtitlesGetView()->text_bytes == 0 && MgsSubtitlesGetView()->text[0] == 0);
}

static void OwnedPresentation(void)
{
    owns = 1;
    MENU_JimakuWrite("caption", 3);
    int previous_uploads = uploads;
    Tick(0);
#ifdef MGS_GODOT_SCENE
    assert(uploads == previous_uploads);
#else
    assert(uploads == previous_uploads + 2);
#endif
    MgsGodotPublishSubtitles();
    assert(!received.frame.active && !received.has_layout);
    Tick(0);
    MgsGodotPublishSubtitles();
    assert(received.frame.active && received.frame.timer == 3 && received.has_layout);
    assert(received.count == 1 && received.width == 256 && received.height == 38);
    assert(received_glyph.code == 'c' && received_glyph.source[0] == 0x1b);
#ifdef MGS_GODOT_SCENE
    assert(prim.next == primitives);
#else
    assert(prim.next > primitives);
#endif
    Tick(0);
    MgsGodotPublishSubtitles();
    assert(received.frame.timer == 2 && !received.has_layout && !received.count);
    ++scene_epoch;
    MgsGodotPublishSubtitles();
    assert(received.has_layout && received.epoch == scene_epoch);
    MENU_AreaNameWrite("modal");
    Tick(0);
    int previous_pauses = pauses, previous_dims = dims;
    Tick(0);
#ifdef MGS_GODOT_SCENE
    assert(pauses == previous_pauses && dims == previous_dims && prim.next == primitives);
#else
    assert(pauses == previous_pauses + 1 && dims == previous_dims + 1);
#endif
    MgsGodotPublishSubtitles();
    assert(received.frame.kind == 1 && received.frame.timer == 0);
    unsigned old_revision = received.revision;
    MgsSubtitlesReset();
    MENU_JimakuWrite("reset", 2);
    Tick(0);
    Tick(0);
    MgsGodotPublishSubtitles();
    assert(received.has_layout && received.revision != old_revision);
    owns = 0;
    int previous_packets = packets;
    MgsGodotPublishSubtitles();
    assert(packets == previous_packets);
    Tick(0);
    assert(prim.next > primitives);
}

int main(void)
{
    menu_jimaku_init(&work);
    TimedAndVisibility();
    ModalAndContinuation();
    SuppressionAndPages();
    OwnedPresentation();
    MgsSubtitlesReset();
    assert(!MgsSubtitlesGetView()->frame.active && !MgsSubtitlesGetView()->text);
    puts("Subtitles: native expiry, caption setting, pause/confirm, continuation and frame ownership passed");
    return 0;
}
