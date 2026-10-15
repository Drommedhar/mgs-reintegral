#include "transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <SDL3/SDL_timer.h>
#include <SDL3/SDL_events.h>
#include <psyz/audio.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
typedef SOCKET MgsSocket;
#define MGS_INVALID_SOCKET INVALID_SOCKET
#define MgsCloseSocket closesocket
#else
#include <arpa/inet.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
typedef int MgsSocket;
#define MGS_INVALID_SOCKET (-1)
#define MgsCloseSocket close
#endif

#define MGS_COMMAND_LIMIT (64u * 1024u * 1024u)
#define MGS_SEND_CHUNK_BYTES (16u * 1024u)
static MgsSocket connection = MGS_INVALID_SOCKET;
static unsigned char *commands;
static uint32_t command_bytes;
static unsigned buttons;
static Uint64 exchange_ns;
static unsigned char session_id[16];
static unsigned selected_capabilities;
static unsigned selected_minor;
static struct {
    uint32_t operation, result_bytes;
    void (*complete)(const void *);
} requests[16];
static unsigned request_count;
static bool servicing_wait;
static void Fail(const char *message);

static void WaitForReply(void) {
    const Uint64 started = SDL_GetTicksNS();
    for (;;) {
        fd_set readable;
        FD_ZERO(&readable);
        FD_SET(connection, &readable);
        struct timeval timeout = {.tv_sec = 0, .tv_usec = 5000};
        int ready = select((int)connection + 1, &readable, NULL, NULL, &timeout);
        if (ready > 0) return;
        if (ready < 0) Fail("cannot poll renderer reply");
        if (SDL_GetTicksNS() - started > 30000000000ull) Fail("renderer reply timed out");
        if (!servicing_wait) {
            servicing_wait = true;
            Psyz_AudioPumpWait();
            servicing_wait = false;
        }
    }
}

unsigned MgsGodotSelectedMinor(void) { return selected_minor; }

bool MgsGodotHasCapability(unsigned capability) {
    return (selected_capabilities & capability) == capability;
}

static void Fail(const char *message) {
    fprintf(stderr, "Godot renderer: %s\n", message);
    MgsGodotClose();
    exit(EXIT_FAILURE);
}

static void Transfer(void *buffer, uint32_t count, bool sending) {
    unsigned char *cursor = buffer;
    while (count) {
        const uint32_t limit = sending ? MGS_SEND_CHUNK_BYTES : INT_MAX;
        int size = (int)(count > limit ? limit : count);
        if (!sending && selected_minor >= 35) WaitForReply();
        int done = sending ? send(connection, (const char *)cursor, size, 0)
                           : recv(connection, (char *)cursor, size, 0);
        if (done <= 0) Fail("connection closed or timed out");
        count -= (uint32_t)done;
        cursor += done;
    }
}

bool MgsGodotConnect(void) {
    if (connection != MGS_INVALID_SOCKET) return true;
    const char *token = getenv("MGS_GODOT_SESSION_TOKEN");
    unsigned char token_bytes[16];
    if (!token || strlen(token) != 32 || strspn(token, "0123456789abcdefABCDEF") != 32) {
        fprintf(stderr, "Godot renderer requires MGS_GODOT_SESSION_TOKEN (32 hex characters).\n");
        return false;
    }
    for (unsigned i = 0; i < sizeof(token_bytes); ++i) {
        char pair[] = {token[i * 2], token[i * 2 + 1], 0};
        token_bytes[i] = (unsigned char)strtoul(pair, NULL, 16);
    }
    const char *setting = getenv("MGS_GODOT_PORT");
    char *end = NULL;
    long port = setting ? strtol(setting, &end, 10) : 0;
    if (!setting || end == setting || *end || port < 1024 || port > 65535) {
        fprintf(stderr, "Godot renderer requires MGS_GODOT_PORT (1024..65535).\n");
        return false;
    }
    const uint32_t endian = 1;
    if (*(const unsigned char *)&endian != 1) {
        fprintf(stderr, "Godot protocol requires a little-endian host.\n");
        return false;
    }
#ifdef _WIN32
    WSADATA startup;
    if (WSAStartup(MAKEWORD(2, 2), &startup)) return false;
#endif
    connection = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (connection == MGS_INVALID_SOCKET) return false;
    const int no_delay = 1;
#ifdef _WIN32
    const DWORD timeout = 30000;
#else
    const struct timeval timeout = {.tv_sec = 30};
#endif
    if (setsockopt(connection, IPPROTO_TCP, TCP_NODELAY,
                   (const char *)&no_delay, sizeof(no_delay)) ||
        setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO,
                   (const char *)&timeout, sizeof(timeout)) ||
        setsockopt(connection, SOL_SOCKET, SO_SNDTIMEO,
                   (const char *)&timeout, sizeof(timeout))) {
        Fail("cannot configure socket");
    }
    const struct sockaddr_in address = {
        .sin_family = AF_INET, .sin_port = htons((unsigned short)port),
        .sin_addr = {.s_addr = htonl(INADDR_LOOPBACK)}};
    if (connect(connection, (const struct sockaddr *)&address, sizeof(address))) {
        fprintf(stderr, "Godot renderer is not listening on 127.0.0.1:%ld.\n", port);
        MgsGodotClose();
        return false;
    }
    commands = malloc(MGS_COMMAND_LIMIT);
    if (!commands) Fail("cannot allocate command buffer");
    const char *scene = getenv("MGS_GODOT_SCENE_VIEW");
    const uint32_t required = 29u | (scene && strcmp(scene, "1") == 0 ? 536870882u : 0u);
    unsigned offered_minor = 35;
    const char *minor = getenv("MGS_PRESENTATION_MINOR");
    if (minor && *minor) {
        if (strcmp(minor, "30") != 0 && strcmp(minor, "31") != 0 && strcmp(minor, "32") != 0 && strcmp(minor, "33") != 0 && strcmp(minor, "34") != 0 && strcmp(minor, "35") != 0)
            Fail("unsupported presentation minor version");
        offered_minor = (unsigned)strtoul(minor, NULL, 10);
    }
    const uint32_t fields[] = {0x3152474d, 15, offered_minor, 20, UINT32_MAX, required};
    unsigned char hello[sizeof(fields) + sizeof(token_bytes)];
    memcpy(hello, fields, sizeof(fields));
    memcpy(hello + sizeof(fields), token_bytes, sizeof(token_bytes));
    uint32_t negotiated[7];
    MgsGodotExchange(MGS_GODOT_HELLO, hello, sizeof(hello), negotiated, sizeof(negotiated));
    if (negotiated[0] != 15 || negotiated[1] < 30 || negotiated[1] > offered_minor ||
          (negotiated[2] & required) != required ||
        !(negotiated[3] | negotiated[4] | negotiated[5] | negotiated[6])) {
        Fail("incompatible renderer negotiation; rebuild the native/Godot pair");
    }
    memcpy(session_id, negotiated + 3, sizeof(session_id));
    selected_capabilities = negotiated[2];
    selected_minor = negotiated[1];
    fprintf(stderr, "Godot renderer connected: protocol 15.%u, capabilities 0x%x, no native GPU device.\n",
            selected_minor, (unsigned)negotiated[2]);
    return true;
}

