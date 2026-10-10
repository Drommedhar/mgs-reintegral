#include "mgs_mods.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define MOD_PATH_CAPACITY 4096
#define MOD_RESOURCE_LIMIT (16u * 1024u * 1024u)

static char mods_root[MOD_PATH_CAPACITY];
static char mods_stage[9];

int MgsModsConfigure(const char *root)
{
    char canonical[MOD_PATH_CAPACITY];
    struct _stat64 status;

    if (root == NULL)
    {
        mods_root[0] = '\0';
        return 0;
    }
    if (root[0] == '\0' || _fullpath(canonical, root, sizeof(canonical)) == NULL ||
        _stat64(canonical, &status) != 0 || (status.st_mode & _S_IFMT) != _S_IFDIR)
    {
        fprintf(stderr, "Invalid mod directory: %s\n", root);
        return -1;
    }
    memcpy(mods_root, canonical, strlen(canonical) + 1);
    return 0;
}

int MgsModsSetStage(const char *stage)
{
    size_t length;
    size_t index;

    if (stage == NULL)
    {
        fprintf(stderr, "Missing mod stage identity.\n");
        return -1;
    }
    length = strlen(stage);
    if (length == 0 || length >= sizeof(mods_stage))
    {
        fprintf(stderr, "Invalid mod stage identity: %s\n", stage);
        return -1;
    }
    for (index = 0; index < length; ++index)
    {
        const char character = stage[index];
        if (!((character >= 'a' && character <= 'z') ||
              (character >= '0' && character <= '9') || character == '_'))
        {
            fprintf(stderr, "Invalid mod stage identity: %s\n", stage);
            return -1;
        }
    }
    memcpy(mods_stage, stage, length + 1);
    return 0;
}

static int read_override(FILE *file, const char *path, void *data, size_t size)
{
    struct _stat64 status;
    unsigned char *replacement;
    int valid;

    if (_fstat64(_fileno(file), &status) != 0 ||
        (status.st_mode & _S_IFMT) != _S_IFREG || status.st_size != (__int64)size)
    {
        fprintf(stderr, "Mod must be a regular file of exactly %zu bytes: %s\n", size, path);
        fclose(file);
        return -1;
    }
    replacement = malloc(size);
    if (replacement == NULL)
    {
        fprintf(stderr, "Cannot allocate mod resource: %s\n", path);
        fclose(file);
        return -1;
    }
    valid = fread(replacement, 1, size, file) == size && fgetc(file) == EOF && !ferror(file);
    if (fclose(file) != 0)
    {
        valid = 0;
    }
    if (valid)
    {
        memcpy(data, replacement, size);
        printf("[mod] %s (%zu bytes)\n", path, size);
    }
    else
    {
        fprintf(stderr, "Could not read complete mod resource: %s\n", path);
    }
    free(replacement);
    return valid ? 1 : -1;
}

int MgsModsApply(unsigned int id, int extension, void *data, size_t size)
{
    char path[MOD_PATH_CAPACITY];
    int length;
    FILE *file;

    if (mods_root[0] == '\0')
    {
        return 0;
    }
    if (extension == 'b')
    {
        fprintf(stderr, "Compiled stage programs cannot be overridden.\n");
        return -1;
    }
    if (mods_stage[0] == '\0' || id > 0xffffu || extension < 'a' || extension > 'z' ||
        data == NULL || size == 0 || size > MOD_RESOURCE_LIMIT)
    {
        fprintf(stderr, "Invalid mod resource identity, destination or size.\n");
        return -1;
    }
    length = snprintf(path, sizeof(path), "%s/stages/%s/%04x.%c",
                      mods_root, mods_stage, id, extension);
    if (length < 0 || (size_t)length >= sizeof(path))
    {
        fprintf(stderr, "Mod resource path is too long.\n");
        return -1;
    }
    errno = 0;
    file = fopen(path, "rb");
    if (file == NULL)
    {
        if (errno == ENOENT)
        {
            return 0;
        }
        fprintf(stderr, "Cannot open mod resource %s: %s\n", path, strerror(errno));
        return -1;
    }
    return read_override(file, path, data, size);
}
