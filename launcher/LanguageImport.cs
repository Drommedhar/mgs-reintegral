using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace ReIntegral
{
    public sealed class LanguageImportRequest
    {
        public string Language, DiscOne, DiscTwo, BaseOne, BaseTwo;

        public string Arguments(string output)
        {
            if (Language != "de" && Language != "en") throw new ArgumentException("Select German or US English.");
            return "--language " + Language + " --disc-one " + Disc(DiscOne, "Regional Disc 1") +
                " --disc-two " + Disc(DiscTwo, "Regional Disc 2") + " --base-one " + Disc(BaseOne, "Integral Disc 1") +
                " --base-two " + Disc(BaseTwo, "Integral Disc 2") + " --output " + GameLaunch.Quote(output);
        }

        private static string Disc(string path, string label)
        {
            if (String.IsNullOrWhiteSpace(path) || !File.Exists(path))
                throw new FileNotFoundException(label + ": select an existing BIN or CUE file.");
            string extension = Path.GetExtension(path);
            if (!extension.Equals(".cue", StringComparison.OrdinalIgnoreCase) &&
                !extension.Equals(".bin", StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException(label + ": select a BIN or CUE file.");
            return GameLaunch.Quote(Path.GetFullPath(path));
        }
    }

    public static class LanguageImport
    {
        public static async Task<string> Run(string importer, string engine, LanguageImportRequest request,
            string dataDirectory, IProgress<string> progress, CancellationToken cancellation)
        {
            if (!Environment.Is64BitOperatingSystem)
                throw new PlatformNotSupportedException("Creating language packs requires 64-bit Windows.");
            string root = Path.Combine(Path.GetFullPath(dataDirectory), "languages");
            string identity = Guid.NewGuid().ToString("N");
            string staging = Path.Combine(root, ".import-" + identity);
            string output = Path.Combine(staging, "pack.mgslang");
            string arguments = request.Arguments(output);
            if (!File.Exists(importer)) throw new FileNotFoundException("The language importer is missing. Extract the complete application download.", importer);
            if (!File.Exists(engine)) throw new FileNotFoundException("The game executable is missing.", engine);
            cancellation.ThrowIfCancellationRequested();
            Directory.CreateDirectory(staging);
            try
            {
                string logs = Path.Combine(dataDirectory, "logs");
                Directory.CreateDirectory(logs);
                string logPath = Path.Combine(logs, "language-import-" + identity + ".log");
                using (var log = new StreamWriter(logPath, false, Encoding.UTF8) { AutoFlush = true })
                {
                    progress.Report("Import log: " + logPath);
                    var start = GameLaunch.StartInfo(importer, arguments, staging);
                    start.EnvironmentVariables["TEMP"] = staging;
                    start.EnvironmentVariables["TMP"] = staging;
                    await RunProcess(start, log, progress, cancellation);
                    if (!File.Exists(output) || !File.Exists(Path.ChangeExtension(output, ".json")))
                        throw new InvalidDataException("Import did not produce a complete pack and receipt.");
                    progress.Report("Checking the completed language pack…");
                    await RunProcess(GameLaunch.StartInfo(engine, "--check-language " + GameLaunch.Quote(output), staging),
                        log, progress, cancellation);
                }
                cancellation.ThrowIfCancellationRequested();
                string destination = Path.Combine(root, request.Language + "-" + identity);
                Directory.Move(staging, destination);
                return Path.Combine(destination, "pack.mgslang");
            }
            finally
            {
                if (Directory.Exists(staging)) Directory.Delete(staging, true);
            }
        }

        private static async Task RunProcess(ProcessStartInfo start, StreamWriter log,
            IProgress<string> progress, CancellationToken cancellation)
        {
            cancellation.ThrowIfCancellationRequested();
            log.WriteLine(start.FileName + " " + start.Arguments);
            using (var process = new Process { StartInfo = start })
            {
                process.Start();
                using (cancellation.Register(delegate { Stop(process); }))
                {
                    await Task.WhenAll(ReadLines(process.StandardOutput, log, progress),
                        ReadLines(process.StandardError, log, progress), Task.Run(() => process.WaitForExit()));
                }
                cancellation.ThrowIfCancellationRequested();
                if (process.ExitCode != 0)
                    throw new InvalidDataException("Import stopped (exit " + process.ExitCode + "). See the import details below for the cause.");
            }
        }

        private static void Stop(Process process)
        {
            try { if (!process.HasExited) process.Kill(); }
            catch (InvalidOperationException) { if (!process.HasExited) throw; }
        }

        private static async Task ReadLines(StreamReader reader, StreamWriter log, IProgress<string> progress)
        {
            string line;
            while ((line = await reader.ReadLineAsync()) != null)
            {
                lock (log) log.WriteLine(line);
                progress.Report(line);
            }
        }
    }
}
