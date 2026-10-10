#include "mgs_native.h"

#include "../vendor/mgs/source/overlays/camera/unknown/camera_native.h"
#include "fixtures/mgs_camera_card_fixtures.h"
#include "fixtures/mgs_camera_writer_fixtures.h"
#include <assert.h>
#include <limits.h>
#include <stdarg.h>
#include <stdint.h>

int camera_dword_800C342C, camera_dword_800C3430, camera_dword_800C3434;
int camera_dword_800C3880, camera_dword_800C3884;
int camera_dword_800D0728, camera_dword_800D0734, camera_dword_800D0738, camera_dword_800D073C;
int camera_dword_800D0740[2];
MEMCARD *camera_dword_800D0748[2];
DATA_INFO *camera_dword_800D072C;
char camera_dword_800C37F8[24];
char *MGS_MemoryCardName = "BISLPM86247X00000000";
short linkvarbuf[MAX_LINKVARBUF];
int GM_PadResetDisable;

static MEMCARD cards[2];
static size_t current_case, cursor, end;
static unsigned int cooperative_waits;
static const CameraWriterFixture *writer;
static unsigned int writer_trace;
static int write_attempts, status_polls, allocation_failure;
static unsigned char file_buffer[3 * MEMCARD_BLOCK_SIZE];

