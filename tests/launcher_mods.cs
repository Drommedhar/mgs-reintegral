using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Threading.Tasks;
using ReIntegral;

internal static class LauncherModsTest
{
    private const string Manifest = "{\"schema\":1.0,\"id\":\"test.lights\",\"name\":\"Test lights\",\"stages\":{\"s00a\":{\"scene\":\"stages/docks.tscn\",\"original_lighting\":false}}}";

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static void Archive(string path, params string[] entries)
    {
        using (var file = File.Create(path))
        using (var archive = new ZipArchive(file, ZipArchiveMode.Create))
            for (int index = 0; index < entries.Length; index += 2)
                using (var writer = new StreamWriter(archive.CreateEntry(entries[index]).Open())) writer.Write(entries[index + 1]);
    }

    private static void Reject(string directory, params string[] entries)
    {
        string zip = Path.Combine(directory, "invalid.zip");
        Archive(zip, entries);
        int count = Directory.GetDirectories(Path.Combine(directory, "mods")).Length;
        try { ModPackage.Install(zip, directory); throw new InvalidOperationException("Accepted invalid archive"); }
        catch (InvalidDataException) { }
        Require(count == Directory.GetDirectories(Path.Combine(directory, "mods")).Length, "Failed install leaked files");
    }

    private static void CheckPackages(string directory)
    {
        using (var session = new GodotSession("", directory))
        {
            var start = GameLaunch.StartInfo("native.exe", "", directory);
            start.EnvironmentVariables["MGS_GODOT_SCENE_VIEW"] = "0";
            session.Configure(start);
            Require(start.EnvironmentVariables["MGS_GODOT_SCENE_VIEW"] == "1", "Native process never enabled Godot world composition");
        }
        string zip = Path.Combine(directory, "mod 日本語.zip");
        Archive(zip, "mod.json", Manifest, "stages/docks.tscn", "authored light");
        var first = ModPackage.Install(zip, directory);
        Require(first.Id == "test.lights" && first.Enabled && first.Name == "Test lights", "Mod metadata missing");
        Require(ModPackage.Install(zip, directory).Package == first.Package, "Same ZIP installed twice");
        string original = ModPackage.Folder(directory, first);
        Require(File.ReadAllText(Path.Combine(original, "stages/docks.tscn")) == "authored light", "ZIP was not installed");
        Archive(zip, "mod.json", Manifest, "stages/docks.tscn", "updated light");
        var updated = ModPackage.Install(zip, directory);
        Require(updated.Package != first.Package, "Updated ZIP reused stale content");
        Require(File.ReadAllText(Path.Combine(original, "stages/docks.tscn")) == "authored light", "Update overwrote previous package");
        Reject(directory, "nested/mod.json", Manifest);
        Reject(directory, "mod.json", "{\"schema\":99,\"id\":\"bad\"}");
        Reject(directory, "mod.json", Manifest);
        foreach (string unsafePath in new[] { "../outside.txt", "/rooted", "C:/rooted", "dir\\..\\escape", "a:stream", "CON.txt", "trailing./file" })
            Reject(directory, "mod.json", Manifest, unsafePath, "escape", "stages/docks.tscn", "light");
        Reject(directory, "mod.json", Manifest, "stages/docks.tscn", "light", "STAGES/DOCKS.TSCN", "duplicate");
        string settingsPath = Path.Combine(directory, "settings.xml");
        first.Enabled = false;
        new Settings { Mods = new List<VisualMod> { first, updated } }.Save(settingsPath);
        var restored = Settings.Load(settingsPath);
        Require(!restored.Mods[0].Enabled && restored.Mods[1].Package == updated.Package, "Mod selections did not persist");
        CheckProject(directory, restored.Mods);
    }

