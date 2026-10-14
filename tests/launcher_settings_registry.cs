using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using ReIntegral;

internal static class SettingsRegistryTest
{
    private static readonly string Token = Guid.NewGuid().ToString("N");
    private static void Check(bool value, string message)
    {
        if (!value) throw new InvalidOperationException(message);
    }

    private static SettingsRequest Request(string action, string revision = null, Dictionary<string, object> values = null)
    {
        return new SettingsRequest { schema = 1, id = 1, token = Token, action = action, revision = revision, values = values };
    }

    private static void Rejected(SettingsRegistry registry, SettingsRequest request)
    {
        try { registry.Execute(request); }
        catch (ArgumentException) { return; }
        catch (InvalidOperationException) { return; }
        throw new InvalidOperationException("Invalid settings request accepted.");
    }

    private static Settings Seed(string path)
    {
        var value = new Settings { DiscOne = "日本語/disc.cue", VoicePack = "voices.mgslang", DebugOverlay = true,
            Mods = new List<VisualMod> { new VisualMod { Id = "keep.me", Name = "Untouched", Enabled = false, Package = "custom.zip" } } };
        value.Save(path);
        return value;
    }

    private static void RegistryChecks(string path)
    {
        var launch = Seed(path);
        var registry = new SettingsRegistry(path, launch);
        var initial = registry.Execute(Request("read"));
        string revision = (string)initial["revision"], original = File.ReadAllText(path);
        var changes = new Dictionary<string, object> { { "display.resolution", "1920x1080" }, { "display.fullscreen", true } };
        var proposed = registry.Execute(Request("validate", revision, changes));
        Check(File.ReadAllText(path) == original && proposed.ContainsKey("candidate"), "Validation wrote settings.");
        foreach (var pair in new Dictionary<string, object> { { "unknown", false }, { "display.fullscreen", 1 },
            { "display.widescreen", "true" }, { "display.resolution", "7680x4320" } })
            Rejected(registry, Request("save", revision, new Dictionary<string, object> { { pair.Key, pair.Value } }));
        Rejected(registry, Request("save", "stale", changes));
        Rejected(registry, Request("apply", revision, changes));
        Check(File.ReadAllText(path) == original, "Rejected settings changed storage.");
        var saved = registry.Execute(Request("save", revision, changes));
        var loaded = Settings.Load(path);
        Check(loaded.Resolution == "1920x1080" && loaded.Fullscreen, "Confirmed settings not persisted.");
        Check(loaded.DiscOne == launch.DiscOne && loaded.VoicePack == launch.VoicePack && loaded.DebugOverlay &&
            loaded.Mods.Count == 1 && loaded.Mods[0].Id == "keep.me" && !loaded.Mods[0].Enabled, "Unrelated settings overwritten.");
        Check(((Dictionary<string, object>)saved["launch"])["display.resolution"].Equals("1280x720"), "Saved values claimed live application.");
        Check(((List<string>)saved["restart_required"]).Count == 2, "Missing restart requirements.");
        Check(GameLaunch.Arguments(loaded, true).Contains("--resolution 1920x1080"), "Native next launch ignored saved resolution.");
        Rejected(registry, Request("save", revision, changes));
        string current = File.ReadAllText(path);
        loaded.DebugOverlay = false;
        loaded.Save(path);
        Rejected(registry, Request("save", (string)saved["revision"], changes));
        Check(!Settings.Load(path).DebugOverlay, "Stale request overwrote newer launcher values.");
        Check(current != File.ReadAllText(path), "Concurrent-change fixture failed.");
        var restore = DisplaySettings.Values(launch);
        var restored = registry.Execute(Request("save", (string)registry.Execute(Request("read"))["revision"], restore));
        Check(((List<string>)restored["restart_required"]).Count == 0, "Restoring launch values retained restart flags.");
        Check(Directory.GetFiles(Path.GetDirectoryName(path), "*.tmp").Length == 0, "Temporary files leaked.");
    }

    private static Dictionary<string, object> Exchange(int port, SettingsRequest request)
    {
        var json = new JavaScriptSerializer();
        using (var client = new TcpClient("127.0.0.1", port))
        using (var stream = client.GetStream())
        {
            client.ReceiveTimeout = 5000;
            var writer = new BinaryWriter(stream, Encoding.UTF8, true);
            byte[] body = Encoding.UTF8.GetBytes(json.Serialize(request));
            writer.Write(body.Length);
            writer.Write(body);
            writer.Flush();
            var reader = new BinaryReader(stream);
            int length = reader.ReadInt32();
            Check(length > 0 && length <= 65536, "Invalid response size.");
            return json.Deserialize<Dictionary<string, object>>(Encoding.UTF8.GetString(reader.ReadBytes(length)));
        }
    }

    private static void BridgeChecks(string path)
    {
        var launch = Seed(path);
        using (var bridge = new SettingsBridge(new SettingsRegistry(path, launch), Token, Console.Error.WriteLine))
        {
            var request = Request("read");
            var response = Exchange(bridge.Port, request);
            Check((string)response["error"] == "" && response.ContainsKey("snapshot"), "Authenticated read failed.");
            request.token = new string('0', 32);
            response = Exchange(bridge.Port, request);
            Check((string)response["error"] != "" && !response.ContainsKey("snapshot"), "Unauthenticated client read settings.");
            using (var unfinished = new TcpClient("127.0.0.1", bridge.Port))
            {
                unfinished.GetStream().WriteByte(64);
                Thread.Sleep(30);
                bridge.Dispose();
            }
        }
    }

    private static int Main()
    {
        string directory = Path.Combine(Path.GetTempPath(), "mgs-settings-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try
        {
            RegistryChecks(Path.Combine(directory, "settings.xml"));
            BridgeChecks(Path.Combine(directory, "settings.xml"));
            Console.WriteLine("SETTINGS REGISTRY TEST passed");
            return 0;
        }
        finally { Directory.Delete(directory, true); }
    }
}
