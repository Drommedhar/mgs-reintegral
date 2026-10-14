#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define MGS_NATIVE 1
#define PAD_UP 0x10
#define PAD_DOWN 0x40
#define PAD_LEFT 0x80
#define PAD_RIGHT 0x20
#define PAD_TRIANGLE 0x1000
#define PAD_CROSS 0x4000
#define PAD_SQUARE 0x8000
#define PAD_CIRCLE 0x2000
typedef struct { int field_18, field_14_bInExecBlock, field_0_state; void *field_C_pScript; } Chara;
typedef struct { int field_212, field_210_codec_state; Chara *field_218; } Work;
typedef struct { unsigned short status, release; } Pad;
static int GV_Time, advances, interrupts, stops, dword_800ABAF8;
static void menu_radio_codec_helper_helper8_80048044(void) { ++advances; }
static void sub_80041118(Work *work) { (void)work; }
static void menu_radio_codec_helper__helper13_800410E4(Work *work, void *script) { (void)work; (void)script; ++interrupts; }
static void GM_StreamPlayStop(void) { ++stops; }
#include "codec_turbo_fixture.h"
int main(int argc, char **argv)
{
    assert(argc == 2);
    int enabled = !strcmp(argv[1], "1");
#ifdef _WIN32
    _putenv_s("REI_CODEC_TURBO", !strcmp(argv[1], "unset") ? "" : argv[1]);
#else
    if (!strcmp(argv[1], "unset")) unsetenv("REI_CODEC_TURBO");
    else setenv("REI_CODEC_TURBO", argv[1], 1);
#endif
    Chara chara = {0};
    Work work = {PAD_TRIANGLE, 4, &chara};
    Pad pad = {PAD_TRIANGLE, 0};
    assert(ReiCodecTurboHeld(pad.status, 0) == enabled);
    assert(!ReiCodecTurboHeld(0, 0));
    assert(!ReiCodecTurboHeld(pad.status, 1));
    GV_Time = 5; Wait(&work, &pad); assert(!advances);
    GV_Time = 6; Wait(&work, &pad);
    assert(advances == enabled);
    assert(work.field_212 == (enabled ? 0 : PAD_TRIANGLE));
    advances = 0; work.field_212 = 0; pad.release = PAD_CROSS;
    Wait(&work, &pad); assert(advances == 1); /* Original release still works. */
    pad.release = PAD_CROSS; chara.field_18 = 1; chara.field_14_bInExecBlock = 1;
    Interrupt(&work, &pad); assert(!interrupts && !stops);
    pad.release = 0; chara.field_18 = 0; Interrupt(&work, &pad);
    assert(interrupts == enabled && stops == enabled);
    assert(chara.field_14_bInExecBlock == (enabled ? 0 : 1));
    assert((chara.field_18 & 0x100) == (enabled ? 0x100 : 0));
    interrupts = stops = 0; pad.status = 0; pad.release = PAD_CROSS;
    Interrupt(&work, &pad); assert(interrupts == 1 && stops == 1);
    puts("Native Codec hold/release, skip guard, cadence and debounce checks passed.");
    return 0;
}
