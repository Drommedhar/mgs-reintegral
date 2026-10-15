#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>
#include "mgs_crash.h"

static wchar_t dump_path[MAX_PATH];

static LONG WINAPI WriteCrashDump(EXCEPTION_POINTERS *exception)
{
    HANDLE file = CreateFileW(dump_path, GENERIC_WRITE, 0, NULL, CREATE_NEW,
                             FILE_ATTRIBUTE_NORMAL, NULL);
    DWORD error = file == INVALID_HANDLE_VALUE ? GetLastError() : ERROR_SUCCESS;
    if (file != INVALID_HANDLE_VALUE) {
        MINIDUMP_EXCEPTION_INFORMATION info = {GetCurrentThreadId(), exception, FALSE};
        if (!MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), file,
                              MiniDumpNormal, &info, NULL, NULL))
            error = GetLastError();
        CloseHandle(file);
    }
    fprintf(stderr, "[crash] Native exception 0x%08lX at %p.\n",
            exception->ExceptionRecord->ExceptionCode,
            exception->ExceptionRecord->ExceptionAddress);
    if (error == ERROR_SUCCESS)
        fprintf(stderr, "[crash] Dump: %ls\n", dump_path);
    else
        fprintf(stderr, "[crash] Cannot write dump (Windows error %lu): %ls\n", error, dump_path);
    fflush(NULL);
    return EXCEPTION_EXECUTE_HANDLER;
}

void MgsCrashInstall(void)
{
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
    SYSTEMTIME now;
    GetSystemTime(&now);
    if (!CreateDirectoryW(L"logs", NULL) && GetLastError() != ERROR_ALREADY_EXISTS) {
        fprintf(stderr, "[crash] Crash reporting unavailable: cannot create logs (Windows error %lu).\n",
                GetLastError());
        return;
    }
    swprintf(dump_path, MAX_PATH, L"logs/native-crash-%04u%02u%02u-%02u%02u%02u-%lu.dmp",
             now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond,
             GetCurrentProcessId());
    SetUnhandledExceptionFilter(WriteCrashDump);
}
