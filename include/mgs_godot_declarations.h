#ifndef MGS_GODOT_DECLARATIONS_H
#define MGS_GODOT_DECLARATIONS_H
#include <stdint.h>
typedef struct {
    uint32_t script, offset;
    char stage[8];
    unsigned char digest[32];
} MgsGodotDeclaration;
void MgsGodotSetScriptSource(const void *data, uint32_t size, const MgsGodotDeclaration *origin);
const void *MgsGodotCommandScope(const void *command);
int MgsGodotCurrentDeclaration(MgsGodotDeclaration *origin);
#endif
