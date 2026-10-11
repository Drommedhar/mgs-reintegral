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
        public static string Prepare(string source, string dataDirectory, IEnumerable<VisualMod> mods)
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
            string key = Fingerprint(files);
            string destination = Path.Combine(dataDirectory, "godot-projects", key);
            if (Directory.Exists(destination)) return destination;
            string staging = Path.Combine(dataDirectory, "godot-projects", ".prepare-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(staging);
            try
            {
                foreach (var file in files)
                {
                    string path = Path.Combine(staging, file.Key);
                    Directory.CreateDirectory(Path.GetDirectoryName(path));
                    File.Copy(file.Value, path);
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
            foreach (string shader in new[] { "psx.vert.glsl", "psx.frag.glsl" })
                files.Add(".generated/" + shader, Path.Combine(source, ".generated", shader));
            return files;
        }

        private static string Fingerprint(SortedDictionary<string, string> files)
        {
            var fingerprint = new StringBuilder("runtime-project-v1\n");
            foreach (var file in files)
            {
                using (var stream = File.OpenRead(file.Value))
                    fingerprint.Append(file.Key).Append('\n').Append(ModPackage.Hash(stream)).Append('\n');
            }
            using (var stream = new MemoryStream(Encoding.UTF8.GetBytes(fingerprint.ToString())))
                return ModPackage.Hash(stream);
        }

        public static string[] Manifests(string project, IEnumerable<VisualMod> mods)
        {
            return mods.Where(mod => mod.Enabled).Select(mod =>
                Path.Combine(project, "mods", mod.Package, "mod.json").Replace('\\', '/')).ToArray();
        }
    }
}
