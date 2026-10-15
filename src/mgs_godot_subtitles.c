#include "mgs_godot_subtitles.h"
#include "mgs_godot_context.h"
#include "mgs_godot_scene.h"
#include "transport.h"
#include <string.h>

int MgsGodotOwnsSubtitles(void)
{
    return MgsGodotSceneEnabled() && MgsGodotHasCapability(MGS_GODOT_SUBTITLES_CAPABILITY);
}

void MgsGodotPublishSubtitles(void)
{
    static uint32_t last_epoch, last_revision;
    static unsigned char last_session[16];
    if (!MgsGodotOwnsSubtitles()) return;
    const MgsSubtitleView *view = MgsSubtitlesGetView();
    MgsGodotSubtitleHeader header = {
        .schema = 1, .epoch = MgsGodotSceneEpoch(), .revision = view->text_revision,
        .frame = view->frame, .stride = sizeof(MgsTextGlyph)
    };
    _Static_assert(sizeof(header) == 128, "Subtitle header wire layout");
    _Static_assert(sizeof(MgsTextGlyph) == 80, "Subtitle glyph wire layout");
    MgsGodotCopySessionId(header.session);
    const MgsTextLayout *layout = view->layout;
    if (layout && (last_epoch != header.epoch || last_revision != header.revision ||
                   memcmp(last_session, header.session, sizeof(last_session)))) {
        header.has_layout = 1;
        header.width = layout->width;
        header.height = layout->height;
        header.count = (uint32_t)layout->count;
        memcpy(header.palette, layout->palette, sizeof(header.palette));
        last_epoch = header.epoch;
        last_revision = header.revision;
        memcpy(last_session, header.session, sizeof(last_session));
    }
    MgsGodotQueue(MGS_GODOT_SUBTITLES, &header, sizeof(header),
                  layout ? layout->glyphs : NULL, header.count * sizeof(MgsTextGlyph));
}
