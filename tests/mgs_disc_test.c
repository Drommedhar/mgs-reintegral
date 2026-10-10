#include "mgs_disc.h"
#include "mgs_safety.h"

#include <assert.h>
#include <libcd.h>
#include <stdio.h>
#include <string.h>

static void CheckSerial(const char *serial)
{
    CdlLOC position;
    unsigned char data[2048];
    unsigned char mode = 0;
    CdIntToPos(19, &position);
    assert(CdControl(CdlSetmode, &mode, NULL));
    assert(CdControl(CdlReadN, (unsigned char *)&position, NULL));
    assert(CdReady(0, NULL) == CdlDataReady);
    assert(CdGetSector(data, sizeof(data) / 4));
    data[sizeof(data) - 1] = 0;
    assert(strstr((const char *)data, serial));
    assert(CdControl(CdlStop, NULL, NULL));
}

int main(int argc, char **argv)
{
    unsigned char result[8];
    if (argc != 3)
        return 64;
    assert(MgsDiscConfigure(argv[1], argv[2]) == 0);
    CheckSerial("SLPM_862.47;1");
    MgsDiscChangeClose();
    CheckSerial("SLPM_862.47;1");
    MgsDiscChangeOpen();
    CdControlB(CdlNop, NULL, result);
    assert(result[0] & CdlStatShellOpen);
    MgsDiscChangeClose();
    assert(CdControlB(CdlNop, NULL, result));
    assert(!(result[0] & CdlStatShellOpen));
    assert(result[0] & CdlStatStandby);
    assert(SafetyCheck(0, 2, 0x16) == 0);
    assert(CdControlB(CdlGetTN, NULL, result));
    assert(result[1] == 1 && result[2] == 1);
    CheckSerial("SLPM_862.48;1");
    puts("Disc swap opens/closes the drive and reads the second image.");
    return 0;
}
