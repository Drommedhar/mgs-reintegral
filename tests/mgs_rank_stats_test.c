#include "mgs_native.h"
#undef fprintf
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "../vendor/mgs/source/overlays/rank/onoda/rank/rank_stats.c"
#include "../vendor/mgs/source/overlays/rank/onoda/rank/rank_data.c"

typedef struct StatsFixture
{
    int input[7];
    uint32_t hash;
    int calls;
} StatsFixture;
#include "mgs_rank_stats_fixtures.h"

short linkvarbuf[MAX_LINKVARBUF];
static uint32_t trace_hash;
static int trace_calls;

static void TraceByte(unsigned int value)
{
    trace_hash = (trace_hash ^ value) * 16777619u;
}

static void TraceNumber(int value)
{
    uint32_t bits = (uint32_t)value;
    int index;
    for (index = 0; index < 4; ++index)
    {
        TraceByte(bits & 255);
        bits >>= 8;
    }
}

void MENU_Locate(int x, int y, int flags)
{
    trace_calls++;
    TraceNumber(1);
    TraceNumber(x);
    TraceNumber(y);
    TraceNumber(flags);
}

void MENU_Color(int red, int green, int blue)
{
    trace_calls++;
    TraceNumber(2);
    TraceNumber(red);
    TraceNumber(green);
    TraceNumber(blue);
}

int MENU_Printf(const char *format, ...)
{
    char text[64];
    va_list args;
    int size, index;
    va_start(args, format);
    size = vsnprintf(text, sizeof(text), format, args);
    va_end(args);
    assert(size >= 0 && size < sizeof(text));
    trace_calls++;
    TraceNumber(3);
    TraceNumber(size);
    for (index = 0; index < size; ++index)
        TraceByte((unsigned char)text[index]);
    return size;
}

static void Prepare(RankWork *work, const StatsFixture *fixture)
{
    static const int counts[] = {0, 1, 9, 10, 99, 100, 999, 1000};
    static const int hours[] = {0, 1, 9, 10, 99, 100, 150, 23};
    const int *input = fixture->input;
    int profile = input[4];
    memset(work, 0, sizeof(*work));
    work->field_498 = input[1];
    work->field_49C = input[2] & 1;
    work->field_4A0 = input[2] & 2;
    GM_GameLevel = input[3];
    work->time = input[5];
    work->field_494 = input[6];
    work->play_hours = hours[profile];
    work->play_minutes = profile * 7 % 60;
    work->play_seconds = profile * 11 % 60;
    GM_SaveCount = counts[profile];
    GM_ContinueCount = counts[(profile + 1) % 8];
    GM_EnemyWatchCount = counts[(profile + 2) % 8];
    GM_EnemyKillCount = counts[(profile + 3) % 8];
    GM_RationUseCount = counts[(profile + 4) % 8];
    trace_hash = 2166136261u;
    trace_calls = 0;
}

int main(void)
{
    RankWork work;
    unsigned int index;
    for (index = 0; index < sizeof(fixtures) / sizeof(fixtures[0]); ++index)
    {
        Prepare(&work, &fixtures[index]);
        if (fixtures[index].input[0])
            rank_800D705C(&work);
        else
            rank_800D536C(&work);
        if (trace_hash != fixtures[index].hash || trace_calls != fixtures[index].calls)
            fprintf(stderr, "ranking stats case %u: hash %u/%u, calls %d/%d\n",
                    index, trace_hash, fixtures[index].hash, trace_calls, fixtures[index].calls);
        assert(trace_hash == fixtures[index].hash);
        assert(trace_calls == fixtures[index].calls);
    }
    puts("3600 original ranking statistics traces passed");
    return 0;
}
