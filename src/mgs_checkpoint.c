#include "mgs_native.h"
#undef fprintf
#include "mgs_checkpoint.h"
#include "mgs_bonus_items.h"
#include "game/game.h"
#include "libgcl/libgcl.h"
#include "menu/menuman.h"
#include <errno.h>
#include <stdint.h>

typedef struct {
    uint32_t size, checksum, version, version2;
    int frame_time, padding[3];
    char stage[16];
    short history[8], linkvars[0x60], variables[1024];
    RadioMemory radio[RADIO_MEMORY_COUNT];
} Checkpoint;

_Static_assert(sizeof(Checkpoint) == 0xa40, "Original Integral save size");

static Checkpoint pending;
static int boot_phase;
static const char *resident_stage;

static int Fail(const char *message) {
    fprintf(stderr, "[checkpoint] %s\n", message);
    return 0;
}

static uint32_t Checksum(const Checkpoint *checkpoint) {
    const unsigned char *bytes = (const unsigned char *)checkpoint;
    uint32_t crc = UINT32_MAX;
    for (unsigned int i = 8; i < sizeof(*checkpoint); ++i) {
        crc ^= bytes[i];
        for (int bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
    }
    return ~crc;
}

static int Validate(const Checkpoint *checkpoint) {
    if (checkpoint->size != sizeof(*checkpoint) || checkpoint->version != 0x60 ||
        checkpoint->version2 != 0x800)
        return Fail("Unsupported checkpoint size or save version.");
    if (checkpoint->checksum != Checksum(checkpoint))
        return Fail("Checkpoint checksum mismatch.");
    if (!memchr(checkpoint->stage, '\0', sizeof(checkpoint->stage)) ||
        !MgsNativeStageAvailable(checkpoint->stage))
        return Fail("Checkpoint stage is invalid or unavailable in this build.");
    if ((unsigned short)checkpoint->linkvars[6] != GV_StrCode(checkpoint->stage))
        return Fail("Checkpoint stage hash does not match its stage name.");
    if (checkpoint->linkvars[1] < -1 || checkpoint->linkvars[1] > 3)
        return Fail("Checkpoint difficulty is outside the original range.");
    if (checkpoint->linkvars[4] != 1 && checkpoint->linkvars[4] != 2)
        return Fail("Checkpoint disc number must be 1 or 2.");
    return 1;
}

int MgsCheckpointConfigure(const char *load_path) {
    boot_phase = 0;
    resident_stage = NULL;
    if (!load_path)
        return 1;
    FILE *file = fopen(load_path, "rb");
    if (!file)
        return Fail(strerror(errno));
    size_t bytes = fread(&pending, 1, sizeof(pending), file);
    int extra = fgetc(file);
    int valid = bytes == sizeof(pending) && extra == EOF && !ferror(file);
    if (fclose(file) != 0)
        valid = 0;
    if (!valid)
        return Fail("Checkpoint must contain exactly 0xA40 bytes.");
    if (!Validate(&pending))
        return 0;
    const unsigned char *variables = (const unsigned char *)pending.variables;
    resident_stage = (variables[0x435] & 1) ? "init_tux" :
                     pending.linkvars[1] == -1 ? "init_ve" : "init";
    boot_phase = 1;
    printf("[checkpoint] Prepared stage=%s resident=%s\n", pending.stage, resident_stage);
    return 1;
}

int MgsCheckpointDisc(void) {
    return boot_phase ? pending.linkvars[4] : 1;
}

const char *MgsCheckpointInitialStage(const char *fallback) {
    if (boot_phase != 1)
        return fallback;
    boot_phase = 2;
    return resident_stage;
}

int MgsCheckpointBoot(const char *requested) {
    if (boot_phase != 2)
        return 0;
    const char *expected = strcmp(resident_stage, "init") == 0 ? "title" : "dummy";
    if (strcmp(requested, expected) != 0) {
        Fail("Resident initialization requested an unexpected transition.");
        return -1;
    }
    if (!GCL_SetLoadFile((char *)&pending)) {
        Fail("Original save loader rejected the checkpoint.");
        return -1;
    }
    GCL_RestoreVar();
    MgsBonusItemsKeepLoadedInventory();
    GM_LoadRequest = 1;
    boot_phase = 0;
    printf("[checkpoint] Restored stage=%s map=%04x spawn=(%d,%d,%d)\n",
           GM_GetArea(0), (unsigned short)GM_SaveMap,
           GM_PlayerPosX, GM_PlayerPosY, GM_PlayerPosZ);
    return 1;
}

int MgsCheckpointWrite(const char *save_path) {
    Checkpoint checkpoint;
    const char *loaded_stage = MgsNativeCurrentStage();
    if (!save_path || !loaded_stage || GM_LoadComplete != 1 || GM_LoadRequest != 0)
        return Fail("Cannot save a checkpoint during a stage transition.");
    if (GCL_MakeSaveFile((char *)&checkpoint) != sizeof(checkpoint) ||
        !Validate(&checkpoint))
        return Fail("Original save serializer produced an invalid checkpoint.");
    if (strcmp(checkpoint.stage, loaded_stage) != 0 ||
        strcmp(checkpoint.stage, GM_GetArea(0)) != 0)
        return Fail("Stored map entry does not belong to the loaded stage.");
    FILE *file = fopen(save_path, "wbx");
    if (!file)
        return Fail(strerror(errno));
    int written = fwrite(&checkpoint, 1, sizeof(checkpoint), file) == sizeof(checkpoint);
    if (fclose(file) != 0)
        written = 0;
    if (!written)
        return Fail("Checkpoint write failed.");
    printf("[checkpoint] Saved original map entry: stage=%s path=%s\n", checkpoint.stage, save_path);
    return 1;
}
