#include "mgs_subtitles.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char *text;
    size_t size, capacity;
    uint32_t revision;
    MgsTextLayout layout;
} SubtitlePage;

static SubtitlePage pages[2];
static unsigned current;
static uint32_t revision;
static MgsSubtitleView view;

void MgsSubtitlesBeginFrame(void)
{
    memset(&view, 0, sizeof(view));
}

void MgsSubtitlesReset(void)
{
    for (unsigned i = 0; i < 2; ++i) {
        free(pages[i].text);
        MgsTextLayoutFree(&pages[i].layout);
    }
    memset(pages, 0, sizeof(pages));
    current = 0;
    MgsSubtitlesBeginFrame();
}

MgsTextLayout *MgsSubtitlesPrepare(const char *native_text)
{
    unsigned next = current ^ 1u;
    if (view.frame.active && view.text == pages[next].text) next = current;
    SubtitlePage *page = &pages[next];
    size_t size = strlen(native_text);
    if (page->capacity < size + 1) {
        char *allocation = realloc(page->text, size + 1);
        if (!allocation) {
            fputs("Subtitle presentation: cannot retain native text.\n", stderr);
            exit(EXIT_FAILURE);
        }
        page->text = allocation;
        page->capacity = size + 1;
    }
    memcpy(page->text, native_text, size + 1);
    page->size = size;
    if (++revision == 0) ++revision;
    page->revision = revision;
    current = next;
    page->layout.count = 0;
    return &page->layout;
}

void MgsSubtitlesPresent(MgsSubtitleFrame frame)
{
    const SubtitlePage *page = &pages[current];
    view.frame = frame;
    view.text_revision = page->revision;
    view.text_bytes = page->size;
    view.text = page->text;
    view.layout = &page->layout;
}

const MgsSubtitleView *MgsSubtitlesGetView(void)
{
    return &view;
}
