#include "mgs_native.h"
#undef fprintf
#include "overlays/s07b/chara/meryl07b/meryl07b.h"
#include "overlays/s07b/chara/psyco/psyco_work.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

SVECTOR DG_ZeroVector;
DG_CHANL DG_Chanls[3];
int GV_Time;
short linkvarbuf[96];
#include "mantis_helpers.inc"
#include "mantis_memory.inc"

typedef struct {
    int64_t input[7];
    int64_t output[9];
} HelperFixture;
#include "mgs_mantis_fixtures.h"

static void TargetSetup(TARGET *target, const int64_t *in)
{
    target->damaged = in[1];
    target->damage = in[2];
    target->faint = in[3];
    target->a_mode = in[4];
    target->weapon = in[5];
}

static void TargetResult(const TARGET *target, int64_t *out)
{
    out[0] = target->damaged;
    out[1] = target->damage;
    out[2] = target->faint;
    out[3] = target->a_mode;
    out[4] = target->weapon;
    out[5] = target->force.vx;
    out[6] = target->force.vy;
    out[7] = target->force.vz;
    out[8] = target->force.pad;
}

static void VerifyFixture(const HelperFixture *fixture)
{
    static const unsigned short traps[6] = {0x1234, 0xbeef, 0x7fff, 0x4321, 0, 0xffff};
    Meryl07bWork meryl = {0};
    PsychoWork mantis = {0};
    TARGET target = {0};
    DG_OBJS objects = {0};
    int64_t out[9] = {0};
    const int64_t *in = fixture->input;
    int op = in[0];
    meryl.target = &target;
    mantis.target = &target;
    mantis.body.objs = &objects;
    target.vital = 321;
    target.force = (SVECTOR){10, -20, 30, 0};
    if (op == 0)
    {
        meryl.control.turn.vy = in[1];
        meryl.control.rot.vy = in[2];
        s07b_800C4974(&meryl);
        out[0] = meryl.control.turn.vz;
    }
    else if (op == 1)
    {
        meryl.control.evt.n_inside = in[2];
        memcpy(meryl.control.evt.inside, traps, sizeof(traps));
        out[0] = s07b_800C46F0(&meryl.control, in[3], in[1]);
    }
    else if (op == 2 || op == 3)
    {
        meryl.flags_84c = in[1];
        target.class = in[2];
        meryl.field_8c2 = in[3];
        if (op == 2) s07b_800C54C0(&meryl, in[3]);
        else s07b_800C5514(&meryl);
        out[0] = meryl.flags_84c;
        out[1] = target.class;
        out[2] = meryl.field_8c2;
    }
    else if (op == 4 || op == 8)
    {
        TargetSetup(&target, in);
        if (op == 4) s07b_800C5554(&target);
        else s07b_800CCBB0(&target);
        TargetResult(&target, out);
    }
    else if (op == 7)
    {
        mantis.flags_850 = in[1];
        mantis.control.step.vy = in[2];
        mantis.recoil.vy = in[3];
        s07b_800CBDA0(&mantis);
        out[0] = mantis.control.step.vy;
        out[1] = mantis.recoil.vy;
    }
    else
    {
        mantis.field_84C = in[1];
        mantis.flags_850 = in[2];
        target.class = in[3];
        mantis.invulnerable_time = in[4];
        mantis.dodge_time = in[5];
        objects.flag = in[6];
        if (op == 5) s07b_800CC9E8(&mantis, in[4]);
        else if (op == 6) s07b_800CCA80(&mantis);
        else s07b_800CCA10(&mantis);
        out[0] = (unsigned)mantis.field_84C;
        out[1] = mantis.flags_850;
        out[2] = target.class;
        out[3] = mantis.invulnerable_time;
        out[4] = mantis.dodge_time;
        out[5] = objects.flag;
    }
    for (unsigned index = 0; index < 9; ++index)
    {
        if (out[index] != fixture->output[index])
            fprintf(stderr, "op %d field %u: %lld != %lld\n", op, index,
                    (long long)out[index], (long long)fixture->output[index]);
        assert(out[index] == fixture->output[index]);
    }
}

static void TestHideoChannel(void)
{
    PsychoWork work = {0};
    OT_TYPE tables[3][2] = {0};
    for (int channel = 0; channel < 3; ++channel)
        for (int bank = 0; bank < 2; ++bank)
            DG_Chanls[channel].ot[bank] = &tables[channel][bank];
    for (int bank = 0; bank < 2; ++bank) {
        GV_Time = bank;
        s07b_800CC174(&work, 0);
        assert(getaddr(&tables[2][bank]) == (u_long)&work.white[bank]);
        s07b_800CC174(&work, 32);
        assert(getaddr(&tables[2][bank]) == (u_long)&work.black[bank]);
        assert(getaddr(&work.black[bank]) == (u_long)&work.hideo[bank]);
        assert(!getaddr(&tables[0][bank]) && !getaddr(&tables[1][bank]));
        s07b_800CC174(&work, 64);
        assert(work.hideo[bank].x0 == 260 && work.hideo[bank].y2 == 24);
        s07b_800CC174(&work, 255);
        assert(getaddr(&tables[2][bank]) == (u_long)&work.white[bank]);
    }
}

static void TestMemoryProfile(void)
{
    MEMCARD first, repeat, other;
    MEMCARD *cards[2] = {&first, NULL};
    NativeMemoryProfile(&first, 42);
    NativeMemoryProfile(&repeat, 42);
    NativeMemoryProfile(&other, 43);
    assert(!memcmp(&first, &repeat, sizeof(first)));
    assert(memcmp(&first, &other, sizeof(first)));
    for (unsigned seed = 1; seed <= 16; ++seed) {
        NativeMemoryProfile(&first, seed);
        assert(first.file_count >= 3 && first.file_count <= 6);
        for (int i = 0; i < first.file_count; ++i) {
            int recognized = 0;
            for (unsigned j = 0; j < COUNTOF(s07b_dword_800C3788); ++j)
                recognized |= !strcmp(first.files[i].name + 2, s07b_dword_800C3788[j].name);
            assert(recognized);
            for (int j = 0; j < i; ++j)
                assert(strcmp(first.files[i].name, first.files[j].name));
        }
        unsigned short mask = s07b_800D8410(cards);
        assert(mask & 0x8000);
        assert(!(mask & ~0xbf33));
    }
    memset(&first, 0, sizeof(first));
    first.file_count = 1;
    memcpy(first.files[0].name, "BISLPM-86023", sizeof("BISLPM-86023"));
    assert(s07b_800D8410(cards) == TITLE_CASTLEVANIA);
    cards[1] = &first;
    assert(s07b_800D8410(cards) == TITLE_CASTLEVANIA);
    memcpy(first.files[0].name, "BIUNKNOWN-0", sizeof("BIUNKNOWN-0"));
    assert(s07b_800D8410(cards) == 0);
}

int main(void)
{
    _set_error_mode(_OUT_TO_STDERR);
    for (unsigned i = 0; i < sizeof(helper_fixtures) / sizeof(helper_fixtures[0]); ++i)
        VerifyFixture(&helper_fixtures[i]);
    puts("58 original MIPS Meryl/Mantis movement, trap, damage and immunity cases match.");
    TestHideoChannel();
    TestMemoryProfile();
    return 0;
}
