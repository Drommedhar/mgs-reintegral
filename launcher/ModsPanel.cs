using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace ReIntegral
{
    public sealed class ModsPanel : UserControl
    {
        private readonly CheckedListBox list = new CheckedListBox();
        private readonly string dataDirectory;
        private readonly Label status = new Label();
        private readonly Label description = new Label();
        private bool loading;
        public bool Busy { get; private set; }
        public event EventHandler Changed;
        public event EventHandler BusyChanged;

        public ModsPanel(string directory, bool supported)
        {
            dataDirectory = directory;
            Dock = DockStyle.Fill;
            description.SetBounds(4, 5, 630, 28);
            SetRenderer(supported);
            Controls.Add(description);
            list.SetBounds(4, 38, 630, 205);
            list.CheckOnClick = true;
            list.ItemCheck += delegate(object sender, ItemCheckEventArgs args) {
                if (loading) return;
                ((VisualMod)list.Items[args.Index]).Enabled = args.NewValue == CheckState.Checked;
                OnChanged();
            };
            Controls.Add(list);
            var add = new Button { Text = "Add ZIPs…", Left = 4, Top = 252, Width = 130, Height = 32, Enabled = supported };
            add.Click += async delegate { await AddPackages(); };
            Controls.Add(add);
            var remove = new Button { Text = "Remove", Left = 145, Top = 252, Width = 130, Height = 32 };
            remove.Click += delegate { if (list.SelectedIndex >= 0) { list.Items.RemoveAt(list.SelectedIndex); OnChanged(); } };
            Controls.Add(remove);
            status.SetBounds(4, 292, 630, 30);
            status.Text = "Selections are remembered. Uncheck a mod to disable it.";
            Controls.Add(status);
        }

        public void LoadMods(IEnumerable<VisualMod> mods)
        {
            loading = true;
            list.Items.Clear();
            foreach (var mod in mods) list.Items.Add(mod, mod.Enabled);
            loading = false;
        }

        public void SetRenderer(bool godot)
        {
            description.Text = godot ? "Add mod ZIPs, tick the ones you want, then Save and play." :
                "Godot visual ZIPs are kept here but will not load with the selected renderer.";
        }

        public List<VisualMod> ReadMods()
        {
            var result = new List<VisualMod>();
            foreach (VisualMod mod in list.Items) result.Add(mod);
            return result;
        }

        private void OnChanged() { if (Changed != null) Changed(this, EventArgs.Empty); }

        private async Task AddPackages()
        {
            using (var dialog = new OpenFileDialog { Filter = "Godot mod ZIPs (*.zip)|*.zip", Multiselect = true,
                CheckFileExists = true, Title = "Add mod ZIPs" })
            {
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                Busy = true;
                Enabled = false;
                if (BusyChanged != null) BusyChanged(this, EventArgs.Empty);
                try
                {
                    foreach (string zip in dialog.FileNames)
                    {
                        status.Text = "Installing " + System.IO.Path.GetFileName(zip) + "…";
                        var mod = await Task.Run(() => ModPackage.Install(zip, dataDirectory));
                        for (int index = list.Items.Count - 1; index >= 0; --index)
                            if (((VisualMod)list.Items[index]).Id == mod.Id) list.Items.RemoveAt(index);
                        loading = true;
                        list.Items.Add(mod, true);
                        loading = false;
                        OnChanged();
                    }
                    status.Text = "Installed and enabled. Press Save and play.";
                }
                catch (Exception error)
                {
                    status.Text = "Mod installation failed.";
                    MessageBox.Show(this, error.Message, "Install mod", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
                finally
                {
                    Busy = false;
                    Enabled = true;
                    if (BusyChanged != null) BusyChanged(this, EventArgs.Empty);
                }
            }
        }
    }
}
