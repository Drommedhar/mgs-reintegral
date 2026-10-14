#include "mgs_save_ui.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    MgsSaveFile files[MGS_SAVE_FILE_LIMIT];
    uint32_t ids[MGS_SAVE_FILE_LIMIT], count;
    int free_blocks;
} SaveStorage;

static MgsSaveView view;
static SaveStorage stores[2];
static MgsSaveTarget targets[MGS_SAVE_ENTRY_LIMIT];
static int enabled, started, preferred_storage = -1;
static char family[14];
static unsigned required_blocks;
static uint32_t next_id, generation;

static void InvalidStorage(void)
{
    fputs("Save UI: invalid native storage metadata.\n", stderr);
    exit(EXIT_FAILURE);
}

static void Advance(uint32_t *value) { if (++*value == 0) ++*value; }

static MgsSaveEntry Entry(uint32_t id, const char *name)
{
    const unsigned char *data = (const unsigned char *)name + 12;
    MgsSaveEntry result = {.id = id};
    if (strlen(name) != 20) return result;
    unsigned h = data[1] & 0x3f, m = data[3] & 0x3f, n = data[4] & 0x3f;
    if (data[0] != 'G' || (h != ':' && (h < '0' || h > '9')) ||
        (h != ':' && (data[2] < '0' || data[2] > '9')) ||
        m < '0' || m > '5' || n < '0' || n > '9' ||
        data[5] < '@' || data[5] > 'O' || data[6] < '@' || data[6] > 127) return result;
    result.metadata_valid = 1;
    result.completion = h == ':';
    result.hours = h == ':' ? 0 : (h - '0') * 10 + data[2] - '0';
    result.minutes = (m - '0') * 10 + n - '0';
    result.disc = ((data[5] - '@') >> 3) + 1;
    result.difficulty = (data[1] & 0x40) ? 0 : 1 + ((data[3] & 0x40) >> 5) + ((data[4] & 0x40) >> 6);
    result.area = data[6] - '@';
    return result;
}

static void Rebuild(void)
{
    view.count = 0;
    view.can_create = 0;
    for (unsigned storage = 0; storage < 2; ++storage) {
        const SaveStorage *source = &stores[storage];
        if (!view.loading && source->free_blocks >= (int)required_blocks) view.can_create = 1;
        for (unsigned index = 0; index < source->count; ++index) {
            if (strncmp(source->files[index].name, family, 13)) continue;
            unsigned row = view.count++;
            view.entries[row] = Entry(source->ids[index], source->files[index].name);
            targets[row] = (MgsSaveTarget){.storage = storage, .file = index};
            memcpy(targets[row].name, source->files[index].name, MGS_SAVE_NAME_SIZE);
        }
    }
    if (view.cursor > view.count) view.cursor = view.count;
    view.selected_id = view.cursor < view.count ? view.entries[view.cursor].id : 0;
}

void MgsSaveUiBeginFrame(int collect)
{
    enabled = collect;
    view.active = 0;
}

void MgsSaveUiEnd(void)
{
    started = 0;
    memset(&view, 0, sizeof(view));
    memset(stores, 0, sizeof(stores));
    memset(targets, 0, sizeof(targets));
    for (unsigned index = 0; index < 2; ++index) stores[index].free_blocks = -1;
    preferred_storage = -1;
}

void MgsSaveUiStart(int loading, const char *prefix, unsigned blocks)
{
    MgsSaveUiEnd();
    if (!enabled) return;
    if (!prefix || strlen(prefix) != 13 || blocks == 0 || blocks > 15) InvalidStorage();
    memcpy(family, prefix, sizeof(family));
    required_blocks = blocks;
    Advance(&generation);
    view.generation = generation;
    view.loading = loading != 0;
    view.state = MGS_SAVE_CHECKING;
    next_id = 0;
    started = 1;
}

