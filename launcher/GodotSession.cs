using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace ReIntegral
{
    public sealed class GodotSession : IDisposable
    {
        private readonly string sourceRoot, dataDirectory;
        private Process renderer;
        private Task output, errors;
        public string Port { get; private set; }

        public GodotSession(string root, string directory)
        {
            sourceRoot = root;
            dataDirectory = directory;
        }

        public async Task Start(Settings settings, IProgress<string> progress)
        {
            string executable = Path.Combine(sourceRoot, ".tools", "godot-4.8-dev7", "Godot_v4.8-dev7_win64_console.exe");
            string assets = Path.Combine(sourceRoot, ".local", "godot-content");
            if (!File.Exists(executable) || !File.Exists(Path.Combine(assets, "catalog.json")))
                throw new FileNotFoundException("This Godot build needs its renderer and prepared disc content. Run tools/prepare-godot-content.ps1 first.");
            progress.Report("Preparing enabled mods…");
            string project = await Task.Run(() => GodotProject.Prepare(
                Path.Combine(sourceRoot, "renderers", "godot", "project"), dataDirectory, settings.Mods));
            string prefix = Path.Combine(dataDirectory, "logs", "godot-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-fff"));
            if (!File.Exists(Path.Combine(project, ".import-complete")))
            {
                progress.Report("Importing mod resources…");
                await Import(executable, project, prefix + "-import");
                File.WriteAllText(Path.Combine(project, ".import-complete"), "complete");
            }
            progress.Report("Starting Godot with the selected mods…");
            var listener = new TcpListener(IPAddress.Loopback, 0);
            listener.Start();
            try { Port = ((IPEndPoint)listener.LocalEndpoint).Port.ToString(); }
            finally { listener.Stop(); }
            string ready = prefix + ".ready";
            var start = GameLaunch.StartInfo(executable, "--path " + GameLaunch.Quote(project) +
                " --rendering-driver vulkan --resolution " + settings.Resolution +
                (settings.Fullscreen ? " --fullscreen" : ""), dataDirectory);
            start.EnvironmentVariables["MGS_GODOT_PORT"] = Port;
            start.EnvironmentVariables["MGS_GODOT_READY_FILE"] = ready;
            start.EnvironmentVariables["MGS_GODOT_ASSETS"] = assets;
            start.EnvironmentVariables["MGS_GODOT_SCENE_VIEW"] = "1";
            start.EnvironmentVariables["MGS_GODOT_RENDER_SIZE"] = settings.Resolution;
            start.EnvironmentVariables["MGS_GODOT_MODS"] = new JavaScriptSerializer().Serialize(GodotProject.Manifests(project, settings.Mods));
            renderer = Process.Start(start);
            output = CopyLog(renderer.StandardOutput, prefix + ".log");
            errors = CopyLog(renderer.StandardError, prefix + ".err");
            var deadline = Stopwatch.StartNew();
            while (!File.Exists(ready))
            {
                if (renderer.HasExited || deadline.Elapsed.TotalSeconds > 60)
                    throw new IOException("Godot could not start. See " + prefix + ".err");
                await Task.Delay(100);
            }
        }

        private static async Task Import(string executable, string project, string prefix)
        {
            using (var process = Process.Start(GameLaunch.StartInfo(executable,
                "--headless --editor --import --path " + GameLaunch.Quote(project), project)))
            {
                var logs = Task.WhenAll(CopyLog(process.StandardOutput, prefix + ".log"),
                    CopyLog(process.StandardError, prefix + ".err"));
                try
                {
                    if (await Task.WhenAny(logs, Task.Delay(180000)) != logs)
                        throw new IOException("Mod resource import timed out. See " + prefix + ".err");
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

        private static async Task CopyLog(StreamReader reader, string path)
        {
            using (var writer = new StreamWriter(path) { AutoFlush = true })
            {
                string line;
                while ((line = await reader.ReadLineAsync().ConfigureAwait(false)) != null)
                    await writer.WriteLineAsync(line).ConfigureAwait(false);
            }
        }

        public void Configure(ProcessStartInfo start)
        {
            start.EnvironmentVariables["MGS_GODOT_PORT"] = Port;
            start.EnvironmentVariables["MGS_GODOT_SCENE_VIEW"] = "1";
        }

        public void Dispose()
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