static unsigned int HashBytes(unsigned int hash, const void *data, size_t length)
{
    const unsigned char *bytes = data;
    size_t i;
    for (i = 0; i < length; ++i)
        hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static void RecordWriter(int value)
{
    writer_trace = HashBytes(writer_trace, &value, sizeof(value));
}

static unsigned int StateHash(void)
{
    unsigned int hash = 2166136261u;
    int values[] = {camera_dword_800C342C,
                    camera_dword_800C3430,
                    camera_dword_800C3434,
                    camera_dword_800C3880,
                    camera_dword_800C3884,
                    camera_dword_800D0728,
                    camera_dword_800D0734,
                    camera_dword_800D0738,
                    camera_dword_800D073C,
                    camera_dword_800D0740[0],
                    camera_dword_800D0740[1],
                    camera_dword_800D0748[0] ? (int)(camera_dword_800D0748[0] - cards) + 1 : 0,
                    camera_dword_800D0748[1] ? (int)(camera_dword_800D0748[1] - cards) + 1 : 0};
    const unsigned char *bytes = (const unsigned char *)values;
    size_t i;
    for (i = 0; i < sizeof(values); ++i)
        hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static int Boundary(int kind, unsigned int a, unsigned int b)
{
    const CameraCardEvent *event;
    unsigned int before = StateHash();
    assert(cursor < end);
    event = &CameraCardEvents[cursor++];
    if (event->kind != kind || event->a != a || event->b != b || event->before != before)
    {
        printf(
            "Camera worker case %u, event %u: call %d/%u/%u, expected %d/%u/%u; state %08x/%08x\n",
            (unsigned int)current_case, (unsigned int)(cursor - 1), kind, a, b, event->kind,
            event->a, event->b, before, event->before);
        abort();
    }
    if (kind == 1)
    {
        camera_dword_800D0738 = a;
        camera_dword_800D073C = event->result;
    }
    if (event->response != INT_MIN)
        camera_dword_800D073C = event->response;
    return event->result;
}

void mts_set_vsync_task(void)
{
    Boundary(0, 0, 0);
}
int camera_800C4D20(int request)
{
    return Boundary(1, request, 0);
}
int memcard_check(int port)
{
    return Boundary(2, port, 0);
}
MEMCARD *memcard_files(int port)
{
    return Boundary(3, port, 0) ? &cards[port] : NULL;
}
int memcard_format(int port)
{
    return Boundary(5, port, 0);
}
int camera_800C4BAC(MEMCARD *card, int entry)
{
    return Boundary(6, (unsigned int)(card - cards), entry);
}
int camera_800C4790(MEMCARD *card)
{
    return Boundary(7, (unsigned int)(card - cards), 0);
}

int memcard_delete(int port, const char *filename)
{
    size_t index;
    for (index = 0; index < MEMCARD_BLOCK_MAX; ++index)
        if (filename == cards[port].files[index].name)
            return Boundary(4, port, (unsigned int)index);
    abort();
}

int mts_wait_vbl(long count)
{
    if (writer)
    {
        RecordWriter(7);
        RecordWriter(count);
        RecordWriter(GM_PadResetDisable);
        return 0;
    }
    assert(count == 1);
    assert(camera_dword_800D073C == -2);
    ++cooperative_waits;
    return 0;
}

void *GV_AllocMemory(int arena, int size)
{
    assert(size > 0 && (size_t)size <= sizeof(file_buffer));
    RecordWriter(1);
    RecordWriter(arena);
    RecordWriter(size);
    RecordWriter(GM_PadResetDisable);
    return allocation_failure ? NULL : file_buffer;
}

void GV_ZeroMemory(void *buffer, int size)
{
    assert(buffer == file_buffer);
    RecordWriter(2);
    RecordWriter(size);
    memset(buffer, 0, size);
}

void GV_FreeMemory(int arena, void *buffer)
{
    assert(buffer == file_buffer);
    RecordWriter(8);
    RecordWriter(arena);
    RecordWriter(GM_PadResetDisable);
}

static void MakeTitle(char *buffer, MEMCARD *card, int hours, int minutes)
{
    int i;
    assert(buffer == (char *)file_buffer + 4 && card == &cards[0]);
    RecordWriter(3);
    RecordWriter(card->port);
    RecordWriter(hours);
    RecordWriter(minutes);
    RecordWriter(GM_PadResetDisable);
    for (i = 0; i < 92; ++i)
        buffer[i] = i * 13 + hours * 7 + minutes * 11 + card->port;
}

static void MakeGameData(char *buffer)
{
    int i, size = writer->input[0] * MEMCARD_BLOCK_SIZE - 256;
    assert(buffer == (char *)file_buffer + 256);
    RecordWriter(4);
    RecordWriter(size);
    RecordWriter(GM_PadResetDisable);
    for (i = 0; i < size; ++i)
        buffer[i] = i * 17 + writer->input[11] * 3;
}

void memcard_write(int port, const char *filename, int offset, char *buffer, int size)
{
    assert(buffer == (char *)file_buffer);
    RecordWriter(5);
    RecordWriter(port);
    RecordWriter(offset);
    RecordWriter(size);
    RecordWriter(HashBytes(2166136261u, filename, strlen(filename)));
    RecordWriter(HashBytes(2166136261u, buffer, size));
    RecordWriter(GM_PadResetDisable);
    ++write_attempts;
    status_polls = 0;
}

int memcard_status(void)
{
    int status =
        status_polls < writer->input[10] ? 1 : (write_attempts <= writer->input[9] ? -1 : 0);
    ++status_polls;
    RecordWriter(6);
    RecordWriter(status);
    return status;
}

void CameraFormat(char *output, size_t capacity, const char *format, ...)
{
    va_list args;
    int length;
    va_start(args, format);
    length = vsnprintf(output, capacity, format, args);
    va_end(args);
    assert(length >= 0 && (size_t)length < capacity);
}

int mgs_fprintf(int channel, const char *format, ...)
{
    va_list args;
    int result;
    assert(channel == 2);
    va_start(args, format);
    result = vprintf(format, args);
    va_end(args);
    return result;
}

#include "camera_card_helpers.inc"

static void CheckWorker(const CameraCardFixture *fixture)
{
    const int *input = fixture->initial;
    unsigned int after;
    int port, entry;
    camera_dword_800C342C = input[0];
    camera_dword_800C3430 = input[1];
    camera_dword_800C3434 = input[2];
    camera_dword_800C3880 = input[3];
    camera_dword_800C3884 = input[4];
    camera_dword_800D0728 = input[5];
    camera_dword_800D0734 = input[6];
    camera_dword_800D0738 = input[7];
    camera_dword_800D073C = input[8];
    camera_dword_800D0740[0] = input[9];
    camera_dword_800D0740[1] = input[10];
    memset(camera_dword_800D0748, 0, sizeof(camera_dword_800D0748));
    memset(cards, 0, sizeof(cards));
    for (port = 0; port < 2; ++port)
    {
        cards[port].port = port;
        cards[port].file_count = MEMCARD_BLOCK_MAX;
        cards[port].free_blocks = fixture->free_blocks;
        for (entry = 0; entry < MEMCARD_BLOCK_MAX; ++entry)
            snprintf(cards[port].files[entry].name, sizeof(cards[port].files[entry].name),
                     "PHOTO%d%02d", port, entry);
    }
    cursor = fixture->first;
    end = cursor + fixture->count;
    camera_800C4D70();
    after = StateHash();
    assert(cursor == end);
    if (after != fixture->after)
        printf("Camera worker case %u: final state %08x/%08x\n", (unsigned int)current_case, after,
               fixture->after);
    assert(after == fixture->after);
}

static void CheckWriter(const CameraWriterFixture *fixture)
{
    DATA_INFO data = {0};
    unsigned int result, body, filename;
    int i;
    const int *input = fixture->input;
    writer = fixture;
    memset(cards, 0, sizeof(cards));
    cards[0].port = input[1];
    cards[0].file_count = input[12];
    cards[0].free_blocks = 15 - input[12];
    for (i = 0; i < input[12]; ++i)
    {
        memcpy(cards[0].files[i].name, fixture->collision, 20);
        cards[0].files[i].name[19] = 'A' + i;
    }
    data.blocks_count = input[0];
    data.field_0[0] = input[2];
    data.field_0[1] = input[3];
    data.field_2 = input[4];
    data.make_title = MakeTitle;
    data.make_game_data = MakeGameData;
    camera_dword_800D072C = &data;
    GM_ClearFlag = input[5];
    GM_Disk = input[6];
    GM_PlayTimeHours = input[7];
    GM_PlayTimeSeconds = input[8];
    GM_PadResetDisable = 13;
    memset(file_buffer, 0xa5, sizeof(file_buffer));
    memset(camera_dword_800C37F8, 0xa5, sizeof(camera_dword_800C37F8));
    write_attempts = status_polls = 0;
    writer_trace = 2166136261u;
    result = CameraWriteActual(&cards[0]);
    body = HashBytes(2166136261u, file_buffer, input[0] * MEMCARD_BLOCK_SIZE);
    filename = HashBytes(2166136261u, camera_dword_800C37F8, sizeof(camera_dword_800C37F8));
    if (result != fixture->result || body != fixture->body || filename != fixture->filename ||
        writer_trace != fixture->calls)
    {
        printf("Camera writer case %u: result %u/%u; body %08x/%08x; filename %08x/%08x; calls "
               "%08x/%08x\n",
               (unsigned int)current_case, result, fixture->result, body, fixture->body, filename,
               fixture->filename, writer_trace, fixture->calls);
        abort();
    }
    assert((unsigned int)GM_PadResetDisable == fixture->locked);
}

static void CheckAllocationFailure(void)
{
    DATA_INFO data = {0};
    data.blocks_count = 1;
    camera_dword_800D072C = &data;
    allocation_failure = 1;
    write_attempts = 0;
    assert(CameraWriteActual(&cards[0]) == 0);
    assert(GM_PadResetDisable == 0);
    assert(write_attempts == 0);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    for (current_case = 0;
         current_case < sizeof(CameraCardFixtures) / sizeof(CameraCardFixtures[0]); ++current_case)
        CheckWorker(&CameraCardFixtures[current_case]);
    assert(cooperative_waits == 384);
    printf("Camera worker: %u original MIPS state/call fixtures passed, %u cooperative waits "
           "checked\n",
           (unsigned int)current_case, cooperative_waits);
    for (current_case = 0;
         current_case < sizeof(CameraWriterFixtures) / sizeof(CameraWriterFixtures[0]);
         ++current_case)
        CheckWriter(&CameraWriterFixtures[current_case]);
    printf("Camera writer: %u original MIPS payload/call fixtures passed\n",
           (unsigned int)current_case);
    CheckAllocationFailure();
    return 0;
}
