#include "../src/mgs_stages.c"
#include <assert.h>

void *StageCharacterEntries;
static const char *video_stage;
void MgsVideoStage(const char *name) { video_stage = name; }

int main(int argc, char **argv) {
  static const char *resident[] = {"init", "init_ve", "init_tux"};
  if (argc == 2) {
    MgsNativeSelectStage(argv[1]);
    return 0;
  }
  assert(MgsNativeConfigureStart("test", -1));
  for (size_t i = 0; i < sizeof(resident) / sizeof(resident[0]); ++i) {
    MgsNativeSelectStage("test");
    assert(MgsNativeStageTable() == MgsStageEntries_test);
    test_state = 91;
    MgsNativeSelectStage(resident[i]);
    assert(strcmp(video_stage, resident[i]) == 0);
    CHARA *table = MgsNativeStageTable();
    assert(table == StageCharacterEntries);
    assert(table[0].class_id == 0 && table[0].func == NULL);
    assert(test_state == 91);
    MgsNativeSelectStage("test");
    MgsNativeReloadOverlay();
    assert(test_state == 37);
  }
  puts("Resident-only init, init_ve and init_tux transitions passed");
  return 0;
}
