#include "mgs_godot_declarations.h"
#include <string.h>

static const void *script_data, *current_command;
static uint32_t script_size;
static MgsGodotDeclaration script_origin;

void MgsGodotSetScriptSource(const void *data, uint32_t size, const MgsGodotDeclaration *origin)
{
    script_data = data;
    script_size = size;
    script_origin = *origin;
}

const void *MgsGodotCommandScope(const void *command)
{
    const void *previous = current_command;
    current_command = command;
    return previous;
}

int MgsGodotCurrentDeclaration(MgsGodotDeclaration *origin)
{
    memset(origin, 0, sizeof(*origin));
    origin->offset = UINT32_MAX;
    uintptr_t offset = (uintptr_t)current_command - (uintptr_t)script_data;
    if (!script_data || !current_command || offset < 3 || offset >= script_size || script_size - offset < 3) return 0;
    const unsigned char *bytes = script_data;
    if (bytes[offset-3] != 0x60 || bytes[offset] != 0x99 || bytes[offset+1] != 0x06) return 0;
    *origin = script_origin;
    origin->offset = (uint32_t)offset - 3;
    return 1;
}
