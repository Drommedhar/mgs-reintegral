#ifndef MGS_GARAGE_ROUTE_H
#define MGS_GARAGE_ROUTE_H

void MgsGarageRouteInit(void);
unsigned short MgsGarageRouteInput(unsigned frame, int player_ready, int *heading);
int MgsGarageRouteFinish(void);

#endif
