#include "mgs_godot_sources.h"
#include "mgs_godot_declarations.h"
#include "mgs_sha256.h"
#include "mgs_stages.h"
#include "mgs_safety.h"
#include "transport.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const void *source;
static uint32_t source_name, source_size;
static unsigned char source_digest[32];

static void SourceFailure(const char *reason)
{
    fprintf(stderr, "Godot model source: %s\n", reason);
    exit(EXIT_FAILURE);
}

void MgsGodotBeginSource(const void *data, unsigned name, int size)
{
    if (!MgsGodotHasCapability(64)) return;
    unsigned extension = (name >> 16) + 'a';
    if (source) SourceFailure("nested resource loading");
    if (extension != 'k' && extension != 'z' && !(extension == 'g' && MgsGodotHasCapability(128))) return;
    if (!data || size <= 0 || size > 64 * 1024 * 1024) SourceFailure("invalid resource size");
    source = data;
    source_name = name;
    source_size = (uint32_t)size;
    MgsSha256(data, source_size, source_digest);
}

void MgsGodotEndSource(void)
{
    source = NULL;
}

void MgsGodotSelectScriptSource(const void *data)
{
    if (!MgsGodotHasCapability(128)) return;
    if (source != data || (source_name >> 16) + 'a' != 'g') SourceFailure("script source was not bounded");
    MgsGodotDeclaration origin = {source_name, 0, {0}, {0}};
    const char *stage = MgsNativeResourceStage();
    if (!stage || strlen(stage) > 8) SourceFailure("invalid script stage");
    memcpy(origin.stage, stage, strlen(stage));
    memcpy(origin.digest, source_digest, 32);
    MgsGodotSetScriptSource(data, source_size, &origin);
}

void MgsGodotPublishModelSource(const void *definition, unsigned model)
{
    if (!MgsGodotHasCapability(64)) return;
    if (!source) SourceFailure("model registered outside a bounded source load");
    uintptr_t offset = (uintptr_t)definition - (uintptr_t)source;
    const char *stage = MgsNativeResourceStage();
    if (offset >= source_size || !stage || strlen(stage) > 8) SourceFailure("invalid model source span or stage");
    uint32_t header[4] = {model & 0xffffu, source_name, source_size, (uint32_t)offset};
    unsigned char tail[60] = {0};
    memcpy(tail, stage, strlen(stage));
    MgsGodotCopySessionId(tail + 8);
    memcpy(tail + 24, source_digest, 32);
    uint32_t disc = (uint32_t)MgsSafetyDiscNumber();
    memcpy(tail + 56, &disc, sizeof(disc));
    MgsGodotQueue(MGS_GODOT_MODEL_SOURCE, header, sizeof(header), tail,
        MgsGodotHasCapability(256) ? 60 : 56);
}
