using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace ReIntegral
{
    public static class GameLaunch
    {
        public static string Quote(string value)
        {
            var result = new StringBuilder("\"");
            int slashes = 0;
            foreach (char character in value)
            {
                if (character == '\\') { ++slashes; continue; }
                result.Append('\\', character == '"' ? slashes * 2 + 1 : slashes);
                result.Append(character);
                slashes = 0;
            }
            return result.Append('\\', slashes * 2).Append('"').ToString();
        }

        public static string Arguments(Settings settings, bool godot = false, bool nativeGraphics = true)
        {
            DisplaySettings.Validate(settings);
            uint frames;
            if (!UInt32.TryParse(settings.Frames, NumberStyles.None, CultureInfo.InvariantCulture, out frames))
                throw new ArgumentException("Frame limit must be a whole number; 0 means unlimited.");
            if (!Regex.IsMatch(settings.Stage, "^[a-z][a-z0-9_]*$"))
                throw new ArgumentException("Startup stage must be a stage identifier, such as title or s00a.");
            var arguments = new List<string> { "--disc", Quote(settings.DiscOne),
                "--disc-two", Quote(settings.DiscTwo), "--resolution", settings.Resolution,
                "--stage", settings.Stage };
            if (settings.Widescreen) arguments.Add("--widescreen");
            if (!godot && nativeGraphics && settings.TextureCorrection) arguments.Add("--texture-correction");
            if (!godot && nativeGraphics && settings.GeometryPrecision) arguments.Add("--geometry-precision");
            if (!godot && nativeGraphics && settings.DepthBuffer) arguments.Add("--depth-buffer");
            if (!godot && settings.Fullscreen) arguments.Add("--fullscreen");
            if (settings.DebugOverlay) arguments.Add("--debug-overlay");
            if (settings.BonusItems) arguments.Add("--bonus-items 1");
            if (settings.Invulnerable) arguments.Add("--invulnerable 1");
            if (settings.AutoCard) arguments.Add("--auto-card 1");
            if (settings.FastLoading) arguments.Add("--fast-loading 1");
            if (!String.IsNullOrWhiteSpace(settings.TextPack)) arguments.Add("--text-pack " + Quote(settings.TextPack));
            if (!String.IsNullOrWhiteSpace(settings.VoicePack)) arguments.Add("--voice-pack " + Quote(settings.VoicePack));
            if (frames > 0) arguments.Add("--frames " + settings.Frames);
            AddMantis(arguments, settings.MantisMemory);
            if (!String.IsNullOrWhiteSpace(settings.Advanced)) arguments.Add(settings.Advanced.Trim());
            return String.Join(" ", arguments);
        }

        private static void AddMantis(List<string> arguments, string value)
        {
            if (value == "off") return;
            int seed;
            if (value == "random") seed = new Random().Next(1, Int32.MaxValue);
            else if (!Int32.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out seed) || seed < 1)
                throw new ArgumentException("Mantis memory must be off, random, or a positive seed up to 2147483647.");
            arguments.Add("--mantis-memory " + seed.ToString(CultureInfo.InvariantCulture));
        }

        public static ProcessStartInfo StartInfo(string executable, string arguments, string directory)
        {
            var start = new ProcessStartInfo(executable, arguments) {
                WorkingDirectory = directory, UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true,
                StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8
            };
            var diagnostics = new List<string>();
            foreach (string name in start.EnvironmentVariables.Keys)
                if (name.StartsWith("MGS_GODOT_CAPTURE_", StringComparison.OrdinalIgnoreCase) ||
                    name.StartsWith("MGS_BASELINE_", StringComparison.OrdinalIgnoreCase) ||
                    name == "MGS_GODOT_DIAGNOSTIC_CAPTURE" || name == "MGS_GODOT_QUIT_FRAME")
                    diagnostics.Add(name);
            foreach (string name in diagnostics) start.EnvironmentVariables.Remove(name);
            start.EnvironmentVariables["MGS_GODOT_PERFORMANCE_RUN"] = "1";
            return start;
        }

        public static async Task ValidateDisc(string executable, string path, int number, string directory)
        {
            if (!File.Exists(path)) throw new FileNotFoundException("Select an existing Disc " + number + " CUE file.", path);
            await ValidateResource(executable, "--check-disc " + number + " " + Quote(Path.GetFullPath(path)),
                "Disc " + number, directory);
        }

        public static async Task ValidateLanguage(string executable, string path, string directory)
        {
            if (String.IsNullOrWhiteSpace(path)) return;
            if (!File.Exists(path)) throw new FileNotFoundException("Select an existing language pack.", path);
            await ValidateResource(executable, "--check-language " + Quote(Path.GetFullPath(path)),
                "Language pack", directory);
        }

        private static async Task ValidateResource(string executable, string arguments, string label, string directory)
        {
            using (var process = Process.Start(StartInfo(executable, arguments, directory)))
            {
                var output = process.StandardOutput.ReadToEndAsync();
                var error = process.StandardError.ReadToEndAsync();
                var complete = Task.WhenAll(output, error);
                if (await Task.WhenAny(complete, Task.Delay(15000)) != complete)
                {
                    process.Kill();
                    process.WaitForExit();
                    throw new IOException(label + " validation timed out. Check that the file is on an accessible local drive.");
                }
                await complete;
                process.WaitForExit();
                if (process.ExitCode != 0)
                    throw new InvalidDataException(label + " could not be validated.\n" + await error + await output);
            }
        }
    }
}
