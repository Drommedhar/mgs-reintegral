#include "mgs_native.h"
#undef fprintf
#include "../vendor/mgs/source/overlays/rank/chara/pocket/pocket_native.h"
#include "linkvar.h"
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>
typedef struct EntryFixture
{
    int input[16], output[15];
    unsigned char name[12], submitted[12];
    uint32_t hash;
    int calls;
} EntryFixture;
#include "mgs_pocket_entry_fixtures.h"

short linkvarbuf[MAX_LINKVARBUF], GM_PDA_ClearRank;
char gap_800B58CC[20];
static uint32_t trace_hash;
static int trace_calls, ports;
static POLY_FT4 polys[4];

static void TraceNumber(uint32_t value)
{
    int i;
    for (i = 0; i < 4; ++i)
    {
        trace_hash = (trace_hash ^ (value & 255)) * 16777619u;
        value >>= 8;
    }
}

static void Record(int tag, int count, ...)
{
    va_list args;
    int i;
    ++trace_calls;
    TraceNumber(tag);
    va_start(args, count);
    for (i = 0; i < count; ++i)
        TraceNumber(va_arg(args, int));
    va_end(args);
}

static void TextRecord(int tag, int first, const char *text, int has_first)
{
    size_t i;
    Record(tag, has_first ? 2 : 1, has_first ? first : (int)strlen(text), (int)strlen(text));
    for (i = 0; text[i]; ++i)
        TraceNumber((unsigned char)text[i]);
}
int rank_800D1C44(void *p, int g, unsigned short hash, short x, short y, int semi)
{
    Record(1, 6, (POLY_FT4 *)p - polys, g, hash, x, y, semi);
    return 0;
}
int rank_800D1E00(void *p, int g, unsigned short hash, short y, int semi)
{
    Record(2, 5, (POLY_FT4 *)p - polys, g, hash, y, semi);
    return 0;
}
void rank_800D21BC(POLY_FT4 *p, unsigned int color)
{
    Record(3, 2, p - polys, color);
}
void rank_800D1A64(void *p, int g, int x, short y)
{
    Record(4, 4, (POLY_FT4 *)p - polys, g, x, y);
}
void rank_800D2830(int depth)
{
    Record(5, 1, depth);
}
void rank_800D2644(short x, short y, short w, short h, unsigned char color, int style)
{
    Record(6, 6, x, y, w, h, color, style);
}
void rank_800D1A40(PocketEntryWork *work, int index)
{
    (void)work;
    Record(7, 1, index);
}
void GM_SeSet2(int pan, int volume, int sound)
{
    Record(8, 3, pan, volume, sound);
}
int GCL_ExecProc(int procedure, GCL_ARGS *args)
{
    (void)args;
    Record(9, 1, procedure);
    return 0;
}
void GV_DestroyActor(void *actor)
{
    (void)actor;
    Record(10, 0);
}
int rank_800CC104(int port)
{
    Record(11, 1, port);
    return (ports >> port) & 1;
}
void rank_800CBD14(int mode, int character, char *name)
{
    size_t i;
    Record(12, 3, mode, character, (int)strlen(name));
    for (i = 0; name[i]; ++i)
        TraceNumber((unsigned char)name[i]);
}
void rank_800D1218(int x, int y, int page)
{
    Record(13, 3, x, y, page);
}
void rank_800D128C(int r, int g, int b, int scale)
{
    Record(14, 4, r, g, b, scale);
}
void rank_800D1230(const char *text, int scale)
{
    TextRecord(15, scale, text, 1);
}
void MENU_Locate(int x, int y, int flags)
{
    Record(16, 3, x, y, flags);
}
void MENU_Color(int r, int g, int b)
{
    Record(17, 3, r, g, b);
}
int MENU_Printf(const char *format, ...)
{
    TextRecord(18, 0, format, 0);
    return strlen(format);
}
void rank_800D2864(void)
{
    Record(19, 0);
}
#include "../vendor/mgs/source/libgv/strcode.c"
#include "pocket_entry_helpers.inc"

int main(void)
{
    static const char *names[] = {"        ", "Ab-12! ?", ""};
    int index;
    for (index = 0; index < sizeof(fixtures) / sizeof(fixtures[0]); ++index)
    {
        const EntryFixture *f = &fixtures[index];
        const int *in = f->input;
        PocketEntryWork work = {0};
        PocketNode node = {0};
        int actual[15];
        size_t length = strlen(names[in[15]]);
        if (length > (size_t)in[10])
            length = in[10];
        memcpy(work.name, names[in[15]], length);
        memset(PocketSubmittedName, 0, 12);
        work.direction = in[4];
        work.repeat = in[5];
        work.mode = in[6];
        work.entry_ready = in[7];
        work.choice = in[8];
        work.cursor = in[9];
        work.name_length = in[10];
        work.filled = in[11];
        for (int j = 0; j < 5; ++j)
            work.procedures[j] = 101 + j;
        node.phase = in[0];
        node.time = in[1];
        node.time2 = 12;
        node.flags = in[2];
        node.selection = in[3];
        node.packets.flat = polys;
        ports = in[12];
        GM_PDA_ClearRank = 0x5a00 | in[13];
        GM_Result = in[14];
        GM_UnkFlag00 = 0x203;
        trace_hash = 2166136261u;
        trace_calls = 0;
        rank_800D28D4(&work, &node);
        int values[] = {work.direction,   work.repeat,
                        work.name_length, work.cursor,
                        work.filled,      work.choice,
                        work.mode,        work.entry_ready,
                        node.time,        node.time2,
                        node.phase,       node.flags,
                        node.selection,   (unsigned short)GM_PDA_ClearRank,
                        GM_Result};
        memcpy(actual, values, sizeof(actual));
        if (memcmp(actual, f->output, sizeof(actual)) || memcmp(work.name, f->name, 12) ||
            memcmp(PocketSubmittedName, f->submitted, 12) || trace_hash != f->hash ||
            trace_calls != f->calls)
        {
            printf("case %d phase%d time%d flags%d key%d: trace %u/%u calls%d/%d\n", index, in[0],
                   in[1], in[2], in[3], trace_hash, f->hash, trace_calls, f->calls);
            for (int j = 0; j < 15; ++j)
                if (actual[j] != f->output[j])
                    printf("field%d: %d/%d\n", j, actual[j], f->output[j]);
            return 1;
        }
    }
    printf("%d original PocketStation entry state/call traces passed\n", index);
    return 0;
}
