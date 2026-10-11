#include "transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <SDL3/SDL_timer.h>

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
        int done = sending ? send(connection, (const char *)cursor, size, 0)
                           : recv(connection, (char *)cursor, size, 0);
        if (done <= 0) Fail("connection closed or timed out");
        count -= (uint32_t)done;
        cursor += done;
    }
}

bool MgsGodotConnect(void) {
    if (connection != MGS_INVALID_SOCKET) return true;
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
    const uint32_t hello[] = {0x3152474d, 13, 20};
    MgsGodotExchange(MGS_GODOT_HELLO, hello, sizeof(hello), NULL, 0);
    fprintf(stderr, "Godot renderer connected: protocol 13, no native GPU device.\n");
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

void MgsGodotExchange(uint32_t operation, const void *header, uint32_t header_bytes,
                      void *result, uint32_t result_bytes) {
    const Uint64 started = SDL_GetTicksNS();
    MgsGodotQueue(operation, header, header_bytes, NULL, 0);
    Transfer(commands, command_bytes, true);
    command_bytes = 0;
    uint32_t reply[3];
    Transfer(reply, sizeof(reply), false);
    if (reply[0] != result_bytes + 4 || reply[1] != (operation | 0x80000000u)) {
        Fail("invalid reply size or operation");
    }
    buttons = reply[2];
    if (result_bytes) Transfer(result, result_bytes, false);
    exchange_ns += SDL_GetTicksNS() - started;
}

double MgsGodotTakeExchangeTimeUs(void) {
    const double elapsed = exchange_ns / 1000.0;
    exchange_ns = 0;
    return elapsed;
}

unsigned MgsGodotButtons(void) { return buttons & 0xffffu; }
bool MgsGodotQuitRequested(void) { return (buttons & 0x80000000u) != 0; }
