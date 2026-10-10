#ifndef MGS_LANGUAGE_H
#define MGS_LANGUAGE_H

#include <stdint.h>

int MgsLanguageConfigure(const char *text_pack, const char *voice_pack);
int MgsLanguageInspect(const char *path);
void MgsLanguageClose(void);
const char *MgsLanguageDescription(unsigned identity, int card_level);
const char *MgsLanguageText(const char *original);
const unsigned char *MgsLanguageGlyph(unsigned code, unsigned *descriptor);
int MgsLanguageUseEnglish(int original);
void MgsLanguageSelectStream(unsigned kind, unsigned disc, unsigned identity, unsigned sector);
int MgsLanguageStreamActive(void);
void MgsLanguageReadSector(unsigned sector, void *output);
void MgsLanguageCloseStream(void);

#endif
