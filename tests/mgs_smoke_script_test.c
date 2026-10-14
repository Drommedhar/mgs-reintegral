#include "mgs_native.h"
#undef fprintf
#include "libdg/libdg.h"
#include "anime/animconv/anime.h"
#include "strcode.h"
#include <assert.h>
#ifdef _WIN32
__declspec(dllimport) unsigned int __stdcall SetErrorMode(unsigned int mode);
#endif

SVECTOR DG_ZeroVector;
static int random_unsigned, random_signed, spawns;
static PRESCRIPT spawned;
static ANIMATION *spawn_animation;
int GV_RandU(int limit) { assert(limit==1024); ++random_unsigned; return 177; }
int GV_RandS(int limit) { assert(limit==32); return ++random_signed-2; }
void *NewAnime(MATRIX *world, int map, ANIMATION *animation)
{
    assert(!world && !map && animation && animation->pre_script);
    ++spawns; spawn_animation=animation; spawned=*animation->pre_script;
    return animation;
}
#ifndef SMOKE_SCRIPT_HELPERS
#define SMOKE_SCRIPT_HELPERS "smoke_script_helpers.inc"
#endif
#include SMOKE_SCRIPT_HELPERS

static void CheckScript(const unsigned char *before, const char *after, size_t size,
                        const int *rgb, const int *decay, int groups, int divisor, unsigned value)
{
    unsigned char expected[256];
    assert(size<=sizeof(expected)); memcpy(expected,before,size);
    for(int group=0;group<groups;++group)
        for(int channel=0;channel<3;++channel) {
            expected[rgb[group]+channel]=(unsigned char)value;
            expected[decay[group]+channel]=(unsigned char)(-(((int)value-1)/divisor));
        }
    assert(!memcmp(expected,after,size));
}

int main(int argc, char **argv)
{
#ifdef _WIN32
    SetErrorMode(0x0001u|0x0002u); /* No UI for private pre-fix crash reproduction. */
#endif
    SVECTOR pos={123,-456,789,0}, speed={-12,34,-56,0};
    const unsigned values[]={176,177,0,255};
    const int socom_rgb[]={12,35,63,91}, socom_decay[]={26,54,82,110};
    const int smoke_rgb[]={6}, smoke_decay[]={34};
    const int line_rgb[]={12,55,108,151}, line_decay[]={46,94,142,190};
    for(unsigned test=0;test<4;++test) {
        unsigned value=values[test]; unsigned char before[256];
        random_unsigned=random_signed=spawns=0;
        if(argc<2 || !strcmp(argv[1],"socom")) {
            memcpy(before,anim_data_800CC1CC,sizeof(anim_data_800CC1CC));
            AN_Unknown_800D70E4(&pos,(char)value,(char)value,(char)value);
            CheckScript(before,anim_data_800CC1CC,sizeof(anim_data_800CC1CC),socom_rgb,socom_decay,4,7,value);
            assert(spawns==1 && random_unsigned==1 && random_signed==0);
            assert(spawn_animation==&anm_800C3BCC && !memcmp(&spawned.pos,&pos,sizeof(pos)));
            assert(!memcmp(&spawned.speed,&DG_ZeroVector,sizeof(speed)) && spawned.scr_num==0 && spawned.s_anim==27);
        }
        random_unsigned=random_signed=spawns=0;
        if(argc<2 || !strcmp(argv[1],"smoke3")) {
            memcpy(before,s13a_dword_800E3280,sizeof(s13a_dword_800E3280));
            AN_Unknown_800DC6AC(&pos,&speed,(char)value,(char)value,(char)value);
            CheckScript(before,s13a_dword_800E3280,sizeof(s13a_dword_800E3280),smoke_rgb,smoke_decay,1,10,value);
            assert(spawns==1 && random_unsigned==1 && random_signed==3);
            assert(spawn_animation==&anm_800C3744 && spawned.pos.vx==122 && spawned.pos.vy==-456 && spawned.pos.vz==790);
            assert(!memcmp(&spawned.speed,&speed,sizeof(speed)) && spawned.scr_num==0 && spawned.s_anim==27);
        }
        random_unsigned=random_signed=spawns=0;
        if(argc<2 || !strcmp(argv[1],"smoke_ln")) {
            memcpy(before,d16e_dword_800D2BF8,sizeof(d16e_dword_800D2BF8));
            AN_Smoke_800CE2C4(&pos,&speed,2,3,(char)value,(char)value,(char)value);
            CheckScript(before,d16e_dword_800D2BF8,sizeof(d16e_dword_800D2BF8),line_rgb,line_decay,4,15,value);
            assert(spawns==1 && !random_unsigned && !random_signed);
            assert(spawn_animation==&d16e_dword_800C361C && !memcmp(&spawned.pos,&pos,sizeof(pos)));
            assert(!memcmp(&spawned.speed,&speed,sizeof(speed)) && spawned.scr_num==3 && spawned.s_anim==0);
        }
    }
    puts("Live smoke script RGB/decay writes, unchanged bytes, spawn fields and RNG calls passed");
    return 0;
}
