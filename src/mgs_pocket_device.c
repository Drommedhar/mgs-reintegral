#include "mgs_pocket_device.h"
#include <stddef.h>

static const MgsPocketDevice *provider;

int MgsPocketSetDevice(const MgsPocketDevice *device) {
  if (device && (!device->probe || !device->serial || !device->configure ||
                 !device->start))
    return 0;
  provider = device;
  return 1;
}

MgsPocketResult MgsPocketProbe(int port) {
  if (port < 0 || port > 1)
    return MGS_POCKET_IO_ERROR;
  return provider ? provider->probe(provider->context, port)
                  : MGS_POCKET_NO_DEVICE;
}

MgsPocketResult MgsPocketSerial(int port, uint32_t *serial) {
  if (port < 0 || port > 1 || !serial)
    return MGS_POCKET_IO_ERROR;
  *serial = 0;
  return provider ? provider->serial(provider->context, port, serial)
                  : MGS_POCKET_NO_DEVICE;
}

MgsPocketResult MgsPocketConfigure(int port, int mode, int argument) {
  if (port < 0 || port > 1)
    return MGS_POCKET_IO_ERROR;
  return provider ? provider->configure(provider->context, port, mode, argument)
                  : MGS_POCKET_NO_DEVICE;
}

MgsPocketResult MgsPocketStart(int port) {
  if (port < 0 || port > 1)
    return MGS_POCKET_IO_ERROR;
  return provider ? provider->start(provider->context, port)
                  : MGS_POCKET_NO_DEVICE;
}
