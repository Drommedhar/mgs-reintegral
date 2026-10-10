#ifndef MGS_THREADS_H
#define MGS_THREADS_H

struct TCB;

struct TCB *MgsThreadsGetTcb(unsigned long thread);
void MgsThreadsStackUsage(unsigned long thread, int *peak, int *used, int *limit);
void MgsThreadsShutdown(void);
void MgsThreadsFail(const char *message);
long CloseTh(unsigned long thread);

#endif
