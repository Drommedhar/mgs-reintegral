using System;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;

namespace ReIntegral
{
    internal static class SettingsHost
    {
        private static bool Flag(string value, bool saved)
        {
            if (value == "saved") return saved;
            if (value != "0" && value != "1") throw new ArgumentException("Display flags must be 0, 1 or saved.");
            return value == "1";
        }

        private static int Main(string[] args)
        {
            try
            {
                if (args.Length != 6) throw new ArgumentException("Expected settings.xml, ready file, stop file, resolution, widescreen and fullscreen.");
                string token = Environment.GetEnvironmentVariable("MGS_GODOT_SESSION_TOKEN");
                if (token == null || !Regex.IsMatch(token, "^[0-9a-fA-F]{32}$"))
                    throw new ArgumentException("Settings host requires the renderer session token.");
                string path = Path.GetFullPath(args[0]);
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                var launch = File.Exists(path) ? Settings.Load(path) : new Settings { Resolution = "1280x960", Widescreen = false };
                if (args[3] != "saved") launch.Resolution = args[3];
                launch.Widescreen = Flag(args[4], launch.Widescreen);
                launch.Fullscreen = Flag(args[5], launch.Fullscreen);
                DisplaySettings.Validate(launch);
                if (!File.Exists(path)) launch.Save(path);
                using (var bridge = new SettingsBridge(new SettingsRegistry(path, launch), token, Console.Error.WriteLine))
                {
                    string ready = new JavaScriptSerializer().Serialize(new { port = bridge.Port, launch = DisplaySettings.Values(launch) });
                    File.WriteAllText(args[1] + ".tmp", ready);
                    File.Move(args[1] + ".tmp", args[1]);
                    while (!File.Exists(args[2])) Thread.Sleep(100);
                }
                return 0;
            }
            catch (Exception error)
            {
                Console.Error.WriteLine("Settings host: " + error.Message);
                return 1;
            }
        }
    }
}
