#include "mgs_native.h"
#include "mgs_bonus_items.h"

#include "game/game.h"
#include "libgcl/libgcl.h"

#include <stdio.h>
#include <string.h>

static int enabled;
static int pending;

void MgsBonusItemsConfigure(int requested) {
  enabled = requested != 0;
  pending = enabled;
}

int MgsBonusItemsEnabled(void) { return enabled; }

void MgsBonusItemsReset(void) { pending = enabled; }
void MgsBonusItemsKeepLoadedInventory(void) { pending = 0; }

static int CampaignStage(const char *stage) {
  return stage && strlen(stage) >= 4 && (stage[0] == 's' || stage[0] == 'd') &&
         stage[1] >= '0' && stage[1] <= '9' && stage[2] >= '0' && stage[2] <= '9';
}

static int EquipmentDisabled(void) {
  for (int i = 0; i < IT_Max; ++i)
    if (GM_Items[i] < -1)
      return 1;
  for (int i = 0; i < WP_Max; ++i)
    if (GM_Weapons[i] < -1)
      return 1;
  return 0;
}

int MgsBonusItemsApply(const char *stage) {
  static const int items[] = {IT_Stealth, IT_Bandana};
  int granted = 0;
  if (!pending || !CampaignStage(stage))
    return 0;
  pending = 0;
  short ownership = (short)(1 | (EquipmentDisabled() ? IT_TYPE_DISABLED : 0));
  for (unsigned i = 0; i < sizeof(items) / sizeof(items[0]); ++i) {
    short *item = &GM_Items[items[i]];
    if (*item == -1 || *item == 0) {
      *item = ownership;
      GCL_SaveLinkVar(item);
      ++granted;
    }
  }
  printf("[native] Optional bonus inventory: stage=%s, granted=%d; select items "
         "through the original equipment menu.\n",
         stage, granted);
  return granted;
}
