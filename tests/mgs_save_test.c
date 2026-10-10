#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef OpenEvent
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <kernel.h>
#include <libapi.h>
#include <libetc.h>
#include <psyz.h>
#include <romio.h>
#include "../vendor/mgs/source/memcard/memcard.h"

extern void Psyz_KernelPoll(void);

static unsigned int hardware_done, software_done, hardware_error, software_error;
static DWORD owner_thread;
static int game_clock_started;
static const char first_name[] = "ABCDEFGHIJKLMNOPQRSA";
static const char second_name[] = "ABCDEFGHIJKLMNOPQRSB";
static char first_path[] = "bu00:ABCDEFGHIJKLMNOPQRSA";
static char second_path[] = "bu00:ABCDEFGHIJKLMNOPQRSB";

static long HardwareDone(void)
{
    assert(CheckCallback() && GetCurrentThreadId() == owner_thread);
    ++hardware_done;
    return 0;
}

static long SoftwareDone(void) { ++software_done; return 0; }
static long HardwareError(void) { ++hardware_error; return 0; }
static long SoftwareError(void) { ++software_error; return 0; }

static void StartEvents(void)
{
    owner_thread = GetCurrentThreadId();
    assert(EnableEvent(OpenEvent(HwCARD, EvSpIOE, EvMdINTR, HardwareDone)));
    assert(EnableEvent(OpenEvent(SwCARD, EvSpIOE, EvMdINTR, SoftwareDone)));
    assert(EnableEvent(OpenEvent(HwCARD, EvSpERROR, EvMdINTR, HardwareError)));
    assert(EnableEvent(OpenEvent(SwCARD, EvSpERROR, EvMdINTR, SoftwareError)));
    _bu_init();
}

static void Frame(void)
{
    PsyzVSyncCb callback = Psyz_SetVSyncCb(NULL);
    Psyz_SetVSyncCb(callback);
    if (callback) callback();
    Psyz_KernelPoll();
}

void mts_set_vsync_task(void) { game_clock_started = 1; }

int mts_wait_vbl(long count)
{
    assert(game_clock_started && count > 0 && count < 128);
    for (long i = 0; i < count; ++i) Frame();
    return 0;
}

static void Complete(unsigned int bytes)
{
    unsigned int initial_hardware = hardware_done, initial_software = software_done;
    for (unsigned int i = 0; i < bytes / 128; ++i) Frame();
    assert(hardware_done == initial_hardware + bytes / 128);
    assert(software_done == initial_software + 1);
}

static void Create(const char* path, int blocks)
{
    int fd = psyz_open(path, FCREAT | (blocks << 16));
    assert(fd >= 0 && psyz_close(fd) == 0);
}

static void Write(const char* path, unsigned char seed)
{
    unsigned char data[8192];
    for (unsigned int i = 0; i < sizeof(data); ++i) data[i] = (unsigned char)(i ^ seed);
    int fd = psyz_open(path, FWRITE | FASYNC);
    assert(fd >= 0 && psyz_write(fd, data, sizeof(data)) == 0);
    assert(psyz_close(fd) == 0);
    Complete(sizeof(data));
}

static void Read(const char* path, unsigned char seed)
{
    unsigned char data[8192];
    memset(data, 0, sizeof(data));
    int fd = psyz_open(path, FREAD | FASYNC);
    assert(fd >= 0 && psyz_read(fd, data, sizeof(data)) == 0);
    assert(psyz_close(fd) == 0);
    Complete(sizeof(data));
    for (unsigned int i = 0; i < sizeof(data); ++i) assert(data[i] == (unsigned char)(i ^ seed));
}

static void WriteCards(void)
{
    Create(first_path, 1);
    Create(second_path, 1);
    Write(first_path, 0x5a);
    Write(second_path, 0xa5);
    assert(psyz_open(first_path, FCREAT | 0x10000) == -1);
    assert(psyz_close(-1) == -1);
    Read(first_path, 0x5a);
    Write(first_path, 0x33);
    Create("bu10:ABCDEFGHIJKLMNOPQR:A", 1);
    Write("bu10:ABCDEFGHIJKLMNOPQR:A", 0x81);
}

static void VerifyCards(void)
{
    struct DIRENTRY entry;
    char pattern[] = "bu00:*";
    assert(firstfile(pattern, &entry));
    assert(memcmp(entry.name, first_name, 20) == 0 && entry.size == 8192);
    assert(nextfile(&entry));
    assert(memcmp(entry.name, second_name, 20) == 0 && entry.size == 8192);
    assert(!nextfile(&entry));
    Read(first_path, 0x33);
    Read(second_path, 0xa5);
    Read("bu10:ABCDEFGHIJKLMNOPQR:A", 0x81);
}

