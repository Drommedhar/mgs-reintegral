using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using ReIntegral;

internal static class PresentationSessionTest
{
    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static void Peer(string mode)
    {
        var listener = new TcpListener(IPAddress.Loopback, Int32.Parse(Environment.GetEnvironmentVariable("MGS_PRESENTATION_PORT")));
        listener.Start();
        string ready = Environment.GetEnvironmentVariable("MGS_PRESENTATION_READY_FILE");
        var response = new { schema = 1, rendererId = Environment.GetEnvironmentVariable("MGS_PRESENTATION_RENDERER_ID"),
            pid = Process.GetCurrentProcess().Id,
            protocol = new { major = 15, minor = 30, mode = "commands", capabilities = mode == "ready-mismatch" ? 1 : 29 } };
        File.WriteAllText(ready + ".tmp", new JavaScriptSerializer().Serialize(response));
        File.Move(ready + ".tmp", ready);
        try
        {
            while (!listener.Pending())
            {
                if (File.Exists(Environment.GetEnvironmentVariable("MGS_PRESENTATION_STOP_FILE"))) return;
                System.Threading.Thread.Sleep(20);
            }
            using (var peer = listener.AcceptTcpClient())
            using (var stream = peer.GetStream())
            using (var reader = new BinaryReader(stream))
            using (var writer = new BinaryWriter(stream))
            {
                Require(reader.ReadUInt32() == 40 && reader.ReadUInt32() == 1, "Host did not send HELLO");
                Require(reader.ReadBytes(40).Length == 40, "Truncated host handshake");
                writer.Write(32u); writer.Write(0x80000001u); writer.Write(0u);
                writer.Write(14u); writer.Write(30u); writer.Write(29u);
                writer.Write(Guid.NewGuid().ToByteArray());
                writer.Flush();
            }
        }
        finally { listener.Stop(); }
    }

    private static RendererPackage Package(string directory, string mode)
    {
        string path = Path.Combine(directory, "renderer.json");
        File.WriteAllText(path, new JavaScriptSerializer().Serialize(new RendererManifest {
            schema = 1, launchApi = 2, id = "test." + mode, name = mode, version = "1", backend = "companion",
            nativeArchitecture = "x86", rendererArchitecture = "x86", executable = "native.exe", companionExecutable = "peer.exe",
            companionArguments = new[] { "--peer", mode }, protocol = new PresentationContract { major = 15, minor = 30, capabilities = 29, mode = "commands" }
        }));
        return RendererPackage.Read(path);
    }

    private static async Task CheckReady(string directory, Settings settings)
    {
        bool rejected = false;
        using (var session = new PresentationSession(Package(directory, "ready-mismatch"), directory))
        {
            try { await session.Start(settings, new Progress<string>()); }
            catch (InvalidDataException error) { rejected = error.Message.Contains("capabilities differ"); }
        }
        Require(rejected, "Startup capability mismatch was accepted");
        string record = Directory.GetFiles(Path.Combine(directory, "logs"), "renderer-test.ready-mismatch-*.ready.json")[0];
        var response = new JavaScriptSerializer().Deserialize<System.Collections.Generic.Dictionary<string, object>>(File.ReadAllText(record));
        bool alive;
        try { using (var process = Process.GetProcessById((int)response["pid"])) alive = !process.HasExited; }
        catch (ArgumentException) { alive = false; }
        Require(!alive, "Rejected renderer process survived session disposal");
    }

    private static async Task CheckHost(string directory, Settings settings)
    {
        var package = Package(directory, "handshake-mismatch");
        using (var session = new PresentationSession(package, directory))
        {
            await session.Start(settings, new Progress<string>());
            var start = GameLaunch.StartInfo(package.Executable, package.Arguments(settings), directory);
            session.Configure(start);
            using (var native = Process.Start(start))
            {
                var output = native.StandardOutput.ReadToEndAsync();
                var errors = native.StandardError.ReadToEndAsync();
                Task all = Task.WhenAll(output, errors);
                if (await Task.WhenAny(all, Task.Delay(20000)) != all)
                { native.Kill(); throw new TimeoutException("Mismatched native handshake did not terminate"); }
                await all;
                native.WaitForExit();
                string stderr = await errors;
                File.WriteAllText(Path.Combine(directory, "native-mismatch.log"), await output);
                File.WriteAllText(Path.Combine(directory, "native-mismatch.err"), stderr);
                Require(native.ExitCode != 0 && stderr.Contains("incompatible renderer negotiation"), "Native host accepted an incompatible runtime handshake");
            }
        }
    }

    private static async Task Run(string[] args)
    {
        Require(args.Length == 0 || args.Length == 4, "Usage: presentation_session_tests [new-evidence-directory native-executable disc-one disc-two]");
        bool live = args.Length == 4;
        string directory = live ? Path.GetFullPath(args[0]) : Path.Combine(Path.GetTempPath(), "reintegral-presentation-" + Guid.NewGuid().ToString("N"));
        Require(!Directory.Exists(directory), "Use a new test evidence directory");
        Directory.CreateDirectory(directory);
        Console.WriteLine("Presentation evidence: " + directory);
        File.Copy(live ? args[1] : typeof(RendererPackage).Assembly.Location, Path.Combine(directory, "native.exe"));
        File.Copy(Assembly.GetExecutingAssembly().Location, Path.Combine(directory, "peer.exe"));
        File.Copy(typeof(RendererPackage).Assembly.Location, Path.Combine(directory, "RE-INTEGRAL.exe"));
        var settings = new Settings { Stage = "d00a", Frames = "1", Resolution = "1280x720" };
        if (live) { settings.DiscOne = args[2]; settings.DiscTwo = args[3]; }
        await CheckReady(directory, settings);
        if (live) await CheckHost(directory, settings);
        Console.WriteLine("PRESENTATION_SESSION_TEST failures=0");
    }

    public static int Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--peer") { Peer(args[1]); return 0; }
        Run(args).GetAwaiter().GetResult();
        return 0;
    }
}
