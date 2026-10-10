#include "mgs_input_log.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(condition) Check((condition), #condition, __LINE__)

static const char identity[] = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
static const char *path;
static unsigned checks;

static void Check(int condition, const char *expression, int line)
{
    ++checks;
    if (!condition)
    {
        fprintf(stderr, "Input log test line %d: %s\n", line, expression);
        exit(EXIT_FAILURE);
    }
}

static MgsInputSample Sample(unsigned index)
{
    static const unsigned kinds[] = {0x41, 0x53, 0x73, 0xff};
    MgsInputSample sample = {0};
    unsigned port, byte, field;
    sample.sample = index;
    sample.vsync = index / 2;
    sample.kinds[0] = kinds[index % 4];
    sample.kinds[1] = kinds[(index + 1) % 4];
    for (port = 0; port < 2; ++port)
        for (byte = 0; byte < MGS_INPUT_PAD_BYTES; ++byte)
            sample.pads[port][byte] = (unsigned char)(index * 34 + byte + port * 91);
    if (index % 2)
        snprintf(sample.stage, sizeof(sample.stage), "aB_012345678901");
    for (field = 0; field < MGS_INPUT_STATE_FIELDS; ++field)
        sample.state[field] = (int)field - 12;
    sample.state[0] = INT_MIN;
    sample.state[1] = INT_MAX;
    return sample;
}

static void SameSample(const MgsInputSample *actual, const MgsInputSample *expected)
{
    CHECK(actual->sample == expected->sample);
    CHECK(actual->vsync == expected->vsync);
    CHECK(memcmp(actual->kinds, expected->kinds, sizeof(actual->kinds)) == 0);
    CHECK(memcmp(actual->pads, expected->pads, sizeof(actual->pads)) == 0);
    CHECK(strcmp(actual->stage, expected->stage) == 0);
    CHECK(memcmp(actual->state, expected->state, sizeof(actual->state)) == 0);
}

static void RoundTrip(void)
{
    MgsInputLog writer = {0}, reader = {0}, duplicate = {0};
    MgsInputSample sample;
    unsigned i;
    CHECK(MgsInputLogOpenWrite(&writer, path, identity));
    for (i = 0; i < 8; ++i)
    {
        sample = Sample(i);
        CHECK(MgsInputLogWriteSample(&writer, &sample));
    }
    sample = Sample(8);
    sample.vsync = UINT_MAX;
    CHECK(MgsInputLogWriteEnd(&writer, &sample));
    CHECK(MgsInputLogClose(&writer));
    CHECK(!MgsInputLogOpenWrite(&duplicate, path, identity));
    CHECK(MgsInputLogError(&duplicate)[0] != '\0');
    CHECK(MgsInputLogOpenRead(&reader, path, identity));
    for (i = 0; i <= 8; ++i)
    {
        MgsInputSample expected = Sample(i);
        if (i == 8)
            expected.vsync = UINT_MAX;
        CHECK(MgsInputLogReadNext(&reader, &sample) == (i == 8 ? 2 : 1));
        SameSample(&sample, &expected);
    }
    CHECK(reader.count == 8);
    CHECK(MgsInputLogClose(&reader));
}

static size_t Load(char *buffer, size_t capacity)
{
    FILE *file = fopen(path, "rb");
    size_t size;
    CHECK(file != NULL);
    size = fread(buffer, 1, capacity - 1, file);
    CHECK(!ferror(file));
    CHECK(feof(file));
    CHECK(fclose(file) == 0);
    buffer[size] = '\0';
    return size;
}

static void Store(const char *buffer, size_t size)
{
    FILE *file = fopen(path, "wb");
    CHECK(file != NULL);
    CHECK(fwrite(buffer, 1, size, file) == size);
    CHECK(fclose(file) == 0);
}

static void Reject(const char *buffer, size_t size)
{
    MgsInputLog log = {0};
    MgsInputSample sample, before;
    unsigned count;
    Store(buffer, size);
    if (MgsInputLogOpenRead(&log, path, identity))
    {
        for (count = 0; count < 10; ++count)
        {
            int type;
            memset(&sample, 0xa5, sizeof(sample));
            before = sample;
            type = MgsInputLogReadNext(&log, &sample);
            CHECK(type != 2);
            if (!type)
            {
                CHECK(memcmp(&sample, &before, sizeof(sample)) == 0);
                break;
            }
        }
        CHECK(count < 10);
        CHECK(!MgsInputLogClose(&log));
    }
    CHECK(MgsInputLogError(&log)[0] != '\0');
}

