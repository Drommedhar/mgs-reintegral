using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows.Forms;
using ReIntegral;

internal static class LauncherRendererLive
{
    private const BindingFlags Private = BindingFlags.Instance | BindingFlags.NonPublic;

    private static object Field(Launcher launcher, string name)
    {
        return typeof(Launcher).GetField(name, Private).GetValue(launcher);
    }

    private static object Call(Launcher launcher, string name, params object[] arguments)
    {
        return typeof(Launcher).GetMethod(name, Private).Invoke(launcher, arguments);
    }

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static async Task Run(Launcher launcher, string profile, string[] renderers)
    {
        var choice = (ComboBox)Field(launcher, "rendererChoice");
        var settings = Settings.Load(Path.Combine(profile, "settings.xml"));
        string marker = Path.Combine(profile, "save-continuity.marker");
        File.WriteAllText(marker, "same save directory");
        foreach (string id in renderers)
        {
            choice.SelectedItem = choice.Items.Cast<RendererPackage>().Single(entry => entry.Id == id);
            var package = (RendererPackage)choice.SelectedItem;
            package.RequireAvailable();
            Require(choice.Text == package.ToString(), "Renderer choice label is empty or incorrect");
            Call(launcher, "Save");
            var saved = Settings.Load(Path.Combine(profile, "settings.xml"));
            Require(saved.RendererId == id && saved.Mods.Count == settings.Mods.Count && saved.DiscOne == settings.DiscOne,
                "Selection did not persist or changed shared configuration");
            var tabs = (TabControl)Field(launcher, "tabs");
            tabs.SelectedIndex = 1;
            using (var image = new Bitmap(launcher.Width, launcher.Height))
            {
                launcher.DrawToBitmap(image, new Rectangle(0, 0, image.Width, image.Height));
                image.Save(Path.Combine(profile, "renderer-" + id + ".png"));
            }
            await (Task)Call(launcher, "Play");
            var game = (Process)Field(launcher, "game");
            Require(game != null, "Launcher did not create a native process");
            Require(Path.GetFullPath(game.StartInfo.FileName) == package.Executable, "Launcher started a different backend");
            Require(game.StartInfo.WorkingDirectory == profile, "Save directory changed with renderer");
            Require((Field(launcher, "godot") != null) == (package.IsGodot || package.IsCompanion), "Companion renderer ownership mismatch");
            if (package.IsGodot) Require(game.StartInfo.EnvironmentVariables["MGS_GODOT_SCENE_VIEW"] ==
                (saved.GodotLegacyRendering ? "0" : "1"), "Native rendering mode differs from saved selection");
            Console.WriteLine("STARTED " + id + " pid=" + game.Id + " executable=" + game.StartInfo.FileName);
            var deadline = Stopwatch.StartNew();
            while (Field(launcher, "game") != null && deadline.Elapsed.TotalSeconds < 45) await Task.Delay(100);
            Require(Field(launcher, "game") == null, "Native run did not terminate");
            Require(Field(launcher, "godot") == null, "Companion renderer was left running");
            Require(((Label)Field(launcher, "status")).Text.StartsWith("Game closed."), "Native run exited with an error");
            Require(File.ReadAllText(marker) == "same save directory", "Shared save marker changed");
            if (id == "godot")
            {
                string log = Directory.GetFiles(Path.Combine(profile, "logs"), "godot-*.log")
                    .Where(path => !path.EndsWith("-import.log")).OrderBy(File.GetLastWriteTimeUtc).Last();
                string output = File.ReadAllText(log);
                if (saved.GodotLegacyRendering)
                {
                    Require(output.Contains("MGS_WORLD_COMPOSITES 0"), "Legacy through Godot used scene composition");
                    Require(!output.Contains("phase=scene_initialize") && !output.Contains("phase=prepared_validation"), "Legacy mode loaded prepared scenes");
                    foreach (var mod in saved.Mods.Where(mod => mod.Enabled)) Require(!output.Contains(mod.Id), "Legacy mode loaded a scene mod: " + mod.Id);
                }
                else
                {
                    Require(System.Text.RegularExpressions.Regex.IsMatch(output, @"MGS_WORLD_COMPOSITES [1-9][0-9]*"), "Godot never presented the loaded world");
                    foreach (var mod in saved.Mods.Where(mod => mod.Enabled)) Require(output.Contains(mod.Id), "Enabled mod was not loaded: " + mod.Id);
                }
            }
            if (package.IsCompanion)
            {
                string output = File.ReadAllText(Directory.GetFiles(Path.Combine(profile, "logs"), "renderer-" + id + "-*.log").Single());
                Require(System.Text.RegularExpressions.Regex.IsMatch(output, @"COMMUNITY_RENDERER frames=[1-9][0-9]* triangles=[1-9][0-9]*"), "Community renderer did not present native geometry");
                Require(output.Contains("PRESENTATION_CONTEXT stage=" + saved.Stage), "Community renderer did not receive native context");
            }
            Console.WriteLine("FINISHED " + id);
        }
        Console.WriteLine("LAUNCHER_RENDERER_LIVE failures=0");
    }

    [STAThread]
    public static int Main(string[] args)
    {
        int result = 0;
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        if (args.Length > 1 && !String.IsNullOrEmpty(args[1]))
        {
            string settingsPath = Path.Combine(args[0], "settings.xml");
            var settings = Settings.Load(settingsPath);
            settings.Mods = new System.Collections.Generic.List<VisualMod> { ModPackage.Install(args[1], args[0]) };
            settings.Save(settingsPath);
        }
        using (var launcher = new Launcher(Path.GetFullPath(args[0]), false))
        {
            launcher.Shown += async delegate {
                try { await Run(launcher, Path.GetFullPath(args[0]), args.Length > 2 ? args[2].Split(',') : new[] { "legacy", "godot" }); }
                catch (Exception error) { Console.Error.WriteLine(error); result = 1; }
                finally
                {
                    var game = (Process)Field(launcher, "game");
                    if (game != null && !game.HasExited) { game.Kill(); game.WaitForExit(); }
                    Call(launcher, "StopGodot");
                    typeof(Launcher).GetField("game", Private).SetValue(launcher, null);
                    launcher.Close();
                }
            };
            Application.Run(launcher);
        }
        return result;
    }
}
