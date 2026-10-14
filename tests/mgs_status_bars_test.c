#include "mgs_native.h"
#include "mgs_godot_bars.h"
#include "mgs_godot_inventory.h"
#include "transport.h"
#include "../vendor/mgs/source/menu/life.c"
#include <assert.h>

short linkvarbuf[MAX_LINKVARBUF];
int GM_GameStatus;
short GM_O2;
static unsigned capabilities, epoch = 1, record_count;
static MgsGodotBar records[MGS_GODOT_BAR_LIMIT];
static unsigned char prims[8192];
static OT_TYPE ordering;
static int labels;
static unsigned text_color;
MenuWork Work;

int MgsGodotOwnsInventory(void) { return 0; }
MgsTextLayout *MgsGodotPrepareInventoryDescription(void) { abort(); }
void MgsGodotInventoryDescription(MgsSubtitleFrame frame) { (void)frame; abort(); }
void MgsTextLayoutBegin(MgsTextLayout *layout, const void *buffer) { (void)layout; (void)buffer; abort(); }
void MgsTextLayoutEnd(const void *palette, unsigned width, unsigned height) { (void)palette; (void)width; (void)height; abort(); }

int ClearImage(RECT *rect, u_char r, u_char g, u_char b) { abort(); }
int font_init_kcb(KCB *kcb, RECT *rect, int x, int y) { abort(); }
int font_set_kcb(KCB *kcb, int w, int h, int cs, int ls, int ts, int flags) { abort(); }
int font_get_buffer_size(KCB *kcb) { abort(); }
void font_set_buffer(KCB *kcb, void *buffer) { abort(); }
void font_set_color(KCB *kcb, int code, int fore, int back) { abort(); }
void font_clut_update(KCB *kcb) { abort(); }
void font_print_string(KCB *kcb, const char *text) { abort(); }
void font_update(KCB *kcb) { abort(); }
void *font_get_buffer_ptr(KCB *kcb) { abort(); }
void *GV_Malloc(int size) { abort(); }
void GV_Free(void *ptr) { abort(); }
int menu_number_draw_string(MenuWork *work, u_long *ot, int x, int y, const char *text, int flags) { abort(); }

bool MgsGodotHasCapability(unsigned bit) { return (capabilities & bit) != 0; }
int MgsGodotSceneEnabled(void) { return 1; }
unsigned MgsGodotSceneEpoch(void) { return epoch; }
void MgsGodotCopySessionId(unsigned char *data) { memset(data, 7, 16); }
void MgsGodotQueue(uint32_t operation, const void *header, uint32_t size, const void *data, uint32_t bytes)
{
    const uint32_t *words = header;
    assert(operation == MGS_GODOT_BARS && size == 32);
    assert(words[0] == 1 && words[1] == epoch && words[3] == sizeof(MgsGodotBar));
    assert(((const unsigned char *)header)[16] == 7);
    record_count = words[2];
    assert(bytes == record_count * sizeof(MgsGodotBar));
    memcpy(records, data, bytes);
}

void _menu_number_draw_string(MenuPrim *prim, TextConfig *config, const char *name)
{
    (void)prim;
    config->xpos += strlen(name) * 5;
    ++labels;
    text_color = config->color;
}

TILE *menu_render_rect_8003DB2C(MenuPrim *prim, int x, int y, int w, int h, int rgb)
{
    TILE *tile;
    _NEW_PRIM(tile, prim);
    setTile(tile);
    setXY0(tile, x, y);
    tile->w = w; tile->h = h;
    setRGB0(tile, rgb & 255, (rgb >> 8) & 255, (rgb >> 16) & 255);
    addPrim(prim->ot, tile);
    return tile;
}

void SetDrawTPage(DR_TPAGE *page, int dfe, int dtd, int tpage)
{ (void)page; (void)dfe; (void)dtd; (void)tpage; }

static void Begin(MenuPrim *prim)
{
    memset(&ordering, 0, sizeof(ordering));
    *prim = (MenuPrim){prims, (u_long *)&ordering, prims + sizeof(prims), {prims, prims}};
    labels = record_count = 0;
    MgsGodotResetBars();
}

typedef struct { MenuMan_MenuBars bars; int status, damage, y, count; } Observation;
static Observation baseline[220];

