#include "mgs_native.h"
#include "mgs_bonus_items.h"

#include "game/game.h"
#include "libgcl/libgcl.h"

#include <assert.h>

RadioMemory radio_memory[RADIO_MEMORY_COUNT];
int gTotalFrameTime;
static char area[16] = "s00a";
static short history[8];

char *GM_GetArea(int flag) {
  assert(flag == 0);
  return area;
}

int GM_SetArea(int stage_id, char *name) {
  assert(stage_id == GV_StrCode(name));
  assert(strlen(name) < sizeof(area));
  snprintf(area, sizeof(area), "%s", name);
  return 0;
}

void GM_GetAreaHistory(short *buffer) { memcpy(buffer, history, sizeof(history)); }

void GM_SetAreaHistory(short *buffer) { memcpy(history, buffer, sizeof(history)); }

static void OriginalInventory(int level) {
  GM_GameLevel = level;
  GCL_InitVar();
  GM_Item = IT_None;
  GM_Weapon = -1;
  GM_Vitality = GM_VitalityMax = 256;
  for (int i = 0; i < IT_Max; ++i)
    GM_Items[i] = -1;
  for (int i = 0; i < WP_Max; ++i)
    GM_Weapons[i] = -1;
  GM_Items[IT_Cigs] = GM_Items[IT_Scope] = 1;
  GCL_SaveVar();
}

static void CheckOnlyOwnershipChanges(void) {
  short expected[MAX_LINKVARBUF];
  MgsBonusItemsConfigure(1);
  for (int level = -1; level <= 3; ++level) {
    OriginalInventory(level);
    memcpy(expected, linkvarbuf, sizeof(expected));
    assert(MgsBonusItemsEnabled());
    assert(MgsBonusItemsApply(NULL) == 0);
    assert(MgsBonusItemsApply("s") == 0);
    assert(MgsBonusItemsApply("init") == 0);
    assert(MgsBonusItemsApply("title") == 0);
    assert(MgsBonusItemsApply("opening") == 0);
    assert(memcmp(linkvarbuf, expected, sizeof(expected)) == 0);
    assert(MgsBonusItemsApply("d00a") == 2);
    expected[47] = expected[48] = 1;
    assert(memcmp(linkvarbuf, expected, sizeof(expected)) == 0);
    assert(GM_Items[IT_Stealth] == 1 && GM_Items[IT_Bandana] == 1);
    assert(GM_Item == IT_None && GM_Weapon == -1 && GM_ClearFlag == 0);
  }
}

static void CheckContinueAndRealSaveRoundTrip(void) {
  unsigned int save_buffer[2048] = {0};
  MgsBonusItemsConfigure(1);
  OriginalInventory(2);
  assert(MgsBonusItemsApply("s00a") == 2);
  GM_Items[IT_Stealth] = GM_Items[IT_Bandana] = -1;
  GCL_RestoreVar();
  assert(GM_Items[IT_Stealth] == 1 && GM_Items[IT_Bandana] == 1);
  int saved_bytes = GCL_MakeSaveFile((char *)save_buffer);
  assert(saved_bytes > 0 && (unsigned)saved_bytes < sizeof(save_buffer));
  memset(linkvarbuf, 0, sizeof(short) * MAX_LINKVARBUF);
  assert(GCL_SetLoadFile((char *)save_buffer) == 1);
  assert(GM_Items[IT_Stealth] == 1 && GM_Items[IT_Bandana] == 1);
  assert(GM_GameLevel == 2 && GM_Item == IT_None && GM_Weapon == -1);
  assert(MgsBonusItemsApply("s01a") == 0);
  GM_Items[IT_Stealth] = GM_Items[IT_Bandana] = -1;
  assert(MgsBonusItemsApply("s02a") == 0);
  save_buffer[8] ^= 1;
  assert(GCL_SetLoadFile((char *)save_buffer) == 0);
  assert(MgsBonusItemsApply("s02a") == 0);
}

