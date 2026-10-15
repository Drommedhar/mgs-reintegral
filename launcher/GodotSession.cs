using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace ReIntegral
{
    public sealed class GodotSession : IRendererSession
    {
        private readonly string engineExecutable, projectSource, assetsDirectory, dataDirectory;
        private readonly string sessionToken = RendererSession.NewToken();
        private Process renderer;
        private SettingsBridge settingsBridge;
        private Task output, errors;
        private bool sceneEnabled = true;
        private int captureFrame;
        private string captureFile;
        private bool captureWorld;
        public string Port { get; private set; }

        public void EnableDiagnosticCapture(int frame, string path, bool includeWorld)
        {
            if (frame <= 0) throw new ArgumentOutOfRangeException("frame");
            captureFile = Path.GetFullPath(path);
            captureFrame = frame;
            captureWorld = includeWorld;
        }

        public GodotSession(string root, string directory)
            : this(Path.Combine(root, ".tools", "godot-4.8-dev7", "Godot_v4.8-dev7_win64_console.exe"),
                Path.Combine(root, "renderers", "godot", "project"), Path.Combine(root, ".local", "godot-content"), directory)
        {
        }

        public GodotSession(string executable, string project, string assets, string directory)
        {
            engineExecutable = executable;
            projectSource = project;
            assetsDirectory = assets;
            dataDirectory = directory;
        }

        public async Task Start(Settings settings, IProgress<string> progress)
        {
            var startup = Stopwatch.StartNew();
            string executable = engineExecutable;
            string assets = assetsDirectory;
            sceneEnabled = !settings.GodotLegacyRendering;
            if (!File.Exists(executable) || sceneEnabled && !File.Exists(Path.Combine(assets, "catalog.json")))
                throw new FileNotFoundException("This Godot build needs its renderer and prepared disc content. Run tools/prepare-godot-content.ps1 first.");
            IEnumerable<VisualMod> enabledMods = sceneEnabled ? (IEnumerable<VisualMod>)settings.Mods : new VisualMod[0];
            progress.Report(sceneEnabled ? "Preparing enabled mods…" : "Preparing Legacy through Godot…");
            string project = await Task.Run(() => GodotProject.Prepare(
                projectSource, dataDirectory, enabledMods, progress));
            string prefix = Path.Combine(dataDirectory, "logs", "godot-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-fff"));
            string timing = prefix + "-startup.txt";
            File.WriteAllText(timing, "project_ms=" + startup.ElapsedMilliseconds + Environment.NewLine);
            startup.Restart();
            if (!File.Exists(Path.Combine(project, ".import-complete")))
            {
                progress.Report("Importing mod resources…");
                await Import(executable, project, prefix + "-import", progress);
                if (sceneEnabled)
                {
                    await Import(executable, project, prefix + "-materials", progress,
                        "--headless --script res://prepare_material_textures.gd");
                    string[] changed = new JavaScriptSerializer().Deserialize<string[]>(
                        File.ReadAllText(Path.Combine(project, ".material-textures-changed")));
                    if (changed.Length != 0)
                        await Import(executable, project, prefix + "-filtered", progress);
                }
                File.WriteAllText(Path.Combine(project, ".import-complete"), "complete");
            }
            File.AppendAllText(timing, "import_ms=" + startup.ElapsedMilliseconds + Environment.NewLine);
            progress.Report(sceneEnabled ? "Starting Godot scene rendering…" : "Starting Legacy through Godot…");
            Port = RendererSession.ReservePort();
            string ready = prefix + ".ready";
            var start = GameLaunch.StartInfo(executable, "--path " + GameLaunch.Quote(project) +
                " --rendering-driver vulkan --resolution " + settings.Resolution +
                (settings.Fullscreen ? " --fullscreen" : ""), dataDirectory);
            start.EnvironmentVariables["MGS_GODOT_PORT"] = Port;
            start.EnvironmentVariables["MGS_PRESENTATION_MINOR"] = "35";
            start.EnvironmentVariables["MGS_GODOT_SESSION_TOKEN"] = sessionToken;
            start.EnvironmentVariables["MGS_GODOT_READY_FILE"] = ready;
            start.EnvironmentVariables["MGS_GODOT_ASSETS"] = assets;
            start.EnvironmentVariables["MGS_GODOT_SCENE_VIEW"] = sceneEnabled ? "1" : "0";
            start.EnvironmentVariables["MGS_GODOT_PIXEL_FONTS"] = settings.GodotSharpText ? "0" : "1";
            start.EnvironmentVariables["MGS_GODOT_RENDER_SIZE"] = settings.Resolution;
            start.EnvironmentVariables["MGS_GODOT_WIDESCREEN"] = settings.Widescreen ? "1" : "0";
            start.EnvironmentVariables["MGS_GODOT_MODS"] = new JavaScriptSerializer().Serialize(GodotProject.Manifests(project, enabledMods));
            start.EnvironmentVariables.Remove("MGS_GODOT_PROFILE");
            if (captureFrame > 0)
            {
                start.EnvironmentVariables["MGS_GODOT_PERFORMANCE_RUN"] = "0";
                start.EnvironmentVariables["MGS_GODOT_DIAGNOSTIC_CAPTURE"] = "1";
                start.EnvironmentVariables["MGS_GODOT_CAPTURE_FRAME"] = captureFrame.ToString(System.Globalization.CultureInfo.InvariantCulture);
                start.EnvironmentVariables["MGS_GODOT_CAPTURE_FILE"] = captureFile;
                start.EnvironmentVariables["MGS_GODOT_CAPTURE_WORLD"] = captureWorld ? "1" : "0";
            }
            settingsBridge = new SettingsBridge(new SettingsRegistry(Path.Combine(dataDirectory, "settings.xml"), settings),
                sessionToken, message => progress.Report(message));
            start.EnvironmentVariables["MGS_SETTINGS_PORT"] = settingsBridge.Port.ToString();
            renderer = Process.Start(start);
            output = RendererSession.CopyLog(renderer.StandardOutput, prefix + ".log", line => ReportProgress(line, progress));
            errors = RendererSession.CopyLog(renderer.StandardError, prefix + ".err");
            var deadline = Stopwatch.StartNew();
            while (!File.Exists(ready))
            {
                if (renderer.HasExited || deadline.Elapsed.TotalSeconds > 120)
                    throw new IOException("Godot could not start. See " + prefix + ".err");
                await Task.Delay(100);
            }
            File.AppendAllText(timing, "renderer_ms=" + deadline.ElapsedMilliseconds + Environment.NewLine);
        }

        internal static string ProgressMessage(string line)
        {
            line = Regex.Replace(line, @"\x1b\[[0-9;]*m", "");
            const string prefix = "MGS_LOAD_PROGRESS ";
            if (line.StartsWith(prefix, StringComparison.Ordinal)) return line.Substring(prefix.Length);
            var match = Regex.Match(line, @"^\[\s*(\d+)%\s*\]\s+(\w+)\s*\|\s*(.+)$");
            if (!match.Success) return null;
            string phase;
            switch (match.Groups[2].Value)
            {
                case "import": return "Importing scene — " + match.Groups[3].Value;
                case "reimport": phase = "Importing assets"; break;
                case "first_scan_filesystem":
                case "_update_scan_actions": phase = "Scanning resources"; break;
                case "update_scripts_classes": phase = "Registering scripts"; break;
                case "loading_editor_layout": phase = "Finishing import"; break;
                default: return null;
            }
            return phase + " (" + match.Groups[1].Value + "%) — " + match.Groups[3].Value;
        }

        private static void ReportProgress(string line, IProgress<string> progress)
        {
            string message = ProgressMessage(line);
            if (message != null) progress.Report(message);
        }

        private static async Task Import(string executable, string project, string prefix, IProgress<string> progress,
            string arguments = "--headless --editor --import")
        {
            using (var process = Process.Start(GameLaunch.StartInfo(executable,
                arguments + " --path " + GameLaunch.Quote(project), project)))
            {
                string current = "Starting mod resource import…";
                var elapsed = Stopwatch.StartNew();
                var logs = Task.WhenAll(RendererSession.CopyLog(process.StandardOutput, prefix + ".log", line =>
                    {
                        string message = ProgressMessage(line);
                        if (message != null) { current = message; progress.Report(message); }
                    }),
                    RendererSession.CopyLog(process.StandardError, prefix + ".err"));
                try
                {
                    while (await Task.WhenAny(logs, Task.Delay(1000)) != logs)
                    {
                        if (elapsed.Elapsed.TotalSeconds > 180)
                            throw new IOException("Mod resource import timed out. See " + prefix + ".err");
                        progress.Report(current + " [" + elapsed.Elapsed.TotalSeconds.ToString("0") + "s elapsed]");
                    }
                    await logs;
                    process.WaitForExit();
                    if (process.ExitCode != 0 || Regex.IsMatch(File.ReadAllText(prefix + ".err"), @"(?m)^(SCRIPT ERROR:|ERROR:)"))
                        throw new InvalidDataException("Mod resources could not be imported. See " + prefix + ".err");
                }
                finally
                {
                    if (!process.HasExited) process.Kill();
                    process.WaitForExit();
                }
            }
        }

        public void Configure(ProcessStartInfo start)
        {
            start.EnvironmentVariables["MGS_GODOT_PORT"] = Port;
            start.EnvironmentVariables["MGS_PRESENTATION_MINOR"] = "35";
            start.EnvironmentVariables["MGS_GODOT_SESSION_TOKEN"] = sessionToken;
            start.EnvironmentVariables["MGS_GODOT_SCENE_VIEW"] = sceneEnabled ? "1" : "0";
        }

        public void Dispose()
        {
            try { if (settingsBridge != null) settingsBridge.Dispose(); }
            finally { settingsBridge = null; StopRenderer(); }
        }

        private void StopRenderer()
        {
            if (renderer == null) return;
            if (!renderer.HasExited) renderer.Kill();
            renderer.WaitForExit();
            renderer.Dispose();
            renderer = null;
            Task.WaitAll(output, errors);
        }
    }
}
