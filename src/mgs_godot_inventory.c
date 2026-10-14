#include "mgs_godot_inventory.h"
#include "mgs_godot_context.h"
#include "mgs_godot_scene.h"
#include "transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static MgsInventoryPanel panels[MGS_INVENTORY_PANEL_LIMIT];
static uint32_t count, epoch, revision, shape = UINT32_MAX;
static MgsTextLayout layout;
static MgsSubtitleFrame description;
static unsigned char records[MGS_INVENTORY_PANEL_LIMIT * sizeof(MgsInventoryPanel) + 4096 * sizeof(MgsTextGlyph)];

int MgsGodotOwnsInventory(void)
{
    return MgsGodotSceneEnabled() && MgsGodotHasCapability(MGS_GODOT_INVENTORY_CAPABILITY);
}

void MgsGodotResetInventory(void)
{
    epoch = MgsGodotSceneEpoch();
    count = 0;
    shape = UINT32_MAX;
    memset(&description, 0, sizeof(description));
}

void MgsGodotSubmitInventoryPanel(MgsInventoryPanel panel, const char *name)
{
    if (!MgsGodotOwnsInventory()) return;
    if (epoch != MgsGodotSceneEpoch()) MgsGodotResetInventory();
    size_t size = strlen(name);
    if (count == MGS_INVENTORY_PANEL_LIMIT || size >= sizeof(panel.name)) {
        fputs("Godot inventory: panel or name capacity exceeded.\n", stderr);
        exit(EXIT_FAILURE);
    }
    memcpy(panel.name, name, size + 1);
    panels[count++] = panel;
}

MgsTextLayout *MgsGodotPrepareInventoryDescription(void)
{
    if (++revision == 0) ++revision;
    return &layout;
}

void MgsGodotInventoryDescription(MgsSubtitleFrame frame) { description = frame; }
void MgsGodotInventoryShape(unsigned value) { shape = value; }

void MgsGodotPublishInventory(void)
{
    static uint32_t last_epoch, last_revision;
    static unsigned char last_session[16];
    if (!MgsGodotOwnsInventory()) return;
    if (epoch != MgsGodotSceneEpoch()) MgsGodotResetInventory();
    struct {
        uint32_t schema, epoch, count, stride, shape, reserved[3];
        unsigned char session[16];
        MgsGodotSubtitleHeader description;
    } header = {.schema = 1, .epoch = epoch, .count = count, .stride = sizeof(MgsInventoryPanel), .shape = shape};
    _Static_assert(sizeof(header) == 176 && sizeof(MgsInventoryPanel) == 80, "Inventory wire layout");
    MgsGodotCopySessionId(header.session);
    MgsGodotSubtitleHeader *text = &header.description;
    *text = (MgsGodotSubtitleHeader){.schema = 1, .epoch = epoch, .revision = revision,
        .frame = description, .stride = sizeof(MgsTextGlyph)};
    memcpy(text->session, header.session, sizeof(text->session));
    if (description.active && (last_epoch != epoch || last_revision != revision ||
                               memcmp(last_session, header.session, sizeof(last_session)))) {
        text->has_layout = 1;
        text->width = layout.width;
        text->height = layout.height;
        text->count = (uint32_t)layout.count;
        memcpy(text->palette, layout.palette, sizeof(text->palette));
        last_epoch = epoch;
        last_revision = revision;
        memcpy(last_session, header.session, sizeof(last_session));
    }
    uint32_t panel_bytes = count * sizeof(*panels);
    uint32_t glyph_bytes = text->count * sizeof(MgsTextGlyph);
    memcpy(records, panels, panel_bytes);
    if (glyph_bytes) memcpy(records + panel_bytes, layout.glyphs, glyph_bytes);
    MgsGodotQueue(MGS_GODOT_INVENTORY, &header, sizeof(header), records, panel_bytes + glyph_bytes);
}
