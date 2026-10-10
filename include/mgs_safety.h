#ifndef MGS_SAFETY_H
#define MGS_SAFETY_H

int MgsSafetyConfigure(const char *cue_path);
int MgsSafetyDiscNumber(void);
int SafetyCheck(int minute, int second, int sector);

#endif