void MgsSaveUiStorage(unsigned storage, const MgsSaveFile *files, unsigned count, int free_blocks)
{
    if (!enabled || !started) return;
    if (storage > 1 || count > MGS_SAVE_FILE_LIMIT || (count && !files) || free_blocks < -1 || free_blocks > 15) InvalidStorage();
    SaveStorage next = {.count = count, .free_blocks = free_blocks};
    for (unsigned index = 0; index < count; ++index) {
        if (!memchr(files[index].name, 0, MGS_SAVE_NAME_SIZE)) InvalidStorage();
        memcpy(next.files[index].name, files[index].name, strlen(files[index].name) + 1);
        next.files[index].bytes = files[index].bytes;
        for (unsigned previous = 0; previous < index; ++previous)
            if (!strcmp(files[index].name, files[previous].name)) InvalidStorage();
        for (unsigned old = 0; old < stores[storage].count; ++old)
            if (!strcmp(files[index].name, stores[storage].files[old].name)) next.ids[index] = stores[storage].ids[old];
        if (!next.ids[index]) { Advance(&next_id); next.ids[index] = next_id; }
    }
    if (!memcmp(&next, &stores[storage], sizeof(next))) return;
    stores[storage] = next;
    Advance(&view.revision);
    Rebuild();
}

void MgsSaveUiPresent(unsigned phase, unsigned status, int storage, const char *selected)
{
    if (!enabled || !started) return;
    view.active = 1;
    view.message = status & 255;
    view.state = phase == 2 ? MGS_SAVE_RESULT : phase == 5 ? MGS_SAVE_CONFIRM :
        phase == 3 || phase == 4 ? MGS_SAVE_BROWSE : (status & 255) == 9 ? MGS_SAVE_BUSY : MGS_SAVE_CHECKING;
    preferred_storage = storage;
    view.selected_id = 0;
    for (unsigned row = 0; row < view.count; ++row)
        if ((int)targets[row].storage == storage && selected && !strcmp(targets[row].name, selected))
            view.selected_id = view.entries[row].id;
}

const MgsSaveView *MgsSaveUiGetView(void) { return &view; }

void MgsSaveUiSelection(unsigned cursor, unsigned choice)
{
    view.cursor = cursor;
    view.choice = choice;
    view.selected_id = cursor < view.count ? view.entries[cursor].id : 0;
}

void MgsSaveUiLocation(unsigned area, const char *encoded)
{
    char text[64] = {0};
    unsigned length = 0;
    const unsigned char *source = (const unsigned char *)encoded;
    while (source && *source && length < sizeof(text) - 1) {
        unsigned character = *source++;
        if (character >= 128 && *source) {
            /* KCB prefixes carry kinsoku flags; 0x9001 is its full-width space. */
            character = ((character << 8) | *source++) & 0x9fff;
            if (character == 0x9001) character = ' ';
            else if (character >= 0x8020 && character <= 0x807e) character &= 0x7f;
        }
        if (character < 32 || character > 126) { length = 0; break; }
        text[length++] = (char)character;
    }
    if (!length) snprintf(text, sizeof(text), "Location %u", area);
    for (unsigned row = 0; row < view.count; ++row)
        if (view.entries[row].area == area) memcpy(view.entries[row].location, text, sizeof(text));
}

static int Current(uint32_t expected_generation, uint32_t revision)
{
    return enabled && started && view.active && view.state == MGS_SAVE_BROWSE &&
        view.generation == expected_generation && view.revision == revision;
}

int MgsSaveUiResolve(uint32_t expected_generation, uint32_t revision, uint32_t id, MgsSaveTarget *target)
{
    if (!target || !Current(expected_generation, revision)) return 0;
    for (unsigned row = 0; row < view.count; ++row) {
        if (view.entries[row].id != id) continue;
        *target = targets[row];
        return 1;
    }
    return 0;
}

int MgsSaveUiResolveNew(uint32_t expected_generation, uint32_t revision, MgsSaveTarget *target)
{
    if (!target || !Current(expected_generation, revision) || !view.can_create) return 0;
    for (unsigned index = 0; index < 2; ++index) {
        unsigned storage = preferred_storage >= 0 && preferred_storage < 2 ? (preferred_storage + index) % 2 : index;
        if (stores[storage].free_blocks < (int)required_blocks) continue;
        *target = (MgsSaveTarget){.storage = storage, .file = 16};
        return 1;
    }
    return 0;
}
