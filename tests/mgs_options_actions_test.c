#include "mgs_native.h"
#include "mgs_godot_options.h"
#include "../vendor/mgs/source/onoda/option/opt.c"
#include "../vendor/mgs/source/libgv/strcode.c"
#include <assert.h>
#include <string.h>

short linkvarbuf[MAX_LINKVARBUF];
int GM_PadVibration, GM_PadVibration2;
int GM_CurrentMap, GM_GameStatus, GV_Clock;
GV_PAD GV_PadData[4];
DG_CHANL DG_Chanls[3];
static unsigned sounds, vibration_calls;
static unsigned audio;
static DG_TEX texture;
int MgsGodotOwnsOptions(void) { return 1; }
void GM_SeSet2(int pan, int volume, int sound) { assert(pan==0 && volume==63); (void)sound; ++sounds; }
void GM_SetSound(int code, int mode) { assert(mode==SD_ASYNC); audio=(unsigned)code; }
void mts_set_pad_vibration(int channel, int value) { assert(channel==1 && value==0); ++vibration_calls; }
void mts_set_pad_vibration2(int channel, int value) { assert(channel==1 && value==0); ++vibration_calls; }
DG_TEX *DG_GetTexture(int name) { (void)name; return &texture; }

void *GV_NewActor(int level, int size) { abort(); }
void GV_SetNamedActor(void *actor, void *act, void *die, const char *name) { abort(); }
void GV_DestroyActor(void *actor) { abort(); }
void *GV_AllocMemory(int region, int bytes) { abort(); }
void GV_FreeMemory(int region, void *data) { abort(); }
int GCL_ExecProc(int procedure, GCL_ARGS *args) { abort(); }
char *GCL_GetOption(char option) { abort(); }
char *GCL_GetString(char *value) { abort(); }
char *GCL_NextStr(void) { abort(); }
int GCL_StrToInt(char *value) { abort(); }
int mts_get_pad_vibration_type(int channel) { abort(); }
void DG_DequeuePrim(DG_PRIM *prim) { abort(); }
void DG_FreePrim(DG_PRIM *prim) { abort(); }
int DG_QueuePrim(DG_PRIM *prim) { abort(); }
DG_PRIM *DG_MakePrim(int type, int count, int channel, SVECTOR *positions, RECT *rect) { abort(); }
int font_init_kcb(KCB *kcb, RECT *rect, int x, int y) { abort(); }
int font_set_kcb(KCB *kcb, int w, int h, int cs, int ls, int ts, int flags) { abort(); }
int font_get_buffer_size(KCB *kcb) { abort(); }
void font_set_buffer(KCB *kcb, void *buffer) { abort(); }
void font_set_color(KCB *kcb, int code, int fore, int back) { abort(); }
void font_clut_update(KCB *kcb) { abort(); }
void font_print_string(KCB *kcb, const char *text) { abort(); }
void font_update(KCB *kcb) { abort(); }
void MgsGodotOptionsBegin(void) { abort(); }
void MgsGodotOptionsEnd(void) { abort(); }
void MgsGodotOptionsBeginText(unsigned index, const void *buffer) { abort(); }
void MgsGodotOptionsText(unsigned index, MgsSubtitleFrame frame, const void *palette) { abort(); }
void MgsGodotOptionsView(MgsOptionsFrame frame, const MgsOptionsElement *elements) { abort(); }
void MgsTextLayoutEnd(const void *palette, unsigned width, unsigned height) { abort(); }
void SetSemiTrans(void *packet, int enabled) { abort(); }

static void Press(Work *work, GV_PAD *pad, unsigned key)
{
    pad->press = key;
    pad->status = key;
    option_800C5950(work);
}

#ifdef MGS_GODOT_SCENE
static MgsOptionsAction Command(Work *work, unsigned kind, unsigned target, unsigned value)
{
    unsigned revision = MgsOptionsActionsView(OptionsState(work), 3, 7);
    return (MgsOptionsAction){1, MgsOptionsActionsResult().id + 1, 3, 7, revision, kind, target, value};
}

