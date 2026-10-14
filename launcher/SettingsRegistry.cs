using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;

namespace ReIntegral
{
    public sealed class SettingsRequest
    {
        public int schema { get; set; }
        public int id { get; set; }
        public string token { get; set; }
        public string action { get; set; }
        public string revision { get; set; }
        public Dictionary<string, object> values { get; set; }
    }

    public sealed class SettingsRegistry
    {
        private readonly string path;
        private readonly Dictionary<string, object> launch;
        private readonly object gate = new object();

        public SettingsRegistry(string settingsPath, Settings launched)
        {
            path = settingsPath;
            DisplaySettings.Validate(launched);
            launch = DisplaySettings.Values(launched);
        }

        private string Revision()
        {
            if (!File.Exists(path)) return "absent";
            using (var hash = SHA256.Create())
                return BitConverter.ToString(hash.ComputeHash(File.ReadAllBytes(path))).Replace("-", "").ToLowerInvariant();
        }

        private Dictionary<string, object> Snapshot(Settings saved)
        {
            var values = DisplaySettings.Values(saved);
            var restart = new List<string>();
            foreach (var pair in launch)
                if (!Object.Equals(pair.Value, values[pair.Key])) restart.Add(pair.Key);
            return new Dictionary<string, object> {
                { "schema", 1 }, { "revision", Revision() }, { "definitions", DisplaySettings.Describe() },
                { "launch", new Dictionary<string, object>(launch) }, { "saved", values }, { "restart_required", restart }, { "live_apply", false }
            };
        }

        public Dictionary<string, object> Execute(SettingsRequest request)
        {
            if (request == null || request.schema != 1 || request.id < 1)
                throw new ArgumentException("Invalid settings request schema or ID.");
            lock (gate)
            {
                var saved = Settings.Load(path);
                if (request.action == "read") return Snapshot(saved);
                if (request.action != "validate" && request.action != "save")
                    throw new ArgumentException("Unknown settings action.");
                if (String.IsNullOrEmpty(request.revision) || request.revision != Revision())
                    throw new InvalidOperationException("Settings changed since they were read. Reload before applying.");
                DisplaySettings.Assign(saved, request.values);
                if (request.action == "save") saved.Save(path);
                var result = Snapshot(Settings.Load(path));
                if (request.action == "validate") result["candidate"] = DisplaySettings.Values(saved);
                return result;
            }
        }
    }
}
