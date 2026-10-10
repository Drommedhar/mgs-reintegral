using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace ReIntegral
{
    public sealed class Launcher : Form
    {
        private readonly string dataDirectory, executable, settingsPath;
        private readonly TextBox discOne = new TextBox(), discTwo = new TextBox();
        private readonly TextBox textPack = new TextBox(), voicePack = new TextBox();
        private readonly ComboBox resolution = new ComboBox(), mantis = new ComboBox();
        private readonly CheckBox wide = new CheckBox(), fullscreen = new CheckBox();
        private readonly CheckBox textureCorrection = new CheckBox();
        private readonly CheckBox geometryPrecision = new CheckBox(), depthBuffer = new CheckBox();
        private readonly CheckBox bonus = new CheckBox(), invulnerable = new CheckBox();
        private readonly CheckBox autoCard = new CheckBox(), overlay = new CheckBox();
        private readonly CheckBox fastLoading = new CheckBox();
        private readonly TextBox stage = new TextBox(), frames = new TextBox(), advanced = new TextBox();
        private readonly Button play = new Button();
        private readonly Label status = new Label();
        private readonly Timer timer = new Timer();
        private readonly object logLock = new object();
        private readonly TabControl tabs = new TabControl();
        private readonly FileStream instanceLock;
        private Process game;
        private StreamWriter log;
        private string activeArguments;
        private DateTime started;
        private int rapidRestarts;
        private bool smoke;
        private bool validating;

        public Launcher(string directory, bool smokeTest)
        {
            dataDirectory = directory;
            smoke = smokeTest;
            Directory.CreateDirectory(dataDirectory);
            Directory.CreateDirectory(Path.Combine(dataDirectory, "logs"));
            instanceLock = new FileStream(Path.Combine(dataDirectory, "launcher.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            executable = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "mgs-integral-native.exe");
            settingsPath = Path.Combine(dataDirectory, "settings.xml");
            Text = "RE:INTEGRAL — " + BuildInfo.Version;
            Font = new Font("Segoe UI", 9F);
            AutoScaleMode = AutoScaleMode.Dpi;
            ClientSize = new Size(720, 665);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BuildLayout();
            LoadSettings(Settings.Load(settingsPath));
            timer.Interval = 400;
            timer.Tick += TickGame;
            timer.Start();
            FormClosing += ClosingLauncher;
            FormClosed += delegate { timer.Dispose(); instanceLock.Dispose(); };
        }

        private void BuildLayout()
        {
            var logo = new PictureBox { Left = 16, Top = 0, Width = 688, Height = 190, SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.FromArgb(25, 28, 30) };
            using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("logo.png"))
            using (var source = Image.FromStream(stream)) logo.Image = new Bitmap(source);
            logo.Disposed += delegate { logo.Image.Dispose(); };
            Controls.Add(logo);
            tabs.SetBounds(16, 202, 688, 365);
            Controls.Add(tabs);
            BuildDisplay();
            BuildGraphics();
            BuildGameplay();
            BuildLanguages();
            BuildAdvanced();
            play.Text = "Save and play";
            play.SetBounds(550, 580, 154, 34);
            play.Click += async delegate { await Play(); };
            Controls.Add(play);
            AddButton(Controls, "Save settings", 16, 580, delegate { Guard(Save); });
            AddButton(Controls, "Open logs", 154, 580, delegate { Guard(delegate { OpenFolder("logs"); }); });
            AddButton(Controls, "Open save folder", 292, 580, delegate { Guard(delegate { OpenFolder(""); }); });
            status.SetBounds(16, 617, 688, 20);
            status.Text = "Ready. Your original disc images remain read-only.";
            Controls.Add(status);
            var notice = new Label { Text = "Unofficial project; not affiliated with or endorsed by Konami", Left = 16, Top = 642, Width = 688 };
            Controls.Add(notice);
        }

        private TabPage Page(string title)
        {
            var page = new TabPage(title) { Padding = new Padding(12), UseVisualStyleBackColor = true };
            tabs.TabPages.Add(page);
            return page;
        }

        private static void LabelAt(Control parent, string text, int y)
        {
            parent.Controls.Add(new Label { Text = text, Left = 16, Top = y, Width = 640, Height = 24 });
        }

        private static void AddButton(Control.ControlCollection controls, string text, int x, int y, EventHandler action)
        {
            var button = new Button { Text = text, Left = x, Top = y, Width = 130, Height = 34 };
            button.Click += action;
            controls.Add(button);
        }

        private void DiscRow(TabPage page, TextBox field, int number, int y)
        {
            LabelAt(page, "Integral Japan — Disc " + number + (number == 1 ? " (SLPM-86247)" : " (SLPM-86248)"), y);
            field.SetBounds(16, y + 27, 505, 26);
            page.Controls.Add(field);
            AddButton(page.Controls, "Browse…", 532, y + 23, delegate {
                using (var dialog = new OpenFileDialog { Filter = "PlayStation disc cues (*.cue)|*.cue", CheckFileExists = true, Title = "Select Integral Disc " + number })
                    if (dialog.ShowDialog(this) == DialogResult.OK) field.Text = dialog.FileName;
            });
        }

        private void BuildDisplay()
        {
            var page = Page("Discs and display");
            DiscRow(page, discOne, 1, 16);
            DiscRow(page, discTwo, 2, 85);
            LabelAt(page, "Keep each CUE beside its matching BIN. No extraction or VR disc is needed.", 151);
            LabelAt(page, "Output resolution", 173);
            resolution.SetBounds(16, 200, 220, 28);
            resolution.Items.AddRange(new object[] { "640x480", "1280x720", "1280x960", "1600x900", "1920x1080", "2560x1440" });
            page.Controls.Add(resolution);
            CheckAt(page, wide, "Widescreen (expand the scene view)", 237);
            CheckAt(page, fullscreen, "Fullscreen", 267);
        }

        private void BuildGraphics()
        {
            var page = Page("Graphics");
            LabelAt(page, BuildInfo.ModernRenderer ? "Modern renderer — experimental enhancements" :
                "These enhancements require the experimental modern renderer build.", 18);
            CheckAt(page, textureCorrection, "Perspective-correct textures", 64);
            CheckAt(page, geometryPrecision, "Subpixel geometry (reduce polygon jitter)", 104);
            CheckAt(page, depthBuffer, "Depth buffer (per-pixel surface visibility)", 144);
            LabelAt(page, "Applies to projected models. Screen effects keep their original rendering.", 206);
            LabelAt(page, "Depth testing may change overlapping surfaces; compare with it off.", 242);
        }

        private static void CheckAt(Control parent, CheckBox field, string text, int y)
        {
            field.Text = text;
            field.SetBounds(16, y, 630, 26);
            parent.Controls.Add(field);
        }

        private void BuildGameplay()
        {
            var page = Page("Gameplay");
            CheckAt(page, bonus, "Start with Stealth Camouflage and Bandana", 18);
            CheckAt(page, invulnerable, "Invulnerability (testing; scripted deaths still apply)", 58);
            CheckAt(page, autoCard, "Use owned access cards without equipping them", 98);
            CheckAt(page, fastLoading, "Faster map loading (experimental)", 138);
            LabelAt(page, "Psycho Mantis memory reading: off, random, or a numeric seed", 185);
            mantis.SetBounds(16, 214, 280, 28);
            mantis.Items.AddRange(new object[] { "off", "random" });
            page.Controls.Add(mantis);
            LabelAt(page, "Controller-port swap: F2 or press both sticks (L3 + R3).", 260);
            LabelAt(page, "Bonus items persist in ordinary saves. Other options apply to this launch.", 295);
        }

        private void BuildAdvanced()
        {
            var page = Page("Developer options");
            CheckAt(page, overlay, "Show debug overlay", 12);
            LabelAt(page, "Startup stage (normally title)                 Frame limit (0 = unlimited)", 52);
            stage.SetBounds(16, 80, 260, 26);
            frames.SetBounds(320, 80, 260, 26);
            page.Controls.Add(stage);
            page.Controls.Add(frames);
            LabelAt(page, "Additional engine arguments (applied after the options above)", 124);
            advanced.SetBounds(16, 155, 646, 82);
            advanced.Multiline = true;
            advanced.ScrollBars = ScrollBars.Vertical;
            page.Controls.Add(advanced);
            AddButton(page.Controls, "Show command", 16, 252, delegate { Guard(ShowCommand); });
            AddButton(page.Controls, "Argument help", 160, 252, delegate { Guard(ShowHelp); });
            LabelAt(page, "Quote paths containing spaces. Direct stage entry does not set campaign state.", 297);
        }

        private void LanguageRow(TabPage page, TextBox field, string label, int y)
        {
            LabelAt(page, label, y);
            field.SetBounds(16, y + 27, 505, 26);
            page.Controls.Add(field);
            AddButton(page.Controls, "Browse…", 532, y + 23, delegate {
                using (var dialog = new OpenFileDialog { Filter = "Language packs (*.mgslang)|*.mgslang", CheckFileExists = true })
                    if (dialog.ShowDialog(this) == DialogResult.OK) field.Text = dialog.FileName;
            });
        }

        private void BuildLanguages()
        {
            var page = Page("Languages");
            LanguageRow(page, textPack, "Text pack — inventory and matched dialogue", 16);
            LanguageRow(page, voicePack, "Speech pack — voices with their timed subtitles", 94);
            LabelAt(page, "Leave a field empty to use Integral. Packs are imported from your own discs.", 180);
            LabelAt(page, "Coverage is partial: unmatched dialogue and movies retain Integral English.", 216);
            LabelAt(page, "Integral stages, models and game scripts remain in use.", 252);
            AddButton(page.Controls, "Use Integral", 16, 282, delegate { textPack.Clear(); voicePack.Clear(); });
            AddButton(page.Controls, "Import from discs…", 164, 282, delegate { Guard(ImportLanguage); });
        }

        private void ImportLanguage()
        {
            using (var dialog = new LanguageImportDialog(dataDirectory, discOne.Text, discTwo.Text))
            {
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                textPack.Text = dialog.PackPath;
                voicePack.Text = dialog.PackPath;
                Save();
                status.Text = "Language imported and selected for text and speech.";
            }
        }

        private void LoadSettings(Settings value)
        {
            discOne.Text = value.DiscOne; discTwo.Text = value.DiscTwo;
            textPack.Text = value.TextPack; voicePack.Text = value.VoicePack;
            resolution.Text = value.Resolution; wide.Checked = value.Widescreen;
            fullscreen.Checked = value.Fullscreen; bonus.Checked = value.BonusItems;
            textureCorrection.Checked = value.TextureCorrection;
            geometryPrecision.Checked = value.GeometryPrecision;
            depthBuffer.Checked = value.DepthBuffer;
            invulnerable.Checked = value.Invulnerable; autoCard.Checked = value.AutoCard;
            fastLoading.Checked = value.FastLoading;
            overlay.Checked = value.DebugOverlay; mantis.Text = value.MantisMemory;
            stage.Text = value.Stage; frames.Text = value.Frames; advanced.Text = value.Advanced;
        }

        private Settings ReadSettings()
        {
            return new Settings { DiscOne = AbsolutePath(discOne.Text), DiscTwo = AbsolutePath(discTwo.Text),
                TextPack = AbsolutePath(textPack.Text), VoicePack = AbsolutePath(voicePack.Text),
                Resolution = resolution.Text.Trim(), Widescreen = wide.Checked, Fullscreen = fullscreen.Checked,
                TextureCorrection = textureCorrection.Checked,
                GeometryPrecision = geometryPrecision.Checked, DepthBuffer = depthBuffer.Checked,
                BonusItems = bonus.Checked, Invulnerable = invulnerable.Checked, AutoCard = autoCard.Checked,
                FastLoading = fastLoading.Checked,
                DebugOverlay = overlay.Checked, MantisMemory = mantis.Text.Trim(), Stage = stage.Text.Trim(),
                Frames = frames.Text.Trim(), Advanced = advanced.Text.Replace("\r", " ").Replace("\n", " ") };
        }

        private static string AbsolutePath(string value)
        {
            return String.IsNullOrWhiteSpace(value) ? "" : Path.GetFullPath(value.Trim());
        }

        private void Save()
        {
            var settings = ReadSettings();
            GameLaunch.Arguments(settings);
            settings.Save(settingsPath);
            status.Text = "Settings saved in " + dataDirectory;
        }

        private async Task Play()
        {
            validating = true;
            play.Enabled = false;
            tabs.Enabled = false;
            status.Text = "Validating your discs and language packs…";
            try
            {
                var settings = ReadSettings();
                activeArguments = GameLaunch.Arguments(settings);
                await GameLaunch.ValidateDisc(executable, settings.DiscOne, 1, dataDirectory);
                await GameLaunch.ValidateDisc(executable, settings.DiscTwo, 2, dataDirectory);
                await GameLaunch.ValidateLanguage(executable, settings.TextPack, dataDirectory);
                if (settings.VoicePack != settings.TextPack)
                    await GameLaunch.ValidateLanguage(executable, settings.VoicePack, dataDirectory);
                settings.Save(settingsPath);
                rapidRestarts = 0;
                StartGame();
            }
            catch (Exception error)
            {
                status.Text = "Setup needs attention.";
                MessageBox.Show(this, error.Message, "RE:INTEGRAL", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                validating = false;
                play.Enabled = game == null;
                tabs.Enabled = game == null;
            }
        }

        private void StartGame()
        {
            string path = Path.Combine(dataDirectory, "logs", DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-fff") + ".log");
            log = new StreamWriter(path, true) { AutoFlush = true };
            log.WriteLine("RE:INTEGRAL " + BuildInfo.Version + " (" + BuildInfo.Commit + ")");
            log.WriteLine(activeArguments);
            game = new Process { StartInfo = GameLaunch.StartInfo(executable, activeArguments, dataDirectory) };
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

        private void TickGame(object sender, EventArgs args)
        {
            if (smoke)
            {
                smoke = false;
                using (var preview = new Bitmap(Width, Height))
                {
                    for (int index = 0; index < tabs.TabCount; ++index)
                    {
                        tabs.SelectedIndex = index;
                        DrawToBitmap(preview, new Rectangle(0, 0, Width, Height));
                        preview.Save(Path.Combine(dataDirectory, "launcher-" + index + ".png"));
                    }
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
            game.Dispose(); game = null;
            log.Dispose(); log = null;
            play.Enabled = true;
            tabs.Enabled = true;
            if (code == 75)
            {
                rapidRestarts = (DateTime.UtcNow - started).TotalSeconds > 5 ? 0 : rapidRestarts + 1;
                if (rapidRestarts < 3) { Guard(StartGame); return; }
            }
            status.Text = code == 0 ? "Game closed. Ready to play again." : "Game exited with code " + code + ". Open logs for details.";
            if (code != 0) MessageBox.Show(this, status.Text, "RE:INTEGRAL", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }

        private void ClosingLauncher(object sender, FormClosingEventArgs args)
        {
            if (game == null && !validating) return;
            args.Cancel = true;
            MessageBox.Show(this, "Close the game before closing the launcher.", "RE:INTEGRAL");
        }

        private void ShowCommand()
        {
            MessageBox.Show(this, GameLaunch.Quote(executable) + " " + GameLaunch.Arguments(ReadSettings()), "Launch command");
        }

        private void ShowHelp()
        {
            using (var process = Process.Start(GameLaunch.StartInfo(executable, "--help", dataDirectory)))
            {
                string help = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();
                process.WaitForExit();
                if (process.ExitCode != 0) throw new IOException(error);
                MessageBox.Show(this, help, "Engine arguments");
            }
        }

        private void OpenFolder(string name)
        {
            Process.Start(new ProcessStartInfo(Path.Combine(dataDirectory, name)) { UseShellExecute = true });
        }

        private void Guard(Action action)
        {
            try { action(); }
            catch (Exception error) { MessageBox.Show(this, error.Message, "RE:INTEGRAL", MessageBoxButtons.OK, MessageBoxIcon.Error); }
        }
    }

    public static class Program
    {
        [STAThread]
        public static int Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            try
            {
                string data = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RE-INTEGRAL");
                bool smoke = args.Length == 3 && args[0] == "--smoke-ui" && args[1] == "--data-dir";
                if (smoke) data = Path.GetFullPath(args[2]);
                else if (args.Length != 0) throw new ArgumentException("Launch RE-INTEGRAL.exe without arguments to configure the game.");
                using (var launcher = new Launcher(data, smoke)) Application.Run(launcher);
                return 0;
            }
            catch (Exception error)
            {
                MessageBox.Show(error.Message + "\n\nClose any other launcher instance. If settings.xml is damaged, move it aside and try again.",
                    "RE:INTEGRAL startup", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
        }
    }
}
