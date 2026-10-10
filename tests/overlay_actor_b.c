static int initialized = 83;

int OverlayActorBInitial(void)
{
    return initialized == 83;
}

void OverlayActorBMutate(void)
{
    initialized = 19;
}
