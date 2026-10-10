#ifndef MGS_BONUS_ITEMS_H
#define MGS_BONUS_ITEMS_H

void MgsBonusItemsConfigure(int enabled);
int MgsBonusItemsEnabled(void);

/* Re-arm after a new inventory or a successfully loaded save. */
void MgsBonusItemsReset(void);
void MgsBonusItemsKeepLoadedInventory(void);

/* Called before the first campaign stage script and its checkpoint snapshot. */
int MgsBonusItemsApply(const char *stage);

#endif
