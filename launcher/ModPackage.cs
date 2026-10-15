using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace ReIntegral
{
    public static class ModPackage
    {
        private const long MaximumBytes = 2L * 1024 * 1024 * 1024;

        public static string Hash(Stream stream)
        {
            using (var hash = SHA256.Create())
                return BitConverter.ToString(hash.ComputeHash(stream)).Replace("-", "").ToLowerInvariant();
        }

        public static string Folder(string dataDirectory, VisualMod mod)
        {
            if (!Regex.IsMatch(mod.Package, "^[a-f0-9]{64}$"))
                throw new InvalidDataException("Invalid installed package: " + mod.Id);
            return Path.Combine(dataDirectory, "mods", mod.Package);
        }

        public static VisualMod Install(string zip, string dataDirectory)
        {
            using (var source = File.OpenRead(zip))
            {
                string hash = Hash(source);
                source.Position = 0;
                using (var archive = new ZipArchive(source, ZipArchiveMode.Read))
                {
                    ValidateEntries(archive);
                    var mod = ReadManifest(archive);
                    mod.Package = hash;
                    string destination = Folder(dataDirectory, mod);
                    if (Directory.Exists(destination)) return mod;
                    string staging = Path.Combine(dataDirectory, "mods", ".install-" + Guid.NewGuid().ToString("N"));
                    Directory.CreateDirectory(staging);
                    try
                    {
                        Extract(archive, staging);
                        Directory.Move(staging, destination);
                    }
                    finally { if (Directory.Exists(staging)) Directory.Delete(staging, true); }
                    return mod;
                }
            }
        }

        private static void ValidateEntries(ZipArchive archive)
        {
            if (archive.Entries.Count > 10000) throw new InvalidDataException("Mod ZIP contains too many files.");
            var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            long total = 0;
            foreach (var entry in archive.Entries)
            {
                string path = EntryPath(entry.FullName);
                if (!paths.Add(path)) throw new InvalidDataException("Duplicate ZIP path: " + path);
                if (((entry.ExternalAttributes >> 16) & 0xF000) == 0xA000)
                    throw new InvalidDataException("Mod ZIP cannot contain symbolic links: " + path);
                if (entry.Length > MaximumBytes - total)
                    throw new InvalidDataException("Mod ZIP exceeds the 2 GiB unpacked limit.");
                total += entry.Length;
            }
        }

        private static string EntryPath(string name)
        {
            string path = name.Replace('\\', '/').TrimEnd('/');
            foreach (string part in path.Split('/'))
            {
                if (part.Length == 0 || part == "." || part == ".." || part.EndsWith(".") || part.EndsWith(" ") ||
                    part.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 ||
                    Regex.IsMatch(part, "^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])($|\\.)", RegexOptions.IgnoreCase))
                    throw new InvalidDataException("Unsafe ZIP path: " + name);
            }
            return path;
        }

        private static VisualMod ReadManifest(ZipArchive archive)
        {
            var entry = archive.GetEntry("mod.json");
            if (entry == null || entry.Length > 1024 * 1024)
                throw new InvalidDataException("Select an exported mod ZIP containing mod.json at its root.");
            Dictionary<string, object> manifest;
            using (var reader = new StreamReader(entry.Open()))
                manifest = new JavaScriptSerializer().DeserializeObject(reader.ReadToEnd()) as Dictionary<string, object>;
            object schema, identity, name;
            if (manifest == null || !manifest.TryGetValue("schema", out schema) ||
                !(schema is int || schema is decimal || schema is double) || Convert.ToDecimal(schema) != 1m ||
                !manifest.TryGetValue("id", out identity) || !(identity is string) || String.IsNullOrWhiteSpace((string)identity))
                throw new InvalidDataException("Mod ZIP requires a schema 1 manifest with a nonempty ID.");
            ValidateReferences(archive, manifest);
            return new VisualMod { Id = (string)identity,
                Name = manifest.TryGetValue("name", out name) && name is string ? (string)name : (string)identity };
        }

        private static void ValidateReferences(ZipArchive archive, Dictionary<string, object> manifest)
        {
            foreach (string section in new[] { "stages", "replacements", "materials" })
            {
                object raw;
                if (!manifest.TryGetValue(section, out raw)) continue;
                var entries = raw as Dictionary<string, object>;
                if (entries == null) throw new InvalidDataException("Invalid mod manifest section: " + section);
                foreach (object value in entries.Values)
                {
                    var entry = value as Dictionary<string, object>;
                    if (entry == null) throw new InvalidDataException("Invalid mod entry in " + section);
                    if (section == "materials")
                    {
                        foreach (string field in new[] { "albedo", "normal", "orm", "emission" })
                            if (entry.ContainsKey(field)) RequireFile(archive, entry, field);
                    }
                    else RequireFile(archive, entry, section == "stages" ? "scene" : "path");
                }
            }
            object extensions;
            if (!manifest.TryGetValue("extensions", out extensions)) return;
            var array = extensions as object[];
            if (array == null) throw new InvalidDataException("Mod extensions must be an array.");
            foreach (object value in array) RequireFile(archive, value as Dictionary<string, object>, "path");
        }

        private static void RequireFile(ZipArchive archive, Dictionary<string, object> entry, string field)
        {
            object value;
            if (entry == null || !entry.TryGetValue(field, out value) || !(value is string))
                throw new InvalidDataException("Mod entry requires " + field);
            string path = EntryPath((string)value);
            if (archive.GetEntry(path) == null) throw new InvalidDataException("Mod ZIP is missing " + path);
        }

        private static void Extract(ZipArchive archive, string directory)
        {
            foreach (var entry in archive.Entries)
            {
                string path = Path.Combine(directory, EntryPath(entry.FullName));
                if (entry.FullName.EndsWith("/") || entry.FullName.EndsWith("\\"))
                {
                    Directory.CreateDirectory(path);
                    continue;
                }
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                using (var input = entry.Open())
                using (var output = new FileStream(path, FileMode.CreateNew))
                {
                    var buffer = new byte[65536];
                    long remaining = entry.Length;
                    int count;
                    while ((count = input.Read(buffer, 0, buffer.Length)) != 0)
                    {
                        if (count > remaining) throw new InvalidDataException("ZIP entry exceeds its declared size.");
                        output.Write(buffer, 0, count);
                        remaining -= count;
                    }
                    if (remaining != 0) throw new InvalidDataException("Truncated ZIP entry: " + entry.FullName);
                }
            }
        }
    }
}
