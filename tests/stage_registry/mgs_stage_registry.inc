static void *TestConstructor(void) { return &test_state; }
static CHARA MgsStageEntries_test[] = {{0x4321, TestConstructor}, {0, NULL}};
static const size_t test_regions[] = {0};
static const MgsStageDescriptor stage_registry[] = {
    {"test", MgsStageEntries_test, test_regions, 1}};
