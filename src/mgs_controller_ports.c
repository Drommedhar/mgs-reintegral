#include "mgs_native.h"
#include "mgs_controller_ports.h"
#include "mgs_input_movie.h"
#include "game/game.h"
#include <psyz/input.h>
#include <psyz/overlay_sdl3.h>

static PsyzOverlayEventCB_SDL3 previous_event;
static SDL_JoystickID chord_controller;

static int PortShortcut(const SDL_Event *event)
{
    if (event->type == SDL_EVENT_KEY_DOWN)
        return !event->key.repeat && event->key.scancode == SDL_SCANCODE_F2;
    if (event->type == SDL_EVENT_GAMEPAD_REMOVED) {
        if (event->gdevice.which == chord_controller)
            chord_controller = 0;
        return 0;
    }
    if ((event->type != SDL_EVENT_GAMEPAD_BUTTON_DOWN &&
         event->type != SDL_EVENT_GAMEPAD_BUTTON_UP) ||
        (event->gbutton.button != SDL_GAMEPAD_BUTTON_LEFT_STICK &&
         event->gbutton.button != SDL_GAMEPAD_BUTTON_RIGHT_STICK))
        return 0;
    if (event->type == SDL_EVENT_GAMEPAD_BUTTON_UP) {
        if (event->gbutton.which == chord_controller)
            chord_controller = 0;
        return 0;
    }
    SDL_Gamepad *pad = SDL_GetGamepadFromID(event->gbutton.which);
    if (!pad || chord_controller == event->gbutton.which ||
        !SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_LEFT_STICK) ||
        !SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_RIGHT_STICK))
        return 0;
    chord_controller = event->gbutton.which;
    return 1;
}

static void ControllerEvent(const SDL_Event *event)
{
    if (previous_event)
        previous_event(event);
    if (MgsInputMovieReplaying() || !PortShortcut(event))
        return;
    int swapped = !Psyz_PadsHostPort(0);
    Psyz_PadsSetHostPortSwap(swapped);
    printf("[input] Primary controller and keyboard moved to port %d. F2 or L3+R3 switches ports.\n",
           swapped + 1);
}

void MgsControllerPortsInit(void)
{
    Psyz_PadsSetHostPortSwap(0);
    chord_controller = 0;
    previous_event = Psyz_OverlayEvent_SDL3(ControllerEvent);
}

const char *MgsControllerPortsHint(void)
{
    int available = (GM_PlayerStatus & PLAYER_SECOND_AVAILABLE) != 0;
    if (MgsInputMovieReplaying()) {
        if (!available)
            return "";
        return (GM_PlayerStatus & PLAYER_SECOND_CONTROLLER) ?
            "REPLAY - CONTROLLER PORT 2" : "REPLAY - CONTROLLER PORT 1";
    }
    if (Psyz_PadsHostPort(0))
        return "CONTROLLER PORT 2\nF2/L3+R3: RETURN TO PORT 1";
    return available ? "CONTROLLER PORT 1\nF2/L3+R3: SWITCH TO PORT 2" : "";
}
