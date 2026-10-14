using System;
using System.Text.RegularExpressions;

namespace ReIntegral
{
    internal static class StartupProgress
    {
        internal static int? Percentage(string message)
        {
            var percent = Regex.Match(message, @"^[^—()]+\((\d+)%\)");
            int value;
            if (percent.Success && Int32.TryParse(percent.Groups[1].Value, out value))
                return Math.Min(100, Math.Max(0, value));
            var counts = Regex.Match(message, @"\b(\d+)\s*/\s*(\d+)\b");
            long completed, total;
            if (counts.Success && Int64.TryParse(counts.Groups[1].Value, out completed) &&
                Int64.TryParse(counts.Groups[2].Value, out total) && total > 0)
                return (int)Math.Min(100, 100.0 * completed / total);
            return null;
        }
    }
}
