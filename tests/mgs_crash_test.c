#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dbghelp.h>
#include <assert.h>
#include <stdio.h>
#include <wchar.h>
#include "mgs_crash.h"

static void CheckDump(const wchar_t *path)
{
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    assert(file != INVALID_HANDLE_VALUE);
    HANDLE mapping = CreateFileMappingW(file, NULL, PAGE_READONLY, 0, 0, NULL);
    assert(mapping != NULL);
    void *view = MapViewOfFile(mapping, FILE_MAP_READ, 0, 0, 0);
    assert(view != NULL);
    MINIDUMP_DIRECTORY *directory;
    MINIDUMP_EXCEPTION_STREAM *exception;
    ULONG size;
    assert(MiniDumpReadDumpStream(view, ExceptionStream, &directory, (void **)&exception, &size));
    assert(size >= sizeof(*exception));
    assert(exception->ExceptionRecord.ExceptionCode == EXCEPTION_ACCESS_VIOLATION);
    UnmapViewOfFile(view);
    CloseHandle(mapping);
    CloseHandle(file);
}

int main(int argc, char **argv)
{
    (void)argv;
    if (argc == 2) {
        MgsCrashInstall();
        RaiseException(EXCEPTION_ACCESS_VIOLATION, EXCEPTION_NONCONTINUABLE, 0, NULL);
        return 1;
    }
    wchar_t executable[MAX_PATH], command[MAX_PATH + 16], folder[64];
    assert(GetModuleFileNameW(NULL, executable, MAX_PATH) > 0);
    swprintf(folder, 64, L"crash-test-%lu", GetCurrentProcessId());
    assert(CreateDirectoryW(folder, NULL));
    assert(SetCurrentDirectoryW(folder));
    swprintf(command, MAX_PATH + 16, L"\"%ls\" child", executable);
    STARTUPINFOW startup = {.cb = sizeof(startup)};
    PROCESS_INFORMATION process;
    assert(CreateProcessW(executable, command, NULL, NULL, FALSE, CREATE_NO_WINDOW,
                          NULL, NULL, &startup, &process));
    assert(WaitForSingleObject(process.hProcess, 15000) == WAIT_OBJECT_0);
    DWORD exit_code;
    assert(GetExitCodeProcess(process.hProcess, &exit_code));
    assert(exit_code == EXCEPTION_ACCESS_VIOLATION);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    WIN32_FIND_DATAW found;
    HANDLE search = FindFirstFileW(L"logs/native-crash-*.dmp", &found);
    assert(search != INVALID_HANDLE_VALUE);
    wchar_t dump[MAX_PATH];
    swprintf(dump, MAX_PATH, L"logs/%ls", found.cFileName);
    CheckDump(dump);
    assert(!FindNextFileW(search, &found));
    FindClose(search);
    assert(DeleteFileW(dump));
    assert(RemoveDirectoryW(L"logs"));
    assert(SetCurrentDirectoryW(L".."));
    assert(RemoveDirectoryW(folder));
    puts("Native unhandled exception retains its exit code and creates a readable crash dump.");
    return 0;
}
