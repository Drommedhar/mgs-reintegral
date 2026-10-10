#include <libgpu.h>

u_long *BreakDraw(void)
{
    /* PsyZ consumes complete chains on the game thread; draining leaves no resume address. */
    DrawSync(0);
    return NULL;
}

int LoadImage2(RECT *rect, u_long *pixels)
{
    return LoadImage(rect, pixels);
}

int StoreImage2(RECT *rect, u_long *pixels)
{
    return StoreImage(rect, pixels);
}

void SetDrawStp(DR_STP *command, int mask)
{
    setlen(command, 1);
    command->code[0] = 0xE6000000 | (mask & 1);
}
