using System;
using System.IO;
using System.Windows.Forms;

namespace ReIntegral
{
    public sealed partial class Launcher
    {
        private readonly ComboBox rendererChoice = new ComboBox();
        private readonly Label rendererDetails = new Label();
        private readonly ComboBox godotMode = new ComboBox();
        private readonly CheckBox sharpText = new CheckBox();
        private RendererPackage activeRenderer;
        private RendererPackage SelectedRenderer { get { return (RendererPackage)rendererChoice.SelectedItem; } }

        private void BuildGraphics()
        {
            var page = Page("Graphics");
            LabelAt(page, "Renderer (applies when starting a new game session)", 12);
            rendererChoice.SetBounds(16, 42, 630, 28);
            rendererChoice.DropDownStyle = ComboBoxStyle.DropDownList;
            rendererChoice.SelectedIndexChanged += delegate { ShowRenderer(); };
            page.Controls.Add(rendererChoice);
            rendererDetails.SetBounds(16, 78, 630, 44);
            page.Controls.Add(rendererDetails);
            godotMode.SetBounds(16, 128, 630, 28);
            godotMode.DropDownStyle = ComboBoxStyle.DropDownList;
            godotMode.Items.AddRange(new object[] { "Godot scene rendering", "Legacy through Godot" });
            godotMode.SelectedIndex = 0;
            godotMode.SelectedIndexChanged += delegate { ShowRenderer(); };
            page.Controls.Add(godotMode);
            CheckAt(page, textureCorrection, "Perspective-correct textures", 166);
            CheckAt(page, geometryPrecision, "Subpixel geometry (reduce polygon jitter)", 200);
            CheckAt(page, depthBuffer, "Depth buffer (per-pixel surface visibility)", 234);
            CheckAt(page, sharpText, "High-quality text (Godot scene rendering)", 268);
            AddButton(page.Controls, "Renderer folder", 16, 316, delegate {
                Directory.CreateDirectory(Path.Combine(dataDirectory, "renderers"));
                Guard(delegate { OpenFolder("renderers"); });
            });
            AddButton(page.Controls, "Refresh", 158, 316, delegate { Guard(delegate { LoadRenderers(SelectedRenderer.Id); }); });
        }

        private void LoadRenderers(string savedId)
        {
            var packages = RendererCatalog.Discover(AppDomain.CurrentDomain.BaseDirectory, dataDirectory);
            var selected = RendererCatalog.Select(packages, savedId, BuildInfo.DefaultRenderer);
            rendererChoice.Items.Clear();
            rendererChoice.Items.AddRange(packages.ToArray());
            rendererChoice.SelectedItem = selected;
        }

        private void ShowRenderer()
        {
            var selected = SelectedRenderer;
            if (selected == null) return;
            godotMode.Enabled = selected.IsGodot;
            bool scene = selected.IsGodot && godotMode.SelectedIndex == 0;
            sharpText.Enabled = scene;
            textureCorrection.Enabled = geometryPrecision.Enabled = depthBuffer.Enabled = selected.Available && selected.NativeGraphicsOptions;
            rendererDetails.Text = !selected.Available ? selected.Error : selected.IsCompanion ?
                "Community presentation renderer. Godot visual mod ZIPs are not loaded; their selections are preserved." : selected.IsGodot && !scene ?
                "Native visuals presented through Godot. Scene lighting, PBR and Godot visual mod ZIPs are disabled." : selected.IsGodot ?
                "Godot lighting, shadows and materials. Enabled visual mod ZIPs are loaded from the Mods tab." :
                "Native renderer. Godot visual mod ZIPs are not loaded; their selections are preserved.";
            if (mods != null) mods.SetRenderer(scene);
        }
    }
}
