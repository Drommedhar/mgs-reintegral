#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "mgs_safety.h"

#undef fprintf

enum { SECTOR_BYTES = 2352, DATA_BYTES = 2048, PATH_BYTES = 4096 };

typedef struct {
    uint32_t sector;
    uint32_t size;
} DiscEntry;

typedef struct {
    FILE *file;
    uint32_t sectors;
} DiscImage;

static char image_path[PATH_BYTES];
static DiscEntry stage_file;
static uint32_t image_sectors;
static int disc_number;

static int Fail(const char *reason)
{
    fprintf(stderr, "[native] Disc validation failed: %s\n", reason);
    return -1;
}

static uint32_t Little32(const unsigned char *data)
{
    return data[0] | (uint32_t)data[1] << 8 | (uint32_t)data[2] << 16 | (uint32_t)data[3] << 24;
}

static int Both32(const unsigned char *data, uint32_t *value)
{
    *value = Little32(data);
    return *value == ((uint32_t)data[4] << 24 | (uint32_t)data[5] << 16 |
                      (uint32_t)data[6] << 8 | data[7]);
}

static int Bcd(int value)
{
    return (value / 10) * 16 + value % 10;
}

static int ReadSector(DiscImage *image, uint32_t sector, unsigned char *data)
{
    static const unsigned char sync[12] = {0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0};
    unsigned char raw[SECTOR_BYTES];
    uint32_t position = sector + 150;
    if (sector >= image->sectors ||
        _fseeki64(image->file, (int64_t)sector * SECTOR_BYTES, SEEK_SET) != 0 ||
        fread(raw, 1, sizeof(raw), image->file) != sizeof(raw))
        return Fail("sector is missing or unreadable");
    if (memcmp(raw, sync, sizeof(sync)) != 0 || raw[15] != 2 ||
        raw[12] != Bcd(position / 4500) || raw[13] != Bcd(position / 75 % 60) ||
        raw[14] != Bcd(position % 75) || memcmp(raw + 16, raw + 20, 4) != 0 || (raw[18] & 0x20))
        return Fail("expected a MODE2 Form1 sector with matching address and XA headers");
    memcpy(data, raw + 24, DATA_BYTES);
    return 0;
}

static int OpenImage(const char *path, DiscImage *image)
{
    int64_t size;
    image->file = fopen(path, "rb");
    if (!image->file)
        return Fail("cannot open the configured BIN image");
    size = _fseeki64(image->file, 0, SEEK_END) == 0 ? _ftelli64(image->file) : -1;
    if (size < 17 * SECTOR_BYTES || size % SECTOR_BYTES || size / SECTOR_BYTES > 449850) {
        fclose(image->file);
        image->file = NULL;
        return Fail("BIN image length is not a supported complete raw-sector disc");
    }
    image->sectors = (uint32_t)(size / SECTOR_BYTES);
    return 0;
}

static int Entry(const unsigned char *record, size_t available, const DiscImage *image, DiscEntry *entry)
{
    if (available < 34 || record[0] < 34 || record[0] > available ||
        33u + record[32] > record[0] || record[1] || (record[25] & ~3u) ||
        record[26] || record[27] || record[28] != 1 || record[29] || record[30] || record[31] != 1 ||
        !Both32(record + 2, &entry->sector) || !Both32(record + 10, &entry->size) ||
        entry->sector >= image->sectors ||
        ((uint64_t)entry->size + DATA_BYTES - 1) / DATA_BYTES > image->sectors - entry->sector)
        return Fail("invalid ISO9660 directory record or file extent");
    return 0;
}