static void TestErrorsAndCriticalSection(void)
{
    unsigned char data[8192] = {0};
    Create(first_path, 1);
    int fd = psyz_open(first_path, FWRITE | FASYNC);
    assert(fd >= 0 && psyz_write(fd, data, sizeof(data)) == 0);
    assert(psyz_close(fd) == 0);
    EnterCriticalSection();
    for (int i = 0; i < 96; ++i) Frame();
    assert(hardware_done == 0 && software_done == 0);
    ExitCriticalSection();
    assert(hardware_done == 1 && software_done == 0);
    for (int i = 0; i < 63; ++i) Frame();
    assert(hardware_done == 64 && software_done == 1);
    fd = psyz_open(first_path, FREAD | FASYNC);
    assert(fd >= 0 && psyz_lseek(fd, 8192, SEEK_SET) == 8192);
    assert(psyz_read(fd, data, 128) == 0);
    Frame();
    assert(hardware_error == 1 && software_error == 1);
    assert(psyz_close(fd) == 0);
    assert(_card_read(0, 0, data) == 1 && data[0] == 'M' && data[1] == 'C');
    assert(_card_read(0, 1, data) == 0 && hardware_error == 2);
    assert(_card_write(0, 1, data) == 0 && hardware_error == 3);
}

static void TestCapacityAndFormat(void)
{
    char card[] = "bu00:", missing[] = "bu00:missing", path[] = "bu00:slot00";
    for (int i = 0; i < 15; ++i) {
        path[9] = '0' + i / 10;
        path[10] = '0' + i % 10;
        Create(path, 1);
    }
    assert(psyz_open("bu00:overflow", FCREAT | 0x10000) == -1);
    assert(!erase(missing));
    assert(erase(path));
    Create("bu00:replacement", 1);
    assert(format(card));
    Create("bu00:wholecard", 15);
    assert(psyz_open("bu00:overflow", FCREAT | 0x10000) == -1);
    assert(format(card));
    assert(psyz_open("bu00:bad", FCREAT | (16 << 16)) == -1);
    assert(psyz_open("bu00:ABCDEFGHIJKLMNOPQRSTU", FCREAT | 0x10000) == -1);
    assert(psyz_open("bu01:unsupported", FCREAT | 0x10000) == -1);
}

static void CompleteGameTransfer(void)
{
    assert(memcard_status() == MEMCARD_BLOCK_SIZE);
    for (int i = 0; i < MEMCARD_BLOCK_SIZE / 128; ++i) {
        Frame();
        assert(memcard_status() == MEMCARD_BLOCK_SIZE - (i + 1) * 128);
    }
}

static void GameSave(int verify)
{
    char data[MEMCARD_BLOCK_SIZE];
    memcard_init();
    assert(((unsigned int)memcard_check(0) & 0x80000000) == 0);
    MEMCARD* card = memcard_files(0);
    assert(card && card->file_count == (verify ? 1 : 0));
    if (!verify) {
        for (unsigned int i = 0; i < sizeof(data); ++i) data[i] = (char)(i ^ 0x5a);
        memcard_write(0, first_name, 0, data, sizeof(data));
        CompleteGameTransfer();
        card = memcard_files(0);
        assert(card && card->file_count == 1 && card->free_blocks == 14);
        assert(strcmp(card->files[0].name, first_name) == 0);
    }
    memset(data, 0, sizeof(data));
    memcard_read(0, first_name, 0, data, sizeof(data));
    CompleteGameTransfer();
    for (unsigned int i = 0; i < sizeof(data); ++i) assert(data[i] == (char)(i ^ 0x5a));
    if (verify) {
        assert(memcard_delete(0, first_name));
        card = memcard_files(0);
        assert(card && card->file_count == 0 && card->free_blocks == 15);
    }
    memcard_exit();
}

int main(int argc, char** argv)
{
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
    assert(argc == 2);
    StartEvents();
    if (strcmp(argv[1], "write") == 0) WriteCards();
    else if (strcmp(argv[1], "verify") == 0) VerifyCards();
    else if (strcmp(argv[1], "events") == 0) TestErrorsAndCriticalSection();
    else if (strcmp(argv[1], "capacity") == 0) TestCapacityAndFormat();
    else if (strcmp(argv[1], "game-write") == 0) GameSave(0);
    else if (strcmp(argv[1], "game-verify") == 0) GameSave(1);
    else return 2;
    puts("Native card persistence, slot identity, capacity, and completion checks passed.");
    return 0;
}
