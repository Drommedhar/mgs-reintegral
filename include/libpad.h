#ifndef MGS_LIBPAD_H
#define MGS_LIBPAD_H

#include <libetc.h>

enum { PadStateDiscon, PadStateFindPad, PadStateFindCTP1,
       PadStateReqInfo = 4, PadStateExecCmd, PadStateStable };
enum { InfoActFunc = 1, InfoActSub, InfoActSize, InfoActCurr };
enum { InfoModeCurID = 1, InfoModeCurExID, InfoModeCurExOffs, InfoModeIdTable };

#endif