static int FindEntry(DiscImage *image, DiscEntry directory, const char *name, int is_directory, DiscEntry *entry)
{
    unsigned char data[DATA_BYTES];
    size_t name_size = strlen(name);
    if (directory.size > 4 * 1024 * 1024)
        return Fail("ISO9660 directory exceeds the supported size");
    for (uint32_t block = 0; block < directory.size; block += DATA_BYTES) {
        uint32_t available = directory.size - block;
        if (available > DATA_BYTES)
            available = DATA_BYTES;
        if (ReadSector(image, directory.sector + block / DATA_BYTES, data) != 0)
            return -1;
        for (uint32_t offset = 0; offset < available && data[offset]; offset += data[offset]) {
            DiscEntry candidate;
            const unsigned char *record = data + offset;
            if (Entry(record, available - offset, image, &candidate) != 0)
                return -1;
            if (record[32] == name_size && memcmp(record + 33, name, name_size) == 0) {
                if (!!(record[25] & 2) != is_directory)
                    return Fail("ISO9660 entry has the wrong file type");
                *entry = candidate;
                return 0;
            }
        }
    }
    return Fail("required Integral file is absent from the disc");
}

static int ReadCue(const char *path, char *binary_path)
{
    char line[PATH_BYTES], filename[PATH_BYTES] = {0};
    FILE *cue = fopen(path, "rb");
    int phase = 0, invalid = 0;
    if (!cue)
        return Fail("cannot open the CUE file");
    while (fgets(line, sizeof(line), cue)) {
        char *text = line;
        size_t length = strlen(text);
        while (length && (text[length - 1] == '\r' || text[length - 1] == '\n' || text[length - 1] == ' '))
            text[--length] = 0;
        while (*text == ' ' || *text == '\t')
            ++text;
        if (!*text || strncmp(text, "REM ", 4) == 0)
            continue;
        if (phase == 0 && strncmp(text, "FILE \"", 6) == 0) {
            char *end = strchr(text + 6, '"');
            if (!end || strcmp(end, "\" BINARY") != 0 || end == text + 6) { invalid = 1; break; }
            *end = 0;
            if (strpbrk(text + 6, "/\\:") || strcmp(text + 6, ".") == 0 || strcmp(text + 6, "..") == 0) {
                invalid = 1; break;
            }
            memcpy(filename, text + 6, (size_t)(end - text - 6) + 1);
        } else if ((phase == 1 && strcmp(text, "TRACK 01 MODE2/2352") == 0) ||
                   (phase == 2 && strcmp(text, "INDEX 01 00:00:00") == 0)) {
            /* The supported Integral images contain one data track. */
        } else { invalid = 1; break; }
        ++phase;
    }
    invalid |= ferror(cue) != 0;
    invalid |= fclose(cue) != 0;
    if (invalid || phase != 3)
        return Fail("CUE must contain one local BIN and one MODE2/2352 track starting at zero");
    const char *slash = strrchr(path, '/'), *backslash = strrchr(path, '\\');
    const char *last = !slash || (backslash && backslash > slash) ? backslash : slash;
    size_t prefix = last ? (size_t)(last - path) + 1 : 0;
    if (prefix + strlen(filename) >= PATH_BYTES)
        return Fail("CUE image path is too long");
    memcpy(binary_path, path, prefix);
    memcpy(binary_path + prefix, filename, strlen(filename) + 1);
    return 0;
}