void MgsGodotClose(void) {
    if (connection != MGS_INVALID_SOCKET) {
        MgsCloseSocket(connection);
        connection = MGS_INVALID_SOCKET;
#ifdef _WIN32
        WSACleanup();
#endif
    }
    free(commands);
    commands = NULL;
    command_bytes = 0;
    buttons = 0;
    exchange_ns = 0;
    selected_capabilities = 0;
    selected_minor = 0;
    request_count = 0;
    memset(session_id, 0, sizeof(session_id));
}

void MgsGodotCopySessionId(unsigned char destination[16]) {
    memcpy(destination, session_id, sizeof(session_id));
}

void MgsGodotQueue(uint32_t operation, const void *header, uint32_t header_bytes,
                   const void *data, uint32_t data_bytes) {
    if (connection == MGS_INVALID_SOCKET || !commands) Fail("command before connection");
    if (header_bytes > MGS_COMMAND_LIMIT - 8 ||
        data_bytes > MGS_COMMAND_LIMIT - 8 - header_bytes) Fail("oversized command");
    uint32_t total = 8 + header_bytes + data_bytes;
    if (command_bytes > MGS_COMMAND_LIMIT - total) {
        Transfer(commands, command_bytes, true);
        command_bytes = 0;
    }
    uint32_t prefix[] = {header_bytes + data_bytes, operation};
    memcpy(commands + command_bytes, prefix, sizeof(prefix));
    command_bytes += sizeof(prefix);
    if (header_bytes) memcpy(commands + command_bytes, header, header_bytes);
    command_bytes += header_bytes;
    if (data_bytes) memcpy(commands + command_bytes, data, data_bytes);
    command_bytes += data_bytes;
}

static void ReceiveReply(uint32_t operation, void *result, uint32_t result_bytes) {
    uint32_t reply[3];
    Transfer(reply, sizeof(reply), false);
    if (reply[0] != result_bytes + 4 || reply[1] != (operation | 0x80000000u)) {
        Fail("invalid reply size or operation");
    }
    if (result_bytes) Transfer(result, result_bytes, false);
    buttons = reply[2];
    if (selected_minor >= 31 && (buttons & 0x10000u)) {
        SDL_Event event = {0};
        event.type = SDL_EVENT_KEY_DOWN;
        event.key.scancode = SDL_SCANCODE_F2;
        event.key.down = true;
        if (!SDL_PushEvent(&event)) Fail("cannot deliver controller-port shortcut");
    }
}

static void CompleteRequests(void) {
    for (unsigned index = 0; index < request_count; ++index) {
        uint32_t result[16];
        ReceiveReply(requests[index].operation, result, requests[index].result_bytes);
        requests[index].complete(result);
    }
    request_count = 0;
}

void MgsGodotExchange(uint32_t operation, const void *header, uint32_t header_bytes,
                      void *result, uint32_t result_bytes) {
    const Uint64 started = SDL_GetTicksNS();
    MgsGodotQueue(operation, header, header_bytes, NULL, 0);
    Transfer(commands, command_bytes, true);
    command_bytes = 0;
    CompleteRequests();
    ReceiveReply(operation, result, result_bytes);
    exchange_ns += SDL_GetTicksNS() - started;
}

double MgsGodotTakeExchangeTimeUs(void) {
    const double elapsed = exchange_ns / 1000.0;
    exchange_ns = 0;
    return elapsed;
}

void MgsGodotRequest(uint32_t operation, const void *header, uint32_t header_bytes,
                     uint32_t result_bytes, void (*complete)(const void *)) {
    uint32_t result[16];
    if (result_bytes > sizeof(result) || !complete || request_count == 16)
        Fail("invalid or excessive deferred replies");
    MgsGodotQueue(operation, header, header_bytes, NULL, 0);
    requests[request_count].operation = operation;
    requests[request_count].result_bytes = result_bytes;
    requests[request_count++].complete = complete;
}

bool MgsGodotInputCaptured(void) { return MgsGodotHasCapability(67108864u) && (buttons & 0x40000000u) != 0; }

unsigned MgsGodotButtons(void) { return buttons & 0xffffu; }
bool MgsGodotQuitRequested(void) { return (buttons & 0x80000000u) != 0; }
