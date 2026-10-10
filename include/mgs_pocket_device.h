#ifndef MGS_POCKET_DEVICE_H
#define MGS_POCKET_DEVICE_H

#include <stdint.h>

typedef enum MgsPocketResult {
  MGS_POCKET_OK = 0,
  MGS_POCKET_NO_DEVICE = 1,
  MGS_POCKET_IO_ERROR = 2,
  MGS_POCKET_NEW_DEVICE = 3
} MgsPocketResult;

typedef struct MgsPocketDevice {
  void *context;
  MgsPocketResult (*probe)(void *context, int port);
  MgsPocketResult (*serial)(void *context, int port, uint32_t *serial);
  MgsPocketResult (*configure)(void *context, int port, int mode, int argument);
  MgsPocketResult (*start)(void *context, int port);
} MgsPocketDevice;

/* The provider must remain alive until it is replaced or removed. */
int MgsPocketSetDevice(const MgsPocketDevice *device);
MgsPocketResult MgsPocketProbe(int port);
MgsPocketResult MgsPocketSerial(int port, uint32_t *serial);
MgsPocketResult MgsPocketConfigure(int port, int mode, int argument);
MgsPocketResult MgsPocketStart(int port);

#endif
