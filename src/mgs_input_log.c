#include "mgs_input_log.h"

#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

enum {
    INPUT_READ = 1,
    INPUT_WRITE = 2,
    INPUT_LINE_BYTES = 512,
    INPUT_TOKENS = 8 + MGS_INPUT_STATE_FIELDS
};

static int Fail(MgsInputLog *log, const char *message)
{
    if (!log->failed)
        snprintf(log->error, sizeof(log->error), "%s", message);
    log->failed = 1;
    return 0;
}

static int HexDigit(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    return -1;
}

static int IdentityValid(const char *identity)
{
    size_t i;
    if (!identity || strlen(identity) != 64)
        return 0;
    for (i = 0; i < 64; ++i)
        if (HexDigit(identity[i]) < 0)
            return 0;
    return 1;
}

static int StageValid(const char *stage)
{
    size_t i;
    for (i = 0; i < 16; ++i)
    {
        unsigned char c = (unsigned char)stage[i];
        if (!c)
            return 1;
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '_'))
            return 0;
    }
    return 0;
}

static int KindValid(unsigned kind)
{
    return kind == 0x41 || kind == 0x53 || kind == 0x73 || kind == 0xff;
}

static int Ready(MgsInputLog *log, int mode)
{
    if (log->failed)
        return 0;
    if (!log->file || log->mode != mode || log->ended)
        return Fail(log, "Input log is not open for this operation");
    return 1;
}

static int SampleValid(MgsInputLog *log, const MgsInputSample *sample)
{
    if (sample->sample != log->count)
        return Fail(log, "Input sample sequence or footer count mismatch");
    if (sample->vsync < log->last_vsync)
        return Fail(log, "Input VSync moved backwards");
    if (!KindValid(sample->kinds[0]) || !KindValid(sample->kinds[1]))
        return Fail(log, "Unsupported controller kind");
    if (!StageValid(sample->stage))
        return Fail(log, "Invalid input stage name");
    return 1;
}

static int ReadLine(MgsInputLog *log, char line[INPUT_LINE_BYTES])
{
    size_t size = 0;
    int c;
    while ((c = fgetc(log->file)) != '\n')
    {
        if (c == EOF)
            return Fail(log, ferror(log->file) ? "Input read failed" : "Truncated input log");
        if (c == 0 || size == INPUT_LINE_BYTES - 1)
            return Fail(log, "Invalid or overlong input line");
        line[size++] = (char)c;
    }
    if (size && line[size - 1] == '\r')
        --size;
    line[size] = '\0';
    return 1;
}

static int Open(MgsInputLog *log, const char *path, const char *identity, int mode)
{
    if (log->file)
        return Fail(log, "Input log is already open");
    memset(log, 0, sizeof(*log));
    if (!path || !IdentityValid(identity))
        return Fail(log, "Input identity must contain 64 lowercase hexadecimal digits");
    log->file = fopen(path, mode == INPUT_WRITE ? "wbx" : "rb");
    if (!log->file)
    {
        snprintf(log->error, sizeof(log->error), "Cannot open input log: %s", strerror(errno));
        log->failed = 1;
        return 0;
    }
    log->mode = mode;
    return 1;
}

static int OpenFailed(MgsInputLog *log)
{
    fclose(log->file);
    log->file = NULL;
    return 0;
}

int MgsInputLogOpenWrite(MgsInputLog *log, const char *path, const char *identity)
{
    if (!Open(log, path, identity, INPUT_WRITE))
        return 0;
    if (fprintf(log->file, "MGSINPUT 1 %s\n", identity) < 0)
    {
        Fail(log, "Cannot write input header");
        return OpenFailed(log);
    }
    return 1;
}

int MgsInputLogOpenRead(MgsInputLog *log, const char *path, const char *identity)
{
    char line[INPUT_LINE_BYTES];
    char expected[80];
    if (!Open(log, path, identity, INPUT_READ))
        return 0;
    snprintf(expected, sizeof(expected), "MGSINPUT 1 %s", identity);
    if (!ReadLine(log, line))
        return OpenFailed(log);
    if (strcmp(line, expected) != 0)
    {
        Fail(log, "Input header version or identity mismatch");
        return OpenFailed(log);
    }
    return 1;
}

static void PadHex(const unsigned char *pad, char hex[69])
{
    static const char digits[] = "0123456789abcdef";
    unsigned i;
    for (i = 0; i < MGS_INPUT_PAD_BYTES; ++i)
    {
        hex[i * 2] = digits[pad[i] >> 4];
        hex[i * 2 + 1] = digits[pad[i] & 15];
    }
    hex[68] = '\0';
}

static int WriteRecord(MgsInputLog *log, const MgsInputSample *sample, int end)
{
    char pads[2][69];
    int i;
    if (!Ready(log, INPUT_WRITE) || !SampleValid(log, sample))
        return 0;
    if (!end && log->count == UINT_MAX)
        return Fail(log, "Input sample count overflow");
    PadHex(sample->pads[0], pads[0]);
    PadHex(sample->pads[1], pads[1]);
    if (fprintf(log->file, "%c %u %u %u %u %s %s %s", end ? 'E' : 'P',
                sample->sample, sample->vsync, sample->kinds[0], sample->kinds[1],
                pads[0], pads[1], sample->stage[0] ? sample->stage : "-") < 0)
        return Fail(log, "Cannot write input record");
    for (i = 0; i < MGS_INPUT_STATE_FIELDS; ++i)
        if (fprintf(log->file, " %d", sample->state[i]) < 0)
            return Fail(log, "Cannot write input state");
    if (fputc('\n', log->file) == EOF || fflush(log->file) != 0)
        return Fail(log, "Cannot finish input record");
    log->last_vsync = sample->vsync;
    log->ended = end;
    if (!end)
        ++log->count;
    return 1;
}

