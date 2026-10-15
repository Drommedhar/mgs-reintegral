#include "mgs_language.h"
#ifdef MGS_GODOT_SCENE
#include "mgs_godot_cinematic.h"
#endif

#include <SDL3/SDL_stdinc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { DESCRIPTION = 1, FONT, TEXT, VOX, DEMO, MAX_RECORDS = 65536 };

typedef struct {
    uint32_t kind, disc, id, offset, size, crc;
    unsigned char *data;
} LanguageRecord;

typedef struct {
    FILE *file;
    LanguageRecord *records;
    unsigned count, language, streams;
} LanguagePack;

static LanguagePack text_pack, voice_pack;
static char description[1024];
static LanguageRecord *current_stream;
static unsigned stream_sector;
static int ValidStream(const LanguageRecord *record);

static uint32_t Read32(const unsigned char *bytes)
{
    return (uint32_t)bytes[0] | (uint32_t)bytes[1] << 8 |
           (uint32_t)bytes[2] << 16 | (uint32_t)bytes[3] << 24;
}

static uint32_t ReadBig32(const unsigned char *bytes)
{
    return (uint32_t)bytes[0] << 24 | (uint32_t)bytes[1] << 16 |
           (uint32_t)bytes[2] << 8 | bytes[3];
}

static int Failure(const char *reason)
{
    fprintf(stderr, "[language] %s\n", reason);
    return 0;
}

static void ClosePack(LanguagePack *pack)
{
    if (pack->file)
        fclose(pack->file);
    for (unsigned i = 0; i < pack->count; ++i)
        free(pack->records[i].data);
    free(pack->records);
    memset(pack, 0, sizeof(*pack));
}

void MgsLanguageClose(void)
{
    current_stream = NULL;
    ClosePack(&text_pack);
    ClosePack(&voice_pack);
}

void MgsLanguageCloseStream(void)
{
    if (current_stream) {
        free(current_stream->data);
        current_stream->data = NULL;
        current_stream = NULL;
    }
}

static int CompareKey(const void *first, const void *second)
{
    const LanguageRecord *a = first, *b = second;
    if (a->kind != b->kind)
        return a->kind < b->kind ? -1 : 1;
    if (a->disc != b->disc)
        return a->disc < b->disc ? -1 : 1;
    return a->id < b->id ? -1 : a->id != b->id;
}

static LanguageRecord *FindRecord(LanguagePack *pack, unsigned kind, unsigned disc, unsigned id)
{
    if (!pack->count)
        return NULL;
    LanguageRecord key = {.kind = kind, .disc = disc, .id = id};
    return bsearch(&key, pack->records, pack->count, sizeof(*pack->records), CompareKey);
}

static int LoadRecord(LanguagePack *pack, LanguageRecord *record)
{
    record->data = malloc(record->size);
    return record->data && fseek(pack->file, record->offset, SEEK_SET) == 0 &&
           fread(record->data, 1, record->size, pack->file) == record->size &&
           SDL_crc32(0, record->data, record->size) == record->crc;
}

static int ValidFont(const LanguageRecord *record)
{
    if (record->size < 12)
        return 0;
    unsigned table_end = ReadBig32(record->data);
    if (table_end < 392 || table_end > record->size || (table_end - 8) % 4)
        return 0;
    for (unsigned pos = 8; pos < table_end; pos += 4) {
        unsigned glyph = ReadBig32(record->data + pos);
        unsigned offset = glyph & 0xffffff, width = (glyph >> 24) & 15;
        if (offset >= record->size - table_end || width * 3 + 1 > record->size - table_end - offset)
            return 0;
    }
    return 1;
}

static uint32_t TextHash(const char *text)
{
    uint32_t hash = 2166136261u;
    while (*text)
        hash = (hash ^ (unsigned char)*text++) * 16777619u;
    return hash;
}

static int ValidText(const LanguageRecord *record)
{
    if (record->size < 7 || record->size > 8192)
        return 0;
    unsigned source = Read32(record->data);
    if (!source || source >= record->size - 6 || record->data[4 + source] ||
        memchr(record->data + 4, 0, source) || !record->data[5 + source] ||
        record->data[record->size - 1] ||
        memchr(record->data + 5 + source, 0, record->size - source - 6))
        return 0;
    return TextHash((const char *)record->data + 4) == record->id;
}

