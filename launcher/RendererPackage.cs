using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace ReIntegral
{
    public sealed class RendererManifest
    {
        public int schema;
        public int launchApi;
        public string id, name, version, backend, nativeArchitecture, rendererArchitecture;
        public string executable, godotExecutable, godotProject, godotAssets;
        public string companionExecutable, presentationAssets;
        public string[] companionArguments;
        public PresentationContract protocol;
        public bool nativeGraphicsOptions;
    }

    public sealed class RendererPackage
    {
        public string Id { get; private set; }
        public string Name { get; private set; }
        public string Version { get; private set; }
        public string ManifestPath { get; private set; }
        public string Error { get; internal set; }
        public string Executable { get; private set; }
        public string GodotExecutable { get; private set; }
        public string GodotProject { get; private set; }
        public string GodotAssets { get; private set; }
        public bool IsGodot { get; private set; }
        public bool IsCompanion { get; private set; }
        public string CompanionExecutable { get; private set; }
        public string[] CompanionArguments { get; private set; }
        public string PresentationAssets { get; private set; }
        public PresentationContract Protocol { get; private set; }
        public bool NativeGraphicsOptions { get; private set; }
        public bool Available { get { return String.IsNullOrEmpty(Error); } }

        public static RendererPackage Missing(string id)
        {
            return new RendererPackage { Id = id, Name = id == "legacy" ? "Legacy 0.2" : id == "godot" ? "Godot" : id,
                Version = "", Error = "Renderer is not installed: " + id };
        }

        public static RendererPackage Read(string path)
        {
            var package = Missing(Path.GetFileName(Path.GetDirectoryName(path)));
            package.ManifestPath = Path.GetFullPath(path);
            try
            {
                package.descriptorText = File.ReadAllText(path);
                var json = new JavaScriptSerializer();
                var fields = json.DeserializeObject(package.descriptorText) as Dictionary<string, object>;
                if (fields == null || !fields.ContainsKey("schema") || !(fields["schema"] is int) ||
                    !fields.ContainsKey("launchApi") || !(fields["launchApi"] is int))
                    throw new InvalidDataException("Renderer schema and launchApi must be integers.");
                var manifest = json.ConvertToType<RendererManifest>(fields);
                package.Load(manifest);
                package.Error = "";
            }
            catch (Exception error)
            {
                if (!(error is IOException || error is InvalidDataException || error is UnauthorizedAccessException ||
                    error is ArgumentException || error is InvalidOperationException || error is FormatException ||
                    error is OverflowException || error is NotSupportedException)) throw;
                package.Error = error.Message;
            }
            return package;
        }

        private void Load(RendererManifest manifest)
        {
            if (manifest == null || String.IsNullOrEmpty(manifest.id) || !Regex.IsMatch(manifest.id, "^[a-z][a-z0-9._-]{0,63}$"))
                throw new InvalidDataException("Renderer descriptor needs a valid id.");
            Id = manifest.id;
            Name = String.IsNullOrWhiteSpace(manifest.name) ? Id : manifest.name;
            Version = manifest.version;
            if (manifest.schema != 1 || manifest.launchApi != (manifest.backend == "companion" ? 2 : 1))
                throw new InvalidDataException("Unsupported renderer descriptor or launch API version.");
            if (String.IsNullOrWhiteSpace(Version)) throw new InvalidDataException("Renderer version is missing.");
            if (manifest.backend != "native" && manifest.backend != "godot" && manifest.backend != "companion")
                throw new InvalidDataException("Unsupported renderer backend: " + manifest.backend);
            if (manifest.nativeArchitecture != "x86")
                throw new InvalidDataException("This launcher requires an x86 native host.");
            IsGodot = manifest.backend == "godot";
            IsCompanion = manifest.backend == "companion";
            NativeGraphicsOptions = !IsGodot && !IsCompanion && manifest.nativeGraphicsOptions;
            Executable = RequiredFile(manifest.executable, "Native executable");
            if (IsCompanion) { LoadCompanion(manifest); return; }
            if (!IsGodot) return;
            if (manifest.rendererArchitecture != "x64" || !Environment.Is64BitOperatingSystem)
                throw new InvalidDataException("Godot requires an x64 renderer and operating system.");
            GodotExecutable = RequiredFile(manifest.godotExecutable, "Godot executable");
            GodotProject = Resolve(manifest.godotProject);
            GodotAssets = Resolve(manifest.godotAssets);
            RequireFile(Path.Combine(GodotProject, "project.godot"), "Godot project");
        }

        private void LoadCompanion(RendererManifest manifest)
        {
            if (manifest.rendererArchitecture != "x86" && manifest.rendererArchitecture != "x64")
                throw new InvalidDataException("Companion renderer architecture must be x86 or x64.");
            if (manifest.rendererArchitecture == "x64" && !Environment.Is64BitOperatingSystem)
                throw new InvalidDataException("This companion requires a 64-bit operating system.");
            if (manifest.protocol == null) throw new InvalidDataException("Companion presentation protocol is missing.");
            manifest.protocol.Validate();
            Protocol = manifest.protocol;
            CompanionExecutable = RequiredFile(manifest.companionExecutable, "Companion executable");
            CompanionArguments = manifest.companionArguments ?? new string[0];
            foreach (string argument in CompanionArguments)
                if (argument == null || argument.IndexOf('\0') >= 0) throw new InvalidDataException("Invalid companion argument.");
            if (!String.IsNullOrEmpty(manifest.presentationAssets))
            {
                PresentationAssets = Resolve(manifest.presentationAssets);
                RequireFile(Path.Combine(PresentationAssets, "catalog.json"), "Prepared disc content");
            }
        }

        private string Resolve(string path)
        {
            if (String.IsNullOrWhiteSpace(path) || Path.IsPathRooted(path))
                throw new InvalidDataException("Renderer paths must be relative to their descriptor.");
            return Path.GetFullPath(Path.Combine(Path.GetDirectoryName(ManifestPath), path));
        }

        private string RequiredFile(string path, string label)
        {
            string resolved = Resolve(path);
            RequireFile(resolved, label);
            return resolved;
        }

        private static void RequireFile(string path, string label)
        {
            if (!File.Exists(path)) throw new FileNotFoundException(label + " is missing: " + path, path);
        }

        public void RequireAvailable()
        {
            if (!Available) throw new InvalidOperationException(Name + ": " + Error);
            var current = Read(ManifestPath);
            if (!current.Available) throw new InvalidOperationException(Name + ": " + current.Error);
            if (current.descriptorText != descriptorText)
                throw new InvalidOperationException("Renderer descriptor changed. Restart the launcher to reload it.");
        }

        public void RequireAvailable(Settings settings)
        {
            RequireAvailable();
            if (IsGodot && !settings.GodotLegacyRendering)
                RequireFile(Path.Combine(GodotAssets, "catalog.json"), "Prepared disc content for Godot scene rendering");
        }

        private string descriptorText;

        public string Arguments(Settings settings)
        {
            return GameLaunch.Arguments(settings, IsGodot || IsCompanion, NativeGraphicsOptions);
        }

        public override string ToString()
        {
            return Name + (String.IsNullOrEmpty(Version) ? "" : " — " + Version) + (Available ? "" : " (unavailable)");
        }
    }
}
