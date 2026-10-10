#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#undef OpenEvent
#include <kernel.h>
#include <libapi.h>
#include <libetc.h>
#include "mgs_threads.h"

enum {
    MGS_THREAD_COUNT = 16,
    MGS_STACK_COMMIT = 64 * 1024,
    MGS_STACK_RESERVE = 1024 * 1024,
    MGS_REGISTER_GP = 28,
    MGS_REGISTER_SP = 29
};

typedef struct {
    void *fiber;
    unsigned long (*entry)(void);
    struct TCB tcb;
    int critical;
    int peak_stack;
    int used_stack;
} MgsThread;

static MgsThread threads[MGS_THREAD_COUNT];
static DWORD owner_thread;
static unsigned long current_thread;
static unsigned long thread_limit = MGS_THREAD_COUNT;
static unsigned long configuration_stack;
static int converted_host;

void MgsThreadsFail(const char *message)
{
    fputs("MGS scheduler: ", stderr);
    fputs(message, stderr);
    fputc('\n', stderr);
    abort();
}

static void CheckOwner(void)
{
    if (owner_thread && owner_thread != GetCurrentThreadId()) {
        MgsThreadsFail("game callbacks must run on the owning OS thread");
    }
    if (owner_thread) {
        return;
    }
    owner_thread = GetCurrentThreadId();
    if (IsThreadAFiber()) {
        threads[0].fiber = GetCurrentFiber();
    } else {
        threads[0].fiber = ConvertThreadToFiberEx(NULL, FIBER_FLAG_FLOAT_SWITCH);
        converted_host = 1;
    }
    if (!threads[0].fiber) {
        MgsThreadsFail("cannot convert the game thread to a fiber");
    }
    threads[0].tcb.status = TcbStACTIVE;
}

static MgsThread *GetThread(unsigned long thread)
{
    CheckOwner();
    if (thread >= thread_limit || !threads[thread].fiber) {
        MgsThreadsFail("invalid or closed thread descriptor");
    }
    return &threads[thread];
}

static void RecordStack(void)
{
    ULONG_PTR low, high;
    uintptr_t stack = (uintptr_t)__builtin_frame_address(0);
    MgsThread *thread = &threads[current_thread];
    GetCurrentThreadStackLimits(&low, &high);
    if (stack < low || stack > high) {
        MgsThreadsFail("fiber stack pointer is outside its Windows stack");
    }
    thread->tcb.reg[MGS_REGISTER_SP] = (unsigned long)stack;
    thread->used_stack = (int)(high - stack);
    if (thread->used_stack > thread->peak_stack) {
        thread->peak_stack = thread->used_stack;
    }
}

static VOID WINAPI ThreadEntry(void *parameter)
{
    MgsThread *thread = parameter;
    RecordStack();
    thread->entry();
    MgsThreadsFail("a game thread returned without exiting through mts_ext_tsk");
}

unsigned long OpenTh(unsigned long (*func)(), unsigned long sp, unsigned long gp)
{
    unsigned long index;
    CheckOwner();
    if (!func) {
        MgsThreadsFail("cannot create a thread with no entry point");
    }
    for (index = 1; index < thread_limit; ++index) {
        if (!threads[index].fiber) {
            break;
        }
    }
    if (index == thread_limit) {
        MgsThreadsFail("the configured thread table is full");
    }
    MgsThread *thread = &threads[index];
    thread->entry = func;
    thread->critical = 1;
    thread->tcb.status = TcbStACTIVE;
    thread->tcb.reg[MGS_REGISTER_SP] = sp;
    thread->tcb.reg[MGS_REGISTER_GP] = gp;
    thread->fiber = CreateFiberEx(MGS_STACK_COMMIT, MGS_STACK_RESERVE,
                                 FIBER_FLAG_FLOAT_SWITCH, ThreadEntry, thread);
    if (!thread->fiber) {
        MgsThreadsFail("Windows could not allocate a game fiber");
    }
    return index;
}

long ChangeTh(unsigned long thread)
{
    MgsThread *target = GetThread(thread);
    MgsThread *source = &threads[current_thread];
    if (CheckCallback()) {
        MgsThreadsFail("fiber switch attempted inside a PsyZ interrupt callback");
    }
    if (thread == current_thread) {
        return 1;
    }
    RecordStack();
    if (source->critical) {
        PS1_ExitCriticalSection();
    }
    current_thread = thread;
    if (target->critical) {
        PS1_EnterCriticalSection();
    }
    SwitchToFiber(target->fiber);
    return 1;
}

long CloseTh(unsigned long thread)
{
    MgsThread *target = GetThread(thread);
    if (thread == 0 || thread == current_thread) {
        MgsThreadsFail("cannot delete the current fiber or host fiber");
    }
    DeleteFiber(target->fiber);
    memset(target, 0, sizeof(*target));
    return 1;
}

void SwEnterCriticalSection(void)
{
    CheckOwner();
    if (!CheckCallback()) {
        threads[current_thread].critical = 1;
        PS1_EnterCriticalSection();
    }
}

void SwExitCriticalSection(void)
{
    CheckOwner();
    if (!CheckCallback()) {
        threads[current_thread].critical = 0;
        PS1_ExitCriticalSection();
    }
}

unsigned long GetGp(void)
{
    CheckOwner();
    return threads[current_thread].tcb.reg[MGS_REGISTER_GP];
}

unsigned long GetSp(void)
{
    CheckOwner();
    RecordStack();
    return threads[current_thread].tcb.reg[MGS_REGISTER_SP];
}

struct TCB *MgsThreadsGetTcb(unsigned long thread)
{
    return &GetThread(thread)->tcb;
}

void MgsThreadsStackUsage(unsigned long thread, int *peak, int *used, int *limit)
{
    MgsThread *target = GetThread(thread);
    if (thread == current_thread) {
        RecordStack();
    }
    *peak = target->peak_stack;
    *used = target->used_stack;
    *limit = MGS_STACK_RESERVE;
}

long SetConf(unsigned long ev, unsigned long tcb, unsigned long sp)
{
    CheckOwner();
    if (ev != 16 || tcb == 0 || tcb >= MGS_THREAD_COUNT) {
        MgsThreadsFail("unsupported kernel event or thread table size");
    }
    for (unsigned long index = 1; index < MGS_THREAD_COUNT; ++index) {
        if (threads[index].fiber) {
            MgsThreadsFail("kernel reconfiguration requires all game threads closed");
        }
    }
    thread_limit = tcb + 1;
    configuration_stack = sp;
    return 1;
}

void GetConf(unsigned long *ev, unsigned long *tcb, unsigned long *sp)
{
    CheckOwner();
    *ev = 16;
    *tcb = thread_limit - 1;
    *sp = configuration_stack;
}

void MgsThreadsShutdown(void)
{
    CheckOwner();
    if (current_thread != 0 || CheckCallback()) {
        MgsThreadsFail("scheduler shutdown requires the host fiber");
    }
    for (unsigned long index = 1; index < thread_limit; ++index) {
        if (threads[index].fiber) {
            DeleteFiber(threads[index].fiber);
        }
    }
    PS1_ExitCriticalSection();
    if (converted_host && !ConvertFiberToThread()) {
        MgsThreadsFail("cannot restore the host thread after fiber shutdown");
    }
    memset(threads, 0, sizeof(threads));
    owner_thread = 0;
    current_thread = 0;
    converted_host = 0;
    thread_limit = MGS_THREAD_COUNT;
}
