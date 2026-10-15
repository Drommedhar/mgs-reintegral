using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

namespace ReIntegral
{
    public sealed class SettingsBridge : IDisposable
    {
        private readonly TcpListener listener = new TcpListener(IPAddress.Loopback, 0);
        private readonly SettingsRegistry registry;
        private readonly string token;
        private readonly Action<string> report;
        private readonly object gate = new object();
        private readonly Thread worker;
        private Exception failure;
        private TcpClient client;
        private bool stopping;
        public int Port { get; private set; }

        public SettingsBridge(SettingsRegistry provider, string sessionToken, Action<string> reportError)
        {
            if (String.IsNullOrEmpty(sessionToken)) throw new ArgumentException("Settings bridge requires a session token.");
            registry = provider;
            token = sessionToken;
            report = reportError;
            listener.Start(4);
            Port = ((IPEndPoint)listener.LocalEndpoint).Port;
            worker = new Thread(Run) { IsBackground = true, Name = "MGS settings provider" };
            worker.Start();
        }

        private void Run()
        {
            try { Serve(); }
            catch (Exception error)
            {
                failure = error;
                report("Settings provider stopped: " + error.Message);
            }
        }

        private void Serve()
        {
            while (true)
            {
                try
                {
                    var accepted = listener.AcceptTcpClient();
                    lock (gate)
                    {
                        if (stopping) { accepted.Close(); return; }
                        client = accepted;
                    }
                    using (accepted)
                    {
                        accepted.ReceiveTimeout = accepted.SendTimeout = 3000;
                        accepted.NoDelay = true;
                        Exchange(accepted.GetStream());
                    }
                }
                catch (Exception error)
                {
                    if (!(error is IOException) && !(error is SocketException) && !(error is ObjectDisposedException)) throw;
                    lock (gate) { if (stopping) return; }
                    report("Settings connection failed: " + error.Message);
                }
                finally { lock (gate) { client = null; } }
            }
        }

        private void Exchange(NetworkStream stream)
        {
            var reader = new BinaryReader(stream, Encoding.UTF8, true);
            int size = reader.ReadInt32();
            if (size < 2 || size > 4096) throw new IOException("Invalid settings request length.");
            byte[] bytes = reader.ReadBytes(size);
            if (bytes.Length != size) throw new IOException("Truncated settings request.");
            var json = new JavaScriptSerializer { MaxJsonLength = 65536, RecursionLimit = 12 };
            var response = new Dictionary<string, object> { { "schema", 1 }, { "id", 0 }, { "error", "" } };
            try
            {
                var request = json.Deserialize<SettingsRequest>(new UTF8Encoding(false, true).GetString(bytes));
                if (request == null || request.token != token) throw new ArgumentException("Settings session token mismatch.");
                response["id"] = request.id;
                response["snapshot"] = registry.Execute(request);
            }
            catch (Exception error)
            {
                if (!(error is ArgumentException) && !(error is InvalidOperationException) && !(error is IOException)
                    && !(error is UnauthorizedAccessException)) throw;
                response["error"] = error.Message;
            }
            byte[] reply = Encoding.UTF8.GetBytes(json.Serialize(response));
            var writer = new BinaryWriter(stream, Encoding.UTF8, true);
            writer.Write(reply.Length);
            writer.Write(reply);
            writer.Flush();
        }

        public void Dispose()
        {
            lock (gate)
            {
                if (stopping) return;
                stopping = true;
                listener.Stop();
                if (client != null) client.Close();
            }
            worker.Join();
            if (failure != null) throw new InvalidOperationException("Settings provider failed.", failure);
        }
    }
}
