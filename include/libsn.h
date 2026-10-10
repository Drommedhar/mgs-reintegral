#ifndef MGS_LIBSN_H
#define MGS_LIBSN_H

int PCinit(void);
int PCopen(const char *name, int flags, int permissions);
int PCcreat(const char *name, int permissions);
int PCread(int descriptor, char *buffer, int length);
int PCwrite(int descriptor, const char *buffer, int length);
int PCclose(int descriptor);
int PClseek(int descriptor, int offset, int mode);

#endif
