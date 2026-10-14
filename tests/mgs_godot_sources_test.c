#include "mgs_sha256.h"
#include "mgs_godot_sources.h"
#include "transport.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static unsigned count;
static bool enabled = true;
static bool disc_identity;
static int disc = 1;
static unsigned char message[76];

bool MgsGodotHasCapability(unsigned capability) { return enabled && (capability == 64 || (disc_identity && capability == 256)); }
int MgsSafetyDiscNumber(void) { return disc; }
const char *MgsNativeResourceStage(void) { return "s00a"; }
void MgsGodotCopySessionId(unsigned char destination[16]) { memset(destination, 0x5a, 16); }
void MgsGodotQueue(uint32_t operation, const void *header, uint32_t header_bytes,
                   const void *data, uint32_t data_bytes)
{
    assert(operation == MGS_GODOT_MODEL_SOURCE && header_bytes == 16 && data_bytes == (disc_identity ? 60 : 56));
    memcpy(message, header, header_bytes);
    memcpy(message + header_bytes, data, data_bytes);
    ++count;
}

static void CheckHash(const void *data, size_t size, const char *expected)
{
    unsigned char digest[32];
    char hex[65];
    MgsSha256(data, size, digest);
    for (unsigned i = 0; i < 32; ++i) sprintf(hex + i*2, "%02x", digest[i]);
    assert(strcmp(hex, expected) == 0);
}

int main(void)
{
    CheckHash(NULL, 0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    CheckHash("abc", 3, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    const char *long_input = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
    CheckHash(long_input, strlen(long_input), "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");
    static char million[1000000];
    memset(million, 'a', sizeof(million));
    CheckHash(million, sizeof(million), "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0");
    unsigned char bytes[] = {1, 2, 3, 4}, digest[32];
    MgsSha256(bytes, sizeof(bytes), digest);
    MgsGodotBeginSource(bytes, ('k'-'a')*65536u + 7, sizeof(bytes));
    memset(bytes, 0, sizeof(bytes));
    MgsGodotPublishModelSource(bytes, 7);
    MgsGodotEndSource();
    assert(count == 1 && memcmp(message + 40, digest, 32) == 0);
    assert(memcmp(message + 16, "s00a\0\0\0\0", 8) == 0 && message[24] == 0x5a);
    MgsGodotBeginSource(bytes, ('z'-'a')*65536u + 9, sizeof(bytes));
    MgsGodotPublishModelSource(bytes + 2, 8);
    MgsGodotEndSource();
    assert(count == 2 && message[12] == 2 && message[0] == 8);
    disc_identity = true;
    disc = 2;
    MgsGodotBeginSource(bytes, ('k'-'a')*65536u + 7, sizeof(bytes));
    MgsGodotPublishModelSource(bytes, 7);
    MgsGodotEndSource();
    assert(count == 3 && message[72] == 2);
    enabled = false;
    MgsGodotBeginSource(NULL, 0, 0);
    MgsGodotPublishModelSource(NULL, 0);
    MgsGodotEndSource();
    assert(count == 3);
    puts("Godot source digest and declaration tests passed");
    return 0;
}
