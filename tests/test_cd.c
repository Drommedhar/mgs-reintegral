#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <libcd.h>
#include <psyz.h>

extern void Psyz_CdVBlank(void);

enum { RAW_SECTOR_BYTES = 2352 };
static unsigned int callback_count;
static unsigned int callback_limit;
static unsigned int callback_errors;
static unsigned int expected_sector;

static void make_sector(unsigned int number, unsigned char *data)
{
    CdlLOC location;
    for (unsigned int i = 0; i < RAW_SECTOR_BYTES; ++i)
        data[i] = (unsigned char)(number * 17 + i);
    CdIntToPos((int)number, &location);
    memcpy(data + 12, &location, 3);
    data[15] = 2;
}

static int short_read(struct PsyzCdRead *read)
{
    (void)read;
    return 100;
}

static void begin_read(unsigned int sector, unsigned char mode)
{
    CdlLOC location;
    CdIntToPos((int)sector, &location);
    assert(CdControl(CdlSetmode, &mode, NULL));
    assert(CdControl(CdlReadN, (unsigned char *)&location, NULL));
}

static void sector_ready(unsigned char status, unsigned char *result)
{
    unsigned char header[12];
    CdlLOC location;
    if (status == CdlDiskError)
    {
        assert(result[0] & CdlStatError);
        ++callback_errors;
        return;
    }
    assert(status == CdlDataReady);
    assert(CdGetSector(header, 3));
    memcpy(&location, header, sizeof(location));
    assert(CdPosToInt(&location) == (int)expected_sector++);
    ++callback_count;
    if (callback_count == callback_limit)
        assert(CdControl(CdlPause, NULL, NULL));
}

static void check_fifo(void)
{
    unsigned char expected[RAW_SECTOR_BYTES];
    unsigned char received[RAW_SECTOR_BYTES];
    make_sector(0, expected);
    begin_read(0, CdlModeSize1);
    assert(CdReady(1, NULL) == CdlDataReady);
    assert(!CdGetSector(received, INT_MAX));
    assert(CdGetSector(received, 3));
    assert(CdGetSector(received + 12, 512));
    assert(CdGetSector2(received + 2060, 70));
    assert(memcmp(received, expected + 12, 2340) == 0);
    assert(!CdGetSector(received, 1));
    assert(CdDataSync(0) == 0);

    begin_read(0, 0);
    assert(CdReady(1, NULL) == CdlDataReady);
    assert(CdGetSector(received, 512));
    assert(memcmp(received, expected + 24, 2048) == 0);

    begin_read(0, CdlModeSize0);
    assert(CdReady(1, NULL) == CdlDataReady);
    assert(CdGetSector(received, 582));
    assert(memcmp(received, expected + 24, 2328) == 0);
}

static void check_callbacks(void)
{
    callback_count = 0;
    callback_limit = 3;
    expected_sector = 0;
    CdReadyCallback(sector_ready);
    begin_read(0, CdlModeSize1 | CdlModeSpeed);
    for (int i = 0; i < 3; ++i)
        Psyz_CdVBlank();
    assert(callback_count == 3 && callback_errors == 0);

    begin_read(4, CdlModeSize1);
    Psyz_CdVBlank();
    Psyz_CdVBlank();
    assert(callback_errors == 1);

    Psyz_CdSetReadCB(short_read);
    begin_read(0, CdlModeSize1);
    Psyz_CdVBlank();
    Psyz_CdVBlank();
    assert(callback_errors == 2);
    Psyz_CdSetReadCB(NULL);
    CdReadyCallback(NULL);
}

static void write_fixture(const char *binary_path, const char *cue_path)
{
    unsigned char sector[RAW_SECTOR_BYTES];
    FILE *file = fopen(binary_path, "wb");
    assert(file != NULL);
    for (unsigned int i = 0; i < 4; ++i)
    {
        make_sector(i, sector);
        assert(fwrite(sector, 1, sizeof(sector), file) == sizeof(sector));
    }
    assert(fclose(file) == 0);
    file = fopen(cue_path, "wb");
    assert(file != NULL);
    assert(fputs("FILE \"disc.bin\" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n", file) >= 0);
    assert(fclose(file) == 0);
}

static unsigned char xa_coding;