    private static void CheckProject(string directory, List<VisualMod> mods)
    {
        string source = Path.Combine(directory, "source");
        Directory.CreateDirectory(Path.Combine(source, ".generated"));
        Directory.CreateDirectory(Path.Combine(source, "mods", "editor-only"));
        File.WriteAllText(Path.Combine(source, "project.godot"), "config_version=5\n[editor_plugins]\nenabled=[\"editor\"]\n[rendering]\n");
        File.WriteAllText(Path.Combine(source, "runtime.gd"), "extends Node");
        File.WriteAllText(Path.Combine(source, "mods", "editor-only", "mod.json"), "do not load");
        foreach (string shader in new[] { "psx.vert.glsl", "psx.frag.glsl" })
            File.WriteAllText(Path.Combine(source, ".generated", shader), "shader");
        string project = GodotProject.Prepare(source, directory, mods);
        Require(Directory.GetDirectories(Path.Combine(project, "mods")).Length == 1, "Disabled or editor mods leaked into runtime");
        Require(!File.ReadAllText(Path.Combine(project, "project.godot")).Contains("editor_plugins"), "Editor plugins enabled at runtime");
        Require(File.Exists(GodotProject.Manifests(project, mods).Single()), "Selected manifest missing");
        Require(project == GodotProject.Prepare(source, directory, mods), "Runtime import cache was not reused");
        mods[1].Enabled = false;
        string disabled = GodotProject.Prepare(source, directory, mods);
        Require(!Directory.Exists(Path.Combine(disabled, "mods")), "Disabling all mods still installed their code");
        File.WriteAllText(Path.Combine(source, "runtime.gd"), "changed renderer");
        Require(disabled != GodotProject.Prepare(source, directory, mods), "Source change reused stale runtime");
    }

    private static void CheckPresentation(string log, Settings settings)
    {
        var match = System.Text.RegularExpressions.Regex.Match(log, @"MGS_GODOT_PRESENTATION (.+)");
        Require(match.Success, "Renderer did not report its displayed aspect");
        var presentation = new System.Web.Script.Serialization.JavaScriptSerializer()
            .Deserialize<Dictionary<string, object>>(match.Groups[1].Value);
        string[] dimensions = settings.Resolution.Split('x');
        double width = Int32.Parse(dimensions[0]), height = Int32.Parse(dimensions[1]);
        double aspect = settings.Widescreen ? width / height : 4.0 / 3.0;
        double fittedHeight = Math.Min(height, width / aspect);
        var screen = (System.Collections.IList)presentation["screen"];
        Require(Math.Abs(Convert.ToDouble(presentation["aspect"]) - aspect) < 0.0001 &&
            Math.Abs(Convert.ToDouble(screen[0]) - fittedHeight * aspect) < 0.01 &&
            Math.Abs(Convert.ToDouble(screen[1]) - fittedHeight) < 0.01,
            "Displayed game rectangle did not match the selected aspect");
    }

