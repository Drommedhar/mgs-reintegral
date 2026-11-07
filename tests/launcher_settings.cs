using System;
using System.IO;
using System.Runtime.InteropServices;
using ReIntegral;

internal static class LauncherSettingsTest
{
    [DllImport("shell32.dll", SetLastError = true)]
    private static extern IntPtr CommandLineToArgvW([MarshalAs(UnmanagedType.LPWStr)] string command, out int count);
    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr pointer);

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static void Rejected<T>(Action action, string message) where T : Exception
    {
        try { action(); }
        catch (T) { return; }
        throw new InvalidOperationException(message);
    }

    private static void CheckQuoting()
    {
        foreach (string path in new[] { "", "C:\\path with spaces\\disc.cue", "D:\\日本語\\ä\\", "a\"b", "trailing\\\\" })
        {
            int count;
            IntPtr arguments = CommandLineToArgvW("program " + GameLaunch.Quote(path), out count);
            Require(arguments != IntPtr.Zero, "Cannot parse command line");
            try
            {
                Require(count == 2 && Marshal.PtrToStringUni(Marshal.ReadIntPtr(arguments, IntPtr.Size)) == path,
                    "Argument changed during Windows quoting: " + path);
            }
            finally { LocalFree(arguments); }
        }
    }

    private static void CheckSettings(string directory)
    {
        string path = Path.Combine(directory, "settings.xml");
        var value = Settings.Load(path);
        Require(!value.Invulnerable && !value.BonusItems && !value.AutoCard, "Gameplay aids must default off");
        Require(value.CodecTurbo, "Codec fast advance must default on in the user launcher");
        Require(!value.FastLoading, "Experimental fast loading must default off");
        Require(!value.GodotLegacyRendering, "Godot must default to full scene rendering");
        Require(value.GodotSharpText, "Godot must default to sharp text");
        Require(!value.TextureCorrection && !value.GeometryPrecision && !value.DepthBuffer,
            "Experimental graphics must default off");
        value.DiscOne = "C:\\日本語\\disc 1.cue";
        value.TextPack = "C:\\my languages\\german.mgslang";
        value.VoicePack = "C:\\my languages\\english.mgslang";
        value.Advanced = "--mods-root \"C:\\my mods\"";
        value.Save(path);
        value.Fullscreen = true;
        value.GodotLegacyRendering = true;
        value.GodotSharpText = false;
        value.FastLoading = true;
        value.CodecTurbo = false;
        value.TextureCorrection = value.GeometryPrecision = value.DepthBuffer = true;
        value.Save(path);
        var restored = Settings.Load(path);
        Require(restored.DiscOne == value.DiscOne && restored.Advanced == value.Advanced && restored.Fullscreen,
            "Settings round-trip or replacement failed");
        Require(restored.TextureCorrection && restored.GeometryPrecision && restored.DepthBuffer,
            "Graphics settings did not round-trip");
        Require(!restored.CodecTurbo, "Codec fast advance opt-out did not persist");
        Require(restored.FastLoading, "Fast loading setting did not round-trip");
        Require(restored.GodotLegacyRendering, "Legacy-through-Godot mode did not round-trip");
        Require(!restored.GodotSharpText, "Original pixel font choice did not round-trip");
        Require(restored.TextPack == value.TextPack && restored.VoicePack == value.VoicePack,
            "Language selections did not round-trip");
        string languages = GameLaunch.Arguments(restored);
        Require(languages.Contains("--text-pack " + GameLaunch.Quote(value.TextPack)) &&
            languages.Contains("--voice-pack " + GameLaunch.Quote(value.VoicePack)), "Language paths were not quoted");
        Require(Directory.GetFiles(directory, "*.tmp").Length == 0, "Temporary settings file leaked");
        File.WriteAllText(path, "<Settings><Version>99</Version></Settings>");
        Rejected<InvalidDataException>(() => Settings.Load(path), "Unknown settings version accepted");
    }

    private static void CheckArguments()
    {
        var settings = new Settings { BonusItems = true, Invulnerable = true, AutoCard = true, FastLoading = true,
            DebugOverlay = true, Fullscreen = true, TextureCorrection = true, GeometryPrecision = true, DepthBuffer = true,
            Stage = "s00a", Frames = "600", MantisMemory = "42",
            Advanced = "--capture \"C:\\frame capture.bmp\"" };
        string command = GameLaunch.Arguments(settings);
        string godot = GameLaunch.Arguments(settings, true);
        Require(godot.Contains("--resolution " + settings.Resolution) && godot.Contains("--widescreen") &&
            !godot.Contains("--texture-correction") && !godot.Contains("--depth-buffer") && !godot.Contains("--fullscreen"),
            "Godot launch received incompatible native display options");
        settings.Widescreen = false;
        Require(!GameLaunch.Arguments(settings, true).Contains("--widescreen"), "Godot ignored original-aspect selection");
        settings.Widescreen = true;
        foreach (string flag in new[] { "--bonus-items 1", "--invulnerable 1", "--auto-card 1", "--debug-overlay",
            "--fullscreen", "--widescreen", "--texture-correction", "--geometry-precision", "--depth-buffer", "--fast-loading 1",
            "--stage s00a", "--frames 600", "--mantis-memory 42", settings.Advanced })
            Require(command.Contains(flag), "Missing option: " + flag);
        foreach (string resolution in new[] { "3840x2160", "2560x1920", "0x0", "1920x1080 --help" })
        {
            settings.Resolution = resolution;
            Rejected<ArgumentException>(() => GameLaunch.Arguments(settings), "Invalid resolution accepted");
        }
    }

    private static void CheckDithering(string directory)
    {
        string path = Path.Combine(directory, "dithering.xml");
        File.WriteAllText(path, "<Settings><Version>1</Version></Settings>");
        var settings = Settings.Load(path);
        Require(settings.GodotDithering && settings.GodotDitherScale == 1m,
            "Existing profiles must retain original dithering and pattern size");
        foreach (string scale in new[] { "0.5", "1.0", "1.3", "1.4" })
        {
            File.WriteAllText(path, "<Settings><Version>1</Version><GodotDithering>false</GodotDithering>" +
                "<GodotDitherScale>" + scale + "</GodotDitherScale></Settings>");
            settings = Settings.Load(path);
            settings.Save(path);
            var restored = Settings.Load(path);
            Require(!restored.GodotDithering &&
                restored.GodotDitherScale == Decimal.Parse(scale, System.Globalization.CultureInfo.InvariantCulture),
                "Fractional dithering settings did not persist: " + scale);
        }
        foreach (string scale in new[] { "0", "-1", "0.24", "4.01" })
        {
            File.WriteAllText(path, "<Settings><Version>1</Version><GodotDitherScale>" + scale + "</GodotDitherScale></Settings>");
            Rejected<ArgumentException>(() => Settings.Load(path), "Invalid dither scale accepted: " + scale);
        }
        var culture = System.Threading.Thread.CurrentThread.CurrentCulture;
        try
        {
            System.Threading.Thread.CurrentThread.CurrentCulture = new System.Globalization.CultureInfo("de-DE");
            settings = new Settings { GodotDithering = false, GodotDitherScale = 1.3m };
            var start = GameLaunch.StartInfo("fixture.exe", "", directory);
            start.EnvironmentVariables["MGS_GODOT_DITHERING"] = "1";
            start.EnvironmentVariables["MGS_GODOT_DITHER_SCALE"] = "4.0";
            GameLaunch.ConfigureGodotDithering(start, settings);
            Require(start.EnvironmentVariables["MGS_GODOT_DITHERING"] == "0" &&
                start.EnvironmentVariables["MGS_GODOT_DITHER_SCALE"] == "1.3",
                "Godot launch must override inherited settings using invariant decimal notation");
            Require(!GameLaunch.Arguments(settings).Contains("dither"), "Preserved Legacy must not receive Godot-only switches");
        }
        finally { System.Threading.Thread.CurrentThread.CurrentCulture = culture; }
    }

    public static int Main()
    {
        string directory = Path.Combine(Path.GetTempPath(), "reintegral-settings-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try { CheckQuoting(); CheckSettings(directory); CheckArguments(); CheckCaptureIsolation(); CheckDithering(directory); }
        finally { Directory.Delete(directory, true); }
        Console.WriteLine("Launcher settings, Windows argument quoting and option checks passed.");
        return 0;
    }

    private static void CheckCaptureIsolation()
    {
        string[] keys = { "MGS_GODOT_CAPTURE_FRAME", "MGS_GODOT_CAPTURE_EVERY", "MGS_GODOT_CAPTURE_FILE",
            "MGS_GODOT_DIAGNOSTIC_CAPTURE", "MGS_GODOT_QUIT_FRAME", "MGS_BASELINE_PROBE" };
        foreach (string key in keys)
        {
            string previous = Environment.GetEnvironmentVariable(key);
            try
            {
                Environment.SetEnvironmentVariable(key, "100");
                var start = GameLaunch.StartInfo("fixture.exe", "", ".");
                Require(!start.EnvironmentVariables.ContainsKey(key), "Normal play inherited " + key);
                Require(start.EnvironmentVariables["MGS_GODOT_PERFORMANCE_RUN"] == "1", "Normal play allows capture");
            }
            finally { Environment.SetEnvironmentVariable(key, previous); }
        }
    }
}
