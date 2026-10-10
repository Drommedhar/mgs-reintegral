#include <assert.h>
#include <stdio.h>
#include <kernel.h>
#include <libapi.h>
#include <libetc.h>
#include "mgs_threads.h"

void Psyz_KernelRaise(unsigned int desc, unsigned int spec);

static unsigned long first_thread;
static unsigned long second_thread;
static int sequence;
static int callback_count;
static const unsigned int event_class = DescUEV | 8;

static long EventCallback(void)
{
    assert(CheckCallback());
    ++callback_count;
    return 0;
}

static unsigned long SecondThread(void)
{
    SwExitCriticalSection();
    assert(sequence == 1 && callback_count == 1);
    assert(GetGp() == 0x2222);
    sequence = 2;
    Psyz_KernelRaise(event_class, EvSpINT);
    assert(callback_count == 2);
    ChangeTh(first_thread);
    MgsThreadsFail("second test thread unexpectedly resumed");
    return 0;
}

static unsigned long FirstThread(void)
{
    volatile unsigned int preserved = 0x12345678;
    SwExitCriticalSection();
    assert(sequence == 0 && GetGp() == 0x1111);
    sequence = 1;
    SwEnterCriticalSection();
    Psyz_KernelRaise(event_class, EvSpINT);
    assert(callback_count == 0);
    ChangeTh(second_thread);
    assert(sequence == 2 && preserved == 0x12345678);
    Psyz_KernelRaise(event_class, EvSpINT);
    assert(callback_count == 2);
    SwExitCriticalSection();
    assert(callback_count == 3);
    sequence = 3;
    ChangeTh(0);
    MgsThreadsFail("first test thread unexpectedly resumed");
    return 0;
}

int main(void)
{
    unsigned long events, count, stack;
    int peak, used, limit;
    SetConf(16, 12, 0);
    GetConf(&events, &count, &stack);
    assert(events == 16 && count == 12 && stack == 0);
    long event = OpenEvent(event_class, EvSpINT, EvMdINTR, EventCallback);
    assert(event != -1 && EnableEvent(event));
    first_thread = OpenTh(FirstThread, 0, 0x1111);
    second_thread = OpenTh(SecondThread, 0, 0x2222);
    ChangeTh(first_thread);
    assert(sequence == 3 && callback_count == 3);
    MgsThreadsStackUsage(first_thread, &peak, &used, &limit);
    assert(peak >= used && used > 0 && used < limit);
    assert(MgsThreadsGetTcb(first_thread)->reg[28] == 0x1111);
    assert(GetSp() != 0);
    assert(CloseTh(first_thread) && CloseTh(second_thread));
    unsigned long recycled = OpenTh(FirstThread, 0, 0);
    assert(recycled == first_thread && CloseTh(recycled));
    assert(CloseEvent(event));
    MgsThreadsShutdown();
    puts("Fiber switching, critical masks, events, TCBs and slot reuse passed.");
    return 0;
}
