#ifndef MGS_GODOT_UI_H
#define MGS_GODOT_UI_H

#define MGS_GODOT_UI_CAPABILITY 65536u

int MgsGodotOwnsGoggles(void);
void MgsGodotGogglesUpdate(const void *owner, int mode, int timer, int scan, int heading);
void MgsGodotGogglesRemove(const void *owner);
int MgsGodotGogglesLayer(unsigned source);
void MgsGodotGogglesLayerUpdate(int layer, int visible, int x, int y);
void MgsGodotPublishUi(void);

#endif