static int stream_sector(struct PsyzCdRead *read)
{
    unsigned char *data = read->buffer;
    memset(data, 0, RAW_SECTOR_BYTES);
    data[15] = 2;
    if (read->sector == 1) {
        data[16] = 1;
        data[17] = 1;
        data[18] = 0x64;
        data[19] = xa_coding;
        for (unsigned block = 0; block < 18; ++block) {
            unsigned char *adpcm = data + 24 + block * 128;
            memset(adpcm + 4, 12, 8);
            memset(adpcm + 16, 0x11, 112);
        }
    } else if (read->sector < 7) {
        unsigned chunk = read->sector > 1 ? read->sector - 1 : 0;
        StHEADER header = {0};
        header.id = 0x160;
        header.type = 0x8001;
        header.secCount = (unsigned short)(chunk % 2);
        header.nSectors = 2;
        header.frameCount = chunk / 2 + 1;
        header.frameSize = 4032;
        header.width = 320;
        header.height = 160;
        memcpy(data + 24, &header, sizeof(header));
        memset(data + 56, (int)chunk + 1, 2016);
    }
    return RAW_SECTOR_BYTES;
}

static void check_streaming(unsigned char coding)
{
    static u_long ring[6 * 2048 / sizeof(u_long)];
    u_long *data, *raw_header;
    short audio[10000];
    CdlLOC location;
    assert(Psyz_AudioInit() == 0);
    Psyz_AudioLock();
    xa_coding = coding;
    Psyz_CdSetReadCB(stream_sector);
    StSetRing(ring, 6);
    StSetStream(0, 0, UINT_MAX, NULL, NULL);
    CdIntToPos(0, &location);
    assert(CdControl(CdlSetloc, (unsigned char *)&location, NULL));
    assert(CdRead2(CdlModeStream2 | CdlModeSpeed | CdlModeRT));
    Psyz_CdVBlank();
    assert(StGetNext(&data, &raw_header) == 1);
    assert(Psyz_CdPullSamples(audio, 512) == 512);
    assert(audio[100] != 0);
    size_t samples = 512 + Psyz_CdPullSamples(audio, 5000);
    if (coding & 4)
        assert(samples >= 4702 && samples <= 4706);
    else
        assert(samples >= 2351 && samples <= 2354);
    assert(Psyz_CdPullSamples(audio, 5000) == 0);
    Psyz_CdVBlank();
    for (unsigned frame = 1; frame <= 2; ++frame) {
        assert(StGetNext(&data, &raw_header) == 0);
        StHEADER *header = (StHEADER *)raw_header;
        assert(header->frameCount == frame && header->nSectors == 2);
        assert(((unsigned char *)data)[0] == frame * 2 - 1);
        assert(((unsigned char *)data)[2016] == frame * 2);
        assert(StFreeRing(data) == 0);
    }
    Psyz_CdVBlank();
    assert(StGetNext(&data, &raw_header) == 0);
    assert(((StHEADER *)raw_header)->frameCount == 3);
    assert(((unsigned char *)data)[0] == 5 && ((unsigned char *)data)[2016] == 6);
    assert(StFreeRing(data) == 0);
    assert(CdControl(CdlPause, NULL, NULL));
    StUnSetRing();
    Psyz_CdSetReadCB(NULL);
    Psyz_AudioUnlock();
    Psyz_AudioDestroy();
}

int main(void)
{
    char temp[MAX_PATH];
    char directory[MAX_PATH];
    char binary_path[MAX_PATH + 16];
    char cue_path[MAX_PATH + 16];
    assert(GetTempPathA(sizeof(temp), temp) > 0);
    assert(GetTempFileNameA(temp, "mgc", 0, directory));
    assert(DeleteFileA(directory));
    assert(CreateDirectoryA(directory, NULL));
    assert(snprintf(binary_path, sizeof(binary_path), "%s/disc.bin", directory) > 0);
    assert(snprintf(cue_path, sizeof(cue_path), "%s/disc.cue", directory) > 0);
    write_fixture(binary_path, cue_path);
    assert(Psyz_CdSetDiskPath(cue_path) == 0);
    assert(CdInit());
    check_fifo();
    check_callbacks();
    check_streaming(1);
    check_streaming(5);
    assert(CdReset(0));
    assert(Psyz_CdSetDiskPath(NULL) == 0);
    assert(DeleteFileA(binary_path));
    assert(DeleteFileA(cue_path));
    assert(RemoveDirectoryA(directory));
    puts("CD FIFO/callback tests passed.");
    return 0;
}