static void Execute(Work *work, unsigned kind, unsigned target, unsigned value)
{
    MgsOptionsAction command = Command(work, kind, target, value);
    assert(MgsOptionsActionsSubmit(&command));
    option_800C5950(work);
    assert(MgsOptionsActionsResult().status == MGS_OPTIONS_APPLIED);
}

static void DirectActions(void)
{
    GV_PAD pad = {0};
    Work work = {.pad=&pad,.f920=1,.f2B54=1};
    GM_Configuration=GM_CONFIG_RADAR_OFF;
    Execute(&work, MGS_OPTIONS_SELECT, 3, 0);
    assert(work.f920 == 3 && !work.f924[3]);
    for (unsigned row=1; row<=5; ++row) Execute(&work, MGS_OPTIONS_SET, row, 1);
    option_800C3B98(&work);
    assert(GM_PadVibration2 == 255 && work.f2B50 == 2);
    assert(GM_Configuration == GM_CONFIG_RADAR_OFF);
    Execute(&work, MGS_OPTIONS_ACTIVATE, 6, 0);
    assert(work.f920 == 7);
    Execute(&work, MGS_OPTIONS_BACK, 0, 0);
    assert(work.f920 == 6);
    Execute(&work, MGS_OPTIONS_ACTIVATE, 8, 0);
    Execute(&work, MGS_OPTIONS_SET, 0, 2);
    Execute(&work, MGS_OPTIONS_SET, 1, 1);
    assert(work.f920 == 9 && work.f29E8 == 2 && work.f29EC == 1 && work.f29E4 == 1);
    Execute(&work, MGS_OPTIONS_BACK, 0, 0);
    Execute(&work, MGS_OPTIONS_ACTIVATE, 10, 0);
    assert(work.f920 == 11 && work.f2B58 == 0 && audio == 0xff000005);
    unsigned flags = GM_CONFIG_RADAR_OFF | GM_CONFIG_CAPTION_OFF | GM_CONFIG_ENGLISH |
        GM_CONFIG_SOUND_MONAURAL | GM_CONFIG_UNKNOWN_2000 | GM_CONFIG_BUTTON_TYPE_C |
        GM_CONFIG_SHUKAN_REVERSE | GM_CONFIG_UNKNOWN_0008;
    assert((unsigned short)GM_Configuration == flags);
    assert(GM_PadVibration == 0 && GM_PadVibration2 == 0 && pad.press == 0 && pad.status == 0);

    MgsOptionsAction command = Command(&work, MGS_OPTIONS_BACK, 0, 0);
    assert(MgsOptionsActionsSubmit(&command) && MgsOptionsActionsResult().status == MGS_OPTIONS_BUSY);
    work.f920 = 1;
    work.f2B54 = 0;
    command = Command(&work, MGS_OPTIONS_SET, 4, 1);
    assert(MgsOptionsActionsSubmit(&command) && MgsOptionsActionsResult().status == MGS_OPTIONS_INVALID);
    work.f2B54 = 2;
    command = Command(&work, MGS_OPTIONS_SET, 5, 1);
    assert(MgsOptionsActionsSubmit(&command) && MgsOptionsActionsResult().status == MGS_OPTIONS_INVALID);
    command = Command(&work, MGS_OPTIONS_SET, 3, 2);
    assert(MgsOptionsActionsSubmit(&command) && MgsOptionsActionsResult().status == MGS_OPTIONS_INVALID);
    command = Command(&work, MGS_OPTIONS_SELECT, 8, 0);
    assert(MgsOptionsActionsSubmit(&command));
    assert(!MgsOptionsActionsSubmit(&command));
    MgsOptionsAction overlap = command;
    ++overlap.id;
    assert(!MgsOptionsActionsSubmit(&overlap));
    work.f920 = 2;
    assert(!OptionsAction(&work) && MgsOptionsActionsResult().status == MGS_OPTIONS_STALE);
    command = Command(&work, MGS_OPTIONS_SELECT, 8, 0);
    --command.epoch;
    assert(MgsOptionsActionsSubmit(&command) && MgsOptionsActionsResult().status == MGS_OPTIONS_STALE);
    command = Command(&work, MGS_OPTIONS_SELECT, 8, 0);
    --command.generation;
    assert(MgsOptionsActionsSubmit(&command) && MgsOptionsActionsResult().status == MGS_OPTIONS_STALE);
    command = Command(&work, MGS_OPTIONS_SELECT, 8, 0);
    assert(MgsOptionsActionsSubmit(&command));
    MgsOptionsActionsView((MgsOptionsFrame){0}, 3, 7);
    assert(MgsOptionsActionsResult().status == MGS_OPTIONS_STALE);
    command = Command(&work, MGS_OPTIONS_SELECT, 8, 0);
    command.schema = 2;
    assert(!MgsOptionsActionsSubmit(&command));
    Execute(&work, MGS_OPTIONS_SET, 3, 0);
    Execute(&work, MGS_OPTIONS_BACK, 0, 0);
    assert(audio == 0xff000006 && !(GM_Configuration & GM_CONFIG_SOUND_MONAURAL));
    puts("Options direct actions: real settings, effects, pages, stale/busy/invalid guards pass without pad input.");
}
#endif

