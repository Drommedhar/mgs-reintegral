#include <stdio.h>
#include <string.h>
#include <libapi.h>
#include <libpad.h>
#include <libspu.h>
#include <psyz/input.h>
#include <psyz/system.h>
#include "mgs_input_movie.h"

enum { PAD_PORTS = 2, PAD_ACTUATORS = 2, PAD_ALIGNMENT_BYTES = 6 };

typedef struct {
    unsigned char *actuators;
    int actuator_bytes;
    unsigned char alignment[PAD_ALIGNMENT_BYTES];
    int rumble_error;
} NativePad;

static NativePad pads[PAD_PORTS];
static PsyzVSyncCb previous_vsync;
static int callback_installed;

static int PadIndex(int port)
{
    return port == 0 ? 0 : port == 0x10 ? 1 : -1;
}

static void UpdateRumble(int index)
{
    NativePad *pad = &pads[index];
    unsigned short low = 0, high = 0;
    if (MgsInputMovieReplaying() || !MgsInputMovieSupportsRumble(index)) {
        pad->rumble_error = 0;
        return;
    }
    for (int i = 0; i < PAD_ALIGNMENT_BYTES && i < pad->actuator_bytes; ++i) {
        if (pad->alignment[i] == 0) {
            high = pad->actuators[i] ? 65535 : 0;
        } else if (pad->alignment[i] == 1) {
            low = (unsigned short)(pad->actuators[i] * 257);
        }
    }
    if (!Psyz_PadsRumble(index, low, high, 100)) {
        if (!pad->rumble_error) {
            fprintf(stderr, "Controller %d rejected vibration output.\n", index + 1);
        }
        pad->rumble_error = 1;
    } else {
        pad->rumble_error = 0;
    }
}

static void PadFrame(void)
{
    if (previous_vsync) {
        previous_vsync();
    }
    if (Psyz_PadsRunning()) {
        for (int i = 0; i < PAD_PORTS; ++i) {
            UpdateRumble(i);
        }
    }
}

void PadInitDirect(unsigned char *pad1, unsigned char *pad2)
{
    StopPAD();
    memset(pads, 0, sizeof(pads));
    for (int i = 0; i < PAD_PORTS; ++i) {
        memset(pads[i].alignment, 0xff, sizeof(pads[i].alignment));
    }
    InitPAD((char *)pad1, PSYZ_PAD_BUF_LEN, (char *)pad2, PSYZ_PAD_BUF_LEN);
    Psyz_PadsSetKind(0, 0, PSYZ_CTRL_ANALOG_PAD);
    Psyz_PadsSetKind(1, 0, PSYZ_CTRL_ANALOG_PAD);
    if (!callback_installed) {
        previous_vsync = Psyz_SetVSyncCb(PadFrame);
        callback_installed = 1;
    }
}

void PadStartCom(void)
{
    if (!StartPAD()) {
        fputs("Cannot start controller communication without receive buffers.\n", stderr);
    }
}

void PadStopCom(void)
{
    StopPAD();
}

int PadGetState(int port)
{
    int index = PadIndex(port);
    char frame[PSYZ_PAD_BUF_LEN];
    if (index < 0 || !Psyz_PadsRunning()) {
        return PadStateDiscon;
    }
    Psyz_PadsGet(index, frame, sizeof(frame));
    if (frame[0] != 0 || (unsigned char)frame[1] == PSYZ_CTRL_DISCONNECTED) {
        return PadStateDiscon;
    }
    return MgsInputMovieSupportsRumble(index) ? PadStateStable : PadStateFindCTP1;
}

int PadInfoAct(int port, int actno, int term)
{
    if (PadGetState(port) != PadStateStable) {
        return 0;
    }
    if (actno == -1) {
        return PAD_ACTUATORS;
    }
    if (actno < 0 || actno >= PAD_ACTUATORS) {
        return 0;
    }
    switch (term) {
    case InfoActFunc: return 1;
    case InfoActSub: return actno == 0 ? 2 : 1;
    case InfoActSize: return actno;
    default: return 0;
    }
}

void PadSetAct(int port, unsigned char *data, int len)
{
    int index = PadIndex(port);
    if (index < 0 || len < 0 || len > PAD_ALIGNMENT_BYTES + 2 || (!data && len)) {
        fputs("Invalid controller actuator buffer.\n", stderr);
        return;
    }
    pads[index].actuators = data;
    pads[index].actuator_bytes = len;
}

int PadSetActAlign(int port, char *data)
{
    int index = PadIndex(port);
    if (index < 0 || !data || PadGetState(port) != PadStateStable) {
        return 0;
    }
    for (int i = 0; i < PAD_ALIGNMENT_BYTES; ++i) {
        if ((unsigned char)data[i] != 0xff && (unsigned char)data[i] >= PAD_ACTUATORS) {
            return 0;
        }
    }
    memcpy(pads[index].alignment, data, PAD_ALIGNMENT_BYTES);
    return 1;
}

int PadInfoMode(int port, int term, int offs)
{
    int index = PadIndex(port);
    if (index < 0 || PadGetState(port) == PadStateDiscon) {
        return 0;
    }
    PsyzControllerKind kind = Psyz_PadsSetKind(index, 0, PSYZ_CTRL_QUERY_KIND);
    switch (term) {
    case InfoModeCurID: return kind >> 4;
    case InfoModeCurExID: return MgsInputMovieSupportsRumble(index) ? kind >> 4 : 0;
    case InfoModeCurExOffs: return kind == PSYZ_CTRL_ANALOG_PAD;
    case InfoModeIdTable:
        return offs == -1 ? 2 : offs == 0 ? 4 : offs == 1 ? 7 : 0;
    default: return 0;
    }
}

int PadSetMainMode(int port, int offs, int lock)
{
    int index = PadIndex(port);
    if (index < 0 || (offs != 0 && offs != 1) || lock < 0 || lock > 3 ||
        PadGetState(port) == PadStateDiscon) {
        return 0;
    }
    /* Native devices have no emulated physical mode-selector button to lock. */
    return Psyz_PadsSetKind(index, 0, offs ? PSYZ_CTRL_ANALOG_PAD : PSYZ_CTRL_DIGITAL_PAD)
        != PSYZ_CTRL_ERROR;
}

extern int _spu_rev_reserve_wa;
extern int _spu_rev_offsetaddr;
extern int _SpuIsInAllocateArea_(unsigned address);

long SpuReserveReverbWorkArea(long on_off)
{
    if (on_off != SPU_ON && on_off != SPU_OFF) {
        return SPU_ERROR;
    }
    _spu_rev_reserve_wa = on_off == SPU_ON &&
        !_SpuIsInAllocateArea_((unsigned)_spu_rev_offsetaddr);
    return _spu_rev_reserve_wa;
}