int MgsInputLogWriteSample(MgsInputLog *log, const MgsInputSample *sample)
{
    return WriteRecord(log, sample, 0);
}

int MgsInputLogWriteEnd(MgsInputLog *log, const MgsInputSample *sample)
{
    return WriteRecord(log, sample, 1);
}

static char *Token(char **cursor)
{
    char *start;
    while (**cursor == ' ')
        ++*cursor;
    if (!**cursor)
        return NULL;
    start = *cursor;
    while (**cursor && **cursor != ' ')
        ++*cursor;
    if (**cursor)
        *(*cursor)++ = '\0';
    return start;
}

static int Decimal(const char *text, int is_signed)
{
    if (is_signed && *text == '-')
        ++text;
    if (!*text)
        return 0;
    do
    {
        if (*text < '0' || *text > '9')
            return 0;
    } while (*++text);
    return 1;
}

static int Unsigned(const char *text, unsigned *out)
{
    unsigned long value;
    if (!Decimal(text, 0))
        return 0;
    errno = 0;
    value = strtoul(text, NULL, 10);
    if (errno == ERANGE || value > UINT_MAX)
        return 0;
    *out = (unsigned)value;
    return 1;
}

static int Signed(const char *text, int *out)
{
    long value;
    if (!Decimal(text, 1))
        return 0;
    errno = 0;
    value = strtol(text, NULL, 10);
    if (errno == ERANGE || value < INT_MIN || value > INT_MAX)
        return 0;
    *out = (int)value;
    return 1;
}

static int ReadPad(const char *text, unsigned char *pad)
{
    unsigned i;
    if (strlen(text) != 68)
        return 0;
    for (i = 0; i < MGS_INPUT_PAD_BYTES; ++i)
    {
        int high = HexDigit(text[i * 2]);
        int low = HexDigit(text[i * 2 + 1]);
        if (high < 0 || low < 0)
            return 0;
        pad[i] = (unsigned char)(high * 16 + low);
    }
    return 1;
}

static int ParseRecord(MgsInputLog *log, char *line, MgsInputSample *sample)
{
    char *tokens[INPUT_TOKENS];
    int i;
    for (i = 0; i < INPUT_TOKENS; ++i)
        if (!(tokens[i] = Token(&line)))
            return Fail(log, "Missing input record field");
    if (Token(&line) || strlen(tokens[0]) != 1 || (tokens[0][0] != 'P' && tokens[0][0] != 'E'))
        return Fail(log, "Invalid input record type or extra field");
    memset(sample, 0, sizeof(*sample));
    if (!Unsigned(tokens[1], &sample->sample) || !Unsigned(tokens[2], &sample->vsync) ||
        !Unsigned(tokens[3], &sample->kinds[0]) || !Unsigned(tokens[4], &sample->kinds[1]))
        return Fail(log, "Invalid unsigned input field");
    if (!ReadPad(tokens[5], sample->pads[0]) || !ReadPad(tokens[6], sample->pads[1]))
        return Fail(log, "Invalid controller bytes");
    if (strcmp(tokens[7], "-") != 0)
    {
        if (strlen(tokens[7]) >= sizeof(sample->stage))
            return Fail(log, "Input stage name is too long");
        snprintf(sample->stage, sizeof(sample->stage), "%s", tokens[7]);
    }
    for (i = 0; i < MGS_INPUT_STATE_FIELDS; ++i)
        if (!Signed(tokens[i + 8], &sample->state[i]))
            return Fail(log, "Invalid signed input state field");
    if (!SampleValid(log, sample))
        return 0;
    return tokens[0][0] == 'P' ? 1 : 2;
}

int MgsInputLogReadNext(MgsInputLog *log, MgsInputSample *sample)
{
    char line[INPUT_LINE_BYTES];
    MgsInputSample parsed;
    int type;
    if (!Ready(log, INPUT_READ) || !ReadLine(log, line))
        return 0;
    type = ParseRecord(log, line, &parsed);
    if (!type)
        return 0;
    if (type == 2)
    {
        if (fgetc(log->file) != EOF || ferror(log->file))
            return Fail(log, "Trailing data or read failure after input footer");
        log->ended = 1;
    }
    else
    {
        if (log->count == UINT_MAX)
            return Fail(log, "Input sample count overflow");
        ++log->count;
    }
    log->last_vsync = parsed.vsync;
    *sample = parsed;
    return type;
}

int MgsInputLogClose(MgsInputLog *log)
{
    if (!log->file)
        return Fail(log, "Input log is not open");
    if (!log->ended)
        Fail(log, "Input log closed without a verified footer");
    if (fclose(log->file) != 0)
        Fail(log, "Cannot close input log");
    log->file = NULL;
    return !log->failed;
}

const char *MgsInputLogError(const MgsInputLog *log)
{
    return log->error;
}
