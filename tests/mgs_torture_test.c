#include "mgs_native.h"
#undef fprintf
#include "game/game.h"
#include "libgcl/libgcl.h"
#include "chara/torture/info.h"
#include "strcode.h"
#include <assert.h>
#include <stddef.h>

#include "torture_helpers.inc"

typedef struct {
    int kind, seed;
    unsigned state, trace, words;
    int result;
} TortureFixture;
#include "mgs_torture_fixtures.h"

_Static_assert(sizeof(Work) == 0x904, "Original torture actor layout");
_Static_assert(offsetof(Work, control.n_msg) == 0x76, "Original message count");
_Static_assert(offsetof(Work, control.msg) == 0x7c, "Original message pointer");
_Static_assert(offsetof(Work, f834) == 0x834, "Original pad pointer");

short linkvarbuf[MAX_LINKVARBUF];
int GM_GameStatus;
static unsigned trace[64], trace_count;
static int seed;
static Work *current;
static const int ticks[] = {-1, 0, 1, 2, 65535, 65536};
static const short health[] = {-32768, -1, 0, 1, 511, 512, 32760, 32767};

static unsigned Hash(unsigned hash, const void *data, size_t size)
{
    const unsigned char *bytes = data;
    for (size_t i = 0; i < size; ++i)
        hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static void Event(unsigned value)
{
    assert(trace_count < sizeof(trace) / sizeof(trace[0]));
    trace[trace_count++] = value;
}

void GM_ConfigObjectAction(OBJECT *object, int action, int frame, int interpolation)
{
    Event(0);
    Event((unsigned char *)object - (unsigned char *)current);
    Event(action);
    Event(frame);
    Event(interpolation);
}

int GCL_ExecProc(int procedure, GCL_ARGS *arguments)
{
    assert(arguments && arguments->argc == 1);
    Event(1);
    Event(procedure);
    Event(arguments->argc);
    Event(arguments->argv[0]);
    if (seed / 768)
        current->f802 = 2;
    return 0;
}

int GV_RandU(int limit)
{
    Event(2);
    Event(limit);
    return 0;
}

void s03b_torture_800C447C(Work *work, int message, int value)
{
    assert(work == current);
    Event(3);
    Event(message);
    Event(value);
}

int GM_VoxEnd(void)
{
    int result = seed / 512 % 2;
    Event(4);
    Event(result);
    return result;
}

void TortureInfoKill(void)
{
    Event(5);
    Event(GM_GameStatus);
}

void s03b_torture_800C5420(Work *work, int tick)
{
    (void)work;
    (void)tick;
    assert(!"Round handoff must schedule the next action without running it");
}

static void Init(Work *work, GV_PAD *pad, GV_MSG messages[2])
{
    static const unsigned short flags[] = {0, 2, 0x8000, 0xffff};
    static const unsigned short modes[] = {0, 4, 0x8000, 0xffff};
    static const unsigned short recoveries[] = {1, 3, 256, 65535};
    static const unsigned short durations[] = {0, 1, 2, 65535};
    static const short counters[] = {0, 1, 2, 32767};
    static const int procedures[] = {-1, 0, 0x7fff};
    unsigned char *bytes = (unsigned char *)work;
    for (size_t i = 0; i < sizeof(*work); ++i)
        bytes[i] = (unsigned char)(i * 37 + seed * 11 + 3);
    work->f808 = (TTortureFn)(uintptr_t)0x12345678;
    work->f80C = 79;
    work->f810 = ticks[seed % 6];
    work->f834 = pad;
    work->f840 = procedures[seed / 6 % 3];
    work->body.action = seed & 1 ? 6 : 2;
    work->f800 = modes[seed / 2 % 4];
    work->f802 = flags[seed / 8 % 4];
    work->f804 = health[seed / 6 % 8];
    work->f818 = seed / 32 % 2;
    work->f81A = counters[seed / 64 % 4];
    work->f84A = recoveries[seed / 48 % 4];
    work->f84C = durations[seed / 192 % 4];
    work->f85C = seed / 256 % 3;
    work->f85E = 2;
    work->control.n_msg = seed % 3;
    work->control.msg = messages;
    pad->press = seed & 1 ? PAD_CIRCLE | PAD_SELECT : 0;
    messages[0].message[0] = seed & 1 ? 4 : 3;
    messages[1].message[0] = seed & 2 ? 4 : 3;
    GM_VitalityMax = 512;
    GM_GameStatus = 0x12563478;
}

static void Check(const TortureFixture *fixture)
{
    Work work;
    GV_PAD pad = {0};
    GV_MSG messages[2] = {0};
    seed = fixture->seed;
    current = &work;
    trace_count = 0;
    Init(&work, &pad, messages);
    int result = 0;
    switch (fixture->kind) {
    case 0: s03b_torture_800C5AF8(&work, ticks[seed % 6]); break;
    case 1: s03b_torture_800C3EB8(&work); break;
    case 2: result = s03b_torture_800C4314(&work); break;
    default: assert(!"Unknown torture fixture");
    }
    work.f834 = (GV_PAD *)(uintptr_t)0x80181000;
    work.control.msg = (GV_MSG *)(uintptr_t)0x80181100;
    if (work.f808 == s03b_torture_800C5420)
        work.f808 = (TTortureFn)(uintptr_t)0x800c5420;
    unsigned state = Hash(2166136261u, &work, sizeof(work));
    state = Hash(state, &GM_GameStatus, sizeof(GM_GameStatus));
    unsigned calls = Hash(2166136261u, trace, trace_count * sizeof(trace[0]));
    if (state != fixture->state || calls != fixture->trace ||
        trace_count != fixture->words || result != fixture->result) {
        fprintf(stderr, "Torture kind%d seed%d: state %08x/%08x, trace %08x/%08x, words %u/%u, result %d/%d\n",
                fixture->kind, seed, state, fixture->state, calls, fixture->trace,
                trace_count, fixture->words, result, fixture->result);
        abort();
    }
}

int main(void)
{
    for (size_t i = 0; i < sizeof(torture_fixtures) / sizeof(torture_fixtures[0]); ++i)
        Check(&torture_fixtures[i]);
    puts("PASS: 2432 original-MIPS torture round, recovery, and surrender comparisons");
    return 0;
}
