using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Xml;
using System.Xml.Serialization;

namespace ReIntegral
{
    public sealed class VisualMod
    {
        public string Id = "";
        public string Name = "";
        public string Package = "";
        public bool Enabled = true;

        public override string ToString() { return Name == Id ? Id : Name + " (" + Id + ")"; }
    }

    public sealed class Settings
    {
        public int Version = 1;
        public string RendererId = "";
        public bool GodotLegacyRendering;
        public bool GodotSharpText = true;
        public string DiscOne = "";
        public string DiscTwo = "";
        public string TextPack = "";
        public string VoicePack = "";
        public string Resolution = "1280x720";
        public bool Widescreen = true;
        public bool Fullscreen;
        public bool TextureCorrection;
        public bool GeometryPrecision;
        public bool DepthBuffer;
        public bool BonusItems;
        public bool Invulnerable;
        public bool AutoCard;
        public bool FastLoading;
        public bool CodecTurbo = true;
        public bool DebugOverlay;
        public string MantisMemory = "off";
        public string Stage = "title";
        public string Frames = "0";
        public string Advanced = "";
        public List<VisualMod> Mods = new List<VisualMod>();

        public static Settings Load(string path)
        {
            if (!File.Exists(path)) return new Settings();
            var options = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null };
            using (var reader = XmlReader.Create(path, options))
            {
                var settings = (Settings)new XmlSerializer(typeof(Settings)).Deserialize(reader);
                if (settings.Version != 1) throw new InvalidDataException("Unsupported settings version.");
                return settings;
            }
        }

        public void Save(string path)
        {
            string temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                using (var writer = new StreamWriter(temporary, false, new UTF8Encoding(false)))
                    new XmlSerializer(typeof(Settings)).Serialize(writer, this);
                if (File.Exists(path)) File.Replace(temporary, path, null);
                else File.Move(temporary, path);
            }
            finally
            {
                if (File.Exists(temporary)) File.Delete(temporary);
            }
        }
    }
}
