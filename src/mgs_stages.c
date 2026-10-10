#include "mgs_stages.h"
#include "charadef.h"
#include "mgs_overlay.h"
#include "mgs_video.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  const char *name;
  CHARA *characters;
  const size_t *regions;
  size_t region_count;
} MgsStageDescriptor;

#include "mgs_overlay_regions.inc"
#include "mgs_stage_registry.inc"

extern void *StageCharacterEntries;
static CHARA empty_stage[] = {{0, NULL}};
static const MgsStageDescriptor *current_stage;
static const char *initial_stage;
static int boot_selected;
static int initial_map = -1;
static int development_load;
static char resource_stage[9];

static void ReleaseOverlayState(void) {
  MgsOverlayRelease(overlay_regions,
                    sizeof(overlay_regions) / sizeof(overlay_regions[0]));
}

static const MgsStageDescriptor *FindStage(const char *name) {
  for (size_t i = 0; i < sizeof(stage_registry) / sizeof(stage_registry[0]);
       ++i) {
    if (strcmp(name, stage_registry[i].name) == 0)
      return &stage_registry[i];
  }
  return NULL;
}

int MgsNativeStageAvailable(const char *name) {
  return name && FindStage(name) != NULL;
}

const char *MgsNativeCurrentStage(void) {
  return current_stage ? current_stage->name : NULL;
}

const char *MgsNativeResourceStage(void) {
  return resource_stage[0] ? resource_stage : NULL;
}

int MgsNativeConfigureStart(const char *name, int map) {
  const MgsStageDescriptor *stage = FindStage(name);
  if (!stage) {
    fprintf(stderr, "Initial stage '%s' is not linked into this build.\n",
            name);
    return 0;
  }
  initial_stage = stage->name;
  initial_map = map;
  boot_selected = 0;
  if (!MgsOverlayCapture(overlay_regions,
                         sizeof(overlay_regions) / sizeof(overlay_regions[0])))
    return 0;
  if (atexit(ReleaseOverlayState) != 0) {
    ReleaseOverlayState();
    fprintf(stderr, "Cannot register overlay snapshot cleanup.\n");
    return 0;
  }
  return 1;
}

void MgsNativeReloadOverlay(void) {
  if (!current_stage) {
    fprintf(stderr, "No native stage selected for overlay load.\n");
    abort();
  }
  MgsOverlayRestore(overlay_regions, current_stage->regions,
                    current_stage->region_count);
  printf("[native] overlay=%s reset_regions=%zu\n", current_stage->name,
         current_stage->region_count);
}

void *MgsNativeStageTable(void) {
  return current_stage ? current_stage->characters : empty_stage;
}

void MgsNativeSelectStage(const char *name) {
  if (strlen(name) >= sizeof(resource_stage)) {
    fputs("Resource stage name exceeds its disc directory field.\n", stderr);
    exit(EXIT_FAILURE);
  }
  memcpy(resource_stage, name, strlen(name) + 1);
  int resident_only = strcmp(name, "init") == 0 ||
                      strcmp(name, "init_ve") == 0 ||
                      strcmp(name, "init_tux") == 0;
  current_stage = resident_only ? NULL : FindStage(name);
  if (!current_stage && !resident_only) {
    fprintf(stderr, "Stage '%s' has not been linked into this native build.\n",
            name);
    exit(EXIT_FAILURE);
  }
  StageCharacterEntries = MgsNativeStageTable();
  MgsVideoStage(name);
  printf("[native] stage=%s\n", name);
}

const char *MgsNativeBootStage(const char *requested) {
  development_load = 0;
  if (!boot_selected && strcmp(requested, "title") == 0) {
    boot_selected = 1;
    if (initial_stage && strcmp(initial_stage, requested) != 0) {
      development_load = 1;
      printf("[native] Explicit stage development entry: %s\n", initial_stage);
      return initial_stage;
    }
  }
  return requested;
}

int MgsNativeBootMap(int requested) {
  if (development_load && initial_map >= 0) {
    printf("[native] Explicit stage development map: %04x\n", initial_map);
    return initial_map;
  }
  return requested;
}
