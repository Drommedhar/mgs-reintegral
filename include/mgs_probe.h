#ifndef MGS_PROBE_H
#define MGS_PROBE_H

/* Explicit development probe; control functions return 1 on success. */
/* The bonus mode requires the optional loadout and validates original menu/actor transitions. */
int MgsProbeInit(const char *mode);
int MgsProbeVSync(void);
int MgsProbeFinish(void);

/* Observations from the mounted player actor; these never modify game state. */
void MgsProbeEscapeAim(int yaw, int locked);
void MgsProbeEscapeShot(void);

void MgsProbeBriefingSelector(int state, int animation, int timer, int selection);
void MgsProbeBriefingGraph(int scene, int state, int timer);

void MgsProbeDockRouteInit(int from_title);
int MgsProbeDockRouteUpdate(unsigned frame, int player_ready,
                           unsigned short *buttons, int *heading);
int MgsProbeDockRouteFinish(void);

unsigned short MgsProbeEndingInput(unsigned frame);
int MgsProbeEndingFinish(void);
unsigned short MgsProbeCompletedLoadInput(unsigned frame, int player_ready);
int MgsProbeCompletedLoadFinish(void);

#endif