static int ValidRecord(LanguagePack *pack, LanguageRecord *record)
{
    if (record->kind >= VOX) {
        ++pack->streams;
        return record->disc >= 1 && record->disc <= 2 && record->id < 449850;
    }
    if (record->disc || record->size > 65536 || !LoadRecord(pack, record))
        return 0;
    if (record->kind == FONT)
        return !record->id && ValidFont(record);
    if (record->kind == TEXT)
        return ValidText(record);
    return record->size < sizeof(description) &&
           record->data[record->size - 1] == 0 &&
           !memchr(record->data, 0, record->size - 1);
}

static int ReadIndex(LanguagePack *pack, const unsigned char *header)
{
    unsigned count = Read32(header + 16), total = Read32(header + 20);
    unsigned offset = 32 + count * 24;
    unsigned char *index = malloc(count * 24);
    pack->records = calloc(count, sizeof(*pack->records));
    if (!index || !pack->records) {
        free(index);
        return 0;
    }
    pack->count = count;
    int valid = fread(index, 24, count, pack->file) == count &&
                SDL_crc32(0, index, count * 24) == Read32(header + 24);
    for (unsigned i = 0; valid && i < count; ++i) {
        const unsigned char *entry = index + i * 24;
        LanguageRecord *record = &pack->records[i];
        *record = (LanguageRecord){Read32(entry), Read32(entry + 4), Read32(entry + 8),
                                  Read32(entry + 12), Read32(entry + 16), Read32(entry + 20), NULL};
        valid = record->kind >= DESCRIPTION && record->kind <= DEMO && record->offset == offset &&
                record->size && record->size <= 32u * 1024 * 1024 && offset <= total &&
                record->size <= total - offset && (!i || CompareKey(record - 1, record) < 0);
        if (valid)
            valid = ValidRecord(pack, record);
        offset += record->size;
    }
    free(index);
    return valid && offset == total && FindRecord(pack, FONT, 0, 0);
}

static int ReadPack(LanguagePack *pack)
{
    unsigned char header[32];
    if (fseek(pack->file, 0, SEEK_END) || ftell(pack->file) > 1024L * 1024 * 1024)
        return 0;
    long file_size = ftell(pack->file);
    rewind(pack->file);
    if (fread(header, 1, sizeof(header), pack->file) != sizeof(header) ||
        memcmp(header, "MGSLOC01", 8) || Read32(header + 8) != 1 ||
        Read32(header + 12) < 1 || Read32(header + 12) > 2 ||
        !Read32(header + 16) || Read32(header + 16) > MAX_RECORDS ||
        Read32(header + 20) != (unsigned long)file_size || Read32(header + 28) ||
        !ReadIndex(pack, header))
        return 0;
    pack->language = Read32(header + 12);
    printf("[language] %s: %u records, %u speech/cinematic streams\n",
           pack->language == 1 ? "English" : "German", pack->count, pack->streams);
    return 1;
}

static int OpenPack(LanguagePack *pack, const char *path)
{
    pack->file = fopen(path, "rb");
    if (!pack->file)
        return Failure("Cannot open selected language pack.");
    if (!ReadPack(pack)) {
        ClosePack(pack);
        return Failure("Invalid, truncated or unsupported language pack.");
    }
    return 1;
}

int MgsLanguageInspect(const char *path)
{
    LanguagePack pack = {0};
    int valid = OpenPack(&pack, path);
    for (unsigned i = 0; valid && i < pack.count; ++i) {
        LanguageRecord *record = &pack.records[i];
        if (record->kind >= VOX) {
            valid = LoadRecord(&pack, record) && ValidStream(record);
            free(record->data);
            record->data = NULL;
            if (!valid)
                Failure("Speech stream failed checksum or packet validation.");
        }
    }
    ClosePack(&pack);
    return valid;
}

int MgsLanguageConfigure(const char *text, const char *voice)
{
    MgsLanguageClose();
    if ((text && !OpenPack(&text_pack, text)) || (voice && !OpenPack(&voice_pack, voice))) {
        MgsLanguageClose();
        return 0;
    }
    if (voice && !voice_pack.streams) {
        MgsLanguageClose();
        return Failure("Selected voice pack contains no speech streams.");
    }
    return 1;
}

