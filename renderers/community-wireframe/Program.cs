using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace CommunityWireframe
{
    internal sealed class RendererWindow : Form
    {
        private readonly Surface surface = new Surface();
        private readonly object gate = new object();
        private readonly Wire wire = new Wire(Environment.GetEnvironmentVariable("MGS_PRESENTATION_TOKEN"));
        private volatile bool quit;
        private volatile uint buttons;
        private bool finished;
        private int frames;
        private readonly Keys[] keys = { Keys.W, Keys.E, Keys.Q, Keys.R, Keys.S, Keys.D, Keys.X, Keys.Z,
            Keys.Back, Keys.D1, Keys.D2, Keys.Enter, Keys.Up, Keys.Right, Keys.Down, Keys.Left };

        internal RendererWindow()
        {
            Text = "Community wireframe renderer — integration sample";
            DoubleBuffered = true;
            BackColor = Color.Black;
            string[] size = (Environment.GetEnvironmentVariable("MGS_PRESENTATION_RESOLUTION") ?? "1280x720").Split('x');
            ClientSize = new Size(Int32.Parse(size[0]), Int32.Parse(size[1]));
            if (Environment.GetEnvironmentVariable("MGS_PRESENTATION_FULLSCREEN") == "1")
            { FormBorderStyle = FormBorderStyle.None; WindowState = FormWindowState.Maximized; }
            Shown += async delegate {
                try { await Task.Run((Action)Serve); }
                catch (Exception error) { Console.Error.WriteLine(error); Environment.ExitCode = 1; }
                finally { finished = true; Close(); }
            };
            FormClosing += delegate(object sender, FormClosingEventArgs args) { if (!finished) { quit = true; args.Cancel = true; } };
            Deactivate += delegate { buttons = 0; };
        }

        protected override bool IsInputKey(Keys keyData) { return Array.IndexOf(keys, keyData) >= 0 || base.IsInputKey(keyData); }
        protected override void OnKeyDown(KeyEventArgs args) { SetKey(args.KeyCode, true); base.OnKeyDown(args); }
        protected override void OnKeyUp(KeyEventArgs args) { SetKey(args.KeyCode, false); base.OnKeyUp(args); }
        private void SetKey(Keys key, bool down)
        {
            int index = Array.IndexOf(keys, key);
            if (index >= 0) buttons = down ? buttons | (1u << index) : buttons & ~(1u << index);
        }

        protected override void OnPaint(PaintEventArgs args)
        {
            base.OnPaint(args);
            lock (gate)
            {
                if (surface.Enabled)
                {
                    args.Graphics.InterpolationMode = InterpolationMode.NearestNeighbor;
                    args.Graphics.DrawImage(surface.Image, ClientRectangle, surface.View, GraphicsUnit.Pixel);
                }
                Text = "Community wireframe — " + wire.Stage + " — native tick " + wire.Tick + " — pause " + wire.Pause;
            }
        }

        private void Serve()
        {
            var listener = new TcpListener(IPAddress.Loopback, Int32.Parse(Environment.GetEnvironmentVariable("MGS_PRESENTATION_PORT")));
            listener.Start(1);
            try
            {
                Ready();
                var deadline = DateTime.UtcNow.AddSeconds(30);
                while (!listener.Pending())
                {
                    if (ShouldStop()) return;
                    if (DateTime.UtcNow > deadline) throw new TimeoutException("Native host did not connect.");
                    System.Threading.Thread.Sleep(20);
                }
                using (var client = listener.AcceptTcpClient())
                {
                    client.NoDelay = true;
                    client.ReceiveTimeout = client.SendTimeout = 30000;
                    Consume(client.GetStream());
                }
            }
            finally { listener.Stop(); }
            Console.WriteLine("COMMUNITY_RENDERER frames=" + frames + " triangles=" + surface.Triangles + " stage=" + wire.Stage);
        }

        private bool ShouldStop()
        {
            return quit || File.Exists(Environment.GetEnvironmentVariable("MGS_PRESENTATION_STOP_FILE"));
        }

        private static void Ready()
        {
            string path = Environment.GetEnvironmentVariable("MGS_PRESENTATION_READY_FILE");
            var ready = new { schema = 1, rendererId = Environment.GetEnvironmentVariable("MGS_PRESENTATION_RENDERER_ID"),
                protocol = new { major = 15, minor = 30, mode = "commands", capabilities = Wire.Capabilities } };
            File.WriteAllText(path + ".tmp", new JavaScriptSerializer().Serialize(ready));
            File.Move(path + ".tmp", path);
        }

        private void Consume(Stream stream)
        {
            byte[] prefix;
            while ((prefix = Wire.Read(stream, 8, true)) != null)
            {
                uint size = Wire.U32(prefix, 0), operation = Wire.U32(prefix, 4);
                Wire.Require(size <= 64 * 1024 * 1024 - 8, "Presentation packet exceeds 64 MiB.");
                byte[] body = Wire.Read(stream, (int)size, false), reply = null;
                lock (gate)
                {
                    if (operation == 1) reply = wire.Hello(body);
                    else { wire.Accept(operation); reply = Dispatch(operation, body); }
                }
                if (reply != null) Wire.Reply(stream, operation, buttons | (ShouldStop() ? 0x80000000u : 0), reply);
                if (operation == 7) BeginInvoke((Action)Invalidate);
            }
        }

        private byte[] Dispatch(uint operation, byte[] body)
        {
            switch (operation)
            {
                case 2: surface.Draw(body); break;
                case 3: surface.Upload(body); break;
                case 4: surface.Move(body); break;
                case 5: return surface.Read(body);
                case 6: Wire.Require(body.Length == 0, "Invalid SYNC."); return new byte[0];
                case 7: surface.Frame(body); ++frames; return new byte[0];
                case 8: surface.Clear(body); break;
                case 11: Wire.Require(body.Length <= 255, "Invalid DEBUG_TEXT."); break;
                case 12: wire.Context(body); break;
            }
            return null;
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) surface.Dispose();
            base.Dispose(disposing);
        }
    }

    internal static class Program
    {
        [STAThread]
        private static int Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            try { using (var window = new RendererWindow()) Application.Run(window); }
            catch (Exception error) { Console.Error.WriteLine(error); return 1; }
            return Environment.ExitCode;
        }
    }
}