int main(void)
{
    GV_PAD pad = {0};
    Work work = {.pad=&pad,.f920=1,.f2B54=1};
    GM_Configuration=GM_CONFIG_RADAR_OFF;
    Press(&work,&pad,PAD_RIGHT);
    assert(work.f924[1]==1 && !(GM_Configuration & GM_CONFIG_CAPTION_OFF));
    Press(&work,&pad,PAD_DOWN);
    assert(work.f920==2);
    Press(&work,&pad,PAD_RIGHT);
    assert(work.f924[2]==1);
    Press(&work,&pad,PAD_DOWN);
    Press(&work,&pad,PAD_RIGHT);
    assert(work.f920==3 && work.f924[3]==1);
    Press(&work,&pad,PAD_DOWN);
    Press(&work,&pad,PAD_RIGHT);
    assert(work.f920==4 && work.f924[4]==1);
    Press(&work,&pad,PAD_DOWN);
    Press(&work,&pad,PAD_RIGHT);
    option_800C3B98(&work);
    assert(work.f920==5 && GM_PadVibration2==255 && work.f2B50==2);
    Press(&work,&pad,PAD_DOWN);
    Press(&work,&pad,PAD_CIRCLE);
    assert(work.f920==7);
    Press(&work,&pad,PAD_CROSS);
    assert(work.f920==6);
    Press(&work,&pad,PAD_DOWN);
    Press(&work,&pad,PAD_CIRCLE);
    assert(work.f920==9 && work.f29E4==0);
    Press(&work,&pad,PAD_RIGHT);
    Press(&work,&pad,PAD_RIGHT);
    assert(work.f29E8==2);
    Press(&work,&pad,PAD_DOWN);
    Press(&work,&pad,PAD_RIGHT);
    assert(work.f29EC==1);
    Press(&work,&pad,PAD_CROSS);
    assert(work.f920==8);
    Press(&work,&pad,PAD_CROSS);
    assert(work.f920==11 && work.f2B58==0 && audio==0xff000005);
    const unsigned flags=GM_CONFIG_RADAR_OFF | GM_CONFIG_CAPTION_OFF | GM_CONFIG_ENGLISH |
        GM_CONFIG_SOUND_MONAURAL | GM_CONFIG_UNKNOWN_2000 | GM_CONFIG_BUTTON_TYPE_C |
        GM_CONFIG_SHUKAN_REVERSE | GM_CONFIG_UNKNOWN_0008;
    assert((unsigned short)GM_Configuration==flags);
    assert(GM_PadVibration==0 && GM_PadVibration2==0 && vibration_calls==2 && sounds>10);
    puts("Options native input: settings, vibration, secondary pages and apply/exit pass.");
#ifdef MGS_GODOT_SCENE
    DirectActions();
#endif
    return 0;
}
