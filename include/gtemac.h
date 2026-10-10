#ifndef MGS_GTEMAC_H
#define MGS_GTEMAC_H

#include <libgte.h>
#include <psyz/gte.h>

extern unsigned long psyz_scratchpad[256];
#define getScratchAddr(offset) (&psyz_scratchpad[(offset)])
#define gte_NormalClip(a, b, c, result) (*(int *)(result) = NormalClip((a), (b), (c)))
#define gte_CompMatrix(a, b, c) CompMatrix((MATRIX *)(a), (MATRIX *)(b), (MATRIX *)(c))
#define gte_rtpt_b() Psyz_GteCommand(0x00280030)
#define gte_stsxy3c(out) Psyz_GteStsxy3((unsigned int *)(out), (unsigned int *)(out) + 1, (unsigned int *)(out) + 2)
#define gte_ReadRotMatrix(out) ReadRotMatrix((MATRIX *)(out))
#define gte_nct_b() Psyz_GteCommand(0x00d80420)
#define gte_ncs() Psyz_GteCommand(0x00c8041e)
#define gte_llv0() Psyz_GteCommand(0x004a6012)
#define gte_ll() Psyz_GteCommand(0x004a6412)
#define gte_intpl() Psyz_GteCommand(0x00980011)
#define gte_sqr12() Psyz_GteCommand(0x00a80428)
#define gte_intpl_b() Psyz_GteCommand(0x00980011)
#define gte_ldlzc(value) Psyz_GteDataWrite(30, (value))
#define gte_stlzc(out) (*(unsigned int *)(out) = Psyz_GteDataRead(31))
#define gte_read_opz(out) ((out) = (int)Psyz_GteDataRead(24))
#define gte_stlvnl0(out) (*(unsigned int *)(out) = Psyz_GteDataRead(25))
#define gte_stlvnl1(out) (*(unsigned int *)(out) = Psyz_GteDataRead(26))
#define gte_stlvnl2(out) (*(unsigned int *)(out) = Psyz_GteDataRead(27))
#define gte_stsxy0(out) (*(unsigned int *)(out) = Psyz_GteDataRead(12))
#define gte_stsxy1(out) (*(unsigned int *)(out) = Psyz_GteDataRead(13))
#define gte_stsxy2(out) (*(unsigned int *)(out) = Psyz_GteDataRead(14))
#define gte_stsxy01(a, b) do { gte_stsxy0(a); gte_stsxy1(b); } while (0)

static inline void gte_ldsv(const SVECTOR *v)
{
    Psyz_GteDataWrite(9, (unsigned short)v->vx);
    Psyz_GteDataWrite(10, (unsigned short)v->vy);
    Psyz_GteDataWrite(11, (unsigned short)v->vz);
}

static inline void gte_stsv(SVECTOR *v)
{
    v->vx = (short)Psyz_GteDataRead(9);
    v->vy = (short)Psyz_GteDataRead(10);
    v->vz = (short)Psyz_GteDataRead(11);
}

static inline void gte_ldlvl(const VECTOR *v)
{
    Psyz_GteDataWrite(9, v->vx);
    Psyz_GteDataWrite(10, v->vy);
    Psyz_GteDataWrite(11, v->vz);
}

static inline void gte_ldfcdir(int x, int y, int z)
{
    Psyz_GteCtrlWrite(21, x);
    Psyz_GteCtrlWrite(22, y);
    Psyz_GteCtrlWrite(23, z);
}

static inline void gte_ld_intpol_sv0(const SVECTOR *v)
{
    gte_ldfcdir(v->vx, v->vy, v->vz);
}

#define gte_ld_intpol_sv1(v) gte_ldsv(v)

static inline void gte_ldsxy3(unsigned int a, unsigned int b, unsigned int c)
{
    Psyz_GteDataWrite(12, a);
    Psyz_GteDataWrite(13, b);
    Psyz_GteDataWrite(14, c);
}

static inline void MgsGteLoadVector(unsigned int reg, unsigned int xy, unsigned int z)
{
    Psyz_GteDataWrite(reg, xy);
    Psyz_GteDataWrite(reg + 1, z);
}

#define gte_ldVXYZ0(xy, z) MgsGteLoadVector(0, (xy), (z))
#define gte_ldVXYZ1(xy, z) MgsGteLoadVector(2, (xy), (z))
#define gte_ldVXYZ2(xy, z) MgsGteLoadVector(4, (xy), (z))

VECTOR *ApplyMatrixLV(MATRIX *matrix, VECTOR *input, VECTOR *output);
VECTOR *ApplyRotMatrixLV(VECTOR *input, VECTOR *output);
SVECTOR *ApplyMatrixSV(MATRIX *matrix, SVECTOR *input, SVECTOR *output);
MATRIX *MulMatrix2(MATRIX *left, MATRIX *right);

#endif
