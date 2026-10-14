using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace ReIntegral
{
    public static class GodotProject
    {
        public static string Prepare(string source, string dataDirectory, IEnumerable<VisualMod> mods, IProgress<string> progress = null)
        {
            var files = RuntimeFiles(source);
            var ids = new HashSet<string>(StringComparer.Ordinal);
            foreach (var mod in mods.Where(value => value.Enabled))
            {
                if (!ids.Add(mod.Id)) throw new InvalidDataException("Mod enabled twice: " + mod.Id);
                string package = ModPackage.Folder(dataDirectory, mod);
                if (!File.Exists(Path.Combine(package, "mod.json")))
                    throw new FileNotFoundException("Reinstall the missing mod ZIP: " + mod.Id);
                foreach (string path in Directory.GetFiles(package, "*", SearchOption.AllDirectories))
                    files.Add("mods/" + mod.Package + "/" + path.Substring(package.Length + 1).Replace('\\', '/'), path);
            }
            string key = Fingerprint(files, progress);
            string destination = Path.Combine(dataDirectory, "godot-projects", key);
            if (Directory.Exists(destination)) return destination;
            string staging = Path.Combine(dataDirectory, "godot-projects", ".prepare-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(staging);
            try
            {
                int copied = 0;
                foreach (var file in files)
                {
                    string path = Path.Combine(staging, file.Key);
                    Directory.CreateDirectory(Path.GetDirectoryName(path));
                    File.Copy(file.Value, path);
                    Report(progress, "Preparing mod files", ++copied, files.Count);
                }
                string config = Path.Combine(staging, "project.godot");
                string text = File.ReadAllText(config);
                text = Regex.Replace(text, @"(?ms)^\[editor_plugins\]\r?\n.*?(?=^\[|\z)", "");
                File.WriteAllText(config, text, new UTF8Encoding(false));
                Directory.Move(staging, destination);
            }
            finally { if (Directory.Exists(staging)) Directory.Delete(staging, true); }
            return destination;
        }

        private static SortedDictionary<string, string> RuntimeFiles(string source)
        {
            if (!File.Exists(Path.Combine(source, "project.godot")))
                throw new FileNotFoundException("Godot renderer project is missing: " + source);
            var files = new SortedDictionary<string, string>(StringComparer.Ordinal);
            foreach (string path in Directory.GetFiles(source)) files.Add(Path.GetFileName(path), path);
            foreach (string generated in new[] { "psx.vert.glsl", "psx.frag.glsl", "legacy-debug-font.bin", "SDL_render_debug_font.h" })
                files.Add(".generated/" + generated, Path.Combine(source, ".generated", generated));
            return files;
        }

        private static string Fingerprint(SortedDictionary<string, string> files, IProgress<string> progress)
        {
            var fingerprint = new StringBuilder("runtime-project-v1\n");
            int checkedFiles = 0;
            foreach (var file in files)
            {
                using (var stream = File.OpenRead(file.Value))
                    fingerprint.Append(file.Key).Append('\n').Append(ModPackage.Hash(stream)).Append('\n');
                Report(progress, "Checking renderer and mod files", ++checkedFiles, files.Count);
            }
            using (var stream = new MemoryStream(Encoding.UTF8.GetBytes(fingerprint.ToString())))
                return ModPackage.Hash(stream);
        }

        private static void Report(IProgress<string> progress, string phase, int complete, int total)
        {
            if (progress != null && (complete == 1 || complete % 25 == 0 || complete == total))
                progress.Report(phase + ": " + complete + " / " + total);
        }

        public static string[] Manifests(string project, IEnumerable<VisualMod> mods)
        {
            return mods.Where(mod => mod.Enabled).Select(mod =>
                Path.Combine(project, "mods", mod.Package, "mod.json").Replace('\\', '/')).ToArray();
        }
    }
}
