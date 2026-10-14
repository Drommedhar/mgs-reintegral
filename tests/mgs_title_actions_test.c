#include "mgs_title_actions.h"
#include <assert.h>
#include <stdio.h>

static MgsTitleFrame view = {.active=1, .mode=7};

static MgsTitleAction Command(unsigned kind, unsigned target)
{
    unsigned revision = MgsTitleActionsView(view, 1, 3, 7);
    return (MgsTitleAction){1, MgsTitleActionsResult().id+1, 3, 7, revision, kind, target};
}

static void Accepted(unsigned kind, unsigned target)
{
    MgsTitleAction action = Command(kind, target), taken;
    assert(MgsTitleActionsSubmit(&action));
    assert(MgsTitleActionsTake(view, 1, &taken));
    assert(taken.kind == kind && taken.target == target);
    MgsTitleActionsComplete(MGS_TITLE_APPLIED);
}

static void Invalid(unsigned kind, unsigned target)
{
    MgsTitleAction action = Command(kind, target);
    assert(MgsTitleActionsSubmit(&action));
    assert(MgsTitleActionsResult().status == MGS_TITLE_INVALID);
}

int main(void)
{
    for (unsigned target=0; target<5; ++target) {
        Accepted(MGS_TITLE_SELECT,target);
        Accepted(MGS_TITLE_ACTIVATE,target);
    }
    Accepted(MGS_TITLE_BACK,0);
    Invalid(MGS_TITLE_SELECT,5);
    Invalid(MGS_TITLE_BACK,1);
    Invalid(0,0);
    view.mode=21;
    for (unsigned target=0; target<4; ++target) Accepted(MGS_TITLE_ACTIVATE,target);
    Invalid(MGS_TITLE_ACTIVATE,4);
    view.extreme=1;
    Accepted(MGS_TITLE_SELECT,4);
    Accepted(MGS_TITLE_ACTIVATE,4);
    for (unsigned mode=18; mode<=19; ++mode) {
        view.mode=mode;
        Accepted(MGS_TITLE_SELECT,0);
        Accepted(MGS_TITLE_ACTIVATE,1);
        Accepted(MGS_TITLE_BACK,0);
        Invalid(MGS_TITLE_SELECT,2);
    }
    for (unsigned mode=0; mode<=6; ++mode) {
        if (mode==2 || mode==3) continue;
        view.mode=mode;
        Accepted(MGS_TITLE_ACTIVATE,0);
        Invalid(MGS_TITLE_BACK,0);
        Invalid(MGS_TITLE_SELECT,0);
    }
    const unsigned unavailable[] = {2,3,13,100};
    for (unsigned i=0; i<sizeof(unavailable)/sizeof(*unavailable); ++i) {
        view.mode=unavailable[i];
        Invalid(MGS_TITLE_ACTIVATE,0);
        Invalid(MGS_TITLE_BACK,0);
        Invalid(MGS_TITLE_SELECT,0);
    }
    view.mode=7;
    MgsTitleAction action=Command(MGS_TITLE_SELECT,2), taken;
    --action.epoch;
    assert(MgsTitleActionsSubmit(&action) && MgsTitleActionsResult().status==MGS_TITLE_STALE);
    action=Command(MGS_TITLE_SELECT,2);
    --action.generation;
    assert(MgsTitleActionsSubmit(&action) && MgsTitleActionsResult().status==MGS_TITLE_STALE);
    action=Command(MGS_TITLE_SELECT,2);
    assert(MgsTitleActionsSubmit(&action));
    assert(!MgsTitleActionsSubmit(&action));
    ++action.id;
    assert(!MgsTitleActionsSubmit(&action));
    view.selection=1;
    assert(!MgsTitleActionsTake(view,1,&taken) && MgsTitleActionsResult().status==MGS_TITLE_STALE);
    action=Command(MGS_TITLE_SELECT,2);
    assert(MgsTitleActionsSubmit(&action));
    assert(!MgsTitleActionsTake(view,0,&taken) && MgsTitleActionsResult().status==MGS_TITLE_STALE);
    puts("Title actions: menu/difficulty/storage limits, identity, single flight and transition guards pass.");
    return 0;
}