static char *Line(char *text, unsigned number)
{
    while (number--)
    {
        text = strchr(text, '\n');
        CHECK(text != NULL);
        ++text;
    }
    return text;
}

static void Replace(char *text, unsigned line, unsigned token, const char *replacement)
{
    char *start = Line(text, line);
    char *end;
    size_t size;
    while (token--)
    {
        start = strchr(start, ' ');
        CHECK(start != NULL);
        ++start;
    }
    end = start + strcspn(start, " \n");
    size = strlen(replacement);
    memmove(start + size, end, strlen(end) + 1);
    memcpy(start, replacement, size);
}

static void BadTokens(const char *valid)
{
    static const struct
    {
        unsigned line, token;
        const char *value;
    } cases[] = {
        {0, 0, "WRONG"}, {0, 1, "2"}, {0, 2, "abc"},
        {1, 0, "Q"}, {1, 0, "PP"}, {1, 1, "1"}, {2, 1, "0"},
        {1, 1, "4294967296"}, {1, 1, "-1"}, {1, 2, "999999999999999999999"},
        {1, 2, "+0"}, {1, 2, "0x1"}, {1, 3, "0"}, {1, 4, "18"},
        {1, 4, "150"}, {1, 3, "4294967296"}, {1, 3, "-65"},
        {1, 5, "00"}, {1, 6, "abcdef"}, {1, 7, "name-with-dash"},
        {1, 7, "0123456789abcdef"}, {1, 7, "stage/other"},
        {1, 8, "2147483648"}, {1, 8, "-2147483649"}, {1, 8, "-"},
        {1, 8, "999999999999999999999"}, {1, 8, "12x"},
        {1, 29, "-999999999999999999999"}, {1, 29, "0 extra"},
        {9, 1, "7"}, {9, 1, "9"}, {9, 2, "0"}, {9, 0, "P"}
    };
    size_t i;
    for (i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i)
    {
        char text[8192];
        snprintf(text, sizeof(text), "%s", valid);
        Replace(text, cases[i].line, cases[i].token, cases[i].value);
        Reject(text, strlen(text));
    }
}

static void Truncation(const char *valid, size_t size)
{
    char text[8192];
    char *first;
    unsigned i;
    for (i = 0; i <= 9; ++i)
    {
        snprintf(text, sizeof(text), "%s", valid);
        Reject(text, (size_t)(Line(text, i) - text));
    }
    Reject(valid, size - 1);
    snprintf(text, sizeof(text), "%sx", valid);
    Reject(text, strlen(text));
    snprintf(text, sizeof(text), "%s\n", valid);
    Reject(text, strlen(text));
    snprintf(text, sizeof(text), "%s", valid);
    first = Line(text, 1);
    first[10] = '\0';
    Reject(text, size);
    snprintf(text, sizeof(text), "%s", valid);
    first = Line(text, 1);
    memset(first, '0', 600);
    first[600] = '\n';
    Reject(text, 601 + (size_t)(first - text));
}

static void CorruptFields(const char *valid)
{
    char text[8192];
    char *field;
    snprintf(text, sizeof(text), "%s", valid);
    text[11] = 'A';
    Reject(text, strlen(text));
    snprintf(text, sizeof(text), "%s", valid);
    field = Line(text, 1);
    field[12] = 'g';
    Reject(text, strlen(text));
    snprintf(text, sizeof(text), "%s", valid);
    field = strchr(Line(text, 1), '\n');
    CHECK(field != NULL);
    memmove(field - 2, field, strlen(field) + 1);
    Reject(text, strlen(text));
    snprintf(text, sizeof(text), "%s", valid);
    Replace(text, 4, 2, "0");
    Reject(text, strlen(text));
}

