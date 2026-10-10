#include "mgs_native.h"
#undef fprintf
#include "mgs_checkpoint.h"
#include "mgs_bonus_items.h"
#include "game/game.h"
#include "libgcl/libgcl.h"
#include "menu/menuman.h"
#include <assert.h>
#include <stdint.h>

RadioMemory radio_memory[RADIO_MEMORY_COUNT];
int gTotalFrameTime, GM_LoadComplete, GM_LoadRequest;
static const char *loaded_stage = "s01a";
static unsigned char saved[0xa40];

int MgsNativeStageAvailable(const char *name) {
    return !strcmp(name, "s01a") || !strcmp(name, "s02a") || !strcmp(name, "title");
}

const char *MgsNativeCurrentStage(void) { return loaded_stage; }

static void SetVariable(int offset, int value) {
    char token[4] = {0x11, 0, (char)(offset >> 8), (char)offset};
    GCL_SetVar(token, value);
}

static int GetVariable(int offset) {
    char token[4] = {0x11, 0, (char)(offset >> 8), (char)offset};
    int type, value;
    GCL_GetVar(token, &type, &value);
    assert(type == GCL_SHORT);
    return value;
}

static uint32_t Crc(const unsigned char *bytes, size_t length) {
    uint32_t crc = UINT32_MAX;
    for (size_t i = 0; i < length; ++i) {
        crc ^= bytes[i];
        for (int bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
    }
    return ~crc;
}

static void WritePayload(const char *path, unsigned char *bytes, size_t length,
                         int recalculate_crc) {
    if (recalculate_crc) {
        uint32_t crc = Crc(bytes + 8, sizeof(saved) - 8);
        memcpy(bytes + 4, &crc, sizeof(crc));
    }
    FILE *file = fopen(path, "wb");
    assert(file);
    assert(fwrite(bytes, 1, length, file) == length);
    assert(fclose(file) == 0);
}

static void SeedMapEntry(void) {
    GCL_InitVar();
    GM_InitArea();
    GM_SetArea(GV_StrCode("s01a"), "s01a");
    GM_SaveArea = GV_StrCode("s01a");
    GM_SaveMap = 0x7df9;
    GM_GameLevel = -1;
    GM_Disk = 1;
    GM_Configuration = 0x107;
    GM_PlayerPosX = -4605;
    GM_PlayerPosY = 469;
    GM_PlayerPosZ = 20452;
    GM_Vitality = GM_VitalityMax = 256;
    GM_Item = GM_Weapon = -1;
    for (int i = 0; i < IT_Max; ++i)
        GM_Items[i] = -1;
    for (int i = 0; i < WP_Max; ++i)
        GM_Weapons[i] = -1;
    GM_Items[IT_Bandana] = 1;
    GM_Weapons[WP_Famas] = 987;
    GM_WeaponsMax[WP_Famas] = 999;
    SetVariable(0x0a, 7);
    SetVariable(0x02, 1024);
    SetVariable(0x03c0, 0x3210);
    radio_memory[0].freq = 14085;
    strcpy(radio_memory[0].name, "COLONEL");
    gTotalFrameTime = 12345;
    GCL_SaveVar();
    GM_LoadComplete = 1;
    GM_LoadRequest = 0;
}

static void CheckSnapshotAndRestore(void) {
    SeedMapEntry();
    GM_PlayerPosX = -8290;
    GM_Vitality = 120;
    GM_Weapons[WP_ChaffGrenade] = 3;
    SetVariable(0x0a, 11);
    assert(MgsCheckpointWrite("entry.bin"));
    assert(!MgsCheckpointWrite("entry.bin"));
    FILE *file = fopen("entry.bin", "rb");
    assert(file && fread(saved, 1, sizeof(saved), file) == sizeof(saved));
    assert(fgetc(file) == EOF && fclose(file) == 0);
    assert(!memcmp(saved + 32, "s01a", 5));
    GCL_InitVar();
    memset(radio_memory, 0, sizeof(radio_memory));
    MgsBonusItemsConfigure(1);
    assert(MgsCheckpointConfigure("entry.bin"));
    assert(MgsCheckpointDisc() == 1);
    assert(GM_Vitality == 0 && GetVariable(0x0a) == 0);
    assert(!strcmp(MgsCheckpointInitialStage("init"), "init_ve"));
    assert(MgsCheckpointBoot("dummy") == 1);
    assert(GM_LoadRequest == 1 && !strcmp(GM_GetArea(0), "s01a"));
    assert(GM_SaveArea == (short)GV_StrCode("s01a") && GM_SaveMap == 0x7df9);
    assert(GM_PlayerPosX == -4605 && GM_PlayerPosY == 469 && GM_PlayerPosZ == 20452);
    assert(GM_Vitality == 256 && GM_Weapons[WP_ChaffGrenade] == -1);
    assert(GM_Weapons[WP_Famas] == 987 && GM_WeaponsMax[WP_Famas] == 999);
    assert(GM_GameLevel == -1 && GM_Configuration == 0x107);
    assert(GM_Disk == 1);
    assert(GetVariable(0x0a) == 7 && GetVariable(0x02) == 1024);
    assert(GetVariable(0x03c0) == 0x3210 && gTotalFrameTime == 12345);
    assert(radio_memory[0].freq == 14085 && !strcmp(radio_memory[0].name, "COLONEL"));
    assert(MgsBonusItemsEnabled() && MgsBonusItemsApply("s01a") == 0);
    assert(GM_Items[IT_Stealth] == -1 && GM_Items[IT_Bandana] == 1);
    assert(MgsCheckpointBoot("title") == 0);
}

static void CheckResidentPacks(void) {
    unsigned char bytes[sizeof(saved)];
    memcpy(bytes, saved, sizeof(bytes));
    bytes[66] = 1;
    bytes[67] = 0;
    WritePayload("normal.bin", bytes, sizeof(bytes), 1);
    assert(MgsCheckpointConfigure("normal.bin"));
    assert(!strcmp(MgsCheckpointInitialStage("init"), "init"));
    assert(MgsCheckpointBoot("title") == 1);
    bytes[256 + 0x435] |= 1;
    WritePayload("tux.bin", bytes, sizeof(bytes), 1);
    assert(MgsCheckpointConfigure("tux.bin"));
    assert(!strcmp(MgsCheckpointInitialStage("init"), "init_tux"));
    assert(MgsCheckpointBoot("dummy") == 1);
    assert(MgsCheckpointConfigure(NULL));
    assert(!strcmp(MgsCheckpointInitialStage("init"), "init"));
    assert(MgsCheckpointBoot("title") == 0);
}

static void CheckRejectedFiles(void) {
    unsigned char bytes[sizeof(saved) + 1];
    const unsigned int offsets[] = {0, 8, 12, 32, 64 + 12, 64 + 2};
    for (unsigned int i = 0; i < sizeof(offsets) / sizeof(offsets[0]); ++i) {
        memcpy(bytes, saved, sizeof(saved));
        bytes[offsets[i]] ^= 0x40;
        WritePayload("bad.bin", bytes, sizeof(saved), 1);
        assert(!MgsCheckpointConfigure("bad.bin"));
    }
    memcpy(bytes, saved, sizeof(saved));
    memset(bytes + 32, 'x', 16);
    WritePayload("bad.bin", bytes, sizeof(saved), 1);
    assert(!MgsCheckpointConfigure("bad.bin"));
    memcpy(bytes, saved, sizeof(saved));
    bytes[600] ^= 1;
    WritePayload("bad.bin", bytes, sizeof(saved), 0);
    assert(!MgsCheckpointConfigure("bad.bin"));
    WritePayload("bad.bin", saved, sizeof(saved) - 1, 0);
    assert(!MgsCheckpointConfigure("bad.bin"));
    bytes[sizeof(saved)] = 0;
    WritePayload("bad.bin", bytes, sizeof(bytes), 0);
    assert(!MgsCheckpointConfigure("bad.bin"));
    assert(!MgsCheckpointConfigure("missing.bin"));
}

static void CheckDiscSelection(void) {
    unsigned char bytes[sizeof(saved)];
    memcpy(bytes, saved, sizeof(bytes));
    bytes[72] = 2;
    WritePayload("disc2.bin", bytes, sizeof(bytes), 1);
    assert(MgsCheckpointConfigure("disc2.bin"));
    assert(MgsCheckpointDisc() == 2);
    assert(!strcmp(MgsCheckpointInitialStage("init"), "init_ve"));
    assert(MgsCheckpointDisc() == 2);
    assert(MgsCheckpointBoot("dummy") == 1 && GM_Disk == 2);
    assert(MgsCheckpointDisc() == 1);
    const short invalid_discs[] = {0, -1, 3, 256};
    for (unsigned int i = 0; i < sizeof(invalid_discs) / sizeof(invalid_discs[0]); ++i) {
        memcpy(bytes + 72, &invalid_discs[i], sizeof(short));
        WritePayload("bad-disc.bin", bytes, sizeof(bytes), 1);
        assert(!MgsCheckpointConfigure("bad-disc.bin"));
        assert(MgsCheckpointDisc() == 1);
    }
    assert(MgsCheckpointConfigure(NULL));
    assert(MgsCheckpointDisc() == 1);
}

static void CheckUnstableEntry(void) {
    SeedMapEntry();
    GM_LoadRequest = 1;
    assert(!MgsCheckpointWrite("unstable.bin"));
    GM_LoadRequest = 0;
    GM_LoadComplete = 0;
    assert(!MgsCheckpointWrite("unstable.bin"));
    GM_LoadComplete = 1;
    loaded_stage = "s02a";
    assert(!MgsCheckpointWrite("unstable.bin"));
    loaded_stage = NULL;
    assert(!MgsCheckpointWrite("unstable.bin"));
    assert(fopen("unstable.bin", "rb") == NULL);
}

int main(void) {
    CheckSnapshotAndRestore();
    CheckResidentPacks();
    CheckRejectedFiles();
    CheckDiscSelection();
    CheckUnstableEntry();
    puts("Original map-entry checkpoint restoration and invalid-file checks passed");
    return 0;
}
