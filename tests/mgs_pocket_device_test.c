#include "mgs_pocket_device.h"
#include <assert.h>
#include <stddef.h>

typedef struct TestDevice {
  int calls;
  int port;
  int mode;
  int argument;
  MgsPocketResult result;
} TestDevice;

static MgsPocketResult probe(void *context, int port) {
  TestDevice *device = context;
  ++device->calls;
  device->port = port;
  return device->result;
}

static MgsPocketResult serial(void *context, int port, uint32_t *value) {
  *value = 0xdead1234;
  return probe(context, port);
}

static MgsPocketResult configure(void *context, int port, int mode,
                                 int argument) {
  TestDevice *device = context;
  device->mode = mode;
  device->argument = argument;
  return probe(context, port);
}

int main(void) {
  TestDevice state = {0};
  MgsPocketDevice device = {&state, probe, serial, configure, probe};
  MgsPocketDevice invalid = device;
  uint32_t value = 1;
  assert(MgsPocketProbe(0) == MGS_POCKET_NO_DEVICE);
  assert(MgsPocketSerial(1, &value) == MGS_POCKET_NO_DEVICE && value == 0);
  assert(MgsPocketConfigure(0, 1, 10) == MGS_POCKET_NO_DEVICE);
  assert(MgsPocketStart(1) == MGS_POCKET_NO_DEVICE);
  assert(MgsPocketSetDevice(&device));
  state.result = MGS_POCKET_NEW_DEVICE;
  assert(MgsPocketProbe(1) == MGS_POCKET_NEW_DEVICE && state.port == 1);
  state.result = MGS_POCKET_OK;
  assert(MgsPocketSerial(0, &value) == MGS_POCKET_OK && value == 0xdead1234 &&
         state.port == 0);
  state.result = MGS_POCKET_IO_ERROR;
  assert(MgsPocketConfigure(1, 1, 10) == MGS_POCKET_IO_ERROR);
  assert(state.mode == 1 && state.argument == 10 && state.port == 1);
  assert(MgsPocketStart(0) == MGS_POCKET_IO_ERROR && state.calls == 4);
  invalid.serial = NULL;
  assert(!MgsPocketSetDevice(&invalid));
  assert(MgsPocketStart(1) == MGS_POCKET_IO_ERROR && state.calls == 5);
  assert(MgsPocketProbe(-1) == MGS_POCKET_IO_ERROR);
  assert(MgsPocketSerial(2, &value) == MGS_POCKET_IO_ERROR);
  assert(MgsPocketSerial(0, NULL) == MGS_POCKET_IO_ERROR);
  assert(MgsPocketConfigure(2, 1, 10) == MGS_POCKET_IO_ERROR);
  assert(MgsPocketStart(-1) == MGS_POCKET_IO_ERROR && state.calls == 5);
  assert(MgsPocketSetDevice(NULL));
  assert(MgsPocketProbe(1) == MGS_POCKET_NO_DEVICE);
  return 0;
}
