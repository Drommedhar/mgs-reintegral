#ifndef MGS_INPUT_LOG_H
#define MGS_INPUT_LOG_H

#include <stdio.h>

#define MGS_INPUT_PAD_BYTES 34
#define MGS_INPUT_STATE_FIELDS 22

typedef struct MgsInputSample
{
    unsigned sample;
    unsigned vsync;
    unsigned kinds[2];
    unsigned char pads[2][MGS_INPUT_PAD_BYTES];
    char stage[16];
    int state[MGS_INPUT_STATE_FIELDS];
} MgsInputSample;

/* Zero-initialize before opening. The error message remains available after close. */
typedef struct MgsInputLog
{
    FILE *file;
    unsigned count;
    unsigned last_vsync;
    int mode;
    int ended;
    int failed;
    char error[160];
} MgsInputLog;

int MgsInputLogOpenWrite(MgsInputLog *log, const char *path, const char *identity);
int MgsInputLogOpenRead(MgsInputLog *log, const char *path, const char *identity);
int MgsInputLogWriteSample(MgsInputLog *log, const MgsInputSample *sample);
int MgsInputLogWriteEnd(MgsInputLog *log, const MgsInputSample *sample);
/* Returns 1 for P, 2 for E, or 0 for an error. Stop reading after E. */
int MgsInputLogReadNext(MgsInputLog *log, MgsInputSample *sample);
/* A missing E record makes close fail in either mode. Always closes the file. */
int MgsInputLogClose(MgsInputLog *log);
const char *MgsInputLogError(const MgsInputLog *log);

#endif
