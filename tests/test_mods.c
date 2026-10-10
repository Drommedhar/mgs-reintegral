#include "mgs_mods.h"

#include <direct.h>
#include <io.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <windows.h>

static int failures;

#define CHECK(expression) check((expression), #expression, __LINE__)

static void check(int passed, const char *expression, int line)
{
    if (!passed)
    {
        fprintf(stderr, "Line %d failed: %s\n", line, expression);
        ++failures;
    }
}

static int write_fixture(const char *path, const char *contents)
{
    FILE *file = fopen(path, "wb");
    int complete;
    if (file == NULL)
    {
        return 0;
    }
    complete = fwrite(contents, 1, strlen(contents), file) == strlen(contents);
    return fclose(file) == 0 && complete;
}

static void test_replacements(const char *root, const char *file_path)
{
    char data[5] = "base";
    char original[5] = {0};
    FILE *file;

    CHECK(MgsModsConfigure(root) == 0);
    CHECK(MgsModsSetStage("s00a") == 0);
    CHECK(MgsModsApply(0x1234, 'k', data, 4) == 0);
    CHECK(memcmp(data, "base", 4) == 0);
    CHECK(write_fixture(file_path, "edit"));
    CHECK(_chmod(file_path, _S_IREAD) == 0);
    CHECK(MgsModsApply(0x1234, 'k', data, 4) == 1);
    CHECK(memcmp(data, "edit", 4) == 0);
    file = fopen(file_path, "rb");
    CHECK(file != NULL);
    if (file != NULL)
    {
        CHECK(fread(original, 1, 4, file) == 4);
        CHECK(fclose(file) == 0);
        CHECK(memcmp(original, "edit", 4) == 0);
    }
    CHECK(_chmod(file_path, _S_IREAD | _S_IWRITE) == 0);
    CHECK(write_fixture(file_path, "wrong size"));
    CHECK(MgsModsApply(0x1234, 'k', data, 4) == -1);
    CHECK(memcmp(data, "edit", 4) == 0);
    CHECK(MgsModsSetStage("init") == 0);
    CHECK(MgsModsApply(0x1234, 'k', data, 4) == 0);
    CHECK(MgsModsSetStage("s00a") == 0);
    CHECK(remove(file_path) == 0);
    CHECK(_mkdir(file_path) == 0);
    CHECK(MgsModsApply(0x1234, 'k', data, 4) == -1);
    CHECK(_rmdir(file_path) == 0);
}

static void test_invalid_inputs(const char *root)
{
    char data[4] = {'b', 'a', 's', 'e'};
    CHECK(MgsModsConfigure(root) == 0);
    CHECK(MgsModsSetStage("../bad") == -1);
    CHECK(MgsModsSetStage("123456789") == -1);
    CHECK(MgsModsSetStage("s00a") == 0);
    CHECK(MgsModsApply(0x1234, 'b', data, 4) == -1);
    CHECK(MgsModsApply(0x10000, 'k', data, 4) == -1);
    CHECK(MgsModsApply(0x1234, '/', data, 4) == -1);
    CHECK(MgsModsApply(0x1234, 'k', NULL, 4) == -1);
    CHECK(MgsModsApply(0x1234, 'k', data, 0) == -1);
    CHECK(MgsModsApply(0x1234, 'k', data, 32u * 1024u * 1024u) == -1);
    CHECK(MgsModsConfigure(NULL) == 0);
    CHECK(MgsModsApply(0x1234, 'k', data, 4) == 0);
    CHECK(memcmp(data, "base", 4) == 0);
    CHECK(MgsModsConfigure("") == -1);
}

int main(void)
{
    char temporary[MAX_PATH];
    char root[MAX_PATH];
    char stages[MAX_PATH];
    char stage[MAX_PATH];
    char file_path[MAX_PATH];

    if (!GetTempPathA(sizeof(temporary), temporary) ||
        !GetTempFileNameA(temporary, "mgs", 0, root) || !DeleteFileA(root) || _mkdir(root) != 0)
    {
        fprintf(stderr, "Could not create isolated mod test directory.\n");
        return 1;
    }
    snprintf(stages, sizeof(stages), "%s/stages", root);
    snprintf(stage, sizeof(stage), "%s/s00a", stages);
    snprintf(file_path, sizeof(file_path), "%s/1234.k", stage);
    CHECK(_mkdir(stages) == 0);
    CHECK(_mkdir(stage) == 0);
    test_replacements(root, file_path);
    test_invalid_inputs(root);
    CHECK(_rmdir(stage) == 0);
    CHECK(_rmdir(stages) == 0);
    CHECK(_rmdir(root) == 0);
    printf("Mod tests: %d failures\n", failures);
    return failures != 0;
}
