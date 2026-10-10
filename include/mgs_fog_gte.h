#ifndef MGS_FOG_GTE_H
#define MGS_FOG_GTE_H

#include "gtemac.h"
#include <libgpu.h>
#include <stddef.h>
#include <string.h>

static inline void MgsFogLoadColor(unsigned int reg, const void *packet, size_t offset)
{
    unsigned int color;
    const char *field = (const char *)packet + offset + offsetof(P_TAG, r0) - 4;
    memcpy(&color, field, sizeof(color));
    Psyz_GteDataWrite(reg, color);
}

static inline void MgsFogStoreColor(unsigned int reg, void *packet, size_t offset)
{
    unsigned int color = Psyz_GteDataRead(reg);
    char *field = (char *)packet + offset + offsetof(P_TAG, r0) - 4;
    memcpy(field, &color, sizeof(color));
}

#define gte_ldrgb_s0(p) MgsFogLoadColor(6, (p), 4)
#define gte_ldrgb_s1(p) MgsFogLoadColor(6, (p), 12)
#define gte_ldrgb_s2(p) MgsFogLoadColor(6, (p), 20)
#define gte_ldrgb_s3(p) MgsFogLoadColor(6, (p), 28)
#define gte_ldrgb_f0(p) MgsFogLoadColor(22, (p), 4)
#define gte_ldrgb_f1(p) MgsFogLoadColor(20, (p), 12)
#define gte_ldrgb_f2(p) MgsFogLoadColor(21, (p), 20)
#define gte_ldrgb_f3(p) MgsFogLoadColor(22, (p), 28)
#define gte_ldrgb_f1_t(p) MgsFogLoadColor(20, (p), 16)
#define gte_ldrgb_f2_t(p) MgsFogLoadColor(21, (p), 28)
#define gte_ldrgb_f3_t(p) MgsFogLoadColor(22, (p), 40)
#define gte_strgb_s0(p) MgsFogStoreColor(22, (p), 4)
#define gte_strgb_s1(p) MgsFogStoreColor(22, (p), 12)
#define gte_strgb_s2(p) do { MgsFogStoreColor(20, (p), 12); MgsFogStoreColor(21, (p), 20); } while (0)
#define gte_strgb_s3(p) do { gte_strgb_s2(p); MgsFogStoreColor(22, (p), 28); } while (0)
#define gte_strgb_s2_t(p) do { MgsFogStoreColor(20, (p), 16); MgsFogStoreColor(21, (p), 28); } while (0)
#define gte_strgb_s3_t(p) do { gte_strgb_s2_t(p); MgsFogStoreColor(22, (p), 40); } while (0)
#define gte_strgb_s4(p) MgsFogStoreColor(22, (void *)(p), 40)
#define gte_ldRGB(p) MgsFogStoreColor(22, (p), 4)
#define gte_ldRGB2(p) MgsFogStoreColor(22, (p), 16)
#define gte_ldRGB3(p) MgsFogStoreColor(22, (p), 28)
#define gte_ldRGBC(color) Psyz_GteDataWrite(6, (color))
#define gte_ldVZ2_2(p) Psyz_GteDataWrite(5, ((PVECTOR *)(p))[2].vz)
#define gte_strgb3_2(p) Psyz_GteStRgb3((CVECTOR *)(p), (CVECTOR *)(p) + 1, (CVECTOR *)(p) + 2)
#define gte_ldVXY0(v) Psyz_GteDataWrite(0, (v))
#define gte_ldVZ0(v) Psyz_GteDataWrite(1, (v))
#define gte_ldVXY1(v) Psyz_GteDataWrite(2, (v))
#define gte_ldVZ1(v) Psyz_GteDataWrite(3, (v))
#define gte_ldVXY2(v) Psyz_GteDataWrite(4, (v))
#define gte_ldVZ2(v) Psyz_GteDataWrite(5, (v))
#define gte_dpcs_b() Psyz_GteCommand(0x00780010)
#define gte_dpct() Psyz_GteCommand(0x00F8002A)
#define gte_nclip_b() Psyz_GteCommand(0x01400006)
/* PsyZ executes GTE commands synchronously; MIPS pipeline delay slots are unnecessary. */
#define gte_nop() ((void)0)

#endif