const char *MgsLanguageDescription(unsigned identity, int card_level)
{
    LanguageRecord *record = FindRecord(&text_pack, DESCRIPTION, 0, identity);
    if (!record)
        return NULL;
    memcpy(description, record->data, record->size);
    for (unsigned i = 0; i < record->size; ++i) {
        if (description[i] == 0x1e)
            description[i] = (char)('0' + (card_level >= 0 && card_level <= 9 ? card_level : 0));
    }
    return description;
}

const char *MgsLanguageText(const char *original)
{
    if (!text_pack.file || !original)
        return original;
    LanguageRecord *record = FindRecord(&text_pack, TEXT, 0, TextHash(original));
    if (!record || strcmp(original, (const char *)record->data + 4))
        return original;
    return (const char *)record->data + Read32(record->data) + 5;
}

const unsigned char *MgsLanguageGlyph(unsigned code, unsigned *descriptor)
{
    if (code < 128 || code >= 255)
        return NULL;
    LanguagePack *pack = text_pack.language == 2 ? &text_pack : &voice_pack;
    LanguageRecord *font = FindRecord(pack, FONT, 0, 0);
    if (!font)
        return NULL;
    unsigned table_end = ReadBig32(font->data), pos = 8 + (code - 32) * 4;
    if (pos >= table_end)
        return NULL;
    *descriptor = ReadBig32(font->data + pos);
    return font->data + table_end + (*descriptor & 0xffffff);
}

int MgsLanguageUseEnglish(int original)
{
    return text_pack.file || voice_pack.file || original;
}

static int ValidCaptions(const unsigned char *data, unsigned size)
{
    unsigned mouth = data[8] | data[9] << 8, text = data[10] | data[11] << 8;
    unsigned font = Read32(data + 12);
    if (mouth < 16 || mouth > text || text > font || font > size || font - text < 16)
        return 0;
    while (text + 16 <= font) {
        unsigned next = Read32(data + text), start = Read32(data + text + 4);
        unsigned duration = Read32(data + text + 8);
        if (!next && !start && !duration)
            return 1;
        unsigned end = next ? text + next : font;
        if (next % 4 || end <= text + 16 || end > font ||
            !memchr(data + text + 16, 0, end - text - 16))
            return 0;
        if (!next)
            return 1;
        text = end;
    }
    return 0;
}

static int ValidStream(const LanguageRecord *record)
{
    if (record->size % 2048)
        return 0;
    unsigned offset = 0;
    while (offset + 4 <= record->size) {
        unsigned header = Read32(record->data + offset), kind = header & 255, size = header >> 8;
        if (kind == 0xf0)
            return (offset + 4 + 2047) / 2048 * 2048 == record->size;
        if ((kind != 1 && kind != 2 && kind != 5 && kind != 6 && kind != 7 && kind != 16) ||
            size < 8 || size % 4 || size > 32768 || size > record->size - offset ||
            (kind == 6 && (size > 4088 || size < 36)))
            return 0;
        if (kind == 6 && !ValidCaptions(record->data + offset + 4, size - 4))
            return 0;
        offset += size;
    }
    return 0;
}

void MgsLanguageSelectStream(unsigned kind, unsigned disc, unsigned identity, unsigned sector)
{
#ifdef MGS_GODOT_SCENE
    MgsGodotCinematicSelect(kind, disc, identity);
#endif
    MgsLanguageCloseStream();
    if (!voice_pack.file)
        return;
    LanguageRecord *record = FindRecord(&voice_pack, kind, disc, identity);
    if (!record) {
        fprintf(stderr, "[language] Integral fallback: disc %u %s sector %u\n",
                disc, kind == DEMO ? "DEMO" : "VOX", identity);
        return;
    }
    if (!LoadRecord(&voice_pack, record) || !ValidStream(record)) {
        Failure("Selected speech stream failed validation.");
        exit(EXIT_FAILURE);
    }
    current_stream = record;
    stream_sector = sector;
    printf("[language] Playing disc %u %s sector %u\n", disc, kind == DEMO ? "DEMO" : "VOX", identity);
}

int MgsLanguageStreamActive(void)
{
    return current_stream != NULL;
}

void MgsLanguageReadSector(unsigned sector, void *output)
{
    if (!current_stream || sector < stream_sector || sector - stream_sector >= current_stream->size / 2048) {
        Failure("Speech reader exceeded selected stream.");
        exit(EXIT_FAILURE);
    }
    memcpy(output, current_stream->data + (sector - stream_sector) * 2048, 2048);
}
