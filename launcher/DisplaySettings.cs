using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text.RegularExpressions;

namespace ReIntegral
{
    public static class DisplaySettings
    {
        public static readonly string[] Resolutions = { "320x240", "640x480", "1280x720", "1280x960", "1600x900", "1920x1080", "2560x1440" };
        public static void Validate(Settings settings)
        {
            var match = Regex.Match(settings.Resolution ?? "", "^([0-9]{3,4})x([0-9]{3,4})$");
            if (!match.Success) throw new ArgumentException("Resolution must use WIDTHxHEIGHT, such as 1920x1080.");
            int width = Int32.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
            int height = Int32.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture);
            if (width < 320 || width > 2560 || height < 240 || height > (settings.Widescreen ? 1792 : 1920))
                throw new ArgumentException("This renderer supports up to 2560x1792 widescreen or 2560x1920 original aspect.");
            if (settings.Widescreen && (width * 3 < height * 4 || width * 3 > height * 12))
                throw new ArgumentException("Widescreen aspect ratio must be between 4:3 and 4:1.");
        }

        public static Dictionary<string, object> Values(Settings settings)
        {
            return new Dictionary<string, object> {
                { "display.resolution", settings.Resolution },
                { "display.widescreen", settings.Widescreen },
                { "display.fullscreen", settings.Fullscreen }
            };
        }

        public static void Assign(Settings settings, IDictionary<string, object> changes)
        {
            if (changes == null || changes.Count == 0) throw new ArgumentException("No settings changes supplied.");
            var candidate = new Settings { Resolution = settings.Resolution, Widescreen = settings.Widescreen, Fullscreen = settings.Fullscreen };
            foreach (var pair in changes)
            {
                switch (pair.Key)
                {
                    case "display.resolution":
                        if (!(pair.Value is string)) throw new ArgumentException("Resolution must be a string.");
                        candidate.Resolution = (string)pair.Value;
                        break;
                    case "display.widescreen":
                    case "display.fullscreen":
                        if (!(pair.Value is bool)) throw new ArgumentException(pair.Key + " must be a boolean.");
                        if (pair.Key == "display.widescreen") candidate.Widescreen = (bool)pair.Value;
                        else candidate.Fullscreen = (bool)pair.Value;
                        break;
                    default: throw new ArgumentException("Unknown setting: " + pair.Key);
                }
            }
            Validate(candidate);
            settings.Resolution = candidate.Resolution;
            settings.Widescreen = candidate.Widescreen;
            settings.Fullscreen = candidate.Fullscreen;
        }

        public static object[] Describe()
        {
            return new object[] {
                new { id = "display.resolution", label = "Resolution", type = "string", owner = "display", application = "restart",
                    format = "WIDTHxHEIGHT", minimum = new[] { 320, 240 }, maximum = new[] { 2560, 1920 }, widescreen_maximum_height = 1792,
                    choices = Resolutions },
                new { id = "display.widescreen", label = "Widescreen", type = "boolean", owner = "display", application = "restart",
                    description = "Use the selected resolution's aspect; disabled uses original 4:3.", minimum_aspect = 4.0 / 3.0, maximum_aspect = 4.0 },
                new { id = "display.fullscreen", label = "Fullscreen", type = "boolean", owner = "display", application = "restart" }
            };
        }
    }
}
