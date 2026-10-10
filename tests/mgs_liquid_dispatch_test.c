#include "mgs_native.h"
#undef fprintf
#include "animal/liquid/liquid_native.h"
#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    unsigned state, trace, words, result;
} LiquidDispatchFixture;

#include "mgs_liquid_dispatch_fixtures.h"

int GM_PlayerStatus;
static unsigned trace[64], trace_count;
static int seed;
static LiquidWork *current;

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

static void Secondary(LiquidWork *work, int tick);

static void ActionEvent(LiquidWork *work, int tick, int kind)
{
    assert(work == current);
    Event(kind);
    Event(tick);
    Event(work->field_934);
    Event(work->field_938);
    Event(work->field_940);
    Event(work->field_944);
    Event(work->field_9A8);
    Event(work->target->class);
    Event(work->attack_target->class);
    if (kind < 2) {
        work->field_940 = tick == 0;
        if (seed / 6 % 3 == 2) {
            work->field_934 = 41;
            work->field_938 = seed & 1 ? -3 : 0;
            work->secondary_action = seed / 18 % 2 ? NULL : Secondary;
            work->field_944 = seed & 1;
        }
    } else {
        work->field_9A8 = tick ^ 0x1234;
    }
}

void liquid_800C82A4(LiquidWork *work, int tick)
{
    ActionEvent(work, tick, 0);
}

static void Primary(LiquidWork *work, int tick)
{
    ActionEvent(work, tick, 1);
}

static void Secondary(LiquidWork *work, int tick)
{
    ActionEvent(work, tick, 2);
}

void sna_act_helper2_helper2_80033054(int id, SVECTOR *vector)
{
    Event(3);
    Event(id);
    Event((unsigned char *)vector - (unsigned char *)current);
    Event(Hash(2166136261u, vector, sizeof(*vector)));
    vector->vx = (short)(seed * 19);
    vector->vy = (short)(-seed * 7);
}

#include "liquid_dispatch_helpers.inc"

static void Initialize(LiquidWork *work, TARGET *target, TARGET *attack, DG_OBJS *objects)
{
    static const int timers[] = {0, 1, -1, 39, INT_MAX, INT_MIN};
    static const int velocities[] = {-32769, -1, 0, 1, 32767, 65537};
    static const short spheres[] = {-2, 449, 450, 451, 1000, -32768};
    static const int statuses[] = {0, 0x20, 0x40, 0x60};
    unsigned char *bytes = (unsigned char *)work;
    for (size_t i = 0; i < sizeof(*work); ++i)
        bytes[i] = (unsigned char)(i * 37 + seed * 11 + 3);
    memset(target, 0xA5, sizeof(*target));
    memset(attack, 0xA5, sizeof(*attack));
    memset(objects, 0xA5, sizeof(*objects));
    work->body.objs = objects;
    work->target = target;
    work->attack_target = attack;
    work->action = seed / 6 % 3 ? Primary : NULL;
    work->secondary_action = seed / 18 % 2 ? Secondary : NULL;
    work->field_934 = timers[seed % 6];
    work->field_938 = timers[(seed + 3) % 6];
    work->field_948 = seed / 9 % 6 - 1;
    work->field_9A4 = seed / 144 % 6 - 1;
    work->field_90C = velocities[seed / 27 % 6];
    work->field_910 = 0x1234FFFF;
    work->control.r_sphere = spheres[seed % 6];
    work->control.mov.vy = (short)(-30000 + seed * 17);
    work->body.height = seed & 1 ? 1234 : -1234;
    work->control.grounded = seed / 2 % 2;
    GM_PlayerStatus = statuses[seed / 36 % 4];
}

static unsigned HashState(const LiquidWork *work)
{
    LiquidWork normalized = *work;
    normalized.target = (TARGET *)(uintptr_t)0x80181000;
    normalized.attack_target = (TARGET *)(uintptr_t)0x80181100;
    normalized.body.objs = (DG_OBJS *)(uintptr_t)0x80182000;
    assert(work->action == Primary || work->action == liquid_800C82A4);
    normalized.action = (LiquidAction)(uintptr_t)(
        work->action == Primary ? 0x801F0000 : 0x800C82A4);
    assert(work->secondary_action == NULL || work->secondary_action == Secondary);
    normalized.secondary_action = (LiquidAction)(uintptr_t)(
        work->secondary_action ? 0x801F0100 : 0);
    unsigned hash = Hash(2166136261u, &normalized, sizeof(normalized));
    hash = Hash(hash, work->target, sizeof(*work->target));
    hash = Hash(hash, work->attack_target, sizeof(*work->attack_target));
    return Hash(hash, work->body.objs, sizeof(*work->body.objs));
}

int main(void)
{
    _Static_assert(sizeof(LiquidWork) == 2636, "Original actor size");
    _Static_assert(sizeof(TARGET) == 72 && sizeof(DG_OBJS) == 72, "Original external data");
    for (seed = 0; seed < (int)(sizeof(liquid_dispatch_fixtures) /
                              sizeof(liquid_dispatch_fixtures[0])); ++seed) {
        LiquidWork work;
        TARGET target, attack;
        DG_OBJS objects;
        Initialize(&work, &target, &attack, &objects);
        current = &work;
        trace_count = 0;
        unsigned result = liquid_800CC2A0(&work);
        unsigned state = HashState(&work);
        unsigned calls = Hash(2166136261u, trace, trace_count * sizeof(*trace));
        const LiquidDispatchFixture *expected = &liquid_dispatch_fixtures[seed];
        if (state != expected->state || calls != expected->trace ||
            trace_count != expected->words || result != expected->result) {
            fprintf(stderr, "Liquid dispatch seed %d: state %08x/%08x, trace %08x/%08x, "
                            "words %u/%u, result %08x/%08x\n", seed, state, expected->state,
                    calls, expected->trace, trace_count, expected->words, result, expected->result);
            return 1;
        }
    }
    puts("864 Liquid dispatcher states and callback traces match original MIPS.");
    return 0;
}
