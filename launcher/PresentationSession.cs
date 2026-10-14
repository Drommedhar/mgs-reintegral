using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace ReIntegral
{
    public sealed class PresentationSession : IRendererSession
    {
        private readonly RendererPackage package;
        private readonly string directory, token = RendererSession.NewToken();
        private string port, stop, prefix;
        private Process renderer;
        private Task logs;
        private SettingsBridge settingsBridge;

        public PresentationSession(RendererPackage package, string directory)
        {
            this.package = package;
            this.directory = directory;
        }

        public async Task Start(Settings settings, IProgress<string> progress)
        {
            package.RequireAvailable();
            port = RendererSession.ReservePort();
            prefix = Path.Combine(directory, "logs", "renderer-" + package.Id + "-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(Path.GetDirectoryName(prefix));
            string ready = prefix + ".ready.json";
            stop = prefix + ".stop";
            var start = GameLaunch.StartInfo(package.CompanionExecutable,
                String.Join(" ", package.CompanionArguments.Select(GameLaunch.Quote)), directory);
            ConfigureCompanion(start, settings, ready);
            settingsBridge = new SettingsBridge(new SettingsRegistry(Path.Combine(directory, "settings.xml"), settings), token,
                message => progress.Report(message));
            start.EnvironmentVariables["MGS_SETTINGS_PORT"] = settingsBridge.Port.ToString();
            progress.Report("Starting " + package.Name + "…");
            renderer = Process.Start(start);
            logs = Task.WhenAll(RendererSession.CopyLog(renderer.StandardOutput, prefix + ".log"),
                RendererSession.CopyLog(renderer.StandardError, prefix + ".err"));
            await WaitReady(ready);
        }

        private void ConfigureCompanion(ProcessStartInfo start, Settings settings, string ready)
        {
            start.EnvironmentVariables["MGS_PRESENTATION_PORT"] = port;
            start.EnvironmentVariables["MGS_PRESENTATION_TOKEN"] = token;
            start.EnvironmentVariables["MGS_PRESENTATION_READY_FILE"] = ready;
            start.EnvironmentVariables["MGS_PRESENTATION_STOP_FILE"] = stop;
            start.EnvironmentVariables["MGS_PRESENTATION_RENDERER_ID"] = package.Id;
            start.EnvironmentVariables["MGS_PRESENTATION_RESOLUTION"] = settings.Resolution;
            start.EnvironmentVariables["MGS_PRESENTATION_FULLSCREEN"] = settings.Fullscreen ? "1" : "0";
            start.EnvironmentVariables["MGS_PRESENTATION_ASSETS"] = package.PresentationAssets ?? "";
        }

        private async Task WaitReady(string ready)
        {
            var deadline = Stopwatch.StartNew();
            while (!File.Exists(ready))
            {
                if (renderer.HasExited || deadline.Elapsed.TotalSeconds > 30)
                    throw new IOException(package.Name + " did not start. See " + prefix + ".err");
                await Task.Delay(50);
            }
            var response = new JavaScriptSerializer().Deserialize<PresentationReady>(File.ReadAllText(ready));
            if (response == null || response.schema != 1 || response.rendererId != package.Id)
                throw new InvalidDataException("Invalid presentation readiness record: " + ready);
            package.Protocol.Match(response.protocol);
            if (renderer.HasExited) throw new IOException(package.Name + " exited during startup. See " + prefix + ".err");
        }

        public void Configure(ProcessStartInfo native)
        {
            native.EnvironmentVariables["MGS_GODOT_PORT"] = port;
            native.EnvironmentVariables["MGS_GODOT_SESSION_TOKEN"] = token;
            native.EnvironmentVariables["MGS_GODOT_SCENE_VIEW"] = package.Protocol.mode == "scene" ? "1" : "0";
            native.EnvironmentVariables["MGS_PRESENTATION_MINOR"] = package.Protocol.minor.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }

        public void Dispose()
        {
            try
            {
                if (renderer != null)
                {
                    if (!renderer.HasExited)
                    {
                        File.WriteAllText(stop, "stop\n");
                        if (!renderer.WaitForExit(2000)) renderer.Kill();
                    }
                    renderer.WaitForExit();
                    // The exited child closed its pipes; log pumps never capture the UI context.
                    if (logs != null) logs.GetAwaiter().GetResult();
                    renderer.Dispose();
                    renderer = null;
                }
            }
            finally
            {
                if (settingsBridge != null) settingsBridge.Dispose();
                settingsBridge = null;
            }
        }
    }
}
