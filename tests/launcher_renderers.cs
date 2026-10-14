using System;
using System.IO;
using System.Linq;
using System.Web.Script.Serialization;
using ReIntegral;

internal static class LauncherRenderersTest
{
    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static string WritePackage(string root, string id, string backend)
    {
        Directory.CreateDirectory(root);
        File.WriteAllText(Path.Combine(root, "native.exe"), "native fixture");
        File.WriteAllText(Path.Combine(root, "godot.exe"), "godot fixture");
        File.WriteAllText(Path.Combine(root, "project.godot"), "project fixture");
        File.WriteAllText(Path.Combine(root, "catalog.json"), "{}");
        string path = Path.Combine(root, "renderer.json");
        File.WriteAllText(path, new JavaScriptSerializer().Serialize(new RendererManifest {
            schema = 1, launchApi = 1, id = id, name = id, version = "test.1", backend = backend,
            nativeArchitecture = "x86", rendererArchitecture = "x64", executable = "native.exe",
            godotExecutable = "godot.exe", godotProject = ".", godotAssets = "."
        }));
        return path;
    }

    private static void Discovery(string root)
    {
        string install = Path.Combine(root, "install"), profile = Path.Combine(root, "profile");
        WritePackage(install, "legacy", "native");
        string godot = WritePackage(Path.Combine(profile, "renderers", "godot"), "godot", "godot");
        string community = WritePackage(Path.Combine(install, "renderers", "community"), "community.test", "native");
        var packages = RendererCatalog.Discover(install, profile);
        Require(packages.Count == 3 && packages.All(package => package.Available), "Installed renderer discovery failed");
        Require(RendererCatalog.Select(packages, "", "legacy").Id == "legacy", "Old settings lost their build default");
        Require(RendererCatalog.Select(packages, "godot", "legacy").IsGodot, "Saved choice was ignored");
        var missing = RendererCatalog.Select(packages, "removed.renderer", "godot");
        Require(missing.Id == "removed.renderer" && !missing.Available, "Missing saved renderer silently fell back");
        var selected = RendererCatalog.Select(packages, "community.test", "legacy");
        selected.RequireAvailable();
        File.AppendAllText(community, " ");
        RejectLaunch(selected, "Changed descriptor was accepted without refresh");
        File.Delete(Path.Combine(Path.GetDirectoryName(godot), "godot.exe"));
        RejectLaunch(RendererCatalog.Select(packages, "godot", "legacy"), "Deleted renderer executable remained launchable");
        WritePackage(Path.Combine(install, "renderers", "duplicate"), "legacy", "native");
        packages = RendererCatalog.Discover(install, profile);
        Require(packages.Where(package => package.Id == "legacy").All(package => !package.Available && package.Error.Contains("Duplicate")),
            "Duplicate renderer ids were silently resolved");
    }

    private static void RejectLaunch(RendererPackage package, string message)
    {
        try { package.RequireAvailable(); }
        catch (InvalidOperationException) { return; }
        throw new InvalidOperationException(message);
    }

    private static void InvalidPackages(string root)
    {
        string path = WritePackage(root, "godot", "godot");
        string valid = File.ReadAllText(path);
        foreach (string content in new[] { "{", "null", valid.Replace("\"schema\":1", "\"schema\":2"),
            valid.Replace("\"schema\":1", "\"schema\":1.1"), valid.Replace("\"schema\":1", "\"schema\":\"1\""),
            valid.Replace("\"schema\":1", "\"schema\":99999999999999"),
            valid.Replace("\"launchApi\":1", "\"launchApi\":99"), valid.Replace("\"x86\"", "\"arm64\""),
            valid.Replace("\"backend\":\"godot\"", "\"backend\":\"unsupported\""), valid.Replace("\"id\":\"godot\"", "\"id\":\"../escape\"") })
        {
            File.WriteAllText(path, content);
            Require(!RendererPackage.Read(path).Available, "Invalid descriptor accepted: " + content);
        }
        File.WriteAllText(path, valid);
        File.Delete(Path.Combine(root, "catalog.json"));
        var package = RendererPackage.Read(path);
        Require(package.Available, "Godot command mode unnecessarily requires prepared content");
        package.RequireAvailable(new Settings { GodotLegacyRendering = true });
        bool rejected = false;
        try { package.RequireAvailable(new Settings()); }
        catch (FileNotFoundException error) { rejected = error.Message.Contains("Prepared disc content"); }
        Require(rejected, "Scene rendering accepted missing prepared content");
    }

