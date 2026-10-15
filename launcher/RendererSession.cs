using System;
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
    }

    internal static class RendererSession
    {
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
