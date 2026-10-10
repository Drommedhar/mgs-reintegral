#ifndef MGS_GODOT_SCENE_H
#define MGS_GODOT_SCENE_H

struct _DG_DEF;
struct _DG_OBJS;
struct _DG_CHANL;
void MgsGodotRegisterModel(struct _DG_DEF *definition, unsigned identity);
enum { MGS_GODOT_GENERATED_LIGHT = 1 };
void MgsGodotRegisterGeneratedModel(struct _DG_DEF *definition, unsigned kind);
void MgsGodotRegisterInstance(struct _DG_OBJS *objects);
void MgsGodotRemoveInstance(struct _DG_OBJS *objects);
void MgsGodotCaptureScene(struct _DG_CHANL *channel, int buffer_index);
int MgsGodotSceneEnabled(void);
int MgsGodotOwnsPart(struct _DG_OBJS *objects, int part, int buffer_index);
void MgsGodotSortWorld(struct _DG_CHANL *channel, int buffer_index);

#endif