    private static void SettingsAndArguments(string root)
    {
        var legacy = RendererPackage.Read(WritePackage(Path.Combine(root, "legacy"), "legacy", "native"));
        var godot = RendererPackage.Read(WritePackage(Path.Combine(root, "godot"), "godot", "godot"));
        var settings = new Settings { RendererId = "godot", DiscOne = "disc 1.cue", Fullscreen = true,
            TextureCorrection = true, GeometryPrecision = true, DepthBuffer = true };
        settings.Mods.Add(new VisualMod { Id = "test", Enabled = true, Package = "custom.zip" });
        string path = Path.Combine(root, "settings.xml");
        settings.Save(path);
        settings = Settings.Load(path);
        Require(settings.RendererId == "godot", "Renderer selection was not saved");
        Require(!godot.Arguments(settings).Contains("--fullscreen") && !godot.Arguments(settings).Contains("--depth-buffer"), "Godot received native display flags");
        settings.RendererId = "legacy";
        settings.Save(path);
        settings = Settings.Load(path);
        Require(settings.RendererId == "legacy" && settings.DiscOne == "disc 1.cue" && settings.Mods[0].Enabled && settings.Fullscreen,
            "Renderer switch lost shared settings or mod selections");
        Require(legacy.Arguments(settings).Contains("--fullscreen") && !legacy.Arguments(settings).Contains("--depth-buffer"), "Legacy received unsupported enhancement flags");
        File.WriteAllText(path, "<Settings><Version>1</Version><Resolution>1280x960</Resolution></Settings>");
        Require(Settings.Load(path).RendererId == "", "Old settings migration was not preserved");
    }

    private static void CompanionPackages(string root)
    {
        string path = WritePackage(root, "example.wireframe", "companion");
        var json = new JavaScriptSerializer();
        var descriptor = json.Deserialize<RendererManifest>(File.ReadAllText(path));
        descriptor.launchApi = 2;
        descriptor.companionExecutable = "godot.exe";
        descriptor.companionArguments = new[] { "argument with spaces", "literal\\path" };
        descriptor.protocol = new PresentationContract { major = 15, minor = 30, mode = "commands", capabilities = 29 };
        string valid = json.Serialize(descriptor);
        File.WriteAllText(path, valid);
        var package = RendererPackage.Read(path);
        Require(package.Available && package.IsCompanion && !package.IsGodot, "Independent companion was not discovered");
        Require(!package.Arguments(new Settings { Fullscreen = true }).Contains("--fullscreen"), "Companion received native window flags");
        Require(package.CompanionArguments[0] == "argument with spaces", "Companion argument boundaries changed");
        File.WriteAllText(path, valid.Replace("\"minor\":30", "\"minor\":31"));
        Require(RendererPackage.Read(path).Available, "Protocol15.31 companion was rejected");
        File.WriteAllText(path, valid.Replace("\"minor\":30", "\"minor\":32"));
        Require(RendererPackage.Read(path).Available, "Protocol15.32 companion was rejected");
        foreach (string invalid in new[] { valid.Replace("\"major\":15", "\"major\":16"),
            valid.Replace("\"minor\":30", "\"minor\":29"), valid.Replace("\"capabilities\":29", "\"capabilities\":1"),
            valid.Replace("\"minor\":30", "\"minor\":33"),
            valid.Replace("\"commands\"", "\"scene\""), valid.Replace("\"launchApi\":2", "\"launchApi\":1"),
            valid.Replace("\"companionExecutable\":\"godot.exe\"", "\"companionExecutable\":\"missing.exe\"") })
        {
            File.WriteAllText(path, invalid);
            Require(!RendererPackage.Read(path).Available, "Incompatible companion was accepted: " + invalid);
        }
    }

    public static int Main()
    {
        string root = Path.Combine(Path.GetTempPath(), "reintegral-renderers-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            Discovery(Path.Combine(root, "discovery"));
            InvalidPackages(Path.Combine(root, "invalid"));
            SettingsAndArguments(Path.Combine(root, "settings"));
            CompanionPackages(Path.Combine(root, "companion"));
            Console.WriteLine("Renderer discovery, rejection, persistence and launch arguments passed.");
            return 0;
        }
        catch (Exception error) { Console.Error.WriteLine(error); return 1; }
        finally { Directory.Delete(root, true); }
    }
}
