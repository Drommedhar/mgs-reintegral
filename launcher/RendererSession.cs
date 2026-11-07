using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Threading.Tasks;

namespace ReIntegral
{
    public interface IRendererSession : IDisposable
    {
        Task Start(Settings settings, IProgress<string> progress);
        void Configure(ProcessStartInfo native);
        void WriteDiagnostics(TextWriter writer);
    }

    internal static class RendererSession
    {
        internal static void WriteDiagnostics(TextWriter writer, string name, string prefix, int? exitCode)
        {
            if (prefix == null)
            {
                writer.WriteLine(name + " renderer was not started.");
                return;
            }
            writer.WriteLine(name + (exitCode.HasValue
                ? " renderer exited with code " + exitCode.Value + " (0x" + exitCode.Value.ToString("X8") + ")."
                : " renderer was stopped by launcher cleanup."));
            WriteLogTail(writer, prefix + ".log", 40);
            WriteLogTail(writer, prefix + ".err", 80);
        }

        private static void WriteLogTail(TextWriter writer, string path, int limit)
        {
            writer.WriteLine("Renderer log: " + path);
            if (!File.Exists(path))
            {
                writer.WriteLine("Log file is unavailable.");
                return;
            }
            var lines = new Queue<string>();
            foreach (string line in File.ReadLines(path))
            {
                lines.Enqueue(line);
                if (lines.Count > limit) lines.Dequeue();
            }
            foreach (string line in lines) writer.WriteLine("[renderer] " + line);
        }

        internal static string NewToken()
        {
            var bytes = new byte[16];
            using (var random = RandomNumberGenerator.Create()) random.GetBytes(bytes);
            return BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();
        }

        internal static string ReservePort()
        {
            var listener = new TcpListener(IPAddress.Loopback, 0);
            listener.Start();
            try { return ((IPEndPoint)listener.LocalEndpoint).Port.ToString(); }
            finally { listener.Stop(); }
        }

        internal static async Task CopyLog(StreamReader reader, string path, Action<string> onLine = null)
        {
            using (var writer = new StreamWriter(path) { AutoFlush = true })
            {
                string line;
                while ((line = await reader.ReadLineAsync().ConfigureAwait(false)) != null)
                {
                    await writer.WriteLineAsync(line).ConfigureAwait(false);
                    if (onLine != null) onLine(line);
                }
            }
        }
    }
}
