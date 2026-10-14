#include "mgs_save_actions.h"
#include "mgs_save_menu.h"
#include "mgs_save_ui.h"
#include <assert.h>

static uint32_t serial;
static const MgsSaveFile files[] = {{"BISLPM-99999G0123@BA",8192}, {"BISLPM-99999G0456HCB",8192}};

static void Open(int loading)
{
    MgsSaveUiBeginFrame(1);
    MgsSaveUiStart(loading, "BISLPM-99999G", 1);
    MgsSaveUiStorage(0, files, 1, 0);
    MgsSaveUiStorage(1, files, 2, 13);
    MgsSaveMenuStep(0x20000001, -1, 0);
}

static MgsSaveAction Action(unsigned kind, uint32_t target)
{
    const MgsSaveView *view = MgsSaveUiGetView();
    return (MgsSaveAction){1, ++serial, 3, view->generation, view->revision,
        view->state, view->message, view->selected_id, kind, target};
}

static void Submit(unsigned kind, uint32_t target)
{
    MgsSaveAction action = Action(kind, target);
    assert(MgsSaveMenuSubmit(&action));
    assert(MgsSaveMenuActionStatus().id == serial);
    assert(MgsSaveMenuActionStatus().status == MGS_SAVE_ACTION_PENDING);
    assert(!MgsSaveMenuSubmit(&action));
}

static void BrowseAndConfirm(void)
{
    Open(0);
    const MgsSaveView *view = MgsSaveUiGetView();
    uint32_t id = view->entries[2].id;
    Submit(MGS_SAVE_SELECT, id);
    assert(!MgsSaveMenuStep(0x20000001, -1, MGS_SAVE_ACCEPT).ready);
    assert(view->cursor == 2 && view->selected_id == id);
    assert(MgsSaveMenuActionStatus().status == MGS_SAVE_ACTION_APPLIED);
    Submit(MGS_SAVE_ACTIVATE, id);
    MgsSaveResponse response = MgsSaveMenuStep(0x20000001, -1, 0);
    assert(response.ready && response.value == 1);
    response = MgsSaveMenuStep(0x20000000, 1, 0);
    assert(response.ready && response.value == 1);
    assert(!MgsSaveMenuStep(0x10000000, 1, 0).ready);
    assert(view->state == MGS_SAVE_CONFIRM && view->choice == 1);
    Submit(MGS_SAVE_BACK, 0);
    response = MgsSaveMenuStep(0x10000000, 1, 0);
    assert(response.ready && response.value == 1);
    MgsSaveMenuStep(0x20000000, 1, 0);
    Submit(MGS_SAVE_ACTIVATE, id);
    assert(MgsSaveMenuStep(0x20000000, 1, 0).value == 1);
    MgsSaveMenuStep(0x10000000, 1, 0);
    Submit(MGS_SAVE_CONFIRM_ACTION, 0);
    response = MgsSaveMenuStep(0x10000000, 1, MGS_SAVE_CANCEL);
    assert(response.ready && response.value == 0);
}

static void NewAndLoad(void)
{
    Open(0);
    Submit(MGS_SAVE_NEW, 0);
    assert(MgsSaveMenuStep(0x20000001, -1, 0).value == 1);
    assert(MgsSaveMenuStep(0x20000000, 1, 0).value == 16);
    MgsSaveMenuStep(0xc1000001, 1, 0);
    Submit(MGS_SAVE_CONTINUE, 0);
    assert(MgsSaveMenuStep(0xc1000001, 1, 0).ready);
    Open(1);
    MgsSaveAction action = Action(MGS_SAVE_NEW, 0);
    assert(MgsSaveMenuSubmit(&action));
    assert(MgsSaveMenuActionStatus().status == MGS_SAVE_ACTION_INVALID);
    Submit(MGS_SAVE_ACTIVATE, MgsSaveUiGetView()->entries[0].id);
    assert(MgsSaveMenuStep(0x20000001, -1, 0).value == 0);
    assert(MgsSaveMenuStep(0x20000000, 0, 0).value == 0);
}

static void RejectStaleAndBusy(void)
{
    Open(0);
    MgsSaveAction action = Action(MGS_SAVE_ACTIVATE, MgsSaveUiGetView()->entries[2].id);
    --action.revision;
    assert(MgsSaveMenuSubmit(&action));
    assert(MgsSaveMenuActionStatus().status == MGS_SAVE_ACTION_STALE);
    Submit(MGS_SAVE_ACTIVATE, MgsSaveUiGetView()->entries[2].id);
    MgsSaveAction overlap = Action(MGS_SAVE_NEW, 0);
    assert(!MgsSaveMenuSubmit(&overlap));
    MgsSaveUiStorage(1, NULL, 0, 15);
    assert(!MgsSaveMenuStep(0x20000001, -1, 0).ready);
    assert(MgsSaveMenuActionStatus().status == MGS_SAVE_ACTION_STALE);
    Submit(MGS_SAVE_NEW, 0);
    Open(0);
    assert(MgsSaveMenuActionStatus().status == MGS_SAVE_ACTION_STALE);
    MgsSaveMenuStep(0x01000009, 0, 0);
    action = Action(MGS_SAVE_BACK, 0);
    assert(MgsSaveMenuSubmit(&action));
    assert(MgsSaveMenuActionStatus().status == MGS_SAVE_ACTION_BUSY);
    Open(0);
    action = Action(MGS_SAVE_CONFIRM_ACTION, 0);
    assert(MgsSaveMenuSubmit(&action));
    assert(MgsSaveMenuActionStatus().status == MGS_SAVE_ACTION_INVALID);
    Submit(MGS_SAVE_NEW, 0);
    MgsSaveUiEnd();
    assert(MgsSaveMenuActionStatus().status == MGS_SAVE_ACTION_STALE);
}

int main(void)
{
    BrowseAndConfirm();
    NewAndLoad();
    RejectStaleAndBusy();
    return 0;
}
