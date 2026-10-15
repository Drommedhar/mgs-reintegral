#ifndef MGS_SHA256_H
#define MGS_SHA256_H
#include <stddef.h>
void MgsSha256(const void *data, size_t size, unsigned char digest[32]);
#endif
