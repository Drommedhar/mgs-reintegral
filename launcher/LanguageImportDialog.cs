using System;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace ReIntegral
{
    public sealed class LanguageImportDialog : Form
    {
        private readonly string dataDirectory;
        private readonly ComboBox language = new ComboBox();
        private readonly TextBox baseOne = new TextBox(), baseTwo = new TextBox();
        private readonly TextBox discOne = new TextBox(), discTwo = new TextBox();
        private readonly Panel choices = new Panel();
        private readonly TextBox details = new TextBox();
        private readonly ProgressBar progress = new ProgressBar();
        private readonly Button import = new Button(), close = new Button();
        private CancellationTokenSource cancellation;
        public string PackPath { get; private set; }

        public LanguageImportDialog(string directory, string integralOne, string integralTwo)
        {
            dataDirectory = directory;
            Text = "Import a language from your discs";
            Font = new Font("Segoe UI", 9F);
            AutoScaleMode = AutoScaleMode.Dpi;
            ClientSize = new Size(680, 590);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterParent;
            BuildChoices();
            baseOne.Text = integralOne;
            baseTwo.Text = integralTwo;
            details.SetBounds(16, 382, 648, 132);
            details.Multiline = true;
            details.ReadOnly = true;
            details.ScrollBars = ScrollBars.Vertical;
            Controls.Add(details);
            progress.SetBounds(16, 526, 648, 12);
            Controls.Add(progress);
            import.Text = "Import and use";
            import.SetBounds(380, 550, 140, 28);
            import.Click += async delegate { await Import(); };
            close.Text = "Close";
            close.SetBounds(532, 550, 132, 28);
            close.Click += delegate { Close(); };
            Controls.Add(import);
            Controls.Add(close);
            FormClosing += delegate(object sender, FormClosingEventArgs args) {
                if (cancellation == null) return;
                args.Cancel = true;
                close.Enabled = false;
                Append("Cancelling import and removing unfinished files…");
                cancellation.Cancel();
            };
        }

        private void BuildChoices()
        {
            choices.SetBounds(0, 0, 680, 374);
            Controls.Add(choices);
            LabelAt("Regional release", 16);
            language.SetBounds(160, 12, 504, 28);
            language.DropDownStyle = ComboBoxStyle.DropDownList;
            language.Items.AddRange(new object[] { "German — SLES-01507 / SLES-11507", "US English v1.0 — SLUS-00594 / SLUS-00776" });
            language.SelectedIndex = 0;
            language.SelectedIndexChanged += delegate { discOne.Clear(); discTwo.Clear(); };
            choices.Controls.Add(language);
            DiscRow(baseOne, "Integral Disc 1 — SLPM-86247", 50);
            DiscRow(baseTwo, "Integral Disc 2 — SLPM-86248", 120);
            DiscRow(discOne, "Regional Disc 1", 190);
            DiscRow(discTwo, "Regional Disc 2", 260);
            var note = new Label { Left = 16, Top = 331, Width = 648, Height = 42,
                Text = "Creates a private local pack. Nothing is uploaded or downloaded.\nAllow several minutes and several GiB of free memory and disk space. Coverage is partial." };
            choices.Controls.Add(note);
        }

        private void LabelAt(string text, int y)
        {
            choices.Controls.Add(new Label { Text = text, Left = 16, Top = y, Width = 648, Height = 22 });
        }

        private void DiscRow(TextBox field, string label, int y)
        {
            LabelAt(label, y);
            field.SetBounds(16, y + 25, 504, 26);
            choices.Controls.Add(field);
            var browse = new Button { Text = "Browse…", Left = 532, Top = y + 23, Width = 132, Height = 28 };
            browse.Click += delegate {
                using (var picker = new OpenFileDialog { Title = label, CheckFileExists = true,
                    Filter = "PlayStation discs (*.cue;*.bin)|*.cue;*.bin" })
                    if (picker.ShowDialog(this) == DialogResult.OK) field.Text = picker.FileName;
            };
            choices.Controls.Add(browse);
        }

        private void Append(string message)
        {
            if (details.TextLength > 60000) details.Clear();
            details.AppendText(message + Environment.NewLine);
        }

        private async Task Import()
        {
            cancellation = new CancellationTokenSource();
            choices.Enabled = false;
            import.Enabled = false;
            close.Text = "Cancel import";
            progress.Style = ProgressBarStyle.Marquee;
            details.Clear();
            try
            {
                var request = new LanguageImportRequest { Language = language.SelectedIndex == 0 ? "de" : "en",
                    BaseOne = baseOne.Text.Trim(), BaseTwo = baseTwo.Text.Trim(),
                    DiscOne = discOne.Text.Trim(), DiscTwo = discTwo.Text.Trim() };
                string application = AppDomain.CurrentDomain.BaseDirectory;
                PackPath = await LanguageImport.Run(Path.Combine(application, "language-importer", "language-importer.exe"),
                    Path.Combine(application, "mgs-integral-native.exe"), request, dataDirectory,
                    new Progress<string>(Append), cancellation.Token);
            }
            catch (OperationCanceledException) { Append("Import cancelled. Your existing packs and disc images are unchanged."); }
            catch (Exception error) { Append("Import failed: " + error.Message); }
            finally
            {
                cancellation.Dispose();
                cancellation = null;
                choices.Enabled = true;
                import.Enabled = true;
                close.Enabled = true;
                close.Text = "Close";
                progress.Style = ProgressBarStyle.Blocks;
            }
            if (PackPath != null) { DialogResult = DialogResult.OK; Close(); }
        }
    }
}
