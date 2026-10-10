#ifndef MGS_REX_PROBE_H
#define MGS_REX_PROBE_H

/* Buttons are ordinary pad bits; heading is -1 or a world yaw for analog movement. */
unsigned short MgsRexProbeInput(unsigned frame, int *heading);
int MgsRexProbeFinish(void);

#endif
