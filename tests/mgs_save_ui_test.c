#include "mgs_save_ui.h"
#include "mgs_save_menu.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static const char family[] = "BISLPM-99999G";
static MgsSaveFile first[] = {{"BISLPM-99999G0123@BA",8192}, {"other-game",8192}};
static MgsSaveFile second[] = {{"BISLPM-99999G0123@BA",8192}, {"BISLPM-99999G0456HCB",8192}};

static void Open(void)
{
    MgsSaveUiBeginFrame(1);
    MgsSaveUiStart(0,family,1);
    MgsSaveUiStorage(0,first,2,0);
    MgsSaveUiStorage(1,second,2,13);
    MgsSaveUiPresent(3,0x20000001,-1,NULL);
}

static void Catalog(void)
{
    Open();
    const MgsSaveView *view=MgsSaveUiGetView();
    assert(view->active && view->state==MGS_SAVE_BROWSE && view->count==3 && view->can_create);
    assert(view->entries[0].id!=view->entries[1].id);
    const MgsSaveEntry *row=&view->entries[2];
    assert(row->metadata_valid && row->hours==4 && row->minutes==56 && row->disc==2 && row->area==3);
    assert(row->difficulty==1 && !row->completion);
    MgsSaveTarget target;
    assert(MgsSaveUiResolve(view->generation,view->revision,row->id,&target));
    assert(target.storage==1 && target.file==1 && !strcmp(target.name,second[1].name));
    assert(MgsSaveUiResolveNew(view->generation,view->revision,&target));
    assert(target.storage==1 && target.file==16 && !target.name[0]);
    MgsSaveUiPresent(4,0,1,second[1].name);
    assert(view->selected_id==row->id);
}

static void Revisions(void)
{
    Open();
    const MgsSaveView *view=MgsSaveUiGetView();
    uint32_t id=view->entries[2].id, revision=view->revision, generation=view->generation;
    MgsSaveTarget target={.storage=9};
    MgsSaveUiStorage(1,second,2,13);
    assert(view->revision==revision);
    MgsSaveFile reversed[]={second[1],second[0]};
    MgsSaveUiStorage(1,reversed,2,13);
    assert(view->entries[1].id==id && view->revision!=revision);
    assert(!MgsSaveUiResolve(generation,revision,id,&target) && target.storage==9);
    assert(MgsSaveUiResolve(generation,view->revision,id,&target) && target.file==0);
    MgsSaveUiStorage(1,NULL,0,-1);
    assert(view->count==1 && !view->can_create);
    assert(!MgsSaveUiResolve(generation,view->revision,id,&target));
    assert(!MgsSaveUiResolveNew(generation,view->revision,&target));
    MgsSaveUiStart(1,family,1);
    MgsSaveUiStorage(1,second,2,13);
    MgsSaveUiPresent(3,0,-1,NULL);
    assert(view->generation!=generation && view->count==2 && !view->can_create);
    assert(!MgsSaveUiResolve(generation,view->revision,view->entries[0].id,&target));
    assert(!MgsSaveUiResolveNew(view->generation,view->revision,&target));
}

static void MetadataAndState(void)
{
    Open();
    MgsSaveFile examples[]={first[0],first[0],first[0]};
    examples[0].name[13]=':';
    examples[0].name[14]='A';
    examples[1].name[15]|=0x40;
    examples[1].name[16]|=0x40;
    examples[2].name[13]|=0x40;
    examples[2].name[19]='C';
    MgsSaveUiStorage(0,examples,3,12);
    const MgsSaveView *view=MgsSaveUiGetView();
    assert(view->entries[0].completion && view->entries[0].metadata_valid);
    assert(view->entries[1].difficulty==4 && view->entries[2].difficulty==0);
    examples[0].name[16]='?';
    MgsSaveUiStorage(0,examples,3,12);
    assert(!view->entries[0].metadata_valid && view->count==5);
    MgsSaveTarget target;
    MgsSaveUiPresent(5,0x10000000,0,NULL);
    assert(view->state==MGS_SAVE_CONFIRM);
    assert(!MgsSaveUiResolveNew(view->generation,view->revision,&target));
    MgsSaveUiPresent(1,0x01000009,0,NULL);
    assert(view->state==MGS_SAVE_BUSY && view->message==9);
    MgsSaveUiPresent(2,0xc1000001,0,NULL);
    assert(view->state==MGS_SAVE_RESULT && view->message==1);
    MgsSaveUiBeginFrame(1);
    assert(!view->active && !MgsSaveUiResolve(view->generation,view->revision,view->entries[0].id,&target));
    MgsSaveUiEnd();
    assert(!view->active && !view->count);
}

