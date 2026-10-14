#include <assert.h>
#include <stdio.h>
void Psyz_AudioPumpWait(void) {}
#include <stdlib.h>
#include <SDL3/SDL.h>
#include "transport.h"

static void check_events(int expected)
{
    SDL_Event event;
    int count = 0;
    while (SDL_PollEvent(&event)) {
        if (event.type != SDL_EVENT_KEY_DOWN) continue;
        assert(event.key.scancode == SDL_SCANCODE_F2);
        assert(event.key.down && !event.key.repeat);
        ++count;
    }
    assert(count == expected);
}

static unsigned received;
static void complete(const void *data)
{
    const uint32_t *words = data;
    assert(words[0] == 31 - received && words[1] == received);
    assert(MgsGodotButtons() == received);
    ++received;
}

static void check_batch(void)
{
    for (uint32_t index = 0; index < 5; ++index) {
        const uint32_t header[] = {index, 0xabcdef};
        MgsGodotRequest(31 - index, header, sizeof(header), sizeof(header), complete);
    }
    assert(received == 0);
    MgsGodotExchange(MGS_GODOT_SYNC, NULL, 0, NULL, 0);
    assert(received == 5 && MgsGodotButtons() == 0x8010);
    received = 0;
    const uint32_t header[] = {0, 0xabcdef};
    MgsGodotRequest(31, header, sizeof(header), sizeof(header), complete);
    MgsGodotExchange(MGS_GODOT_SYNC, NULL, 0, NULL, 0);
    assert(received == 1 && MgsGodotButtons() == 0x8010);
}

int main(int argc, char **argv)
{
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
    assert(argc == 2);
    int enabled = atoi(argv[1]) >= 31;
    assert(SDL_Init(SDL_INIT_EVENTS));
    assert(MgsGodotConnect());
    check_events(0);
    for (int tick = 0; tick < 3; ++tick) {
        MgsGodotExchange(MGS_GODOT_SYNC, NULL, 0, NULL, 0);
        assert(MgsGodotButtons() == 0x8010u);
        check_events(enabled && tick != 1);
    }
    check_batch();
    MgsGodotClose();
    SDL_Quit();
    puts("PASS: negotiated controller-port events remain separate from held pad buttons");
    return 0;
}
