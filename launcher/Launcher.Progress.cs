using System;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;

namespace ReIntegral
{
    public sealed partial class Launcher
    {
        private readonly ProgressBar startupBar = new ProgressBar();
        private int startupGeneration;
        private bool startupActive;

        private void BuildBanner()
        {
            var banner = new Panel { Left = 16, Top = 0, Width = 688, Height = 190, BackColor = Color.FromArgb(25, 28, 30) };
            var artwork = new Panel { Left = 0, Top = 0, Width = 688, Height = 126 };
            var logo = new PictureBox { Left = 0, Top = -28, Width = 688, Height = 190, SizeMode = PictureBoxSizeMode.Zoom };
            using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("logo.png"))
            using (var source = Image.FromStream(stream)) logo.Image = new Bitmap(source);
            logo.Disposed += delegate { logo.Image.Dispose(); };
            artwork.Controls.Add(logo);
            banner.Controls.Add(artwork);
            status.SetBounds(16, 126, 656, 36);
            status.ForeColor = Color.WhiteSmoke;
            status.TextAlign = ContentAlignment.MiddleCenter;
            status.AutoEllipsis = true;
            status.Text = "Ready. Your original disc images remain read-only.";
            banner.Controls.Add(status);
            status.BringToFront();
            startupBar.SetBounds(24, 170, 640, 12);
            startupBar.MarqueeAnimationSpeed = 25;
            startupBar.Visible = false;
            banner.Controls.Add(startupBar);
            Controls.Add(banner);
        }

        private void ShowStartupProgress(string message)
        {
            status.Text = message;
            int? percentage = StartupProgress.Percentage(message);
            startupBar.Style = percentage.HasValue ? ProgressBarStyle.Continuous : ProgressBarStyle.Marquee;
            startupBar.Value = percentage.GetValueOrDefault();
            startupBar.Visible = true;
        }

        private IProgress<string> BeginStartupProgress()
        {
            int generation = ++startupGeneration;
            startupActive = true;
            ShowStartupProgress("Starting renderer…");
            return new Progress<string>(message => {
                if (generation != startupGeneration) return;
                if (startupActive) ShowStartupProgress(message);
                else if (game != null && message.StartsWith("Settings ", StringComparison.Ordinal)) status.Text = message;
            });
        }

        private void FinishStartupProgress()
        {
            startupActive = false;
            startupBar.Visible = false;
        }
    }
}