static void EmptyAndCrLf(void)
{
    char text[1024], crlf[2048];
    size_t i, output = 0, size;
    MgsInputLog log = {0};
    MgsInputSample sample = Sample(0), actual;
    sample.vsync = UINT_MAX;
    snprintf(sample.stage, sizeof(sample.stage), "aB_012345678901");
    for (i = 0; i < MGS_INPUT_STATE_FIELDS; ++i)
        sample.state[i] = INT_MIN;
    CHECK(remove(path) == 0);
    CHECK(MgsInputLogOpenWrite(&log, path, identity));
    CHECK(MgsInputLogWriteEnd(&log, &sample));
    CHECK(MgsInputLogClose(&log));
    size = Load(text, sizeof(text));
    for (i = 0; i < size; ++i)
    {
        if (text[i] == '\n')
            crlf[output++] = '\r';
        crlf[output++] = text[i];
    }
    Store(crlf, output);
    CHECK(MgsInputLogOpenRead(&log, path, identity));
    CHECK(MgsInputLogReadNext(&log, &actual) == 2);
    SameSample(&actual, &sample);
    CHECK(MgsInputLogClose(&log));
}

static void WriterFailures(void)
{
    MgsInputLog log = {0};
    MgsInputSample sample;
    unsigned i;
    for (i = 0; i < 6; ++i)
    {
        CHECK(remove(path) == 0);
        CHECK(MgsInputLogOpenWrite(&log, path, identity));
        sample = Sample(0);
        if (i == 0)
            sample.sample = 1;
        else if (i == 1)
            sample.kinds[1] = 0;
        else if (i == 2)
            memset(sample.stage, 'a', sizeof(sample.stage));
        else if (i == 3)
            sample.stage[0] = '-';
        else if (i == 4)
        {
            CHECK(MgsInputLogWriteSample(&log, &sample));
            sample = Sample(1);
            sample.vsync = 9;
            CHECK(MgsInputLogWriteSample(&log, &sample));
            sample = Sample(2);
        }
        if (i < 5)
            CHECK(!MgsInputLogWriteSample(&log, &sample));
        CHECK(!MgsInputLogClose(&log));
        CHECK(MgsInputLogError(&log)[0] != '\0');
    }
}

static void BadIdentity(void)
{
    MgsInputLog log = {0};
    char changed[65];
    snprintf(changed, sizeof(changed), "%s", identity);
    changed[0] = 'f';
    CHECK(!MgsInputLogOpenRead(&log, path, changed));
    CHECK(log.file == NULL);
    changed[0] = 'F';
    CHECK(!MgsInputLogOpenRead(&log, path, changed));
    CHECK(!MgsInputLogOpenWrite(&log, path, "short"));
}

static void ReadWhileWriting(void)
{
    MgsInputLog writer = {0}, reader = {0};
    MgsInputSample first = Sample(0), second = Sample(1), actual;
    CHECK(remove(path) == 0);
    CHECK(MgsInputLogOpenWrite(&writer, path, identity));
    CHECK(MgsInputLogWriteSample(&writer, &first));
    CHECK(MgsInputLogOpenRead(&reader, path, identity));
    CHECK(MgsInputLogReadNext(&reader, &actual) == 1);
    SameSample(&actual, &first);
    CHECK(MgsInputLogWriteSample(&writer, &second));
    CHECK(MgsInputLogReadNext(&reader, &actual) == 1);
    SameSample(&actual, &second);
    second = Sample(2);
    CHECK(MgsInputLogWriteEnd(&writer, &second));
    CHECK(MgsInputLogReadNext(&reader, &actual) == 2);
    SameSample(&actual, &second);
    CHECK(MgsInputLogClose(&reader));
    CHECK(MgsInputLogClose(&writer));
}

int main(int argc, char **argv)
{
    char valid[8192];
    size_t size;
    path = argc > 1 ? argv[1] : "mgs-input-log-test.tmp";
    RoundTrip();
    size = Load(valid, sizeof(valid));
    BadIdentity();
    BadTokens(valid);
    Truncation(valid, size);
    CorruptFields(valid);
    EmptyAndCrLf();
    WriterFailures();
    ReadWhileWriting();
    CHECK(remove(path) == 0);
    printf("Input log tests passed: %u checks\n", checks);
    return 0;
}
