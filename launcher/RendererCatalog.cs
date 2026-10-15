using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace ReIntegral
{
    public static class RendererCatalog
    {
        public static List<RendererPackage> Discover(string installation, string profile)
        {
            var paths = new List<string>();
            string bundled = Path.Combine(installation, "renderer.json");
            if (File.Exists(bundled)) paths.Add(bundled);
            foreach (string root in new[] { Path.Combine(installation, "renderers"), Path.Combine(profile, "renderers") })
                if (Directory.Exists(root))
                    foreach (string directory in Directory.GetDirectories(root).OrderBy(value => value, StringComparer.OrdinalIgnoreCase))
                    {
                        string path = Path.Combine(directory, "renderer.json");
                        if (File.Exists(path)) paths.Add(path);
                    }
            var packages = paths.Distinct(StringComparer.OrdinalIgnoreCase).Select(RendererPackage.Read).ToList();
            foreach (var group in packages.GroupBy(package => package.Id, StringComparer.OrdinalIgnoreCase).Where(group => group.Skip(1).Any()))
                foreach (var package in group)
                    package.Error = "Duplicate renderer id '" + group.Key + "': " + String.Join(", ", group.Select(entry => entry.ManifestPath));
            foreach (string id in new[] { "legacy", "godot" })
                if (!packages.Any(package => package.Id == id)) packages.Add(RendererPackage.Missing(id));
            return packages.OrderBy(package => package.Id, StringComparer.Ordinal).ToList();
        }

        public static RendererPackage Select(List<RendererPackage> packages, string savedId, string defaultId)
        {
            string id = String.IsNullOrEmpty(savedId) ? defaultId : savedId;
            var selected = packages.FirstOrDefault(package => package.Id == id);
            if (selected != null) return selected;
            selected = RendererPackage.Missing(id);
            packages.Add(selected);
            return selected;
        }
    }
}
