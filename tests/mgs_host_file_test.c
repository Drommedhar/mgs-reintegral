#include "libsn.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static void check_contents(const char *path)
{
    char data[8] = {0};
    int  file = PCopen(path, 0, 0);
    assert(file >= 0);
    assert(PClseek(file, 0, 2) == 4);
    assert(PClseek(file, -3, 2) == 1);
    assert(PCread(file, data, sizeof(data)) == 3);
    assert(memcmp(data, "\0\xfe\x7f", 3) == 0);
    assert(PCread(file, data, sizeof(data)) == 0);
    assert(PClseek(file, 0, 0) == 0);
    assert(PCread(file, data, sizeof(data)) == 4);
    assert(memcmp(data, "A\0\xfe\x7f", 4) == 0);
    assert(PCwrite(file, "x", 1) == -1);
    assert(PCclose(file) == 0);
    assert(PCclose(file) == -1);
}

static void check_capacity(const char *path)
{
    int files[32], i;
    for (i = 0; i < 32; ++i)
    {
        files[i] = PCopen(path, 0, 0);
        assert(files[i] >= 0);
    }
    assert(PCopen(path, 0, 0) == -1);
    assert(PCcreat(path, 0) == -1);
    assert(PCinit() == 0);
    for (i = 0; i < 32; ++i)
        assert(PCclose(files[i]) == -1);
    check_contents(path);
}

int main(int argc, char **argv)
{
    char data[4];
    int  file;
    assert(argc == 2);
    assert(PCinit() == 0);
    assert(PCopen(NULL, 0, 0) == -1);
    assert(PCopen(argv[1], 3, 0) == -1);
    file = PCcreat(argv[1], 0);
    assert(file >= 0);
    assert(PCwrite(file, "A\0\xfe\x7f", 4) == 4);
    assert(PClseek(file, 0, 0) == 0);
    assert(PCread(file, data, sizeof(data)) == 4);
    assert(memcmp(data, "A\0\xfe\x7f", 4) == 0);
    assert(PCwrite(file, NULL, 1) == -1);
    assert(PCread(file, data, -1) == -1);
    assert(PClseek(file, 0, 3) == -1);
    assert(PCclose(file) == 0);
    check_contents(argv[1]);
    file = PCopen(argv[1], 1, 0);
    assert(file >= 0);
    assert(PCread(file, data, 1) == -1);
    assert(PCwrite(file, "A", 1) == 1);
    assert(PCclose(file) == 0);
    check_capacity(argv[1]);
    assert(PCread(-1, data, 1) == -1);
    assert(PCwrite(32, "A", 1) == -1);
    assert(PClseek(-1, 0, 0) == -1);
    assert(remove(argv[1]) == 0);
    assert(PCopen(argv[1], 0, 0) == -1);
    return 0;
}