    private static async Task Boot(string[] args)
    {
        string root = args[1], directory = args[3];
        Directory.CreateDirectory(Path.Combine(directory, "logs"));
        var mod = ModPackage.Install(args[2], directory);
        var settings = new Settings { Mods = new List<VisualMod> { mod }, DiscOne = args[4], DiscTwo = args[5],
            Stage = "s00a", Frames = "900", Resolution = "640x480", Widescreen = false };
        bool widescreenCheck = args[0] == "--widescreen-check";
        bool renderCheck = args[0] == "--render-check" || widescreenCheck;
        settings.Widescreen = widescreenCheck;
        bool performanceCheck = args[0] == "--performance-check";
        if (renderCheck || performanceCheck)
        {
            settings.Resolution = args[6];
            settings.Frames = "1800";
            settings.DebugOverlay = true;
            settings.Advanced = "--probe dock";
            mod.Enabled = performanceCheck || args.Length == 7;
        }
        if (performanceCheck)
        {
            int frames;
            Require(Int32.TryParse(args[7], out frames) && frames >= 1800 && frames <= 6000,
                "Performance run requires 1800..6000 VSyncs");
            settings.Frames = frames.ToString();
            settings.Advanced += " --cadence-log " + GameLaunch.Quote(Path.Combine(directory, "timing.csv"));
            Environment.SetEnvironmentVariable("MGS_CADENCE_ALL_FRAMES", "1");
            Environment.SetEnvironmentVariable("MGS_GODOT_CAPTURE_FRAME", "0");
            Environment.SetEnvironmentVariable("MGS_GODOT_CAPTURE_EVERY", "0");
            Environment.SetEnvironmentVariable("MGS_GODOT_QUIT_FRAME", "0");
        }
        if (renderCheck)
        {
            Environment.SetEnvironmentVariable("MGS_GODOT_CAPTURE_FRAME", "1200");
            Environment.SetEnvironmentVariable("MGS_GODOT_CAPTURE_EVERY", "0");
            Environment.SetEnvironmentVariable("MGS_GODOT_CAPTURE_WORLD", "1");
            Environment.SetEnvironmentVariable("MGS_GODOT_CAPTURE_FILE", Path.Combine(directory, "render.png"));
        }
        settings.Save(Path.Combine(directory, "settings.xml"));
        using (var session = new GodotSession(root, directory))
        {
            await session.Start(settings, new Progress<string>(Console.WriteLine));
            var start = GameLaunch.StartInfo(Path.Combine(root, "build/windows-x86-godot/mgs-integral-native.exe"),
                GameLaunch.Arguments(settings, true), directory);
            session.Configure(start);
            using (var game = Process.Start(start))
            {
                var output = game.StandardOutput.ReadToEndAsync();
                var error = game.StandardError.ReadToEndAsync();
                if (!await Task.Run(() => game.WaitForExit(120000)))
                {
                    game.Kill();
                    throw new IOException("Modded disc boot timed out");
                }
                string nativeLog = await output + await error;
                File.WriteAllText(Path.Combine(directory, "logs", "native.log"), nativeLog);
                Require(game.ExitCode == 0, "Modded native runtime failed");
                Require(nativeLog.Contains("[native] stage=s00a"), "Docks were not loaded during the boot check");
                if (widescreenCheck)
                    Require(nativeLog.Contains(settings.Resolution + " widescreen"), "Selected aspect did not reach the native runtime");
            }
        }
        string latest = Directory.GetFiles(Path.Combine(directory, "logs"), "godot-*.log")
            .Where(path => !path.EndsWith("-import.log")).OrderByDescending(path => path).First();
        Require(File.ReadAllText(latest).Contains("MGS_STAGE_OVERRIDE s00a mod=" + mod.Id) == mod.Enabled,
            "In-game overlay did not match the enabled mod selection");
        Require(!File.ReadAllText(Path.ChangeExtension(latest, ".err")).Contains("ERROR:"), "Renderer reported an error");
        if (renderCheck || performanceCheck)
        {
            string log = File.ReadAllText(latest);
            Require(System.Text.RegularExpressions.Regex.IsMatch(log, @"MGS_WORLD_COMPOSITES [1-9][0-9]*"),
                "The game never composed the modded world into the displayed image");
            if (renderCheck) CheckPresentation(log, settings);
        }
        Console.WriteLine("ZIP selection verified during real Godot/native disc boot.");
    }

    public static int Main(string[] args)
    {
        AppContext.SetSwitch("Switch.System.IO.UseLegacyPathHandling", false);
        AppContext.SetSwitch("Switch.System.IO.BlockLongPaths", false);
        if ((args.Length == 6 && args[0] == "--boot") ||
            (args.Length == 7 && args[0] == "--widescreen-check") ||
            (args.Length == 8 && args[0] == "--performance-check") ||
            (args.Length >= 7 && args[0] == "--render-check" &&
                (args.Length == 7 || (args.Length == 8 && args[7] == "--without-mod"))))
        { Boot(args).GetAwaiter().GetResult(); return 0; }
        string directory = Path.Combine(Path.GetTempPath(), "reintegral-mods-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try { CheckPackages(directory); }
        finally { Directory.Delete(directory, true); }
        Console.WriteLine("Mod ZIP installation, updates, validation, persisted selections and runtime isolation passed.");
        return 0;
    }
}
