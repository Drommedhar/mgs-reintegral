#include "mgs_native.h"
#undef fprintf
#include <assert.h>
#include <stdint.h>
#include <stdio.h>

#include "countdown_helpers.inc"
#include "mgs_countdown_fixtures.h"

int GV_Time;
static unsigned int trace_hash;
static int radar_ticks;

void MgsRadarSetCountdown(int ticks) { radar_ticks = ticks; }

static unsigned int HashBytes(unsigned int hash, const void *data,
                              size_t size) {
  const unsigned char *bytes = data;
  for (size_t i = 0; i < size; i++)
    hash = (hash ^ bytes[i]) * 16777619u;
  return hash;
}

void sub_8003FD50(MenuPrim *prim, int x, int y, int digit, RadioUnknown *shape,
                  int abe) {
  int values[] = {1, x, y, digit, shape == &s19b_dword_800C327C, abe};
  assert(prim &&
         (shape == &s19b_dword_800C327C || shape == &s19b_dword_800C3258));
  trace_hash = HashBytes(trace_hash, values, sizeof(values));
}

void GCL_ForceExecProc(int proc, GCL_ARGS *args) {
  int values[] = {2, proc, args->argv[0]};
  assert(args->argc == 1);
  trace_hash = HashBytes(trace_hash, values, sizeof(values));
}

static unsigned int HashPackets(const OT_TYPE *ot, const unsigned char *buffer,
                                size_t size) {
  unsigned int hash = 2166136261u;
  const P_TAG *packet = nextPrim(ot);
  int count = 0;
  while ((uintptr_t)packet != 0xffffff) {
    unsigned char length = getlen(packet);
    assert((const unsigned char *)packet >= buffer);
    const unsigned char *payload = &packet->r0;
    assert(payload + length * 4 <= buffer + size);
    hash = HashBytes(hash, &length, sizeof(length));
    hash = HashBytes(hash, payload, length * 4);
    packet = nextPrim(packet);
    assert(++count <= 11);
  }
  assert(count == 11);
  return hash;
}

static void CheckFixture(const struct CountdownFixture *fixture) {
  _Alignas(16) unsigned char buffer[1024];
  OT_TYPE ot = {0};
  MenuPrim prim = {0};
  MenuWork work = {0};
  DG_TEX textures[2] = {{0x1111, 1, 0, 0x25, 0x567, 20, 40, 65, 10},
                        {0x2222, 1, 0, 0x35, 0x678, 90, 120, 65, 8}};
  memset(buffer, 0x5a, sizeof(buffer));
  setaddr(&ot, 0xffffff);
  prim.next = buffer;
  prim.ot = (u_long *)&ot;
  work.prim = &prim;
  warn1_texture = &textures[0];
  warn2_texture = &textures[1];
  GV_Time = fixture->tick;
  countdown_time = fixture->time;
  countdown_proc = 123;
  trace_hash = 2166136261u;
  radar_ticks = -1;
  s19b_countdwn_800C3C90(&work, (u_long *)&ot);
  assert(radar_ticks == fixture->time);
  assert(countdown_time == fixture->remaining);
  assert(countdown_proc == fixture->proc);
  assert(trace_hash == fixture->trace_hash);
  assert(HashPackets(&ot, buffer, sizeof(buffer)) == fixture->packet_hash);
}

int main(void) {
  for (size_t i = 0;
       i < sizeof(countdown_fixtures) / sizeof(countdown_fixtures[0]); i++)
    CheckFixture(&countdown_fixtures[i]);
  puts("252 original-MIPS countdown timer, callback, digit, and packet "
       "comparisons passed.");
  return 0;
}
