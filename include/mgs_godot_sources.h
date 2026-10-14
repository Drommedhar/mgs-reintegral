#ifndef MGS_GODOT_SOURCES_H
#define MGS_GODOT_SOURCES_H
void MgsGodotBeginSource(const void *data, unsigned name, int size);
void MgsGodotEndSource(void);
void MgsGodotSelectScriptSource(const void *data);
void MgsGodotPublishModelSource(const void *definition, unsigned model);
#endif
