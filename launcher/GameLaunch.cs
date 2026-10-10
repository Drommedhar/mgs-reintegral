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

        public static string Arguments(Settings settings)
        {
            ValidateDisplay(settings);
            uint frames;
            if (!UInt32.TryParse(settings.Frames, NumberStyles.None, CultureInfo.InvariantCulture, out frames))
                throw new ArgumentException("Frame limit must be a whole number; 0 means unlimited.");
            if (!Regex.IsMatch(settings.Stage, "^[a-z][a-z0-9_]*$"))
                throw new ArgumentException("Startup stage must be a stage identifier, such as title or s00a.");
            var arguments = new List<string> { "--disc", Quote(settings.DiscOne),
                "--disc-two", Quote(settings.DiscTwo), "--resolution", settings.Resolution,
                "--stage", settings.Stage };
            if (settings.Widescreen) arguments.Add("--widescreen");
            if (settings.TextureCorrection) arguments.Add("--texture-correction");
            if (settings.GeometryPrecision) arguments.Add("--geometry-precision");
            if (settings.DepthBuffer) arguments.Add("--depth-buffer");
            if (settings.Fullscreen) arguments.Add("--fullscreen");
            if (settings.DebugOverlay) arguments.Add("--debug-overlay");
            if (settings.BonusItems) arguments.Add("--bonus-items 1");
            if (settings.Invulnerable) arguments.Add("--invulnerable 1");
            if (settings.AutoCard) arguments.Add("--auto-card 1");
            if (frames > 0) arguments.Add("--frames " + settings.Frames);
            AddMantis(arguments, settings.MantisMemory);
            if (!String.IsNullOrWhiteSpace(settings.Advanced)) arguments.Add(settings.Advanced.Trim());
            return String.Join(" ", arguments);
        }

        private static void ValidateDisplay(Settings settings)
        {
            var match = Regex.Match(settings.Resolution, "^([0-9]{3,4})x([0-9]{3,4})$");
            if (!match.Success) throw new ArgumentException("Resolution must use WIDTHxHEIGHT, such as 1920x1080.");
            int width = Int32.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
            int height = Int32.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture);
            if (width < 320 || width > 2560 || height < 240 || height > (settings.Widescreen ? 1792 : 1920))
                throw new ArgumentException("This renderer supports up to 2560x1792 widescreen or 2560x1920 original aspect.");
            if (settings.Widescreen && (width * 3 < height * 4 || width * 3 > height * 12))
                throw new ArgumentException("Widescreen aspect ratio must be between 4:3 and 4:1.");
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
            return new ProcessStartInfo(executable, arguments) {
                WorkingDirectory = directory, UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true,
                StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8
            };
        }

        public static async Task ValidateDisc(string executable, string path, int number, string directory)
        {
            if (!File.Exists(path)) throw new FileNotFoundException("Select an existing Disc " + number + " CUE file.", path);
            using (var process = Process.Start(StartInfo(executable,
                "--check-disc " + number + " " + Quote(Path.GetFullPath(path)), directory)))
            {
                var output = process.StandardOutput.ReadToEndAsync();
                var error = process.StandardError.ReadToEndAsync();
                var complete = Task.WhenAll(output, error);
                if (await Task.WhenAny(complete, Task.Delay(15000)) != complete)
                {
                    process.Kill();
                    process.WaitForExit();
                    throw new IOException("Disc validation timed out. Check that the image is on an accessible local drive.");
                }
                await complete;
                process.WaitForExit();
                if (process.ExitCode != 0)
                    throw new InvalidDataException("Disc " + number + " could not be validated.\n" + await error + await output);
            }
        }
    }
}
