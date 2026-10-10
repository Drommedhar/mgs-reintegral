#ifndef MGS_ESCAPE_ROUTE_H
#define MGS_ESCAPE_ROUTE_H

void MgsEscapeRouteInit(void);
void MgsEscapeRouteAim(int yaw, int locked);
void MgsEscapeRouteShot(void);
unsigned short MgsEscapeRouteInput(unsigned frame, int *direction);
int MgsEscapeRouteFinish(void);

#endif