static void Run(int owns)
{
    MenuPrim prim;
    MenuWork work = {.prim = &prim};
    GM_VitalityMax = GM_Vitality = GM_O2 = 1024;
    GM_GameStatus = gTakeDamageCounter_800AB5FC = 0;
    capabilities = owns ? MGS_GODOT_BARS_CAPABILITY : 0;
    menu_life_init_8003F7E0(&work);
    for (int tick = 0; tick < 220; ++tick) {
        Begin(&prim);
        if (tick == 1) { GM_Vitality = 700; GM_GameStatus |= STATE_DAMAGED; }
        if (tick == 20) GM_O2 = 640;
        if (tick == 25) GM_O2 = 1024;
        if (tick == 40) GM_Vitality = 1024;
        menu_life_update_8003F530(&work, (u_long *)&ordering);
        if (owns) MgsGodotPublishBars();
        Observation now = {work.field_204_bars, GM_GameStatus, gTakeDamageCounter_800AB5FC,
                           gSnakeLifeYPos_800ABAF0, owns ? record_count : labels};
        if (!owns) baseline[tick] = now;
        else {
            assert(memcmp(&now.bars, &baseline[tick].bars, sizeof(now.bars)) == 0);
            assert(now.status == baseline[tick].status && now.damage == baseline[tick].damage);
            assert(now.y == baseline[tick].y && now.count == baseline[tick].count);
            assert(prim.next == prims && labels == 0);
            if (record_count) {
                assert(records[0].kind == 1 && records[0].value == GM_Vitality);
                assert(records[0].rest == work.field_204_bars.field_6_snake_hp);
                assert(records[0].y == work.field_204_bars.field_4_bar_y);
                assert(records[0].flags == (tick >= 1 && tick <= 8));
            }
            if (record_count == 2) assert(records[1].kind == 2 && records[1].height == 4);
        }
        if (tick == 8) assert(work.field_204_bars.field_4_bar_y == 16);
        if (!owns && tick >= 1 && tick <= 8) assert(text_color == 0x643030ff);
        if (tick == 12) assert(work.field_204_bars.field_6_snake_hp == 896);
        if (tick == 219) assert(work.field_204_bars.field_0_state == BAR_STATE_HIDDEN);
    }
}

static void SharedBars(void)
{
    MenuPrim prim;
    MENU_BAR_CONF boss = {"MG-REX", {16, 111, 159}, {31, 223, 127}, 0};
    capabilities = MGS_GODOT_BARS_CAPABILITY;
    GM_GameStatus = 0; gSnakeLifeYPos_800ABAF0 = 16;
    Begin(&prim);
    draw_life_defaultX_8003F408(&prim, 28, 1400, 1000, 1500, &boss);
    draw_player_life_8003F4B8(&prim, 76, 24);
    MgsGodotPublishBars();
    assert(record_count == 2 && (GM_GameStatus & STATE_SHOW_LIFEBAR));
    assert(records[0].maximum == 1500 && records[0].x == 16 && records[0].y == 28);
    assert(records[0].kind == 0 && strcmp(records[0].name, "MG-REX") == 0);
    assert(records[1].kind == 1 && records[1].x == 76 && records[1].y == 24);
    Begin(&prim);
    MgsGodotPublishBars();
    assert(record_count == 0);
    for (unsigned flag = 0; flag < 3; ++flag) {
        int flags[] = {STATE_TAKING_PHOTO, STATE_LIFE_OFF, STATE_DEMO};
        GM_GameStatus = flags[flag];
        draw_player_life_8003F4B8(&prim, 76, 24);
        MgsGodotPublishBars();
        assert(record_count == 0);
    }
    GM_GameStatus = 0;
    draw_player_life_8003F4B8(&prim, 76, 24);
    ++epoch;
    MgsGodotPublishBars();
    assert(record_count == 0);
}

static void VisibilityBoundaries(void)
{
    MenuPrim prim;
    MenuWork work = {.prim = &prim};
    GM_GameStatus = STATE_DAMAGED;
    GM_VitalityMax = GM_Vitality = GM_O2 = 1024;
    menu_life_init_8003F7E0(&work);
    GM_Vitality = 700; GM_O2 = 600;
    work.field_2A_state = 1;
    Begin(&prim);
    menu_life_update_8003F530(&work, (u_long *)&ordering);
    MgsGodotPublishBars();
    assert(record_count == 0 && work.field_204_bars.health_delay_counter == 9);
    assert(work.field_204_bars.field_1_O2_hp == 150 && (GM_GameStatus & STATE_DAMAGED));
    work.field_2A_state = 0;
    GM_GameStatus |= STATE_DEMO;
    menu_life_update_8003F530(&work, (u_long *)&ordering);
    MgsGodotPublishBars();
    assert(record_count == 0 && !(GM_GameStatus & STATE_DAMAGED) && gTakeDamageCounter_800AB5FC == 7);
    GM_Vitality = GM_O2 = 1024;
    work.field_204_bars.field_6_snake_hp = 1024;
    work.field_204_bars.field_4_bar_y = 16;
    GM_GameStatus = STATE_HIDE_LIFEBAR;
    for (int tick = 0; tick < 8; ++tick) {
        Begin(&prim);
        menu_life_update_8003F530(&work, (u_long *)&ordering);
    }
    MgsGodotPublishBars();
    assert(record_count == 0 && GM_GameStatus == STATE_LIFE_OFF);
    assert(work.field_204_bars.field_0_state == BAR_STATE_HIDDEN && work.field_204_bars.field_1_O2_hp == 0);
    GM_GameStatus = 0;
    work.field_204_bars.field_0_state = BAR_STATE_FORCE_HIDE;
    Begin(&prim);
    menu_life_update_8003F530(&work, (u_long *)&ordering);
    MgsGodotPublishBars();
    assert(record_count == 1 && records[0].y == -48);
}

int main(void)
{
    Run(0);
#ifdef MGS_GODOT_SCENE
    Run(1);
    SharedBars();
    VisibilityBoundaries();
#endif
    puts("Status bars: native damage, oxygen, slide/hide and shared calls passed");
    return 0;
}
