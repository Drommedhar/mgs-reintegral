using System;
using System.IO;

namespace ReIntegral
{
    public sealed class PresentationContract
    {
        public int major, minor;
        public uint capabilities;
        public string mode;

        public void Validate()
        {
            if (major != 15 || minor < 30 || minor > 32)
                throw new InvalidDataException("Presentation host requires protocol 15.30–15.32; install a matching renderer package.");
            if (mode != "commands" && mode != "scene")
                throw new InvalidDataException("Presentation mode must be commands or scene.");
            uint required = mode == "scene" ? 536870911u : 29u;
            if ((capabilities & required) != required)
                throw new InvalidDataException("Presentation renderer lacks required " + mode + " capabilities: 0x" + (required & ~capabilities).ToString("x8"));
        }

        public void Match(PresentationContract actual)
        {
            if (actual == null || actual.major != major || actual.minor != minor ||
                actual.capabilities != capabilities || actual.mode != mode)
                throw new InvalidDataException("Renderer startup capabilities differ from its descriptor; install a matching package.");
        }
    }

    public sealed class PresentationReady
    {
        public int schema;
        public string rendererId;
        public PresentationContract protocol;
    }
}
