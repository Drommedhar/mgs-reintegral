using System;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using ReIntegral;

public static class ImportTests
{
    private sealed class ProgressSink : IProgress<string>
    {
        public Action<string> OnReport = delegate { };
        public void Report(string value) { OnReport(value); }
    }

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static string Argument(string[] args, string name)
    {
        return args[Array.IndexOf(args, name) + 1];
    }

    private static int FakeTool(string[] args)
    {
        if (args[0] == "--check-language") return File.ReadAllText(args[1]) == "ok" ? 0 : 2;
        string output = Argument(args, "--output");
        string mode = File.ReadAllText(Argument(args, "--disc-one"));
        Require(Path.GetFullPath(Path.GetTempPath()).TrimEnd('\\') == Path.GetDirectoryName(output),
            "Temporary files escaped the import staging directory");
        File.WriteAllText(output, mode);
        File.WriteAllText(Path.ChangeExtension(output, ".json"), "{}");
        if (mode == "fail") { Console.Error.WriteLine("Unsupported donor revision"); return 2; }
        if (mode == "wait")
        {
            Directory.CreateDirectory(Path.Combine(Path.GetTempPath(), "temporary"));
            Console.WriteLine("Waiting for cancellation");
            Console.Out.Flush();
            Thread.Sleep(30000);
            return 3;
        }
        if (mode == "missing") File.Delete(Path.ChangeExtension(output, ".json"));
        return 0;
    }

    private static async Task CheckImports(string directory)
    {
        string tool = Assembly.GetExecutingAssembly().Location;
        string disc = Path.Combine(directory, "disc ü 日本語.bin");
        File.WriteAllText(disc, "ok");
        var request = new LanguageImportRequest { Language = "de", DiscOne = disc, DiscTwo = disc, BaseOne = disc, BaseTwo = disc };
        var progress = new ProgressSink();
        string first = await LanguageImport.Run(tool, tool, request, directory, progress, CancellationToken.None);
        Require(File.ReadAllText(first) == "ok", "Successful import was not installed");
        Require(File.Exists(Path.ChangeExtension(first, ".json")), "Receipt missing");
        string second = await LanguageImport.Run(tool, tool, request, directory, progress, CancellationToken.None);
        Require(first != second && File.ReadAllText(first) == "ok", "Existing pack was overwritten");
        foreach (string mode in new[] { "fail", "bad", "missing" })
        {
            File.WriteAllText(disc, mode);
            try
            {
                await LanguageImport.Run(tool, tool, request, directory, progress, CancellationToken.None);
                throw new InvalidOperationException("Accepted incomplete/failed import: " + mode);
            }
            catch (InvalidDataException) { }
            Require(Directory.GetDirectories(Path.Combine(directory, "languages")).Length == 2, "Failed import leaked files");
            Require(File.ReadAllText(disc) == mode, "Source image modified");
        }
        File.WriteAllText(disc, "wait");
        using (var cancellation = new CancellationTokenSource())
        {
            progress.OnReport = line => { if (line == "Waiting for cancellation") cancellation.Cancel(); };
            try
            {
                await LanguageImport.Run(tool, tool, request, directory, progress, cancellation.Token);
                throw new InvalidOperationException("Cancellation did not stop the importer");
            }
            catch (OperationCanceledException) { }
        }
        Require(Directory.GetDirectories(Path.Combine(directory, "languages")).Length == 2, "Cancelled import leaked files");
        Require(File.ReadAllText(disc) == "wait" && File.ReadAllText(first) == "ok", "Cancellation changed an existing file");
        request.DiscTwo = Path.Combine(directory, "missing.bin");
        try
        {
            await LanguageImport.Run(tool, tool, request, directory, progress, CancellationToken.None);
            throw new InvalidOperationException("Accepted a missing disc");
        }
        catch (FileNotFoundException) { }
    }

    public static int Main(string[] args)
    {
        if (args.Length > 0) return FakeTool(args);
        string directory = Path.Combine(Path.GetTempPath(), "reintegral import ü 日本語 " + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try { CheckImports(directory).GetAwaiter().GetResult(); }
        finally { Directory.Delete(directory, true); }
        Console.WriteLine("Import success, repeat import, failure, corrupt output, missing receipt, cancellation, Unicode paths and read-only checks passed.");
        return 0;
    }
}