static void CheckLoadedInventoryRestrictions(void) {
  unsigned int save_buffer[2048] = {0};
  MgsBonusItemsConfigure(1);
  OriginalInventory(1);
  assert(MgsBonusItemsApply("s00a") == 2);
  GM_Items[IT_Stealth] = (short)(IT_TYPE_DISABLED | 1);
  GM_Items[IT_Bandana] = -1;
  GM_Items[IT_Scope] = (short)(IT_TYPE_DISABLED | 1);
  GCL_SaveVar();
  GCL_MakeSaveFile((char *)save_buffer);
  assert(GCL_SetLoadFile((char *)save_buffer) == 1);
  assert(MgsBonusItemsApply("s03c") == 1);
  assert(GM_Items[IT_Stealth] == (short)(IT_TYPE_DISABLED | 1));
  assert(GM_Items[IT_Bandana] == (short)(IT_TYPE_DISABLED | 1));
  GM_Items[IT_Bandana] = -1;
  GCL_RestoreVar();
  assert(GM_Items[IT_Bandana] == (short)(IT_TYPE_DISABLED | 1));
  assert(GM_Item == IT_None);
}

static void CheckDefaultAndNewGame(void) {
  short expected[MAX_LINKVARBUF];
  MgsBonusItemsConfigure(0);
  OriginalInventory(0);
  memcpy(expected, linkvarbuf, sizeof(expected));
  assert(!MgsBonusItemsEnabled());
  assert(MgsBonusItemsApply("s00a") == 0);
  assert(memcmp(expected, linkvarbuf, sizeof(expected)) == 0);
  MgsBonusItemsConfigure(1);
  assert(MgsBonusItemsApply("s00a") == 2);
  GM_Items[IT_Bandana] = -1;
  assert(MgsBonusItemsApply("s01a") == 0);
  assert(GM_Items[IT_Bandana] == -1);
  OriginalInventory(3);
  assert(MgsBonusItemsApply("d00a") == 2);
  MgsBonusItemsConfigure(0);
  assert(!MgsBonusItemsEnabled());
  assert(GM_Items[IT_Stealth] == 1 && GM_Items[IT_Bandana] == 1);
}

static unsigned SaveCrc(const unsigned char *bytes, unsigned size) {
  unsigned table[256], value = ~0u;
  for (unsigned i = 0; i < 256; ++i) {
    unsigned entry = i;
    for (unsigned bit = 0; bit < 8; ++bit)
      entry = (entry >> 1) ^ ((entry & 1) ? 0xedb88320u : 0);
    table[i] = entry;
  }
  for (unsigned i = 0; i < size; ++i)
    value = (value >> 8) ^ table[(value ^ bytes[i]) & 255];
  return ~value;
}

static void CheckMalformedStageName(void) {
  unsigned int save_buffer[2048] = {0};
  unsigned char *bytes = (unsigned char *)save_buffer;
  short expected[MAX_LINKVARBUF];
  MgsBonusItemsConfigure(0);
  OriginalInventory(1);
  unsigned size = (unsigned)GCL_MakeSaveFile((char *)bytes);
  assert(size > 48 && size < sizeof(save_buffer));
  assert(save_buffer[1] == SaveCrc(bytes + 8, size - 8));
  memset(bytes + 32, 'A', 16);
  save_buffer[1] = SaveCrc(bytes + 8, size - 8);
  memcpy(expected, linkvarbuf, sizeof(expected));
  assert(GCL_SetLoadFile((char *)bytes) == 0);
  assert(memcmp(expected, linkvarbuf, sizeof(expected)) == 0);
}

int main(void) {
  CheckOnlyOwnershipChanges();
  CheckContinueAndRealSaveRoundTrip();
  CheckLoadedInventoryRestrictions();
  CheckDefaultAndNewGame();
  CheckMalformedStageName();
  puts("Bonus items: original checkpoint/save persistence, equipment restrictions, "
       "five difficulties and unchanged default inventory pass.");
  return 0;
}
