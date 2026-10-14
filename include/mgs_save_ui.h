#ifndef MGS_SAVE_UI_H
#define MGS_SAVE_UI_H

#include <stdint.h>

enum { MGS_SAVE_FILE_LIMIT = 15, MGS_SAVE_ENTRY_LIMIT = 30, MGS_SAVE_NAME_SIZE = 21 };
enum { MGS_SAVE_BROWSE, MGS_SAVE_CHECKING, MGS_SAVE_CONFIRM, MGS_SAVE_BUSY, MGS_SAVE_RESULT };

typedef struct { char name[MGS_SAVE_NAME_SIZE]; uint32_t bytes; } MgsSaveFile;
typedef struct {
    uint32_t id, hours, minutes, disc, difficulty, completion, area;
    uint32_t metadata_valid;
    char location[64];
} MgsSaveEntry;
typedef struct {
    uint32_t active, generation, revision, loading, state, message;
    uint32_t count, selected_id, can_create, cursor, choice;
    MgsSaveEntry entries[MGS_SAVE_ENTRY_LIMIT];
} MgsSaveView;

/* Internal routing only; storage identifiers are not visible UI concepts. */
typedef struct {
    uint32_t storage, file;
    char name[MGS_SAVE_NAME_SIZE];
} MgsSaveTarget;

void MgsSaveUiBeginFrame(int enabled);
void MgsSaveUiStart(int loading, const char *family, unsigned blocks);
void MgsSaveUiEnd(void);
void MgsSaveUiStorage(unsigned storage, const MgsSaveFile *files, unsigned count, int free_blocks);
void MgsSaveUiPresent(unsigned phase, unsigned status, int storage, const char *selected);
void MgsSaveUiSelection(unsigned cursor, unsigned choice);
void MgsSaveUiLocation(unsigned area, const char *encoded);
const MgsSaveView *MgsSaveUiGetView(void);
int MgsSaveUiResolve(uint32_t generation, uint32_t revision, uint32_t id, MgsSaveTarget *target);
int MgsSaveUiResolveNew(uint32_t generation, uint32_t revision, MgsSaveTarget *target);

#endif
