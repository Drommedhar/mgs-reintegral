using System;
using System.IO;
using System.Linq;
using ReIntegral;

internal static class SdkLauncherTest
{
    public static int Main(string[] args)
    {
        string root = Path.GetFullPath(args[0]);
        var packages = RendererCatalog.Discover(root, Path.Combine(root, "proof-profile"));
        foreach (var package in packages)
        {
            package.RequireAvailable();
            if (!package.Executable.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Renderer escaped the relocated SDK: " + package.Executable);
            Console.WriteLine("SDK_RENDERER " + package.Id + " " + package.Executable);
        }
        if (packages.Count != 2 || !packages.Any(package => package.Id == "godot") ||
            !packages.Any(package => package.Id == "legacy"))
            throw new InvalidOperationException("Both SDK renderers must be discoverable");
        Console.WriteLine("MGS_SDK_LAUNCHER_TEST failures=0");
        return 0;
    }
}
