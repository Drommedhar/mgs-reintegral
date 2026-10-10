#include <stdarg.h>
#include <stdio.h>

int mgs_fprintf(int channel, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vfprintf(channel == 2 ? stderr : stdout, format, arguments);
    va_end(arguments);
    return result;
}