static void Capacity(void)
{
    MgsSaveFile files[MGS_SAVE_FILE_LIMIT];
    for (unsigned index=0;index<MGS_SAVE_FILE_LIMIT;++index) {
        files[index]=first[0];
        files[index].name[19]='A'+index;
    }
    MgsSaveUiStart(0,family,2);
    MgsSaveUiStorage(0,files,15,0);
    MgsSaveUiStorage(1,files,15,1);
    assert(MgsSaveUiGetView()->count==30 && !MgsSaveUiGetView()->can_create);
    MgsSaveUiEnd();
    MgsSaveUiBeginFrame(0);
    MgsSaveUiStart(0,family,1);
    MgsSaveUiStorage(0,files,15,0);
    MgsSaveUiPresent(3,0,0,NULL);
    assert(!MgsSaveUiGetView()->active && !MgsSaveUiGetView()->count);
}

static void Menu(void)
{
    Open();
    MgsSaveResponse response = MgsSaveMenuStep(0x20000001,-1,0);
    assert(!response.ready && MgsSaveUiGetView()->cursor==3);
    response=MgsSaveMenuStep(0x20000001,-1,MGS_SAVE_ACCEPT);
    assert(response.ready && response.value==1);
    response=MgsSaveMenuStep(0x20000000,1,0);
    assert(response.ready && response.value==16);
    assert(MgsSaveMenuStep(0x01000009,1,0).ready);
    assert(!MgsSaveMenuStep(0xc1000001,1,0).ready);
    assert(MgsSaveMenuStep(0xc1000001,1,MGS_SAVE_ACCEPT).ready);

    Open();
    MgsSaveMenuStep(0x20000001,-1,0);
    MgsSaveMenuStep(0x20000001,-1,MGS_SAVE_UP);
    assert(MgsSaveMenuStep(0x20000001,-1,MGS_SAVE_ACCEPT).value==1);
    response=MgsSaveMenuStep(0x20000000,1,0);
    assert(response.ready && response.value==1);
    assert(!MgsSaveMenuStep(0x10000000,1,0).ready);
    assert(MgsSaveUiGetView()->choice==1);
    assert(MgsSaveMenuStep(0x10000000,1,MGS_SAVE_ACCEPT).value==1);
    MgsSaveMenuStep(0x20000000,1,MGS_SAVE_UP);
    MgsSaveMenuStep(0x20000000,1,MGS_SAVE_UP);
    assert(MgsSaveMenuStep(0x20000000,1,MGS_SAVE_ACCEPT).value==-1);
    assert(MgsSaveMenuStep(0x20000001,-1,0).value==0);
    response=MgsSaveMenuStep(0x20000000,0,0);
    assert(response.ready && response.value==0);
    MgsSaveMenuStep(0x10000000,0,MGS_SAVE_UP);
    assert(MgsSaveMenuStep(0x10000000,0,MGS_SAVE_ACCEPT).value==0);
    assert(MgsSaveMenuStep(0x20000000,0,MGS_SAVE_CANCEL).value==-1);
    assert(MgsSaveMenuStep(0x20000001,-1,0).value==-1);

    Open();
    MgsSaveUiLocation(3,"\x80" "D\xc0" "o\xa0" "c\xe0" "k");
    assert(!strcmp(MgsSaveUiGetView()->entries[2].location,"Dock"));
    MgsSaveUiLocation(3,"\x80" "B\x80" "l\x80" "a\x80" "s\x80" "t\x90\x01\x80" "Furnace");
    assert(!strcmp(MgsSaveUiGetView()->entries[2].location,"Blast Furnace"));
    MgsSaveMenuStep(0x20000001,-1,0);
    MgsSaveMenuStep(0x20000001,-1,MGS_SAVE_UP);
    MgsSaveMenuStep(0x20000001,-1,MGS_SAVE_ACCEPT);
    MgsSaveUiStorage(1,NULL,0,-1);
    assert(!MgsSaveMenuStep(0x20000000,1,0).ready);
    MgsSaveUiStart(1,family,1);
    MgsSaveUiStorage(0,first,2,13);
    assert(MgsSaveMenuStep(0x20000001,-1,MGS_SAVE_ACCEPT).value==0);
    response=MgsSaveMenuStep(0x20000000,0,0);
    assert(response.ready && response.value==0 && !MgsSaveUiGetView()->can_create);
}

int main(void)
{
    Catalog();
    Revisions();
    MetadataAndState();
    Capacity();
    MgsSaveUiBeginFrame(1);
    Menu();
    puts("Save UI catalog: unified entries, routing, capacity, stale actions and metadata pass.");
    return 0;
}
