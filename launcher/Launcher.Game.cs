using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace ReIntegral
{
    public sealed partial class Launcher
    {
        private async Task Play()
        {
            validating = true;
            play.Enabled = false;
            tabs.Enabled = false;
            ShowStartupProgress("Validating your discs and language packs…");
            try
            {
                var settings = ReadSettings();
                activeRenderer = SelectedRenderer;
                activeRenderer.RequireAvailable(settings);
                string executable = activeRenderer.Executable;
                activeArguments = activeRenderer.Arguments(settings);
                activeSettings = settings;
                await GameLaunch.ValidateDisc(executable, settings.DiscOne, 1, dataDirectory);
                await GameLaunch.ValidateDisc(executable, settings.DiscTwo, 2, dataDirectory);
                await GameLaunch.ValidateLanguage(executable, settings.TextPack, dataDirectory);
                if (settings.VoicePack != settings.TextPack)
                    await GameLaunch.ValidateLanguage(executable, settings.VoicePack, dataDirectory);
                settings.Save(settingsPath);
                rapidRestarts = 0;
                await StartGame();
            }
            catch (Exception error)
            {
                status.Text = "Setup needs attention.";
                MessageBox.Show(this, error.Message, "RE:INTEGRAL", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                FinishStartupProgress();
                validating = false;
                play.Enabled = game == null;
                tabs.Enabled = game == null;
            }
        }

        private async Task StartGame()
        {
            var progress = BeginStartupProgress();
            try
            {
                activeRenderer.RequireAvailable(activeSettings);
                if (activeRenderer.IsGodot)
                {
                    godot = new GodotSession(activeRenderer.GodotExecutable, activeRenderer.GodotProject, activeRenderer.GodotAssets, dataDirectory);
                }
                else if (activeRenderer.IsCompanion) godot = new PresentationSession(activeRenderer, dataDirectory);
                if (godot != null) await godot.Start(activeSettings, progress);
                StartNativeGame();
            }
            catch
            {
                StopGodot();
                throw;
            }
            finally { FinishStartupProgress(); }
        }

        private void StopGodot()
        {
            if (godot == null) return;
            godot.Dispose();
            godot = null;
        }

        private void StartNativeGame()
        {
            string path = Path.Combine(dataDirectory, "logs", DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-fff") + ".log");
            log = new StreamWriter(path, true) { AutoFlush = true };
            log.WriteLine("RE:INTEGRAL " + BuildInfo.Version + " (" + BuildInfo.Commit + ")");
            log.WriteLine("Renderer " + activeRenderer.Id + " " + activeRenderer.Version + " — " + activeRenderer.Executable);
            log.WriteLine(activeArguments);
            game = new Process { StartInfo = GameLaunch.StartInfo(activeRenderer.Executable, activeArguments, dataDirectory) };
            game.StartInfo.EnvironmentVariables["REI_CODEC_TURBO"] = activeSettings.CodecTurbo ? "1" : "0";
            if (godot != null) godot.Configure(game.StartInfo);
            game.OutputDataReceived += WriteLog;
            game.ErrorDataReceived += WriteLog;
            try { game.Start(); }
            catch { game.Dispose(); game = null; log.Dispose(); log = null; throw; }
            game.BeginOutputReadLine();
            game.BeginErrorReadLine();
            started = DateTime.UtcNow;
            play.Enabled = false;
            tabs.Enabled = false;
            status.Text = "Game running. Saves and logs are stored outside the installation folder.";
        }

        private void WriteLog(object sender, DataReceivedEventArgs args)
        {
            if (args.Data != null) lock (logLock) log.WriteLine(args.Data);
        }

        private async void TickGame(object sender, EventArgs args)
        {
            if (smoke)
            {
                smoke = false;
                var lateProgress = BeginStartupProgress();
                FinishStartupProgress();
                status.Text = "Ready. Your original disc images remain read-only.";
                lateProgress.Report("Importing scene — stale progress");
                await Task.Delay(100);
                if (startupBar.Visible || status.Text.Contains("stale progress"))
                    throw new InvalidOperationException("Finished startup accepted a delayed loading message.");
                using (var preview = new Bitmap(Width, Height))
                {
                    for (int index = 0; index < tabs.TabCount; ++index)
                    {
                        tabs.SelectedIndex = index;
                        DrawToBitmap(preview, new Rectangle(0, 0, Width, Height));
                        preview.Save(Path.Combine(dataDirectory, "launcher-" + index + ".png"));
                    }
                    tabs.SelectedIndex = 4;
                    ShowStartupProgress("Importing scene — Importing Scene... [46s elapsed]");
                    DrawToBitmap(preview, new Rectangle(0, 0, Width, Height));
                    preview.Save(Path.Combine(dataDirectory, "launcher-progress-busy.png"));
                    ShowStartupProgress("Preparing mod files: 25 / 100");
                    await Task.Delay(400);
                    DrawToBitmap(preview, new Rectangle(0, 0, Width, Height));
                    preview.Save(Path.Combine(dataDirectory, "launcher-progress-measured.png"));
                    FinishStartupProgress();
                }
                using (var dialog = new LanguageImportDialog(dataDirectory, discOne.Text, discTwo.Text))
                {
                    dialog.Show(this);
                    using (var preview = new Bitmap(dialog.Width, dialog.Height))
                    {
                        dialog.DrawToBitmap(preview, new Rectangle(0, 0, dialog.Width, dialog.Height));
                        preview.Save(Path.Combine(dataDirectory, "launcher-import.png"));
                    }
                    dialog.Close();
                }
                Close();
                return;
            }
            if (game == null || !game.HasExited) return;
            game.WaitForExit();
            int code = game.ExitCode;
            log.WriteLine("Native process exited with code " + code + " (0x" + code.ToString("X8") + ").");
            game.Dispose(); game = null;
            log.Dispose(); log = null;
            Guard(StopGodot);
            Guard(ReloadDisplaySettings);
            play.Enabled = true;
            tabs.Enabled = true;
            if (code == 75)
            {
                rapidRestarts = (DateTime.UtcNow - started).TotalSeconds > 5 ? 0 : rapidRestarts + 1;
                if (rapidRestarts < 3)
                {
                    validating = true;
                    play.Enabled = false;
                    tabs.Enabled = false;
                    try { await StartGame(); }
                    catch (Exception error)
                    {
                        status.Text = "Game restart failed: " + error.Message;
                        MessageBox.Show(this, status.Text, "RE:INTEGRAL", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }
                    finally { validating = false; play.Enabled = game == null; tabs.Enabled = game == null; }
                    return;
                }
            }
            status.Text = code == 0 ? "Game closed. Ready to play again." : "Game exited with code " + code + ". Open logs for details.";
            if (code != 0) MessageBox.Show(this, status.Text, "RE:INTEGRAL", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }

        private void ClosingLauncher(object sender, FormClosingEventArgs args)
        {
            if (game == null && !validating && !mods.Busy) return;
            args.Cancel = true;
            MessageBox.Show(this, "Close the game before closing the launcher.", "RE:INTEGRAL");
        }

        private void ReloadDisplaySettings()
        {
            var saved = Settings.Load(settingsPath);
            DisplaySettings.Assign(activeSettings, DisplaySettings.Values(saved));
            resolution.Text = saved.Resolution;
            wide.Checked = saved.Widescreen;
            fullscreen.Checked = saved.Fullscreen;
            activeArguments = activeRenderer.Arguments(activeSettings);
        }

    }
}
