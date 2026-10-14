#ifndef MGS_GODOT_SCENE_H
#define MGS_GODOT_SCENE_H

#include <stdint.h>

struct _DG_DEF;
struct _DG_OBJS;
struct _DG_CHANL;
struct _DG_PRIM;
void MgsGodotRegisterModel(struct _DG_DEF *definition, unsigned identity);
enum { MGS_GODOT_GENERATED_LIGHT = 1 };
enum { MGS_GODOT_PART_VISIBLE = 1, MGS_GODOT_PART_SHADOW = 2, MGS_GODOT_PART_TRANSPARENT = 4 };
enum { MGS_GODOT_LEGACY_GLOW = 0x10000 };
enum { MGS_GODOT_EFFECT_SNOW = 0x10000 };
enum { MGS_GODOT_ALARM_ACTIVE = 0x20000, MGS_GODOT_ALARM_GLASS = 0x40000 };
void MgsGodotRegisterGeneratedModel(struct _DG_DEF *definition, unsigned kind);
void MgsGodotRegisterInstance(struct _DG_OBJS *objects);
void MgsGodotUseLiveTextures(struct _DG_OBJS *objects);
uint32_t MgsGodotGetInstanceId(struct _DG_OBJS *objects);
void MgsGodotRemoveInstance(struct _DG_OBJS *objects);
void MgsGodotSetCamouflage(struct _DG_OBJS *objects, float amount, unsigned tint);
void MgsGodotClearCamouflage(struct _DG_OBJS *objects);
void MgsGodotCaptureScene(struct _DG_CHANL *channel, int buffer_index);
int MgsGodotSceneEnabled(void);
int MgsGodotRetainObjects(const struct _DG_OBJS *objects);
int MgsGodotOwnsPart(struct _DG_OBJS *objects, int part, int buffer_index);
unsigned MgsGodotModelIdentity(const struct _DG_OBJS *objects);
int MgsGodotLegacyPart(struct _DG_OBJS *objects, int part);
int MgsGodotLegacyShadowPacket(const void *packet, int type);
void MgsGodotSortWorld(struct _DG_CHANL *channel, int buffer_index);
void MgsGodotRegisterEffect(struct _DG_PRIM *prim, unsigned texture, int first_face, int face_count);
void MgsGodotRegisterRipple(struct _DG_PRIM *prim, unsigned texture);
void MgsGodotRegisterLamp(struct _DG_PRIM *prim, unsigned texture);
void MgsGodotRegisterBeam(struct _DG_PRIM *prim, unsigned texture);
void MgsGodotRemoveEffect(struct _DG_PRIM *prim);
unsigned MgsGodotEffectTexture(const struct _DG_PRIM *prim, int face);
int MgsGodotOwnsEffect(struct _DG_PRIM *prim, int face, const void *packet);
uint32_t MgsGodotAppendEffects(struct _DG_CHANL *channel, int buffer_index,
                              unsigned char *destination, uint32_t capacity);
void MgsGodotRegisterWeaponLight(struct _DG_PRIM *prim);
void MgsGodotRemoveWeaponLight(struct _DG_PRIM *prim);
void MgsGodotRegisterAlarmLight(struct _DG_OBJS *beam, int fill);
void MgsGodotRemoveAlarmLight(struct _DG_OBJS *beam);
unsigned MgsGodotCopyTemporaryLights(void *destination, unsigned capacity);
uint32_t MgsGodotAppendLights(unsigned char *destination, uint32_t capacity);

#endif