static int ValidateDisc(DiscImage *image, DiscEntry *stage)
{
    unsigned char data[DATA_BYTES];
    DiscEntry root, mgs, system, executable;
    uint32_t volume_size;
    const char *serial = NULL;
    if (ReadSector(image, 16, data) != 0)
        return -1;
    if (memcmp(data, "\1CD001\1", 7) != 0 ||
        !Both32(data + 80, &volume_size) || !volume_size || volume_size > image->sectors ||
        memcmp(data + 128, "\0\10\10\0", 4) != 0)
        return Fail("invalid ISO9660 primary volume descriptor");
    if (!(data[181] & 2))
        return Fail("ISO9660 root record is not a directory");
    if (Entry(data + 156, DATA_BYTES - 156, image, &root) != 0 ||
        FindEntry(image, root, "MGS", 1, &mgs) != 0 ||
        FindEntry(image, root, "SYSTEM.CNF;1", 0, &system) != 0)
        return -1;
    if (!system.size || system.size >= DATA_BYTES || ReadSector(image, system.sector, data) != 0)
        return Fail("invalid SYSTEM.CNF extent");
    data[system.size] = 0;
    if (strstr((char *)data, "SLPM_862.47;1")) serial = "SLPM_862.47;1";
    else if (strstr((char *)data, "SLPM_862.48;1")) serial = "SLPM_862.48;1";
    if (!serial)
        return Fail("expected Metal Gear Solid Integral disc 1 or disc 2");
    if (FindEntry(image, mgs, serial, 0, &executable) != 0 ||
        FindEntry(image, mgs, "STAGE.DIR;1", 0, stage) != 0 ||
        ReadSector(image, executable.sector, data) != 0)
        return -1;
    if (executable.size < DATA_BYTES || memcmp(data, "PS-X EXE", 8) != 0 ||
        (uint64_t)Little32(data + 28) + DATA_BYTES > executable.size)
        return Fail("Integral boot executable has an invalid PS-X EXE header");
    printf("[native] Validated %s, STAGE.DIR at sector %u (%u bytes).\n", serial, stage->sector, stage->size);
    disc_number = strcmp(serial, "SLPM_862.47;1") == 0 ? 1 : 2;
    return 0;
}

int MgsSafetyConfigure(const char *cue_path)
{
    DiscImage image;
    DiscEntry stage;
    char path[PATH_BYTES];
    int result;
    image_path[0] = 0;
    disc_number = 0;
    if (!cue_path)
        return Fail("launcher did not supply a CUE path");
    if (ReadCue(cue_path, path) != 0 || OpenImage(path, &image) != 0)
        return -1;
    result = ValidateDisc(&image, &stage);
    if (fclose(image.file) != 0)
        return Fail("cannot close the validated BIN image");
    if (result != 0)
        return result;
    stage_file = stage;
    image_sectors = image.sectors;
    memcpy(image_path, path, strlen(path) + 1);
    return 0;
}

int MgsSafetyDiscNumber(void)
{
    return disc_number;
}

static int ValidateStageTable(DiscImage *image)
{
    unsigned char data[DATA_BYTES];
    uint32_t size;
    if (stage_file.size < DATA_BYTES)
        return Fail("STAGE.DIR is shorter than its directory sector");
    if (ReadSector(image, stage_file.sector, data) != 0)
        return -1;
    size = Little32(data);
    if (!size || size > DATA_BYTES - 4 || size % 12)
        return Fail("STAGE.DIR has an invalid stage table size");
    for (uint32_t offset = 4; offset < size + 4; offset += 12) {
        uint32_t sector = Little32(data + offset + 8);
        int ended = 0;
        if (!data[offset] || !sector || (uint64_t)sector * DATA_BYTES >= stage_file.size)
            return Fail("STAGE.DIR contains an invalid stage extent");
        for (int i = 0; i < 8; ++i) {
            unsigned char c = data[offset + i];
            if (!c) ended = 1;
            else if (ended || !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_'))
                return Fail("STAGE.DIR contains an invalid stage name");
        }
    }
    return 0;
}

int SafetyCheck(int minute, int second, int sector)
{
    DiscImage image;
    /* FS_FILE_STAGE.pos and the original caller's CdIntToPos each add 150. */
    uint32_t expected = stage_file.sector + 300;
    int result;
    if (!image_path[0])
        return Fail("disc validation was not configured by the launcher");
    /* The original disc-change actor checks the volume descriptor at LBA16. */
    if (!(minute == 0 && second == 2 && sector == 0x16) &&
        (minute != Bcd(expected / 4500) || second != Bcd(expected / 75 % 60) || sector != Bcd(expected % 75)))
        return Fail("safety request does not match the original Integral disc position");
    if (OpenImage(image_path, &image) != 0)
        return -1;
    result = image.sectors == image_sectors ? ValidateStageTable(&image) : Fail("BIN image length changed");
    if (fclose(image.file) != 0)
        return Fail("cannot close BIN image after safety validation");
    if (result == 0)
        printf("[native] Disc content safety check passed; physical console SCEx checks do not apply.\n");
    return result;
}
